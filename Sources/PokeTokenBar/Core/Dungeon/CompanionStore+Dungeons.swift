import Foundation

/// The dungeons in the game: what opens them, the teams and their loops, the departure, the tokens walking the team,
/// the answers the player gives (emergency heal, throws, leaving), and the end, its loot in the Bag.
extension CompanionStore {
    var expedition: Expedition? { state.dungeons.expedition }
    var dungeonProgress: DungeonProgress { state.dungeons }

    /// Q1: while a team explores or waits for its heal, the Pokémon raised and the egg do not grow.
    var growthPaused: Bool {
        switch expedition?.phase {
        case .exploring?, .awaitingHeal?: true
        default: false
        }
    }

    private var expeditionContext: ExpeditionContext? {
        expedition.map { ExpeditionContext(tier: DungeonCatalog.dungeon($0.dungeon).tier,
                                           shinyDenominator: Int(shinyDenominator), now: currentDate) }
    }

    // MARK: Opening (Q27, R10, R11)

    /// The conditions still unmet for a dungeon to open; empty when it is open.
    func unmetUnlocks(_ id: DungeonID) -> [DungeonUnlock] {
        DungeonCatalog.dungeon(id).unlocks.filter { !isMet($0) }
    }

    func isMet(_ unlock: DungeonUnlock) -> Bool {
        let graduated = state.dex.filter { !$0.isReleased }
        switch unlock {
        case .graduated(let count): return graduated.count >= count
        case .won(let id): return state.dungeons.wins(id) > 0
        case .linesGraduated(let count): return graduatedCollectionProgress.lines >= count
        case .legendariesGraduated(let count):
            return Set(graduated.filter { $0.rarity == .legendary }.map(\.finalID)).count >= count
        case .beatBosses(let species): return species.allSatisfy(state.dungeons.beat)
        case .treasureMap: return itemCount(.treasureMap) > 0
        }
    }

    func isDungeonOpen(_ id: DungeonID) -> Bool { unmetUnlocks(id).isEmpty }

    /// The Legendary Keys an entry spends (R10, R11): the Ruins of Alph take their Treasure Map instead.
    func keysToEnter(_ id: DungeonID) -> Int { id == .ruinsOfAlph ? 0 : DungeonCatalog.dungeon(id).tier.keys }

    /// Whether a team may set off for it now: open, its keys in the Bag, no other expedition under way.
    func canEnter(_ id: DungeonID) -> Bool {
        expedition == nil && isDungeonOpen(id) && itemCount(.legendaryKey) >= keysToEnter(id)
    }

    // MARK: The team (Q5 to Q8, R4)

    /// The team's size and rules: the Ruins of Alph draw theirs for each visit.
    func teamRules(_ id: DungeonID) -> (size: Int, rules: [DungeonRule]) {
        if id == .ruinsOfAlph {
            let drawn = DungeonCatalog.alphRules(seed: UInt64(state.dungeons.departures) &+ 0xA1F)
            return (drawn.teamSize, drawn.rules)
        }
        let dungeon = DungeonCatalog.dungeon(id)
        return (dungeon.teamSize, dungeon.rules)
    }

    /// The graduated Pokémon a team is formed from (Q6: not sent off), those the battle table knows.
    var dungeonCandidates: [DexEntry] {
        state.dex.filter { !$0.isReleased && SpeciesBattleTable.data(speciesID: $0.finalID, form: $0.form) != nil }
    }

    /// A graduated Pokémon's battle self for a dungeon: its chosen loop, else the one suggested against the theme (none
    /// outside a dungeon, as on its Pokédex page).
    func dungeonSpec(_ entry: DexEntry, for id: DungeonID?) -> BattlerSpec? {
        DungeonTeamBuilder.spec(for: entry, loop: state.dungeons.moveLoops[entry.id], unlocked: state.dungeons.unlockedMoves,
                                theme: id.map { DungeonCatalog.dungeon($0).themeTypes } ?? [])
    }

