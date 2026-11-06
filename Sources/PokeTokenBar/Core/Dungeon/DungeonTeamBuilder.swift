import Foundation

/// From the Pokédex to a team: a graduated Pokémon's battle self, "Compose for me" (Q8) and the odds of reaching the
/// boss (R7), both against the dungeon's theme, never its boss.
enum DungeonTeamBuilder {
    /// A graduated Pokémon at level 100 with its IVs, nature and ability; its loop is the one chosen for it, else the
    /// one the app suggests against `theme` with the moves `unlocked` (R4).
    static func spec(for entry: DexEntry, loop: [String]? = nil, unlocked: Set<String> = [],
                     theme: [PokemonType] = []) -> BattlerSpec? {
        let ivs = entry.profile.map { p in
            [p.ivs.hp, p.ivs.attack, p.ivs.defense, p.ivs.specialAttack, p.ivs.specialDefense, p.ivs.speed]
        } ?? Array(repeating: 15, count: 6)
        // A battle form has its own ability (a Mega Charizard X's Tough Claws), not the Pokémon's usual one.
        let ability = BattleForms.form(speciesID: entry.finalID, form: entry.form) == nil ? entry.profile?.abilityName : nil
        guard var spec = BattlerSpec.make(id: entry.id, speciesID: entry.finalID, form: entry.form, level: 100, ivs: ivs,
                                          nature: entry.nature, ability: ability, isShiny: entry.isShiny),
              let data = SpeciesBattleTable.data(speciesID: entry.finalID, form: entry.form) else { return nil }
        // Its profile's gender, or the one its profile will draw once enriched.
        spec.gender = entry.profile.flatMap { profile in
            profile.gender ?? SpeciesInfo.all[entry.finalID]?.genderRate.map(profile.drawnGender)
        }
        let chosen = (loop ?? []).filter { MoveTable.move($0) != nil }
        spec.moves = chosen.isEmpty
            ? MoveSuggester.suggest(data, stats: spec.stats, types: spec.types,
                                    learnable: entry.profile?.moves.map(\.name) ?? [], unlocked: unlocked, theme: theme)
            : Array(chosen.prefix(4))
        if spec.moves.isEmpty { spec.moves = ["struggle"] }
        return spec
    }

    /// The dungeon's wild Pokémon at the middle of its tier's levels, IVs of 15: what a team is measured against.
    static func sampleFoes(_ dungeon: Dungeon, limit: Int = 24) -> [BattlerSpec] {
        let level = (dungeon.tier.wildLevels.lowerBound + dungeon.tier.wildLevels.upperBound) / 2
        let step = max(1, dungeon.wild.count / limit)
        return stride(from: 0, to: dungeon.wild.count, by: step).compactMap { i in
            BattlerSpec.make(id: "sample\(i)", speciesID: dungeon.wild[i], level: level,
                             ivs: Array(repeating: 15, count: 6))
        }
    }

    /// How a Pokémon fares against the theme: its mean matchup over the sample.
    static func themeScore(_ spec: BattlerSpec, foes: [BattlerSpec]) -> Double {
        guard !foes.isEmpty else { return 0 }
        let bulk = Double(spec.stats.hp) * Double(spec.stats.defense + spec.stats.specialDefense) / 200_000
        return foes.reduce(0) { $0 + BattleMatchup.score(spec, against: $1) } / Double(foes.count) + bulk
    }

    /// Q8: the best team the rules allow, the strongest against the theme first. A team-wide rule (one shared type,
    /// one region) tries each type or region and keeps the best group. Empty when no team of `size` fits. The team
    /// screen then lets the simulation decide among `candidateTeams` (`ComposeChoice`).
    static func compose(_ pool: [(candidate: DungeonCandidate, spec: BattlerSpec)], dungeon: Dungeon, size: Int,
                        rules: [DungeonRule]) -> [String] {
        candidateTeams(pool, dungeon: dungeon, size: size, rules: rules).first ?? []
    }

