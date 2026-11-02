import Foundation

/// A dungeon's tier: its length in tokens, its floors, its wild Pokémon's levels, and the keys its entry costs.
enum DungeonTier: Int, Codable, Sendable, CaseIterable, Comparable {
    case t1 = 1, t2, t3, t4, t5

    static func < (lhs: DungeonTier, rhs: DungeonTier) -> Bool { lhs.rawValue < rhs.rawValue }

    var floors: Int {
        switch self {
        case .t1: 5
        case .t2: 8
        case .t3: 10
        case .t4: 12
        case .t5: 15
        }
    }

    /// Q2: a tier costs what a graduation of the same rank costs (T1 a Common's, T4 a Legendary's); T5 half as much
    /// again (R11, 900M at today's difficulty).
    func cost(difficulty: Double) -> Int {
        switch self {
        case .t1: PokemonBalance.scaled(PokemonBalance.graduationTotal(.common), by: difficulty)
        case .t2: PokemonBalance.scaled(PokemonBalance.graduationTotal(.uncommon), by: difficulty)
        case .t3: PokemonBalance.scaled(PokemonBalance.graduationTotal(.rare), by: difficulty)
        case .t4: PokemonBalance.scaled(PokemonBalance.graduationTotal(.legendary), by: difficulty)
        case .t5: PokemonBalance.scaled(PokemonBalance.graduationTotal(.legendary) * 3 / 2, by: difficulty)
        }
    }

    /// The wild Pokémon's levels: close to the team's 100 from the start, or a full Pokédex never notices them.
    var wildLevels: ClosedRange<Int> {
        switch self {
        case .t1: 55...65
        case .t2: 70...80
        case .t3: 85...95
        case .t4: 95...100
        case .t5: 90...100
        }
    }

    /// The least IV a wild Pokémon has; a trainer's ten more.
    var foeIVFloor: Int {
        switch self {
        case .t1: 0
        case .t2: 5
        case .t3: 10
        case .t4: 15
        case .t5: 10
        }
    }

    /// How many wild Pokémon a battle shows, one of these drawn: more of them deeper.
    var wildCounts: [Int] {
        switch self {
        case .t1: [1, 1, 1, 1, 2, 2, 2, 2, 3, 3]
        case .t2: [1, 1, 2, 2, 2, 2, 3, 3, 3, 3]
        // The Hall of Origin's length and its shinies-only team are its test: its floors fight as T3's.
        case .t3, .t5: [1, 2, 2, 2, 3, 3, 3, 3, 3, 3]
        case .t4: [2, 2, 3, 3, 3, 3, 3, 3, 3, 3]
        }
    }

    /// Legendary Keys spent at the entry (R10, R11).
    var keys: Int {
        switch self {
        case .t4: 1
        case .t5: 3
        default: 0
        }
    }
}

/// What a team must be (Q7): the families of rules, a dungeon combining one or two.
enum DungeonRule: Codable, Sendable, Hashable {
    case noLegendary
    case atMostOneLegendary
    case onlyLegendaries
    /// The starter lines of the nine regions (`CollectorBonus.starterLines`).
    case onlyStarters
    /// Every member shares a type.
    case sharedType
    /// Every member from one region, by its generation.
    case oneRegion
    case maxRarity(Rarity)
    case bannedType(PokemonType)
    case onlyShinies
}

/// What opens a dungeon (Q27).
enum DungeonUnlock: Codable, Sendable, Hashable {
    /// Graduated Pokémon, not sent off.
    case graduated(Int)
    /// A dungeon won once.
    case won(DungeonID)
    /// Evolution lines with a graduated Pokémon.
    case linesGraduated(Int)
    /// Legendary Pokémon graduated.
    case legendariesGraduated(Int)
    /// These bosses beaten somewhere.
    case beatBosses([Int])
    /// A Treasure Map in the Bag, spent at the entry (the Ruins of Alph).
    case treasureMap
}

