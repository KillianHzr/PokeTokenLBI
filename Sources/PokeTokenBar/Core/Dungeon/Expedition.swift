import Foundation

/// An egg a dungeon gives: a boss caught (Q20 B) or a shiny met and caught. It hatches its line, shiny when it was
/// (R9 B: IVs and nature are drawn at the hatch).
struct DungeonEgg: Codable, Sendable, Equatable, Identifiable {
    var id: String
    /// The line's first species, what hatches.
    var baseID: Int
    var form: PokemonForm?
    var isShiny: Bool
    /// The Pokémon it came from: a legendary boss's egg has its own look (R14), the others their first type's (R8).
    var sourceSpeciesID: Int

    /// A legendary boss's egg (the owner, 2026-11-04): won once per species; its Pokémon graduates for 200M
    /// (`MonState.graduationTotal`) and is never sent off while raised.
    var isLegendary: Bool { SpeciesInfo.lineRarity(of: sourceSpeciesID) == .legendary }
}

/// What an expedition has gathered, kept unless the team leaves without an Escape Rope (Q4, the owner 2026-11-04).
struct ExpeditionLoot: Codable, Sendable, Equatable {
    var candies = 0
    var items: [String: Int] = [:]
    var eggs: [DungeonEgg] = []

    var isEmpty: Bool { candies == 0 && items.values.allSatisfy { $0 == 0 } && eggs.isEmpty }

    mutating func add(_ kind: ItemKind, _ count: Int = 1) {
        guard count > 0 else { return }
        items[kind.rawValue, default: 0] += count
    }

    mutating func add(_ other: ExpeditionLoot) {
        candies += other.candies
        for (key, count) in other.items { items[key, default: 0] += count }
        eggs += other.eggs
    }
}

/// A Pokémon of the team, its HP kept from one battle to the next (Q11).
struct ExpeditionMember: Codable, Sendable, Equatable {
    /// Its Pokédex entry.
    var entryID: String
    /// Its battle self; `spec.hp` is the HP it has now.
    var spec: BattlerSpec

    var isFainted: Bool { spec.hp <= 0 }
}

/// The kind of a floor's event (Q16, R6: eight of them, no merchant) or battle.
enum ExpeditionEventKind: String, Codable, Sendable {
    case wild, horde, trainer, chest, trap, spring, center, lost, shiny, boss
}

/// A battle fought: its setup replays it to the millisecond (R: "Revoir, c'est rejouer").
struct ExpeditionBattle: Codable, Sendable, Equatable {
    var kind: ExpeditionEventKind
    var setup: BattleSetup
    var won: Bool
    var duration: Int
    var foes: [Int]
}

/// One line of the expedition's journal.
enum ExpeditionLogKind: Codable, Sendable, Equatable {
    case battle(ExpeditionBattle)
    case chest(ExpeditionLoot)
    /// The share of their HP each Pokémon lost, or the item it cost.
    case trap(percent: Int, item: String?)
    case spring(percent: Int)
    case center
    case lost(speciesID: Int, percent: Int, loot: ExpeditionLoot)
    case shiny(speciesID: Int, caught: Bool)
    /// The dice of a branch (Q14 C) and the path it took.
    case branch(roll: Int, risky: Bool)
    /// #141 (DyRize's idea, the owner's rule of 2026-11-06): a secret passage, the next floor skipped unpaid, or a
    /// hidden room and its chest.
    case secretPassage(skipped: Bool, loot: ExpeditionLoot?)
    case revive(entryID: String, max: Bool)
    case emergencyHeal(paid: Int)
    case bossReached(speciesID: Int, isShiny: Bool)
    case capture(attempt: Int, ball: String?, caught: Bool)
    case victory
    case defeat
    case abandon(rope: Bool)
}

struct ExpeditionLogEntry: Codable, Sendable, Equatable, Identifiable {
    var id: Int
    var floor: Int
    var date: Date
    var kind: ExpeditionLogKind
    /// Shown first, in gold (Q31: the rare stands out).
    var isRare = false
}

/// The boss, drawn at the entry and hidden until reached (Q17).
struct ExpeditionBoss: Codable, Sendable, Equatable {
    var speciesID: Int
    var form: PokemonForm?
    var isShiny: Bool
}

/// Where the expedition stands.
enum ExpeditionPhase: Codable, Sendable, Equatable {
    case exploring
    /// R5: the team waits for the emergency heal's answer; the tokens grow the Pokémon raised meanwhile (2026-11-09).
    case awaitingHeal(price: Int)
    /// The boss fell: up to three throws (Q18) to catch it.
    case capture(throwsLeft: Int)
    case finished(won: Bool)
}

