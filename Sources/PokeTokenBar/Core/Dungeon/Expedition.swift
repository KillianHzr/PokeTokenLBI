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
}

/// What an expedition has gathered, kept only if its boss falls (Q3) or an Escape Rope takes the team out (Q4).
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
    /// R5: the team waits for the emergency heal's answer; the tokens go to the reserve.
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
    /// Tokens held while the team waits (R5), put in once it moves again.
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
    /// Something waits for the player: the emergency heal, the boss, the end (R13: the menu bar badge).
    var needsAttention = false
    var battles = 0

    var floors: Int { dungeon == .hallOfOrigin ? DungeonTier.t5.floors : DungeonCatalog.dungeon(dungeon).floors }
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

    /// The candies a tier's expedition holds, around its average (Q22).
    static func candyRange(_ tier: DungeonTier) -> ClosedRange<Int> {
        switch tier {
        case .t1: 0...3
        case .t2: 1...4
        case .t3: 2...6
        case .t4: 5...11
        case .t5: 8...16
        }
    }

    // MARK: Entry

    static func start(dungeon: Dungeon, team: [ExpeditionMember], rules: [DungeonRule], teamSize: Int, seed: UInt64,
                      cost: Int, berries: [BattleBerry: Int], revives: [String: Int], context: ExpeditionContext) -> Expedition {
        var random = BattleRandom(seed: seed)
        let bossID = dungeon.bosses[random.below(dungeon.bosses.count)]
        let shiny = random.below(max(1, context.shinyDenominator)) == 0
        let range = candyRange(dungeon.tier)
        return Expedition(dungeon: dungeon.id, teamSize: teamSize, rules: rules, startedAt: context.now, seed: seed,
                          cost: cost, team: team, boss: ExpeditionBoss(speciesID: bossID, form: nil, isShiny: shiny),
                          candiesLeft: random.between(range.lowerBound, range.upperBound), berries: berries,
                          revives: revives)
    }

    // MARK: Tokens

    /// Tokens walk the team on: each floor filled plays its event, the last its boss. While the team waits, they go
    /// to the reserve.
    static func feed(_ e: inout Expedition, tokens: Int, context: ExpeditionContext) {
        guard tokens > 0 else { return }
        switch e.phase {
        case .awaitingHeal:
            e.reserve += tokens
            return
        case .capture, .finished:
            return
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
        if case .awaitingHeal = e.phase { e.reserve += left }
    }

    private static func resolveFloor(_ e: inout Expedition, context: ExpeditionContext) {
        var random = BattleRandom(seed: e.seed &+ UInt64(e.floor) &* 0x9E37_79B9_7F4A_7C15)
        let dungeon = DungeonCatalog.dungeon(e.dungeon)
        if e.floor >= e.floors {
            fightBoss(&e, dungeon: dungeon, random: &random, context: context)
            return
        }
        // A Pokémon Center halfway through the long dungeons heals everything (Q16).
        if context.tier >= .t3, e.floor == e.floors / 2 {
            for i in e.team.indices { e.team[i].spec.hp = e.team[i].spec.stats.hp }
            append(&e, .center, context: context)
        } else {
            playEvent(&e, kind: drawEvent(e, tier: context.tier, random: &random), dungeon: dungeon,
                      random: &random, context: context)
        }
        guard !e.isOver else { return }
        if e.team.allSatisfy(\.isFainted) {
            finish(&e, won: false, context: context)
            return
        }
        // Q15: a branch every three floors, rolled (Q14 C).
        if e.floor % 3 == 0 {
            let roll = 1 + random.below(6)
            e.risky = roll >= 4
            append(&e, .branch(roll: roll, risky: e.risky), context: context)
        }
        offerHealIfCritical(&e)
    }

    /// The floor's event: battles most often, the risky path more of them and of traps.
    private static func drawEvent(_ e: Expedition, tier: DungeonTier, random: inout BattleRandom) -> ExpeditionEventKind {
        // R13: a shiny meeting, 1% of the events from T3.
        if tier >= .t3, random.below(100) == 0 { return .shiny }
        let battle = e.risky ? 1.4 : 1.0
        var weights: [(ExpeditionEventKind, Double)] = [
            (.wild, 30 * battle), (.chest, 16), (.trap, e.risky ? 14 : 9), (.spring, 10), (.lost, 8),
        ]
        if tier >= .t2 {
            weights.append((.horde, 10 * battle))
            weights.append((.trainer, 12 * battle))
        }
        let total = weights.reduce(0) { $0 + $1.1 }
        var roll = Double(random.below(10_000)) / 10_000 * total
        for (kind, weight) in weights {
            roll -= weight
            if roll < 0 { return kind }
        }
        return .wild
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
            default: count = [1, 1, 1, 1, 1, 1, 2, 2, 2, 3][random.below(10)]
            }
            let foes = drawFoes(count: count, kind: kind, dungeon: dungeon, tier: tier, random: &random)
            fight(&e, kind: kind, foes: foes, foesActive: kind == .trainer ? 1 : foes.count, random: &random,
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
            let floorIV = kind == .trainer ? 20 : 0
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

    private static func fight(_ e: inout Expedition, kind: ExpeditionEventKind, foes: [BattlerSpec], foesActive: Int,
                              random: inout BattleRandom, context: ExpeditionContext) {
        guard !foes.isEmpty else { return }
        let alive = e.team.filter { !$0.isFainted }
        // R2: as many of mine as foes in sight, all that are left when fewer stand.
        let active = max(1, min(foesActive, alive.count))
        let setup = BattleSetup(sides: [BattleSideSpec(battlers: alive.map(\.spec), active: active, berries: e.berries),
                                        BattleSideSpec(battlers: foes, active: foesActive)],
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
        let boss = bossSpec(e.boss, random: &random)
        let alive = e.team.filter { !$0.isFainted }
        guard let boss, !alive.isEmpty else {
            finish(&e, won: false, context: context)
            return
        }
        // R2 A: three of mine against the boss.
        let setup = BattleSetup(sides: [BattleSideSpec(battlers: alive.map(\.spec), active: min(3, alive.count),
                                                       berries: e.berries),
                                        BattleSideSpec(battlers: [boss], active: 1)], seed: random.next())
        let outcome = BattleEngine.run(setup)
        for i in e.team.indices {
            if let hp = outcome.hpLeft[e.team[i].spec.id] { e.team[i].spec.hp = hp }
        }
        e.berries = outcome.berriesLeft.first ?? e.berries
        e.battles += 1
        let won = outcome.winner == 0
        append(&e, .battle(ExpeditionBattle(kind: .boss, setup: setup, won: won, duration: outcome.duration,
                                            foes: [e.boss.speciesID])), rare: won, context: context)
        e.needsAttention = true
        if won {
            e.loot.candies += e.candiesLeft
            e.candiesLeft = 0
            append(&e, .victory, rare: true, context: context)
            e.phase = .capture(throwsLeft: 3)
        } else {
            finish(&e, won: false, context: context)
        }
    }

    /// R13: level 100, IVs of 20 to 31, three times the HP; a legendary four times and stats ×1.2, Arceus five
    /// times and ×1.3.
    static func bossSpec(_ boss: ExpeditionBoss, random: inout BattleRandom) -> BattlerSpec? {
        let ivs = (0..<6).map { _ in 20 + random.below(12) }
        let legendary = SpeciesInfo.all[boss.speciesID]?.isLegendary ?? false
        let arceus = boss.speciesID == DungeonCatalog.arceusID
        return BattlerSpec.make(id: "boss-\(boss.speciesID)", speciesID: boss.speciesID, form: boss.form, level: 100,
                                ivs: ivs, isShiny: boss.isShiny, isBoss: true,
                                hpFactor: arceus ? 5 : legendary ? 4 : 3, statFactor: arceus ? 1.3 : legendary ? 1.2 : 1)
    }

    // MARK: Loot

    /// The items a tier's chests hold (Q22 to Q24, without Mints).
    static func itemTable(_ tier: DungeonTier) -> [ItemKind] {
        switch tier {
        case .t1: [.oranBerry, .oranBerry, .greatBall]
        case .t2: [.sitrusBerry, .revive, .ultraBall, .oranBerry]
        case .t3: [.sitrusBerry, .revive, .escapeRope, .ultraBall, .silverCapsule]
        case .t4: [.sitrusBerry, .maxRevive, .ultraBall, .revive, .goldCapsule]
        case .t5: [.maxRevive, .ultraBall, .goldCapsule, .sitrusBerry]
        }
    }

    private static func chest(_ e: inout Expedition, tier: DungeonTier, better: Bool,
                              random: inout BattleRandom) -> ExpeditionLoot {
        var loot = ExpeditionLoot()
        if e.candiesLeft > 0, random.below(10) < (better ? 8 : 6) {
            let give = min(e.candiesLeft, 1 + random.below(max(1, e.candiesLeft / 2)))
            loot.candies = give
            e.candiesLeft -= give
        }
        if better || random.below(10) < 6 {
            let table = itemTable(better && tier < .t5 ? DungeonTier(rawValue: tier.rawValue + 1)! : tier)
            loot.add(table[random.below(table.count)])
        }
        if loot.isEmpty { loot.add(itemTable(tier)[0]) }
        e.loot.add(loot)
        return loot
    }

    static func isRare(_ loot: ExpeditionLoot) -> Bool {
        !loot.eggs.isEmpty || [ItemKind.goldCapsule, .silverCapsule, .masterBall, .treasureMap, .explorerChest,
                               .legendaryKey].contains { (loot.items[$0.rawValue] ?? 0) > 0 }
    }

    // MARK: The emergency heal

    private static func offerHealIfCritical(_ e: inout Expedition) {
        guard !e.healOffered, !e.isOver, case .exploring = e.phase, e.hpShare < healThreshold,
              !e.team.allSatisfy(\.isFainted) else { return }
        e.healOffered = true
        e.phase = .awaitingHeal(price: healPrice(cost: e.cost))
        e.needsAttention = true
    }

    /// R5: paid, the team is back to full and the knocked-out stand; either way it moves on with the reserve.
    static func answerHeal(_ e: inout Expedition, paid: Bool, context: ExpeditionContext) {
        guard case .awaitingHeal(let price) = e.phase else { return }
        if paid {
            for i in e.team.indices { e.team[i].spec.hp = e.team[i].spec.stats.hp }
            e.healUsed = true
            append(&e, .emergencyHeal(paid: price), context: context)
        }
        e.phase = .exploring
        e.needsAttention = false
        e.floor += 1
        let reserve = e.reserve
        e.reserve = 0
        feed(&e, tokens: reserve, context: context)
    }

    // MARK: The end

    static func finish(_ e: inout Expedition, won: Bool, context: ExpeditionContext) {
        e.phase = .finished(won: won)
        e.needsAttention = true
        if !won { append(&e, .defeat, context: context) }
    }

    /// A throw at the fallen boss (Q18, R12): a Great Ball ×1.5, an Ultra Ball ×2, a Master Ball sure. Returns
    /// whether it was caught.
    static func throwBall(_ e: inout Expedition, ball: ItemKind?, context: ExpeditionContext) -> Bool {
        guard case .capture(let left) = e.phase, left > 0 else { return false }
        var random = BattleRandom(seed: e.seed &+ 0xC0FFEE &+ UInt64(left))
        let base = captureOdds(SpeciesInfo.lineRarity(of: e.boss.speciesID))
        let factor: Double = switch ball {
        case .greatBall?: 1.5
        case .ultraBall?: 2
        case .masterBall?: 100
        default: 1
        }
        let caught = Double(random.below(1000)) / 1000 < min(1, base * factor)
        append(&e, .capture(attempt: 4 - left, ball: ball?.rawValue, caught: caught), rare: caught, context: context)
        if caught {
            e.loot.eggs.append(DungeonEgg(id: "boss-\(e.seed)", baseID: SpeciesInfo.baseID(of: e.boss.speciesID),
                                          form: e.boss.form, isShiny: e.boss.isShiny, sourceSpeciesID: e.boss.speciesID))
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