/// The thirteen dungeons (Q25, Q26: places of the series, their official names).
enum DungeonID: String, Codable, Sendable, CaseIterable {
    case viridianForest, diglettsCave, mtMoon, mtEmber, victoryRoad, pokemonTower, dragonsDen, powerPlant
    case seafoamIslands, ceruleanCave, mtCoronet, ruinsOfAlph, hallOfOrigin
}

/// One dungeon: its tier, team, rules, theme (always shown, R7), wild Pokémon, bosses (never shown, Q17) and what
/// opens it.
struct Dungeon: Sendable, Equatable {
    let id: DungeonID
    let tier: DungeonTier
    let teamSize: Int
    let rules: [DungeonRule]
    /// The types of its wild Pokémon and of its boss, shown on its card.
    let themeTypes: [PokemonType]
    /// The species its wild Pokémon are drawn from.
    let wild: [Int]
    /// The bosses one is drawn from at the entry.
    let bosses: [Int]
    let unlocks: [DungeonUnlock]

    var floors: Int { tier.floors }
}

enum DungeonCatalog {
    static let all: [Dungeon] = DungeonID.allCases.map(make)

    static func dungeon(_ id: DungeonID) -> Dungeon { all.first { $0.id == id }! }

    private static func make(_ id: DungeonID) -> Dungeon {
        switch id {
        case .viridianForest:
            return Dungeon(id: id, tier: .t1, teamSize: 3, rules: [.maxRarity(.common)], themeTypes: [.bug, .grass],
                           wild: themed([.bug, .grass], tier: .t1), bosses: [15, 12, 45], unlocks: [.graduated(6)])
        case .diglettsCave:
            return Dungeon(id: id, tier: .t1, teamSize: 3, rules: [.noLegendary], themeTypes: [.ground, .rock],
                           wild: themed([.ground, .rock], tier: .t1), bosses: [51, 76, 208], unlocks: [.graduated(6)])
        case .mtMoon:
            return Dungeon(id: id, tier: .t2, teamSize: 4, rules: [.oneRegion], themeTypes: [.fairy, .rock],
                           wild: themed([.fairy, .rock], tier: .t2) + FossilDig.lines.filter { SpeciesBattleTable.all[$0] != nil },
                           bosses: [36, 169, 139], unlocks: [.won(.viridianForest)])
        case .mtEmber:
            return Dungeon(id: id, tier: .t2, teamSize: 4, rules: [.bannedType(.water)], themeTypes: [.fire],
                           wild: themed([.fire], tier: .t2), bosses: [59, 467, 324], unlocks: [.won(.diglettsCave)])
        case .victoryRoad:
            return Dungeon(id: id, tier: .t3, teamSize: 6, rules: [.onlyStarters], themeTypes: [.grass, .fire, .water],
                           wild: finalStarters, bosses: [6, 3, 9], unlocks: [.won(.mtMoon), .won(.mtEmber)])
        case .pokemonTower:
            return Dungeon(id: id, tier: .t3, teamSize: 5, rules: [.maxRarity(.uncommon)], themeTypes: [.ghost],
                           wild: themed([.ghost], tier: .t3), bosses: [94, 442, 609], unlocks: [.won(.mtEmber)])
        case .dragonsDen:
            return Dungeon(id: id, tier: .t3, teamSize: 6, rules: [.atMostOneLegendary], themeTypes: [.dragon],
                           wild: themed([.dragon], tier: .t3), bosses: [149, 445, 635], unlocks: [.won(.pokemonTower)])
        case .powerPlant:
            return Dungeon(id: id, tier: .t3, teamSize: 5, rules: [.sharedType], themeTypes: [.electric, .steel],
                           wild: themed([.electric, .steel], tier: .t3), bosses: [462, 466, 101], unlocks: [.won(.mtMoon)])
        case .seafoamIslands:
            return Dungeon(id: id, tier: .t4, teamSize: 6, rules: [.noLegendary, .maxRarity(.rare)],
                           themeTypes: [.ice, .water], wild: themed([.ice, .water], tier: .t4), bosses: [144, 249, 245],
                           unlocks: [.won(.dragonsDen)])
        case .ceruleanCave:
            return Dungeon(id: id, tier: .t4, teamSize: 6, rules: [.noLegendary, .bannedType(.psychic)],
                           themeTypes: [.psychic], wild: themed([.psychic], tier: .t4), bosses: [150],
                           unlocks: [.won(.seafoamIslands), .linesGraduated(100)])
        case .mtCoronet:
            return Dungeon(id: id, tier: .t4, teamSize: 6, rules: [.onlyLegendaries],
                           themeTypes: [.steel, .water, .ghost, .dragon],
                           wild: themed([.steel, .water, .ghost, .dragon], tier: .t4), bosses: [483, 484, 487],
                           unlocks: [.won(.ceruleanCave), .legendariesGraduated(10)])
        case .ruinsOfAlph:
            // Q25, Q13: secret, opened once by a Treasure Map; its rules are drawn at random (`alphRules`), its
            // boss is any final species but Arceus.
            return Dungeon(id: id, tier: .t4, teamSize: 6, rules: [], themeTypes: [.psychic],
                           wild: [201] + themed([.psychic, .rock], tier: .t4),
                           bosses: SpeciesInfo.all.keys.filter {
                               $0 != arceusID && $0 <= 1025 && SpeciesInfo.isFinal($0) && SpeciesBattleTable.all[$0] != nil
                           }.sorted(),
                           unlocks: [.treasureMap])
        case .hallOfOrigin:
            return Dungeon(id: id, tier: .t5, teamSize: 6, rules: [.onlyShinies], themeTypes: [.normal],
                           wild: SpeciesInfo.all.keys.filter { id in
                               guard id <= 1025, let data = SpeciesBattleTable.all[id], let info = SpeciesInfo.all[id],
                                     !info.isLegendary, SpeciesInfo.isFinal(id) else { return false }
                               return data.baseStats.reduce(0, +) >= 530
                           }.sorted(),
                           bosses: [arceusID], unlocks: [.beatBosses([483, 484, 487])])
        }
    }