/// An expedition in progress, saved with the game.
struct Expedition: Codable, Sendable, Equatable {
    var dungeon: DungeonID
    var teamSize: Int
    var rules: [DungeonRule]
    var startedAt: Date
    var seed: UInt64
    /// The tokens the whole dungeon takes.
    var cost: Int
    var team: [ExpeditionMember]
    var boss: ExpeditionBoss
    /// The floor being crossed, from 1; the boss waits at the end of the last.
    var floor = 1
    var floorTokens = 0
    /// Tokens held while the team waited (R5), put in once it moves again. Only a save from before 2026-11-09 has any:
    /// the tokens of the wait now grow the Pokémon raised.
    var reserve = 0
    var tokensIn = 0
    var loot = ExpeditionLoot()
    /// The Rare Candies of the whole expedition, drawn at the entry around its tier's average (Q22) and handed out by
    /// its chests, the rest by its boss.
    var candiesLeft: Int
    var berries: [BattleBerry: Int]
    /// Revives and Max Revives taken along from the Bag.
    var revives: [String: Int]
    var risky = false
    var log: [ExpeditionLogEntry] = []
    var healOffered = false
    var healUsed = false
    var phase: ExpeditionPhase = .exploring
    var battles = 0
    /// True: the player kept the Master Ball out of this expedition at the departure; the automatic throws never take
    /// it, even at a legendary boss. Nil from an expedition saved before the throws were automatic.
    var keepsMasterBall: Bool?
    /// What catching the boss gives (the owner, 2026-11-04), settled at the departure (`CompanionStore.bossReward`).
    enum BossReward: String, Codable, Sendable {
        /// Its own egg: a boss not caught yet, or a legendary whose egg was never won (it comes shiny when the player
        /// has it already).
        case ownEgg
        /// An egg of the tier's rarity: a boss caught already that is no legendary.
        case tierEgg
        /// A Legendary Egg: a legendary the player has shiny already, its egg never won.
        case legendaryEgg
        /// The loot only: a legendary whose egg was won once. No throws, so no ball is spent.
        case lootOnly
    }
    /// Nil: its own egg, as an expedition saved before.
    var bossReward: BossReward?

    var floors: Int { info.floors }
    /// The dungeon walked.
    var info: Dungeon { DungeonCatalog.dungeon(dungeon) }
    var floorCost: Int { max(1, cost / floors) }
    /// The team's HP left, out of its maximum.
    var hpShare: Double {
        let total = team.reduce(0) { $0 + $1.spec.stats.hp }
        return total > 0 ? Double(team.reduce(0) { $0 + max(0, $1.spec.hp) }) / Double(total) : 0
    }
    var isOver: Bool { if case .finished = phase { return true }; return false }
    var bossReached: Bool { log.contains { if case .bossReached = $0.kind { return true }; return false } }
}

/// What an expedition needs from the game around it.
struct ExpeditionContext: Sendable {
    var tier: DungeonTier
    /// The shiny odds' denominator (1 in 64, 48 with the Shiny Charm).
    var shinyDenominator: Int
    var now: Date
}

/// The expedition's rules, pure and deterministic: each floor draws from the expedition's seed and its number, so the
/// same tokens always walk the same dungeon.
enum ExpeditionEngine {
    /// The emergency heal's threshold (R5): under a quarter of the team's HP.
    static let healThreshold = 0.25
    /// Its price: a quarter of the dungeon's cost (R5).
    static func healPrice(cost: Int) -> Int { cost / 4 }

    /// Q19: a throw's odds by the boss's line rarity.
    static func captureOdds(_ rarity: Rarity) -> Double {
        switch rarity {
        case .common: 0.60
        case .uncommon: 0.45
        case .rare: 0.30
        case .legendary: 0.12
        }
    }

    /// Arceus's throw odds, one in three (the owner, 2026-11-09: reaching him costs about 2B tokens, so a throw should
    /// not miss as often as at the other legendaries): about 70% over three Poké Balls, the Master Ball still sure.
    static let arceusCaptureOdds = 1.0 / 3

    /// A throw's odds at this boss before the ball: its line's (Q19), Arceus's own.
    static func captureOdds(_ boss: ExpeditionBoss) -> Double {
        boss.speciesID == DungeonCatalog.arceusID ? arceusCaptureOdds
            : captureOdds(SpeciesInfo.lineRarity(of: boss.speciesID))
    }

    /// The candies a tier's expedition holds, around its average (Q22). Rebalanced on 2026-11-02 at the owner's word
    /// ("10-18, c'est énorme"): they give back about half the tokens walked (a Rare Candy is 100M EXP); a dungeon's
    /// real prize is its boss's egg, its keys and items.
    static func candyRange(_ tier: DungeonTier) -> ClosedRange<Int> {
        switch tier {
        case .t1: 0...1
        case .t2: 0...2
        case .t3: 1...3
        // T4 and T5 raised on 2026-11-04 (the owner): the dearest dungeons gave the least per token.
        case .t4: 4...7
        case .t5: 6...10
        }
    }

    // MARK: Entry