    /// Its loop is frozen while it explores (R4: set outside an expedition).
    func isExploring(_ entryID: String) -> Bool { expedition?.team.contains { $0.entryID == entryID } == true }

    /// R4: the player's loop for a Pokémon, outside an expedition; an empty one goes back to the suggestion. Locked
    /// moves are refused.
    @discardableResult
    func setMoveLoop(_ moves: [String], for entryID: String) -> Bool {
        guard !isExploring(entryID) else { return false }
        let allowed = moves.filter { slug in
            guard let move = MoveTable.move(slug) else { return false }
            return !move.isLocked || state.dungeons.unlockedMoves.contains(slug)
        }
        guard allowed.count == moves.count, moves.count <= 4 else { return false }
        changeDungeons { $0.moveLoops[entryID] = moves.isEmpty ? nil : moves }
        persist()
        return true
    }

    /// Q8: the best team the rules allow against the dungeon's theme.
    func composeTeam(for id: DungeonID) -> [String] {
        let (size, rules) = teamRules(id)
        let pool = dungeonCandidates.compactMap { entry in dungeonSpec(entry, for: id).map { (DungeonCandidate(entry), $0) } }
        return DungeonTeamBuilder.compose(pool, dungeon: DungeonCatalog.dungeon(id), size: size, rules: rules)
    }

    /// R7: the odds this team reaches the boss.
    func reachOdds(team ids: [String], for id: DungeonID) -> Double {
        let members = ids.compactMap { id in state.dex.first { $0.id == id } }
            .compactMap { entry in dungeonSpec(entry, for: id).map { ExpeditionMember(entryID: entry.id, spec: $0) } }
        return DungeonTeamBuilder.reachOdds(team: members, dungeon: DungeonCatalog.dungeon(id),
                                            berries: bagBerries, revives: bagRevives)
    }

    private var bagBerries: [BattleBerry: Int] {
        [.oran: itemCount(.oranBerry), .sitrus: itemCount(.sitrusBerry)].filter { $0.value > 0 }
    }

    private var bagRevives: [String: Int] {
        [ItemKind.revive.rawValue: itemCount(.revive), ItemKind.maxRevive.rawValue: itemCount(.maxRevive)]
            .filter { $0.value > 0 }
    }

    // MARK: Departure

    /// Sets the team off: the rules held, the keys or the map spent, the Bag's berries and Revives taken along.
    @discardableResult
    func startExpedition(_ id: DungeonID, team ids: [String]) -> Bool {
        guard canEnter(id) else { return false }
        let entries = ids.compactMap { id in dungeonCandidates.first { $0.id == id } }
        let (size, rules) = teamRules(id)
        guard entries.count == ids.count,
              DungeonTeamRules.isValid(entries.map(DungeonCandidate.init), size: size, rules: rules) else { return false }
        let dungeon = DungeonCatalog.dungeon(id)
        let members = entries.compactMap { entry in dungeonSpec(entry, for: id).map { ExpeditionMember(entryID: entry.id, spec: $0) } }
        guard members.count == size else { return false }
        if id == .ruinsOfAlph { changeBag(.treasureMap, by: -1) }
        changeBag(.legendaryKey, by: -keysToEnter(id))
        let berries = bagBerries
        let revives = bagRevives
        changeBag(.oranBerry, by: -(berries[.oran] ?? 0))
        changeBag(.sitrusBerry, by: -(berries[.sitrus] ?? 0))
        changeBag(.revive, by: -(revives[ItemKind.revive.rawValue] ?? 0))
        changeBag(.maxRevive, by: -(revives[ItemKind.maxRevive.rawValue] ?? 0))
        let context = ExpeditionContext(tier: dungeon.tier, shinyDenominator: Int(shinyDenominator), now: currentDate)
        let seed = drawSeed() ^ UInt64(state.dungeons.departures + 1)
        let started = ExpeditionEngine.start(dungeon: dungeon, team: members, rules: rules, teamSize: size, seed: seed,
                                             cost: dungeon.tier.cost(difficulty: growthDifficulty), berries: berries,
                                             revives: revives, context: context)
        changeDungeons {
            $0.expedition = started
            $0.lastResult = nil
            $0.departures += 1
        }
        AppLog.write("dungeon: \(id.rawValue) set off, team \(ids.joined(separator: ","))")
        persist()
        return true
    }