    /// The teams "Compose for me" weighs, the best by theme score first: each group's best (one per type or region a
    /// team-wide rule asks), then each again with the dungeon's bosses counted. The Mt. Moon of 2026-11-05 showed why
    /// the theme score alone is not enough: its best region won 85% of the runs, another one 98%.
    static func candidateTeams(_ pool: [(candidate: DungeonCandidate, spec: BattlerSpec)], dungeon: Dungeon, size: Int,
                               rules: [DungeonRule], keep: Int = 6) -> [[String]] {
        let foes = sampleFoes(dungeon)
        var random = BattleRandom(seed: 1)
        let bosses = dungeon.bosses.prefix(8).compactMap {
            ExpeditionEngine.bossSpec(ExpeditionBoss(speciesID: $0, form: nil, isShiny: false), tier: dungeon.tier, random: &random)
        }
        let admitted = pool.filter { DungeonTeamRules.admits($0.candidate, rules: rules) }
        let theme = admitted.map { themeScore($0.spec, foes: foes) }
        let withBosses = admitted.indices.map { i in
            bosses.isEmpty ? theme[i]
                : theme[i] + bosses.reduce(0) { $0 + BattleMatchup.score(admitted[i].spec, against: $1) } / Double(bosses.count)
        }
        func greedy(_ order: [Int], _ score: [Double]) -> (ids: [String], score: Double)? {
            var team: [DungeonCandidate] = [], total = 0.0
            for i in order where team.count < size {
                let item = admitted[i]
                guard !team.contains(where: { $0.speciesID == item.candidate.speciesID }) else { continue }
                let next = team + [item.candidate]
                guard rules.allSatisfy({ DungeonTeamRules.holds($0, for: next) || $0 == .sharedType || $0 == .oneRegion })
                else { continue }
                team = next
                total += score[i]
            }
            return team.count == size ? (team.map(\.entryID), total) : nil
        }
        var groups: [[Int]] = [Array(admitted.indices)]
        if rules.contains(.sharedType) {
            groups = PokemonType.allCases.map { type in admitted.indices.filter { admitted[$0].candidate.types.contains(type) } }
        }
        if rules.contains(.oneRegion) {
            let regions = Set(admitted.map(\.candidate.generation)).sorted()
            groups = groups.flatMap { group in regions.map { region in group.filter { admitted[$0].candidate.generation == region } } }
        }
        func ranked(_ score: [Double]) -> [(ids: [String], score: Double)] {
            groups.compactMap { group in
                greedy(group.sorted { (score[$0], admitted[$0].candidate.entryID) > (score[$1], admitted[$1].candidate.entryID) }, score)
            }
            .sorted { $0.score > $1.score }
        }
        var teams: [[String]] = []
        for team in ranked(theme).prefix(keep).map(\.ids) + ranked(withBosses).prefix(keep / 2).map(\.ids)
        where !teams.contains(where: { Set($0) == Set(team) }) {
            teams.append(team)
        }
        return teams
    }

    /// "Compose for me" off the main thread: each candidate team run to its end, its boss included, the same runs for
    /// all; the one that wins most, the best by theme score on a tie.
    struct ComposeChoice: Sendable {
        let teams: [[ExpeditionMember]]
        let dungeon: Dungeon
        let boss: ExpeditionBoss?

        func run(runs: Int = 24) -> [String] {
            guard teams.count > 1 else { return teams.first?.map(\.entryID) ?? [] }
            var best: (ids: [String], odds: Double)?
            for team in teams {
                let odds = DungeonTeamBuilder.winOdds(team: team, dungeon: dungeon, runs: runs, boss: boss)
                if best.map({ odds > $0.odds }) ?? true { best = (team.map(\.entryID), odds) }
            }
            return best?.ids ?? []
        }
    }

    /// The share of `runs` expeditions this team wins: every floor, then its boss falling.
    static func winOdds(team: [ExpeditionMember], dungeon: Dungeon, runs: Int = 24, seed: UInt64 = 1,
                        boss: ExpeditionBoss? = nil) -> Double {
        guard !team.isEmpty, runs > 0 else { return 0 }
        let context = ExpeditionContext(tier: dungeon.tier, shinyDenominator: 64, now: Date(timeIntervalSince1970: 0))
        var won = 0
        for run in 0..<runs {
            var expedition = ExpeditionEngine.start(dungeon: dungeon, team: team, rules: dungeon.rules,
                                                    teamSize: team.count, seed: seed &+ UInt64(run) &* 7919,
                                                    cost: dungeon.floors * 1000, berries: [:], revives: [:],
                                                    context: context, boss: boss)
            // Bounded: every feed walks a floor or ends the run.
            for _ in 0...(dungeon.floors * 4) {
                if case .capture = expedition.phase { break }
                if expedition.isOver { break }
                ExpeditionEngine.feed(&expedition, tokens: expedition.floorCost, context: context)
                if case .awaitingHeal = expedition.phase {
                    ExpeditionEngine.answerHeal(&expedition, paid: false, context: context)
                }
            }
            if case .capture = expedition.phase { won += 1 } else if case .finished(won: true) = expedition.phase { won += 1 }
        }
        return Double(won) / Double(runs)
    }