    static func start(dungeon: Dungeon, team: [ExpeditionMember], rules: [DungeonRule], teamSize: Int, seed: UInt64,
                      cost: Int, berries: [BattleBerry: Int], revives: [String: Int], context: ExpeditionContext,
                      boss chosen: ExpeditionBoss? = nil) -> Expedition {
        var random = BattleRandom(seed: seed)
        // A challenge's boss is the battle form drawn for the day or the week, never shiny.
        // A challenge's estimate (`DungeonTeamBuilder.reachOdds`) may come without its boss, which it leaves out: a
        // stand-in keeps `[][0]` from trapping (the review of 2026-11-02 found the Prepare screen crashing).
        let boss = chosen ?? {
            guard !dungeon.bosses.isEmpty else {
                return ExpeditionBoss(speciesID: dungeon.wild.first ?? 1, form: nil, isShiny: false)
            }
            let bossID = dungeon.bosses[random.below(dungeon.bosses.count)]
            return ExpeditionBoss(speciesID: bossID, form: nil, isShiny: random.below(max(1, context.shinyDenominator)) == 0)
        }()
        let range = candyRange(dungeon.tier)
        return Expedition(dungeon: dungeon.id, teamSize: teamSize, rules: rules, startedAt: context.now, seed: seed,
                          cost: cost, team: team, boss: boss,
                          candiesLeft: random.between(range.lowerBound, range.upperBound), berries: berries,
                          revives: revives)
    }

    // MARK: Tokens

    /// Tokens walk the team on: each floor filled plays its event, the last its boss. Returns those it did not take,
    /// once the boss fell, the team lost or while it waits for the heal: the growth they paused takes them back (a
    /// morning's catch-up finishing the last floor lost hundreds of millions, review of 2026-11-02).
    @discardableResult
    static func feed(_ e: inout Expedition, tokens: Int, context: ExpeditionContext) -> Int {
        guard tokens > 0 else { return 0 }
        switch e.phase {
        case .awaitingHeal, .capture, .finished:
            // The team waiting for the heal takes none either (the owner, 2026-11-09: held for it, a day away from the
            // app was a day of growth lost); they grow the Pokémon raised.
            return tokens
        case .exploring:
            break
        }
        var left = tokens + e.reserve
        e.reserve = 0
        while left > 0, case .exploring = e.phase {
            let need = e.floorCost - e.floorTokens
            let used = min(need, left)
            e.floorTokens += used
            e.tokensIn += used
            left -= used
            guard e.floorTokens >= e.floorCost else { break }
            e.floorTokens = 0
            resolveFloor(&e, context: context)
            if case .exploring = e.phase { e.floor += 1 }
        }
        // The heal offered, the rest goes back to growth with the rest of the wait.
        return left
    }

    private static func resolveFloor(_ e: inout Expedition, context: ExpeditionContext) {
        var random = BattleRandom(seed: e.seed &+ UInt64(e.floor) &* 0x9E37_79B9_7F4A_7C15)
        let dungeon = e.info
        if e.floor >= e.floors {
            fightBoss(&e, dungeon: dungeon, random: &random, context: context)
            return
        }
        // A Pokémon Center halfway through the long dungeons heals everything (Q16).
        if context.tier >= .t3, e.floor == e.floors / 2 {
            for i in e.team.indices { e.team[i].spec.hp = e.team[i].spec.stats.hp }
            append(&e, .center, context: context)
        } else {
            playEvent(&e, kind: drawEvent(e, tier: context.tier, shinyDenominator: context.shinyDenominator, random: &random), dungeon: dungeon,
                      random: &random, context: context)
        }
        guard !e.isOver else { return }
        if e.team.allSatisfy(\.isFainted) {
            finish(&e, won: false, context: context)
            return
        }
        // Q15: a branch every three floors, rolled (Q14 C).
        if e.floor % 3 == 0 { rollBranch(&e, random: &random, context: context) }
        secretPassage(&e, dungeon: dungeon, context: context)
        offerHealIfCritical(&e)
    }

    private static func rollBranch(_ e: inout Expedition, random: inout BattleRandom, context: ExpeditionContext) {
        let roll = 1 + random.below(6)
        e.risky = roll >= 4
        append(&e, .branch(roll: roll, risky: e.risky), context: context)
    }

    /// #141: from T2, a floor's secret passage one time in 25 (`secretPassagePercent`), its own die so that every
    /// other draw stays what it was: half the time the team skips the next floor, its tokens unpaid, never the boss's;
    /// else a hidden room holds a chest.
    static let secretPassagePercent = 4

    private static func secretPassage(_ e: inout Expedition, dungeon: Dungeon, context: ExpeditionContext) {
        guard context.tier >= .t2, !e.dungeon.isChallenge else { return }
        var random = BattleRandom(seed: e.seed &+ UInt64(e.floor) &* 0x5EC2_E7F1_0A55_A9E5 &+ 0x41)
        guard random.below(100) < secretPassagePercent else { return }
        // Never the boss's floor, nor the Pokémon Center's (Q16): a passage never costs the team its heal.
        let canSkip = e.floor + 1 < e.floors && !(context.tier >= .t3 && e.floor + 1 == e.floors / 2)
        if canSkip, random.below(2) == 0 {
            append(&e, .secretPassage(skipped: true, loot: nil), rare: true, context: context)
            e.floor += 1
            // The skipped floor's fork still comes: the floors after it need their path.
            if e.floor % 3 == 0 { rollBranch(&e, random: &random, context: context) }
        } else {
            let loot = chest(&e, tier: context.tier, better: false, random: &random)
            append(&e, .secretPassage(skipped: false, loot: loot), rare: true, context: context)
        }
    }

