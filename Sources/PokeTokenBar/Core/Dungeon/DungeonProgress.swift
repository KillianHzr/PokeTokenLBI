import Foundation

/// How an expedition ended, kept for the return screen (maquette 7) until the player has seen it.
struct ExpeditionResult: Codable, Sendable, Equatable {
    var dungeon: DungeonID
    /// The boss fell (whatever the throws).
    var won: Bool
    /// The team left before the boss, its floors' loot kept (once only with an Escape Rope, hence the name).
    var roped = false
    var startedAt: Date
    var endedAt: Date
    var tokens: Int
    var battles: Int
    var boss: ExpeditionBoss
    var caught: Bool
    /// What went into the Bag: the loot, doubled on a first victory, and the victory's extras.
    var loot: ExpeditionLoot
    var firstVictory: Bool
    /// The dungeons this result opened (Q27).
    var unlocked: [DungeonID]
    /// The move a Technical Capsule unlocked (R4), if one dropped.
    var unlockedMove: String?
    /// The battle form a challenge won (`BattleForm.key`).
    var battleForm: String? = nil
    /// What the boss's capture gave (`Expedition.BossReward`), nil for its own egg: the result card says so.
    var bossReward: Expedition.BossReward? = nil
    var log: [ExpeditionLogEntry]
}

/// The dungeons' side of the save, decoded field by field so a damaged one never costs the rest.
struct DungeonProgress: Codable, Sendable, Equatable {
    var expedition: Expedition?
    /// Victories by dungeon (`DungeonID.rawValue`).
    var wins: [String: Int] = [:]
    /// Bosses reached (Q17: their silhouette shows), as "dungeon:species".
    var bossesReached: Set<String> = []
    /// Bosses beaten (shown whole), as "dungeon:species".
    var bossesBeaten: Set<String> = []
    /// The loop each graduated Pokémon fights with (R4), by Pokédex entry.
    var moveLoops: [String: [String]] = [:]
    /// Offensive moves of 100 power or more unlocked by Technical Capsules (R4).
    var unlockedMoves: Set<String> = []
    /// Eggs won: bosses and shinies caught, in the Bag until used.
    var eggs: [DungeonEgg] = []
    var lastResult: ExpeditionResult?
    /// Expeditions set off, which seeds each one and the Ruins of Alph's rules.
    var departures = 0
    /// Battle forms won (`BattleForm.key`), never used up: in the Pokédex, and for any graduated Pokémon of the species.
    var battleForms: Set<String> = []
    /// The battle form each graduated Pokémon fights in, by Pokédex entry; none for its usual form.
    var battleFormChoice: [String: String] = [:]
    /// The day (`yyyy-MM-dd`) and the week (`yyyy-Www`) whose challenge was tried: one try each.
    var dailyTried: String?
    var weeklyTried: String?
    /// The challenges' bosses as first shown ("daily:2026-11-02" → `BattleForm.key`), kept for their period.
    var challengeDraws: [String: String] = [:]
    /// The legendary bosses whose egg was won, or the Legendary Egg in its place: once per species (the owner,
    /// 2026-11-04). They give the loot only afterwards.
    var legendaryEggsWon: Set<Int> = []

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        expedition = c.lenientOptional(Expedition.self, forKey: .expedition)
        wins = c.lenient([String: Int].self, forKey: .wins, default: [:])
        bossesReached = c.lenient(Set<String>.self, forKey: .bossesReached, default: [])
        bossesBeaten = c.lenient(Set<String>.self, forKey: .bossesBeaten, default: [])
        moveLoops = c.lenient([String: [String]].self, forKey: .moveLoops, default: [:])
        unlockedMoves = c.lenient(Set<String>.self, forKey: .unlockedMoves, default: [])
        eggs = c.lenient([Lossy<DungeonEgg>].self, forKey: .eggs, default: []).compactMap(\.value)
        lastResult = c.lenientOptional(ExpeditionResult.self, forKey: .lastResult)
        departures = c.lenient(Int.self, forKey: .departures, default: 0)
        // Only the forms this build knows: one a later build added waits, unread, for that build.
        battleForms = c.lenient(Set<String>.self, forKey: .battleForms, default: []).filter { BattleForms.form(key: $0) != nil }
        battleFormChoice = c.lenient([String: String].self, forKey: .battleFormChoice, default: [:])
        dailyTried = c.lenientOptional(String.self, forKey: .dailyTried)
        weeklyTried = c.lenientOptional(String.self, forKey: .weeklyTried)
        challengeDraws = c.lenient([String: String].self, forKey: .challengeDraws, default: [:])
        legendaryEggsWon = c.lenient(Set<Int>.self, forKey: .legendaryEggsWon, default: [])
    }

    func wins(_ id: DungeonID) -> Int { wins[id.rawValue] ?? 0 }

    static func bossKey(_ dungeon: DungeonID, _ species: Int) -> String { "\(dungeon.rawValue):\(species)" }

    /// Whether this boss fell anywhere.
    func beat(_ species: Int) -> Bool { bossesBeaten.contains { $0.hasSuffix(":\(species)") } }
}