    // MARK: Tokens

    /// Q1: while a team explores or waits for its heal, the tokens walk it instead of growing the Pokémon. Returns
    /// whether they went to the dungeon; once the boss fell, growth takes them again.
    func feedExpedition(_ tokens: Int) -> Bool {
        guard var e = expedition, let context = expeditionContext else { return false }
        switch e.phase {
        case .exploring, .awaitingHeal: break
        case .capture, .finished: return false
        }
        let reached = e.bossReached
        ExpeditionEngine.feed(&e, tokens: tokens, context: context)
        store(e, bossNewlyReached: !reached && e.bossReached)
        return true
    }

    /// Saves the expedition's step and ends it when it is over.
    private func store(_ e: Expedition, bossNewlyReached: Bool = false) {
        changeDungeons {
            $0.expedition = e
            if bossNewlyReached { $0.bossesReached.insert(DungeonProgress.bossKey(e.dungeon, e.boss.speciesID)) }
        }
        if e.isOver { finishExpedition(roped: false) } else { persist() }
    }

    // MARK: The player's answers

    /// R5: pays the emergency heal from the wallet, or goes on without it.
    @discardableResult
    func answerEmergencyHeal(pay: Bool) -> Bool {
        guard var e = expedition, let context = expeditionContext, case .awaitingHeal(let price) = e.phase else { return false }
        if pay {
            guard availableTokens >= price else { return false }
            spendTokens(price)
        }
        ExpeditionEngine.answerHeal(&e, paid: pay, context: context)
        store(e)
        return true
    }

    /// Q4: leaves the dungeon; the loot is lost unless an Escape Rope takes it out.
    func abandonExpedition() {
        guard var e = expedition, let context = expeditionContext, !e.isOver else { return }
        let roped = changeBag(.escapeRope, by: -1) == -1
        ExpeditionEngine.append(&e, .abandon(rope: roped), context: context)
        e.phase = .finished(won: false)
        changeDungeons { $0.expedition = e }
        finishExpedition(roped: roped)
    }

    /// Q18: a throw at the fallen boss, with a ball of the Bag or a plain one. Returns whether it was caught; nil when
    /// no throw is possible.
    @discardableResult
    func throwAtBoss(_ ball: ItemKind?) -> Bool? {
        guard var e = expedition, let context = expeditionContext, case .capture = e.phase else { return nil }
        if let ball {
            guard [.greatBall, .ultraBall, .masterBall].contains(ball), changeBag(ball, by: -1) == -1 else { return nil }
        }
        let caught = ExpeditionEngine.throwBall(&e, ball: ball, context: context)
        store(e)
        return caught
    }

    /// Lets the boss go without throwing again: the expedition ends, won.
    func endCapture() {
        guard var e = expedition, case .capture = e.phase else { return }
        e.phase = .finished(won: true)
        store(e)
    }

    /// Something waits for the player (R13): the emergency heal, the throws at the boss, the return not yet closed.
    var dungeonNeedsAttention: Bool {
        if let e = expedition {
            switch e.phase {
            case .awaitingHeal, .capture: return true
            case .exploring, .finished: return false
            }
        }
        return state.dungeons.lastResult != nil
    }

    /// The menu bar's floor while a team explores ("É6/12"), in place of the growth it pauses.
    var dungeonMenuFloor: String? {
        expedition.map { l.dungeonFloorTag(min($0.floor, $0.floors), $0.floors) }
    }