    /// The floor's event: battles most often, the risky path more of them and of traps.
    private static func drawEvent(_ e: Expedition, tier: DungeonTier, shinyDenominator: Int,
                                  random: inout BattleRandom) -> ExpeditionEventKind {
        // R13: a shiny meeting, 1% of the events from T3, more with the Shiny Charm and the Reveal Glass as every
        // shiny roll (the owner, 2026-11-06): 1 in 64 makes 1%, 1 in 48 1.33%, 1 in 24 2.67%.
        if tier >= .t3, random.below(10_000) < shinyEncounterPerTenThousand(shinyDenominator: shinyDenominator) {
            return .shiny
        }
        let weights = eventWeights(tier: tier, risky: e.risky)
        let total = weights.reduce(0) { $0 + $1.1 }
        var roll = Double(random.below(10_000)) / 10_000 * total
        for (kind, weight) in weights {
            roll -= weight
            if roll < 0 { return kind }
        }
        return .wild
    }

    /// A floor's shiny meeting from T3, in ten thousandths: 100 at the plain 1 in 64.
    static func shinyEncounterPerTenThousand(shinyDenominator: Int) -> Int {
        Int((100 * 64 / Double(max(1, shinyDenominator))).rounded())
    }

    /// The weights a floor's event is drawn with (Q14 C): the risky path, from a die of 4 to 6 every three floors,
    /// weighs battles 1.4 times and traps 12 rather than 8. Its order is the draw's.
    static func eventWeights(tier: DungeonTier, risky: Bool) -> [(ExpeditionEventKind, Double)] {
        let battle = risky ? 1.4 : 1.0
        var weights: [(ExpeditionEventKind, Double)] = [
            (.wild, 40 * battle), (.chest, 12), (.trap, risky ? 12 : 8), (.spring, 7), (.lost, 6),
        ]
        if tier >= .t2 {
            weights.append((.horde, 12 * battle))
            weights.append((.trainer, 14 * battle))
        }
        return weights
    }

    /// A floor's events in percent, the shiny meeting of T3 and beyond first: what each dungeon's page shows of the
    /// two paths (the owner, 2026-11-06: nothing said what the dice change).
    static func eventOdds(tier: DungeonTier, risky: Bool, shinyDenominator: Int = 64) -> [(kind: ExpeditionEventKind, percent: Double)] {
        let shiny = tier >= .t3 ? Double(shinyEncounterPerTenThousand(shinyDenominator: shinyDenominator)) / 100 : 0
        let weights = eventWeights(tier: tier, risky: risky)
        let total = weights.reduce(0) { $0 + $1.1 }
        return (shiny > 0 ? [(.shiny, shiny)] : []) + weights.map { ($0.0, $0.1 / total * (100 - shiny)) }
    }

    private static func playEvent(_ e: inout Expedition, kind: ExpeditionEventKind, dungeon: Dungeon,
                                  random: inout BattleRandom, context: ExpeditionContext) {
        let tier = context.tier
        switch kind {
        case .wild, .horde, .trainer:
            let count: Int
            switch kind {
            case .horde: count = 3 + random.below(3)
            case .trainer: count = 3
            default: count = tier.wildCounts[random.below(tier.wildCounts.count)]
            }
            let foes = drawFoes(count: count, kind: kind, dungeon: dungeon, tier: tier, random: &random)
            fight(&e, kind: kind, foes: foes, random: &random,
                  context: context)
            if kind == .trainer, !e.team.allSatisfy(\.isFainted), !e.isOver {
                let loot = chest(&e, tier: tier, better: true, random: &random)
                append(&e, .chest(loot), rare: isRare(loot), context: context)
            }
        case .chest:
            let loot = chest(&e, tier: tier, better: false, random: &random)
            append(&e, .chest(loot), rare: isRare(loot), context: context)
        case .trap:
            if random.below(10) < 3, let key = e.loot.items.filter({ $0.value > 0 }).keys.sorted().first {
                e.loot.items[key, default: 0] -= 1
                append(&e, .trap(percent: 0, item: key), context: context)
            } else {
                let percent = 10 + random.below(16)
                for i in e.team.indices where !e.team[i].isFainted {
                    let loss = e.team[i].spec.stats.hp * percent / 100
                    e.team[i].spec.hp = max(1, e.team[i].spec.hp - loss)
                }
                append(&e, .trap(percent: percent, item: nil), context: context)
            }
        case .spring:
            for i in e.team.indices where !e.team[i].isFainted {
                e.team[i].spec.hp = min(e.team[i].spec.stats.hp, e.team[i].spec.hp + e.team[i].spec.stats.hp / 2)
            }
            append(&e, .spring(percent: 50), context: context)
        case .lost:
            let species = dungeon.wild.isEmpty ? 25 : dungeon.wild[random.below(dungeon.wild.count)]
            let percent = 10 + random.below(11)
            for i in e.team.indices where !e.team[i].isFainted {
                e.team[i].spec.hp = max(1, e.team[i].spec.hp - e.team[i].spec.stats.hp * percent / 100)
            }
            var loot = ExpeditionLoot()
            if random.below(10) < 3 {
                loot.add(.pokemonEgg)
            } else {
                loot.add(itemTable(tier)[random.below(itemTable(tier).count)])
            }
            e.loot.add(loot)
            append(&e, .lost(speciesID: species, percent: percent, loot: loot), context: context)
        case .shiny:
            let species = dungeon.wild.isEmpty ? 25 : dungeon.wild[random.below(dungeon.wild.count)]
            let caught = Double(random.below(1000)) / 1000 < captureOdds(SpeciesInfo.lineRarity(of: species))
            if caught {
                let base = SpeciesInfo.baseID(of: species)
                e.loot.eggs.append(DungeonEgg(id: "egg-\(e.seed)-\(e.floor)", baseID: base, form: nil, isShiny: true,
                                              sourceSpeciesID: species))
            }
            append(&e, .shiny(speciesID: species, caught: caught), rare: true, context: context)
        case .center, .boss:
            break
        }
    }

