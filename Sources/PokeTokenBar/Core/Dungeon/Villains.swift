import Foundation

/// The villains' teams (issue #180, the owner, 2026-11-10): one may ambush the player for an item of the Bag. Beaten, it
/// flies off with nothing; winning, it takes the item to its hideout, a dungeon of the item's tier whose leader keeps it
/// until a team gets it back.
enum VillainTeam: String, Codable, Sendable, CaseIterable {
    case rocket, aqua, magma, galactic, plasma, flare, skull

    var themeTypes: [PokemonType] {
        switch self {
        case .rocket: [.poison, .normal]
        case .aqua: [.water, .dark]
        case .magma: [.fire, .ground]
        case .galactic: [.poison, .steel]
        case .plasma: [.dark, .ground]
        case .flare: [.fire, .dark]
        case .skull: [.poison, .bug]
        }
    }

    /// The grunts' Pokémon, as in their games.
    var grunts: [Int] {
        switch self {
        case .rocket: [20, 24, 42, 89, 110, 97]
        case .aqua: [262, 319, 342, 73, 42, 279]
        case .magma: [262, 323, 324, 110, 42, 219]
        case .galactic: [435, 454, 432, 437, 42, 426]
        case .plasma: [510, 505, 560, 553, 569, 528]
        case .flare: [229, 620, 687, 310, 317, 262]
        case .skull: [758, 748, 42, 89, 168, 760]
        }
    }

    /// The leader's three at the end of the hideout: their legendary at the top tier (Giovanni and Mewtwo, Persian, the
    /// owner), their own aces from T3, a grunt's best below.
    func leaderTeam(_ tier: DungeonTier) -> [Int] {
        switch tier {
        case .t5:
            switch self {
            case .rocket: [150, 53, 34]
            case .aqua: [382, 319, 342]
            case .magma: [383, 323, 169]
            case .galactic: [483, 461, 430]
            case .plasma: [646, 635, 625]
            case .flare: [717, 130, 668]
            case .skull: [794, 768, 127]
            }
        case .t3, .t4:
            switch self {
            case .rocket: [53, 34, 112]
            case .aqua: [319, 342, 73]
            case .magma: [323, 169, 262]
            case .galactic: [461, 430, 435]
            case .plasma: [635, 625, 560]
            case .flare: [130, 668, 229]
            case .skull: [768, 127, 168]
            }
        case .t1, .t2: Array(grunts.prefix(3))
        }
    }

    /// Who waits at the end: the leader from T3, a grunt below.
    func bossIsLeader(_ tier: DungeonTier) -> Bool { tier >= .t3 }

    var gruntPortrait: String { "villain-\(rawValue)-grunt" }
    var leaderPortrait: String { "villain-\(rawValue)-leader" }

    /// The team's color, for its cards.
    var rgb: (red: Double, green: Double, blue: Double) {
        switch self {
        case .rocket: (0.86, 0.16, 0.20)
        case .aqua: (0.16, 0.45, 0.90)
        case .magma: (0.90, 0.32, 0.14)
        case .galactic: (0.38, 0.58, 0.72)
        case .plasma: (0.42, 0.50, 0.86)
        case .flare: (0.95, 0.45, 0.12)
        case .skull: (0.55, 0.55, 0.60)
        }
    }

