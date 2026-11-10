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
    /// What a hideout's leader gave back (issue #180).
    var recovered: [String: Int]? = nil
    /// The secret boss met, how it went (`SecretBosses`).
    var secret: SecretEncounter? = nil
    /// Whose hideout it was.
    var villain: VillainTeam? { dungeon.villain }
    var log: [ExpeditionLogEntry]
}

/// One expedition that ended, for its dungeon's page (2026-11-05): when, how, how deep, what it brought.
struct DungeonRunRecord: Codable, Sendable, Equatable {
    var dungeon: DungeonID
    var endedAt: Date
    var won: Bool
    /// The team left before the boss.
    var left: Bool
    var floor: Int
    var floors: Int
    var tokens: Int
    var candies: Int
    var eggs: Int
    var items: Int
    var bossSpeciesID: Int
    var caught: Bool
    /// #133: the journal and the team as they ended, every battle replayable; the latest `journalsKept` only, the
    /// older ones a line (5 to 22 KB each, measured on 2026-11-06).
    var log: [ExpeditionLogEntry]?
    var team: [ExpeditionMember]?

    static let kept = 100
    static let journalsKept = 30

    /// The last ones kept, and the journals of the latest `journalsKept` of them.
    static func trimmed(_ history: [DungeonRunRecord]) -> [DungeonRunRecord] {
        var kept = Array(history.suffix(kept))
        for i in kept.indices.dropLast(journalsKept) {
            kept[i].log = nil
            kept[i].team = nil
        }
        return kept
    }
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
    /// When each battle form was won, for its line in the catch log (the owner, 2026-11-10); those won before it was
    /// kept take their challenge's win in the history, none when it is gone.
    var battleFormsWonAt: [String: Date] = [:]
    /// The battle form each graduated Pokémon fights in, by Pokédex entry; none for its usual form.
    var battleFormChoice: [String: String] = [:]
    /// The day (`yyyy-MM-dd`) and the week (`yyyy-Www`) whose challenge was tried: one try each.
    var dailyTried: String?
    var weeklyTried: String?
    /// The challenges' bosses as first shown ("daily:2026-11-02" → `BattleForm.key`), kept for their period.
    var challengeDraws: [String: String] = [:]
    /// The boss each challenge was beaten against, by the period its run set off in (keyed as `challengeDraws`): the
    /// day's boss stays until the next day, the week's until Monday, its dungeon closed till then (the owner,
    /// 2026-11-10: "une forme de la semaine par semaine au plus"). Filled from the history in a save from before.
    var challengeWins: [String: String] = [:]
    /// The legendary bosses whose egg was won, or the Legendary Egg in its place: once per species (the owner,
    /// 2026-11-04). They give the loot only afterwards.
    var legendaryEggsWon: Set<Int> = []
    /// The player's general team (entry ids, six at most): a dungeon's team screen starts from it (a player, 2026-11-05).
    var savedTeam: [String] = []
    /// The expeditions that ended, the latest last, a hundred at most: each dungeon's page lists its own.
    var history: [DungeonRunRecord] = []
    /// The thefts waiting on Home to be chased, then how it went (issue #180): they add up (the owner, 2026-11-10).
    var ambushes: [VillainAmbush] = []
    /// What each team took to its hideout, one a team: its hideout stays open until its leader falls.
    var stashes: [VillainStash] = []
    /// The last day (`yyyy-MM-dd`) whose draw was settled: one theft a day at most.
    var villainDay: String?
    /// The last day a team stole: never two days in a row.
    var villainLastTheft: String?
    /// The secret bosses met and those caught (`SecretBosses.key`, "seafoamIslands:144:galar"), apart from the
    /// dungeons' bosses: they count for none of their records.
    var secretsMet: Set<String> = []
    var secretsCaught: Set<String> = []

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
        secretsMet = c.lenient(Set<String>.self, forKey: .secretsMet, default: [])
        secretsCaught = c.lenient(Set<String>.self, forKey: .secretsCaught, default: [])
        savedTeam = c.lenient([String].self, forKey: .savedTeam, default: [])
        history = c.lenient([Lossy<DungeonRunRecord>].self, forKey: .history, default: []).compactMap(\.value)
        battleFormsWonAt = c.lenient([String: Date].self, forKey: .battleFormsWonAt, default: [:])
            .filter { battleForms.contains($0.key) }
        for key in battleForms where battleFormsWonAt[key] == nil {
            guard let form = BattleForms.form(key: key) else { continue }
            if let run = history.first(where: { $0.won && $0.dungeon.isChallenge && $0.bossSpeciesID == form.speciesID }) {
                battleFormsWonAt[key] = run.endedAt
            }
        }
        ambushes = c.lenient([Lossy<VillainAmbush>].self, forKey: .ambushes, default: []).compactMap(\.value)
        stashes = c.lenient([Lossy<VillainStash>].self, forKey: .stashes, default: []).compactMap(\.value)
        villainDay = c.lenientOptional(String.self, forKey: .villainDay)
        villainLastTheft = c.lenientOptional(String.self, forKey: .villainLastTheft)
        challengeWins = c.lenient([String: String].self, forKey: .challengeWins, default: [:])
            .filter { BattleForms.form(key: $0.value) != nil }
        // A save from before keyed its wins nowhere: each won run counts for the period it ended in.
        if challengeWins.isEmpty {
            for run in history where run.won && run.dungeon.isChallenge {
                let forms = (run.dungeon == .weekly ? BattleForms.weekly : BattleForms.daily)
                    .filter { $0.speciesID == run.bossSpeciesID && battleForms.contains($0.key) }
                guard let form = forms.first(where: { battleFormsWonAt[$0.key] == run.endedAt }) ?? forms.first else { continue }
                challengeWins[Self.challengeKey(run.dungeon, at: run.endedAt)] = form.key
            }
        }
    }

    /// The day (`yyyy-MM-dd`) or the ISO week (`yyyy-Www`) a challenge's boss and try belong to, in local time.
    static func challengePeriod(_ id: DungeonID, at date: Date) -> String {
        let calendar = Calendar(identifier: .iso8601)
        let c = calendar.dateComponents([.year, .month, .day, .yearForWeekOfYear, .weekOfYear], from: date)
        if id == .weekly { return String(format: "%04d-W%02d", c.yearForWeekOfYear ?? 0, c.weekOfYear ?? 0) }
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    /// "daily:2026-11-10", "weekly:2026-W46": a challenge's period, for its draw and its win.
    static func challengeKey(_ id: DungeonID, at date: Date) -> String { "\(id.rawValue):\(challengePeriod(id, at: date))" }

    func wins(_ id: DungeonID) -> Int { wins[id.rawValue] ?? 0 }

    static func bossKey(_ dungeon: DungeonID, _ species: Int) -> String { "\(dungeon.rawValue):\(species)" }

    /// Whether this boss fell anywhere.
    func beat(_ species: Int) -> Bool { bossesBeaten.contains { $0.hasSuffix(":\(species)") } }
}