    // MARK: Battles

    private static func drawFoes(count: Int, kind: ExpeditionEventKind, dungeon: Dungeon, tier: DungeonTier,
                                 random: inout BattleRandom) -> [BattlerSpec] {
        var picked: [Int] = []
        var foes: [BattlerSpec] = []
        let levels = tier.wildLevels
        for i in 0..<count where !dungeon.wild.isEmpty {
            var species = dungeon.wild[random.below(dungeon.wild.count)]
            for _ in 0..<4 where picked.contains(species) { species = dungeon.wild[random.below(dungeon.wild.count)] }
            picked.append(species)
            var level = random.between(levels.lowerBound, levels.upperBound)
            if kind == .horde { level = max(1, level - 8) }
            if kind == .trainer { level = levels.upperBound }
            let floorIV = min(31, tier.foeIVFloor + (kind == .trainer ? 10 : 0))
            let ivs = (0..<6).map { _ in floorIV + random.below(32 - floorIV) }
            let nature = PokemonNature.allCases[random.below(PokemonNature.allCases.count)]
            let abilities = SpeciesBattleTable.data(speciesID: species)?.abilities.filter { !$0.hidden } ?? []
            let ability = abilities.isEmpty ? nil : abilities[random.below(abilities.count)].slug
            if let spec = BattlerSpec.make(id: "foe\(i)-\(species)", speciesID: species, level: level, ivs: ivs,
                                           nature: nature, ability: ability) {
                foes.append(spec)
            }
        }
        return foes
    }

    /// A boss one against one (the owner, 2026-11-06: "1v1 partout, boss affaiblis", its stats with its HP): its HP
    /// and stats were set for three of mine at once (R2 A); one at a time, both are multiplied by its kind's share,
    /// set so that the dungeons' and the challenges' odds stay what they were (`DungeonSimulatorTests`, `ZZLootSim`).
    /// Raised on 2026-11-09 with the battle rules 2 (a foe stepping in faces the bench's best, no wait after a
    /// knock-out), which made every dungeon easier: the owner chose to keep the odds of before (T3 0.6 to 0.8, T1 and
    /// T2 0.72 to 0.77, legendaries 0.7 to 0.8, challenges 0.7 to 0.8). Measured then against the owner's save and an
    /// average player, before and after: the challenges 55% and 33% to 52% and 32%, Mt. Moon 79% to 82%, the T3s on
    /// average 82% to 87% (an average player 39% to 45%), the T4 legendaries on average 56% to 53% (the Cerulean Cave
    /// 47% to 29%, Mt. Coronet 63% to 76%: one share for them all).
    static let oneOnOneBoss = 0.8
    /// T1 and T2.
    static let oneOnOneBossEarly = 0.77
    static let oneOnOneLegendary = 0.8
    /// Arceus alone (the owner, 2026-11-09: about 2B tokens to reach him, then good odds of having him, and "ma vraie
    /// équipe actuelle elle est pas censée réussir, elle est beaucoup trop random"): the best shiny team beats him 78%
    /// of the times it reaches him, a team of whatever shinies came along 3% (`DungeonSimulatorTests`, battle rules 2).
    static let oneOnOneArceus = 0.65
    static let oneOnOneChallenge = 0.8

