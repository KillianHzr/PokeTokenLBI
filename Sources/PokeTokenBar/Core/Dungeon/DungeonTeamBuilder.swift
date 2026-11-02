import Foundation

/// From the Pokédex to a team: a graduated Pokémon's battle self, "Compose for me" (Q8) and the odds of reaching the
/// boss (R7), both against the dungeon's theme, never its boss.
enum DungeonTeamBuilder {
    /// A graduated Pokémon at level 100 with its IVs, nature and ability; its loop is the one chosen for it, else the
    /// four moves it knows.
    static func spec(for entry: DexEntry, loop: [String]? = nil) -> BattlerSpec? {
        let ivs = entry.profile.map { p in
            [p.ivs.hp, p.ivs.attack, p.ivs.defense, p.ivs.specialAttack, p.ivs.specialDefense, p.ivs.speed]
        } ?? Array(repeating: 15, count: 6)
        let moves = loop ?? entry.profile?.moves.map(\.name)
        return BattlerSpec.make(id: entry.id, speciesID: entry.finalID, form: entry.form, level: 100, ivs: ivs,
                                nature: entry.nature, ability: entry.profile?.abilityName, moves: moves,
                                isShiny: entry.isShiny)
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
    /// one region) tries each type or region and keeps the best group. Empty when no team of `size` fits.
    static func compose(_ pool: [(candidate: DungeonCandidate, spec: BattlerSpec)], dungeon: Dungeon, size: Int,
                        rules: [DungeonRule]) -> [String] {
        let foes = sampleFoes(dungeon)
        let ranked = pool.filter { DungeonTeamRules.admits($0.candidate, rules: rules) }
            .map { (entry: $0, score: themeScore($0.spec, foes: foes)) }
            .sorted { ($0.score, $0.entry.candidate.entryID) > ($1.score, $1.entry.candidate.entryID) }
        func greedy(_ list: [(entry: (candidate: DungeonCandidate, spec: BattlerSpec), score: Double)]) -> (ids: [String], score: Double) {
            var team: [DungeonCandidate] = []
            var score = 0.0
            for item in list where team.count < size {
                guard !team.contains(where: { $0.speciesID == item.entry.candidate.speciesID }) else { continue }
                let next = team + [item.entry.candidate]
                guard rules.allSatisfy({ DungeonTeamRules.holds($0, for: next) || $0 == .sharedType || $0 == .oneRegion })
                else { continue }
                team = next
                score += item.score
            }
            return (team.map(\.entryID), team.count == size ? score : -.infinity)
        }
        var groups: [[(entry: (candidate: DungeonCandidate, spec: BattlerSpec), score: Double)]] = [ranked]
        if rules.contains(.sharedType) {
            groups = PokemonType.allCases.map { type in ranked.filter { $0.entry.candidate.types.contains(type) } }
        }
        if rules.contains(.oneRegion) {
            let regions = Set(ranked.map(\.entry.candidate.generation)).sorted()
            groups = groups.flatMap { group in regions.map { region in group.filter { $0.entry.candidate.generation == region } } }
        }
        let best = groups.map(greedy).max { $0.score < $1.score }
        guard let best, best.score > -.infinity else { return [] }
        return best.ids
    }

    /// R7: the share of `runs` expeditions that reach the boss, the boss itself left out.
    static func reachOdds(team: [ExpeditionMember], dungeon: Dungeon, runs: Int = 24, seed: UInt64 = 1,
                          berries: [BattleBerry: Int] = [:], revives: [String: Int] = [:]) -> Double {
        guard !team.isEmpty, runs > 0 else { return 0 }
        let context = ExpeditionContext(tier: dungeon.tier, shinyDenominator: 64, now: Date(timeIntervalSince1970: 0))
        var reached = 0
        for run in 0..<runs {
            var expedition = ExpeditionEngine.start(dungeon: dungeon, team: team, rules: dungeon.rules,
                                                    teamSize: team.count, seed: seed &+ UInt64(run) &* 7919,
                                                    cost: dungeon.floors * 1000, berries: berries, revives: revives,
                                                    context: context)
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