    /// Their Pokémon Masters EX renders, from WikiDex as Prof. Oak's and the merchants'.
    static let portraitURLs: [String: String] = {
        let base = "https://images.wikidexcdn.net/mwuploads/wikidex/"
        return [
            "villain-rocket-grunt": base + "d/d7/latest/20210914060636/Recluta_del_Team_Rocket_masculino_Masters.png",
            "villain-aqua-grunt": base + "5/51/latest/20220727061405/Recluta_del_Equipo_Aqua_masculino_Masters.png",
            "villain-magma-grunt": base + "4/43/latest/20220727061259/Recluta_del_Equipo_Magma_masculino_Masters.png",
            "villain-galactic-grunt": base + "5/53/latest/20211221094210/Recluta_Galaxia_masculino_Masters.png",
            "villain-plasma-grunt": base + "9/94/latest/20221027063526/Recluta_del_Equipo_Plasma_masculino_Masters.png",
            "villain-flare-grunt": base + "c/c0/latest/20221226063717/Recluta_del_Team_Flare_%28hombre%29_Masters.png",
            "villain-skull-grunt": base + "b/ba/latest/20250819193111/Recluta_del_Team_Skull_masculino_Masters.png",
            "villain-rocket-leader": base + "b/b2/latest/20200825103758/Giovanni_Masters.png",
            "villain-aqua-leader": base + "d/d5/latest/20210426062209/Aquiles_Masters.png",
            "villain-magma-leader": base + "6/65/latest/20210426062636/Magno_Masters.png",
            "villain-galactic-leader": base + "a/ad/latest/20200929193057/Helio_Masters.png",
            "villain-plasma-leader": base + "c/c7/latest/20210426062450/Ghechis_Masters.png",
            "villain-flare-leader": base + "2/20/latest/20210126055647/Lysson_Masters.png",
            "villain-skull-leader": base + "3/3b/latest/20200323132750/Guzm%C3%A1n_Masters.png",
        ]
    }()
}

/// A team waiting on Home for the player to defend an item (no time limit), then how it went.
struct VillainAmbush: Codable, Sendable, Equatable {
    var team: VillainTeam
    /// `ItemKind.rawValue`, and how many of it.
    var item: String
    var count: Int
    var at: Date
    var seed: UInt64
    var grunts: [Int]
    /// Nil until the player defends; then whether they won.
    var won: Bool?
    var battle: ExpeditionBattle?

    var kind: ItemKind? { ItemKind(rawValue: item) }
    var tier: DungeonTier { kind.flatMap(VillainRules.tier) ?? .t1 }
}

/// What a team took to its hideout, given back when its leader falls.
struct VillainStash: Codable, Sendable, Equatable {
    var team: VillainTeam
    var items: [String: Int]
    /// The hideout's tier: the most precious item's.
    var tier: DungeonTier
}

enum VillainRules {
    /// One day in three at most, at an hour of the day between 9 and 21, a team drawn from the day alone.
    static let oneDayIn = 3

    /// What an item is worth to a thief: the hideout's tier. Nil: never stolen (badges, medals, form rewards, whose
    /// steps are counted apart).
    static func tier(of kind: ItemKind) -> DungeonTier? {
        switch kind {
        case .rareCandy, .oranBerry, .sitrusBerry, .greatBall, .revive: return .t1
        case .ultraBall, .maxRevive, .mint, .silverCapsule, .pokemonEgg, .uncommonEgg, .explorerChest, .treasureMap:
            return .t2
        case .rareEgg, .goldCapsule, .legendaryKey, .fossilEgg: return .t3
        case .masterBall, .legendaryEgg, .typeNullEgg, .birthdayEgg: return .t4
        default: break
        }
        if kind.stoneType != nil { return .t2 }
        if EventEgg(item: kind) != nil { return .t3 }
        guard kind.isPassive, !kind.isRegional, kind.moreFormsSpecies == nil else { return nil }
        // The achievements' artifacts are the big prize; the Shop's a step below.
        return kind.isAchievement ? .t5 : .t4
    }

    /// The draw's weights by tier, among the tiers the Bag holds: a candy most often, an artifact rarely.
    static let tierWeights: [DungeonTier: Int] = [.t1: 40, .t2: 28, .t3: 18, .t4: 9, .t5: 5]

    /// Up to three of an everyday item at once, one of anything else.
    static func count(of kind: ItemKind, have: Int) -> Int { tier(of: kind) == .t1 ? min(3, have) : min(1, have) }

    /// The day's draw (`yyyy-MM-dd`), the same all day on every launch: FNV-1a, as the merchant's.
    static func day(_ day: String) -> (comes: Bool, hour: Int, team: VillainTeam) {
        var random = random(day)
        let comes = random.below(oneDayIn) == 0
        let hour = 9 + random.below(13)
        let team = VillainTeam.allCases[random.below(VillainTeam.allCases.count)]
        return (comes, hour, team)
    }

    static func random(_ text: String) -> BattleRandom {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in "villain:\(text)".utf8 { hash = (hash ^ UInt64(byte)) &* 0x100_0000_01b3 }
        return BattleRandom(seed: hash)
    }