    private static func fight(_ e: inout Expedition, kind: ExpeditionEventKind, foes: [BattlerSpec],
                              random: inout BattleRandom, context: ExpeditionContext) {
        guard !foes.isEmpty else { return }
        let alive = e.team.filter { !$0.isFainted }
        // One against one (the owner, 2026-11-06: "tous 1 par 1 chacun leur tour"): the others wait on the bench, the
        // best against the foe in front stepping in. It was R2, as many of mine as foes in sight.
        let setup = BattleSetup(sides: [BattleSideSpec(battlers: alive.map(\.spec), active: 1, berries: e.berries),
                                        BattleSideSpec(battlers: foes, active: 1)],
                                seed: random.next())
        let outcome = BattleEngine.run(setup)
        for i in e.team.indices {
            if let hp = outcome.hpLeft[e.team[i].spec.id] { e.team[i].spec.hp = hp }
        }
        e.berries = outcome.berriesLeft.first ?? e.berries
        e.battles += 1
        let won = outcome.winner == 0
        append(&e, .battle(ExpeditionBattle(kind: kind, setup: setup, won: won, duration: outcome.duration,
                                            foes: foes.map(\.speciesID))), context: context)
        reviveFallen(&e, context: context)
        if !won, e.team.allSatisfy(\.isFainted) { finish(&e, won: false, context: context) }
    }

    /// The team's Revives get up those knocked out after a battle, Max Revives first (Q24).
    private static func reviveFallen(_ e: inout Expedition, context: ExpeditionContext) {
        for i in e.team.indices where e.team[i].isFainted {
            if (e.revives[ItemKind.maxRevive.rawValue] ?? 0) > 0 {
                e.revives[ItemKind.maxRevive.rawValue, default: 0] -= 1
                e.team[i].spec.hp = e.team[i].spec.stats.hp
                append(&e, .revive(entryID: e.team[i].entryID, max: true), context: context)
            } else if (e.revives[ItemKind.revive.rawValue] ?? 0) > 0 {
                e.revives[ItemKind.revive.rawValue, default: 0] -= 1
                e.team[i].spec.hp = max(1, e.team[i].spec.stats.hp / 2)
                append(&e, .revive(entryID: e.team[i].entryID, max: false), context: context)
            }
        }
    }

    private static func fightBoss(_ e: inout Expedition, dungeon: Dungeon, random: inout BattleRandom,
                                  context: ExpeditionContext) {
        append(&e, .bossReached(speciesID: e.boss.speciesID, isShiny: e.boss.isShiny), rare: true, context: context)
        let boss = bossSpec(e.boss, tier: dungeon.tier, challenge: dungeon.id.isChallenge ? dungeon.id : nil, random: &random)
        let alive = e.team.filter { !$0.isFainted }
        guard let boss, !alive.isEmpty else {
            finish(&e, won: false, context: context)
            return
        }
        // A hideout's leader comes with three (the owner, 2026-11-10: Giovanni with Mewtwo and Persian).
        let foes = e.dungeon.villain.map { VillainRules.leaderSpecs($0, tier: $0.tier, random: &random) } ?? [boss]
        // One against the boss too (2026-11-06); it was R2 A, three of mine against it.
        let setup = BattleSetup(sides: [BattleSideSpec(battlers: alive.map(\.spec), active: 1,
                                                       berries: e.berries),
                                        BattleSideSpec(battlers: foes, active: 1)], seed: random.next())
        let outcome = BattleEngine.run(setup)
        for i in e.team.indices {
            if let hp = outcome.hpLeft[e.team[i].spec.id] { e.team[i].spec.hp = hp }
        }
        e.berries = outcome.berriesLeft.first ?? e.berries
        e.battles += 1
        let won = outcome.winner == 0
        append(&e, .battle(ExpeditionBattle(kind: .boss, setup: setup, won: won, duration: outcome.duration,
                                            foes: foes.map(\.speciesID))), rare: won, context: context)
        if won {
            e.loot.candies += e.candiesLeft
            e.candiesLeft = 0
            append(&e, .victory, rare: true, context: context)
            // A challenge's battle form is won as the boss falls: no throws (one try a day, the owner); nor at a
            // legendary whose egg was won once, which gives the loot only.
            if e.dungeon.isChallenge || e.bossReward == .lootOnly || e.dungeon.isHideout {
                finish(&e, won: true, context: context)
            } else {
                e.phase = .capture(throwsLeft: 3)
            }
        } else {
            finish(&e, won: false, context: context)
        }
    }

    /// R13: level 100, IVs of 20 to 31, its HP and stats raised: deeper, the more (balanced 2026-11-02 so a full
    /// Pokédex still has a fight), a legendary four times the HP and ×1.18, Arceus ×4.5 and ×1.2, a challenge's boss
    /// the most (`challengeFactors`).
    static func bossSpec(_ boss: ExpeditionBoss, tier: DungeonTier, challenge: DungeonID? = nil,
                         random: inout BattleRandom) -> BattlerSpec? {
        let ivs = (0..<6).map { _ in 20 + random.below(12) }
        let legendary = SpeciesInfo.all[boss.speciesID]?.isLegendary ?? false
        let (hp, stats): (Double, Double)
        if let challenge, let data = SpeciesBattleTable.data(speciesID: boss.speciesID, form: boss.form),
           let factors = challengeFactors(challenge, baseTotal: data.baseStats.reduce(0, +)) {
            (hp, stats) = factors
        } else if boss.speciesID == DungeonCatalog.arceusID {
            (hp, stats) = (4.5, 1.2)
        } else if legendary {
            (hp, stats) = (4, 1.18)
        } else {
            switch tier {
            case .t1: (hp, stats) = (3, 1.1)
            case .t2: (hp, stats) = (3.5, 1.2)
            default: (hp, stats) = (4, 1.25)
            }
        }
        // Its HP and stats were set for three of mine at once (R2 A); one at a time, both are lowered alike.
        let oneOnOne = challenge != nil ? oneOnOneChallenge
            : boss.speciesID == DungeonCatalog.arceusID ? oneOnOneArceus
            : legendary ? oneOnOneLegendary : tier <= .t2 ? oneOnOneBossEarly : oneOnOneBoss
        return BattlerSpec.make(id: "boss-\(boss.speciesID)", speciesID: boss.speciesID, form: boss.form, level: 100,
                                ivs: ivs, isShiny: boss.isShiny, isBoss: true, hpFactor: hp * oneOnOne,
                                statFactor: stats * oneOnOne)
    }