    func dismissExpeditionResult() {
        guard state.dungeons.lastResult != nil else { return }
        changeDungeons { $0.lastResult = nil }
        persist()
    }

    // MARK: The Bag's dungeon items

    /// The six IVs in the order the Pokédex shows them, HP to Speed.
    static let ivKeyPaths: [WritableKeyPath<PokemonIVs, Int>] = [\.hp, \.attack, \.defense, \.specialAttack,
                                                                \.specialDefense, \.speed]

    /// The graduated Pokémon a Capsule can raise: those with an IV under 31.
    var capsuleCandidates: [DexEntry] {
        state.dex.filter { entry in
            !entry.isReleased && entry.profile.map { p in Self.ivKeyPaths.contains { p.ivs[keyPath: $0] < 31 } } == true
        }
    }

    /// A Silver Capsule raises one IV (`stat`, 0 for HP to 5 for Speed) to 31, a Gold Capsule all six. Spent only
    /// when it raised something.
    @discardableResult
    func useCapsule(_ kind: ItemKind, on entryID: String, stat: Int? = nil) -> Bool {
        guard itemCount(kind) > 0, let entry = capsuleCandidates.first(where: { $0.id == entryID }),
              let ivs = entry.profile?.ivs else { return false }
        let raised: [WritableKeyPath<PokemonIVs, Int>]
        switch kind {
        case .goldCapsule:
            raised = Self.ivKeyPaths
        case .silverCapsule:
            guard let stat, Self.ivKeyPaths.indices.contains(stat), ivs[keyPath: Self.ivKeyPaths[stat]] < 31 else { return false }
            raised = [Self.ivKeyPaths[stat]]
        default:
            return false
        }
        changeProfile(of: entryID) { profile in for path in raised { profile.ivs[keyPath: path] = 31 } }
        changeBag(kind, by: -1)
        AppLog.write("dungeon: \(kind.rawValue) on \(entryID), stat \(stat.map(String.init) ?? "all")")
        persist()
        return true
    }

    /// Q23: an Explorer's Chest holds one of the Explorer Kit's treasures, drawn at the opening.
    @discardableResult
    func openExplorerChest() -> (kind: ItemKind, count: Int)? {
        guard changeBag(.explorerChest, by: -1) == -1 else { return nil }
        let treasure = ExplorerKit.treasure(roll: Int(drawSeed() % UInt64(ExplorerKit.rollRange)))
        if treasure.kind == .rareCandy { _ = grantRareCandies(treasure.count) } else { changeBag(treasure.kind, by: treasure.count) }
        AppLog.write("dungeon: explorer's chest gave \(treasure.count) \(treasure.kind.rawValue)")
        persist()
        return treasure
    }

    // MARK: The end

    /// The tier's extras on a victory (Q22, Q23, R10, R4): an egg sometimes, the very rare items, a Legendary Key
    /// from T3 (sure at the first T3 victory), a Technical Capsule.
    static func victoryExtras(tier: DungeonTier, firstT3Victory: Bool, random: inout BattleRandom) -> ExpeditionLoot {
        var loot = ExpeditionLoot()
        func roll(_ percent: Double) -> Bool { Double(random.below(10_000)) < percent * 100 }
        switch tier {
        case .t1: if roll(10) { loot.add(.pokemonEgg) }
        case .t2: if roll(10) { loot.add(.uncommonEgg) }
        case .t3:
            if roll(10) { loot.add(.rareEgg) }
            if firstT3Victory || roll(25) { loot.add(.legendaryKey) }
            if roll(5) { loot.add(.treasureMap) }
            if roll(0.5) { loot.add(.explorerChest) }
        case .t4:
            if roll(25) { loot.add(.rareEgg) }
            if roll(1) { loot.add(.legendaryEgg) }
            if roll(2) { loot.add(.masterBall) }
            if roll(1) { loot.add(.explorerChest) }
        case .t5:
            if roll(5) { loot.add(.legendaryEgg) }
            if roll(10) { loot.add(.masterBall) }
        }
        return loot
    }