    /// The item a team goes for, and how many: a tier by its weight among those the Bag holds, then one of its items.
    static func target(_ bag: [ItemKind: Int], random: inout BattleRandom) -> (kind: ItemKind, count: Int)? {
        let held = bag.filter { $0.value > 0 && tier(of: $0.key) != nil }.keys.sorted { $0.rawValue < $1.rawValue }
        let byTier = Dictionary(grouping: held) { tier(of: $0) ?? .t1 }
        let tiers = DungeonTier.allCases.filter { byTier[$0] != nil }
        let total = tiers.reduce(0) { $0 + (tierWeights[$1] ?? 0) }
        guard total > 0 else { return nil }
        var roll = random.below(total)
        for tier in tiers {
            let weight = tierWeights[tier] ?? 0
            if roll < weight, let items = byTier[tier] {
                let kind = items[random.below(items.count)]
                return (kind, count(of: kind, have: bag[kind] ?? 0))
            }
            roll -= weight
        }
        return nil
    }

    /// Three grunts' Pokémon, none twice.
    static func grunts(_ team: VillainTeam, random: inout BattleRandom) -> [Int] {
        var pool = team.grunts
        var picked: [Int] = []
        while picked.count < 3, !pool.isEmpty { picked.append(pool.remove(at: random.below(pool.count))) }
        return picked
    }

    /// The ambush's HP and stats: they come three against six, so each stands longer, more so for a precious item (the
    /// owner: "faut pas que tu les battes tout le temps"). Measured on 2026-11-10 over 420 fights a tier, a team of
    /// legendaries wins 91, 80, 72, 57 and 44 % from T1 to T5, Charizard and friends 49, 27, 13, 8 and 4 %.
    static func ambushFactors(_ tier: DungeonTier) -> (hp: Double, stats: Double) {
        switch tier {
        case .t1: (2.6, 1.15)
        case .t2: (2.8, 1.19)
        case .t3: (3.0, 1.23)
        case .t4: (3.2, 1.27)
        case .t5: (3.4, 1.31)
        }
    }

    static func gruntSpecs(_ species: [Int], tier: DungeonTier, seed: UInt64) -> [BattlerSpec] {
        var random = BattleRandom(seed: seed)
        let (hp, stats) = ambushFactors(tier)
        return species.enumerated().compactMap { i, id in
            let ivs = (0..<6).map { _ in 16 + random.below(16) }
            return BattlerSpec.make(id: "grunt-\(i)-\(id)", speciesID: id, level: 100, ivs: ivs, hpFactor: hp, statFactor: stats)
        }
    }

    /// The leader's three at the hideout's end, each a boss of its tier at two thirds of a lone boss's HP (three in a row),
    /// their legendary as one (`ExpeditionEngine.bossSpec`).
    static func leaderSpecs(_ team: VillainTeam, tier: DungeonTier, random: inout BattleRandom) -> [BattlerSpec] {
        var specs: [BattlerSpec] = []
        for (i, id) in team.leaderTeam(tier).enumerated() {
            guard var spec = ExpeditionEngine.bossSpec(ExpeditionBoss(speciesID: id, form: nil, isShiny: false), tier: tier,
                                                       random: &random) else { continue }
            spec.id = "leader-\(i)-\(id)"
            if !(SpeciesInfo.all[id]?.isLegendary ?? false) {
                spec.stats.hp = max(1, spec.stats.hp * 2 / 3)
                spec.hp = spec.stats.hp
            }
            specs.append(spec)
        }
        return specs
    }

    /// The hideout as a dungeon: its tier's floors and team size, no rule, the team's Pokémon on its floors, its
    /// leader's ace as the boss (the other two join it, `leaderSpecs`).
    static func hideout(_ stash: VillainStash) -> Dungeon {
        let size = stash.tier == .t1 ? 3 : stash.tier == .t2 ? 4 : 6
        return Dungeon(id: .hideout, tier: stash.tier, teamSize: size, rules: [], themeTypes: stash.team.themeTypes,
                       wild: stash.team.grunts, bosses: [stash.team.leaderTeam(stash.tier)[0]], unlocks: [])
    }
}