    /// The daily and weekly bosses' HP and stats, hard on purpose (the owner, 2026-11-03): a full Pokédex wins about
    /// one daily try in two and one weekly try in three (`DungeonSimulatorTests`). Measured against the form's base
    /// stat total, so that a Gigantamax Pikachu (320) stands as long as a Primal Groudon (770): one factor for all
    /// left the first a walkover and the second out of reach, the week's chances drawn with its boss.
    static func challengeFactors(_ id: DungeonID, baseTotal: Int) -> (hp: Double, stats: Double)? {
        let (hp, stats): (Double, Double)
        switch id {
        case .daily: (hp, stats) = (5.75, 1.375)
        case .weekly: (hp, stats) = (6.5, 1.5)
        default: return nil
        }
        let scale = challengeReferenceTotal / Double(max(1, baseTotal))
        return (hp * scale, stats * scale.squareRoot())
    }

    /// The base stat total the challenges' factors are set for.
    static let challengeReferenceTotal = 600.0

    // MARK: Loot

    /// The items a tier's chests hold (Q22 to Q24). A Mint from T2, as one Revive weighs (the owner, 2026-11-09: they
    /// left the chests with Q24 and came back).
    static func itemTable(_ tier: DungeonTier) -> [ItemKind] {
        switch tier {
        // Drawn evenly: the Capsules, which raise IVs to 31 for good, one draw in nine or ten.
        case .t1: [.oranBerry, .oranBerry, .greatBall]
        case .t2: [.sitrusBerry, .revive, .ultraBall, .oranBerry, .mint]
        case .t3: [.sitrusBerry, .sitrusBerry, .revive, .revive, .ultraBall, .ultraBall, .silverCapsule, .mint]
        case .t4: [.sitrusBerry, .sitrusBerry, .maxRevive, .revive, .revive, .ultraBall, .ultraBall, .silverCapsule,
                   .goldCapsule, .mint]
        case .t5: [.maxRevive, .maxRevive, .ultraBall, .ultraBall, .sitrusBerry, .sitrusBerry, .silverCapsule, .goldCapsule,
                   .mint]
        }
    }

    private static func chest(_ e: inout Expedition, tier: DungeonTier, better: Bool,
                              random: inout BattleRandom) -> ExpeditionLoot {
        var loot = ExpeditionLoot()
        // Most candies in the chests rather than with the boss (2026-11-04): a defeat keeps the floors' loot.
        if e.candiesLeft > 0, random.below(10) < (better ? 10 : 8) {
            let give = min(e.candiesLeft, 1 + random.below(max(1, e.candiesLeft / 2)))
            loot.candies = give
            e.candiesLeft -= give
        }
        if better || random.below(10) < 6 {
            let table = itemTable(better && tier < .t5 ? DungeonTier(rawValue: tier.rawValue + 1)! : tier)
            loot.add(table[random.below(table.count)])
        }
        // The dungeon's own tier for every chest, a trainer's too: its odds are the chest's (the owner, 2026-11-04).
        if let egg = chestEgg(tier, random: &random) { loot.add(egg) }
        if loot.isEmpty { loot.add(itemTable(tier)[0]) }
        e.loot.add(loot)
        return loot
    }

    /// The egg a chest may hold (the owner, 2026-11-04: once the bosses are caught, the dungeons are run again for
    /// their loot): none in T1; an Uncommon Egg one chest in 8 in T2; a Rare Egg one in 10 in T3; in T4 a Legendary
    /// Egg one in 50, else a Rare Egg 3 in 20; in T5 a Legendary Egg one in 15, else a Rare Egg one in 5.
    static func chestEgg(_ tier: DungeonTier, random: inout BattleRandom) -> ItemKind? {
        let odds = chestEggOdds(tier)
        guard !odds.isEmpty else { return nil }
        var roll = random.below(1000)
        for (egg, perMille) in odds {
            if roll < perMille { return egg }
            roll -= perMille
        }
        return nil
    }