    /// What `reachOdds` runs on, built on the main thread (`CompanionStore.reachEstimate`), run off it.
    struct ReachEstimate: Sendable {
        let team: [ExpeditionMember]
        let dungeon: Dungeon
        let berries: [BattleBerry: Int]
        let revives: [String: Int]
        let boss: ExpeditionBoss?

        func run() -> Odds {
            DungeonTeamBuilder.odds(team: team, dungeon: dungeon, berries: berries, revives: revives, boss: boss)
        }
    }

    /// R7 and the owner's ask of 2026-11-06 ("a player with no good Pokémon should not enter"): the share of runs that
    /// reach the boss, and of those that win, the boss falling. A dungeon's boss is drawn as at the entry, so the
    /// second is its odds over every boss it may hold, never telling which.
    struct Odds: Sendable, Equatable {
        let reach: Double
        let win: Double
    }

    static func odds(team: [ExpeditionMember], dungeon: Dungeon, runs: Int = 24, seed: UInt64 = 1,
                     berries: [BattleBerry: Int] = [:], revives: [String: Int] = [:], boss: ExpeditionBoss? = nil) -> Odds {
        guard !team.isEmpty, runs > 0 else { return Odds(reach: 0, win: 0) }
        let context = ExpeditionContext(tier: dungeon.tier, shinyDenominator: 64, now: Date(timeIntervalSince1970: 0))
        var reached = 0, won = 0
        for run in 0..<runs {
            var expedition = ExpeditionEngine.start(dungeon: dungeon, team: team, rules: dungeon.rules,
                                                    teamSize: team.count, seed: seed &+ UInt64(run) &* 7919,
                                                    cost: dungeon.floors * 1000, berries: berries, revives: revives,
                                                    context: context, boss: boss)
            var atBoss = false
            // Bounded: every feed walks a floor or ends the run.
            for _ in 0...(dungeon.floors * 4) {
                if case .capture = expedition.phase { break }
                if expedition.isOver { break }
                if !atBoss, expedition.floor >= expedition.floors, !expedition.team.allSatisfy(\.isFainted) { atBoss = true }
                ExpeditionEngine.feed(&expedition, tokens: expedition.floorCost, context: context)
                if case .awaitingHeal = expedition.phase {
                    ExpeditionEngine.answerHeal(&expedition, paid: false, context: context)
                }
            }
            let win: Bool
            if case .capture = expedition.phase { win = true } else if case .finished(won: true) = expedition.phase { win = true } else { win = false }
            if atBoss || win { reached += 1 }
            if win { won += 1 }
        }
        return Odds(reach: Double(reached) / Double(runs), win: Double(won) / Double(runs))
    }

    /// R7: the share of `runs` expeditions that reach the boss, the boss itself left out.
    static func reachOdds(team: [ExpeditionMember], dungeon: Dungeon, runs: Int = 24, seed: UInt64 = 1,
                          berries: [BattleBerry: Int] = [:], revives: [String: Int] = [:],
                          boss: ExpeditionBoss? = nil) -> Double {
        guard !team.isEmpty, runs > 0 else { return 0 }
        let context = ExpeditionContext(tier: dungeon.tier, shinyDenominator: 64, now: Date(timeIntervalSince1970: 0))
        var reached = 0
        for run in 0..<runs {
            var expedition = ExpeditionEngine.start(dungeon: dungeon, team: team, rules: dungeon.rules,
                                                    teamSize: team.count, seed: seed &+ UInt64(run) &* 7919,
                                                    cost: dungeon.floors * 1000, berries: berries, revives: revives,
                                                    context: context, boss: boss)
            // Walk every floor but the boss's; an emergency heal is taken, as the estimate assumes the player answers.
            while expedition.floor < expedition.floors, !expedition.isOver {
                ExpeditionEngine.feed(&expedition, tokens: expedition.floorCost, context: context)
                if case .awaitingHeal = expedition.phase {
                    ExpeditionEngine.answerHeal(&expedition, paid: false, context: context)
                }
            }
            if !expedition.isOver, !expedition.team.allSatisfy(\.isFainted) { reached += 1 }
        }
        return Double(reached) / Double(runs)
    }
}