    /// R4 (validated 2026-10-30): a successful expedition unlocks a Technical Capsule 10%, 20%, 35% of the time in T1,
    /// T2, T3; from T3 up, 35%.
    static func technicalCapsuleChance(_ tier: DungeonTier) -> Int {
        switch tier {
        case .t1: 10
        case .t2: 20
        default: 35
        }
    }

    private func finishExpedition(roped: Bool) {
        guard let e = expedition, case .finished(let won) = e.phase else { return }
        let dungeon = DungeonCatalog.dungeon(e.dungeon)
        var random = BattleRandom(seed: e.seed ^ 0xFEED_F00D)
        let openBefore = Set(DungeonID.allCases.filter(isDungeonOpen))
        let firstVictory = won && state.dungeons.wins(e.dungeon) == 0
        let t3Victories = DungeonCatalog.all.filter { $0.tier == .t3 }.reduce(0) { $0 + state.dungeons.wins($1.id) }
        var loot = won || roped ? e.loot : ExpeditionLoot()
        var unlockedMove: String?
        if won {
            if firstVictory {
                // Q22: a first victory doubles the loot and adds a dungeon item.
                loot.candies *= 2
                for (key, count) in loot.items { loot.items[key] = count * 2 }
                let table = ExpeditionEngine.itemTable(dungeon.tier)
                loot.add(table[random.below(table.count)])
            }
            loot.add(Self.victoryExtras(tier: dungeon.tier, firstT3Victory: dungeon.tier == .t3 && t3Victories == 0,
                                        random: &random))
            if random.below(100) < Self.technicalCapsuleChance(dungeon.tier) {
                let locked = MoveTable.all.values.filter { $0.isLocked && $0.hasEffect && !state.dungeons.unlockedMoves.contains($0.slug) }
                    .map(\.slug).sorted()
                if !locked.isEmpty { unlockedMove = locked[random.below(locked.count)] }
            }
        }
        _ = grantRareCandies(loot.candies)
        for (key, count) in loot.items { if let kind = ItemKind(rawValue: key) { changeBag(kind, by: count) } }
        // What was taken along and not used goes back to the Bag.
        changeBag(.oranBerry, by: e.berries[.oran] ?? 0)
        changeBag(.sitrusBerry, by: e.berries[.sitrus] ?? 0)
        changeBag(.revive, by: e.revives[ItemKind.revive.rawValue] ?? 0)
        changeBag(.maxRevive, by: e.revives[ItemKind.maxRevive.rawValue] ?? 0)
        let caught = e.log.contains { if case .capture(_, _, true) = $0.kind { return true }; return false }
        changeDungeons { progress in
            progress.eggs += loot.eggs
            if let unlockedMove { progress.unlockedMoves.insert(unlockedMove) }
            if won {
                progress.wins[e.dungeon.rawValue, default: 0] += 1
                progress.bossesBeaten.insert(DungeonProgress.bossKey(e.dungeon, e.boss.speciesID))
            }
            if e.bossReached { progress.bossesReached.insert(DungeonProgress.bossKey(e.dungeon, e.boss.speciesID)) }
            progress.expedition = nil
        }
        let unlocked = DungeonID.allCases.filter { isDungeonOpen($0) && !openBefore.contains($0) && $0 != .ruinsOfAlph }
        changeDungeons {
            $0.lastResult = ExpeditionResult(dungeon: e.dungeon, won: won, roped: roped, startedAt: e.startedAt,
                                             endedAt: currentDate, tokens: e.tokensIn, battles: e.battles, boss: e.boss,
                                             caught: caught, loot: loot, firstVictory: firstVictory,
                                             unlocked: unlocked, unlockedMove: unlockedMove, log: e.log)
        }
        AppLog.write("dungeon: \(e.dungeon.rawValue) over, won=\(won) roped=\(roped) caught=\(caught) candies=\(loot.candies)")
        persist()
    }
}