    /// The eggs a chest may hold, each in chests per thousand: the draw's own table, which each dungeon's page shows.
    static func chestEggOdds(_ tier: DungeonTier) -> [(egg: ItemKind, perMille: Int)] {
        switch tier {
        case .t1: []
        case .t2: [(.uncommonEgg, 125)]
        case .t3: [(.rareEgg, 100)]
        case .t4: [(.legendaryEgg, 20), (.rareEgg, 150)]
        case .t5: [(.legendaryEgg, 67), (.rareEgg, 200)]
        }
    }

    /// The egg the boss's capture gives in place of its own: the tier's (`tierEgg`) or a Legendary Egg; nil for its own.
    static func eggInPlace(_ reward: Expedition.BossReward?, tier: DungeonTier) -> ItemKind? {
        switch reward {
        case .tierEgg?: tierEgg(tier)
        case .legendaryEgg?: .legendaryEgg
        case .ownEgg?, .lootOnly?, nil: nil
        }
    }

    /// The egg of the tier's rarity a boss already caught gives in place of its own (2026-11-04).
    static func tierEgg(_ tier: DungeonTier) -> ItemKind {
        switch tier {
        case .t1: .pokemonEgg
        case .t2: .uncommonEgg
        case .t3, .t4: .rareEgg
        case .t5: .legendaryEgg
        }
    }

    static func isRare(_ loot: ExpeditionLoot) -> Bool {
        !loot.eggs.isEmpty || [ItemKind.goldCapsule, .silverCapsule, .masterBall, .treasureMap, .explorerChest,
                               .legendaryKey, .legendaryEgg, .rareEgg].contains { (loot.items[$0.rawValue] ?? 0) > 0 }
    }

    // MARK: The emergency heal

    private static func offerHealIfCritical(_ e: inout Expedition) {
        guard !e.healOffered, !e.isOver, case .exploring = e.phase, e.hpShare < healThreshold,
              !e.team.allSatisfy(\.isFainted) else { return }
        e.healOffered = true
        e.phase = .awaitingHeal(price: healPrice(cost: e.cost))
    }

    /// R5: paid, the team is back to full and the knocked-out stand; either way it moves on. A reserve a save from
    /// before 2026-11-09 still holds walks on, and what the dungeon did not take is returned (`feed`).
    @discardableResult
    static func answerHeal(_ e: inout Expedition, paid: Bool, context: ExpeditionContext) -> Int {
        guard case .awaitingHeal(let price) = e.phase else { return 0 }
        if paid {
            for i in e.team.indices { e.team[i].spec.hp = e.team[i].spec.stats.hp }
            e.healUsed = true
            append(&e, .emergencyHeal(paid: price), context: context)
        }
        e.phase = .exploring
        e.floor += 1
        let reserve = e.reserve
        e.reserve = 0
        return feed(&e, tokens: reserve, context: context)
    }

    // MARK: The end

    static func finish(_ e: inout Expedition, won: Bool, context: ExpeditionContext) {
        e.phase = .finished(won: won)
        if !won { append(&e, .defeat, context: context) }
    }

    /// A throw's odds at this boss: its line's (Q19) or Arceus's own, a Great Ball ×1.5, an Ultra Ball ×2, a Master Ball
    /// sure.
    static func throwOdds(_ boss: ExpeditionBoss, ball: ItemKind?) -> Double {
        let factor: Double = switch ball {
        case .greatBall?: 1.5
        case .ultraBall?: 2
        case .masterBall?: 100
        default: 1
        }
        return min(1, captureOdds(boss) * factor)
    }

    /// A throw at the fallen boss (Q18, R12): a Great Ball ×1.5, an Ultra Ball ×2, a Master Ball sure. Returns
    /// whether it was caught.
    static func throwBall(_ e: inout Expedition, ball: ItemKind?, context: ExpeditionContext) -> Bool {
        guard case .capture(let left) = e.phase, left > 0 else { return false }
        var random = BattleRandom(seed: e.seed &+ 0xC0FFEE &+ UInt64(left))
        let caught = Double(random.below(1000)) / 1000 < throwOdds(e.boss, ball: ball)
        append(&e, .capture(attempt: 4 - left, ball: ball?.rawValue, caught: caught), rare: caught, context: context)
        if caught {
            // A boss already caught gives an egg of the tier's rarity rather than a second of its own, a legendary had
            // shiny already a Legendary Egg (2026-11-04).
            if let egg = eggInPlace(e.bossReward, tier: context.tier) {
                e.loot.add(egg)
            } else {
                e.loot.eggs.append(DungeonEgg(id: "boss-\(e.seed)", baseID: SpeciesInfo.baseID(of: e.boss.speciesID),
                                              form: e.boss.form, isShiny: e.boss.isShiny, sourceSpeciesID: e.boss.speciesID))
            }
            e.phase = .finished(won: true)
        } else if left > 1 {
            e.phase = .capture(throwsLeft: left - 1)
        } else {
            e.phase = .finished(won: true)
        }
        return caught
    }

    static func append(_ e: inout Expedition, _ kind: ExpeditionLogKind, rare: Bool = false,
                       context: ExpeditionContext) {
        e.log.append(ExpeditionLogEntry(id: e.log.count, floor: e.floor, date: context.now, kind: kind, isRare: rare))
    }
}