    static let arceusID = 493

    /// The final stages of the nine regions' starters, Victory Road's wild Pokémon.
    static let finalStarters = [3, 6, 9, 154, 157, 160, 254, 257, 260, 389, 392, 395, 497, 500, 503, 655, 658,
                                652, 724, 727, 730, 812, 815, 818, 908, 911, 914].sorted()

    /// Wild Pokémon of these types, never legendary: any stage in T1 and T2, only final stages from T3.
    static func themed(_ types: [PokemonType], tier: DungeonTier) -> [Int] {
        SpeciesInfo.all.keys.filter { id in
            guard id <= 1025, let data = SpeciesBattleTable.all[id], let info = SpeciesInfo.all[id], !info.isLegendary,
                  data.types.contains(where: types.contains) else { return false }
            switch tier {
            case .t1: return SpeciesInfo.lineRarity(of: id) != .rare
            case .t2: return true
            default: return SpeciesInfo.isFinal(id)
            }
        }.sorted()
    }

    /// The Ruins of Alph's rules, drawn from a visit's seed: a team of three to six and one or two rules.
    static func alphRules(seed: UInt64) -> (teamSize: Int, rules: [DungeonRule]) {
        var random = BattleRandom(seed: seed)
        let size = 3 + random.below(4)
        let pool: [DungeonRule] = [.noLegendary, .maxRarity(.uncommon), .maxRarity(.rare), .oneRegion, .sharedType,
                                   .bannedType(PokemonType.allCases[random.below(PokemonType.allCases.count)])]
        var rules = [pool[random.below(pool.count)]]
        if random.chance(50) {
            let second = pool[random.below(pool.count)]
            if second != rules[0] { rules.append(second) }
        }
        return (size, rules)
    }
}
