import Foundation

/// R4: the four moves the app suggests for a Pokémon in a dungeon, among those it can learn and the player may use (an
/// offensive move of 100 power or more only once a Technical Capsule unlocked it). A setup or recovery move first
/// when it has one, then its strongest moves of its own types, then the best against the dungeon's theme.
enum MoveSuggester {
    static func suggest(_ data: SpeciesBattleData, stats: BattleStats, types: [PokemonType], learnable: [String] = [],
                        unlocked: Set<String> = [], theme: [PokemonType] = []) -> [String] {
        let physical = stats.attack >= stats.specialAttack
        let candidates = Array(Set(data.pool + learnable)).sorted().compactMap(MoveTable.move).filter { move in
            move.hasEffect && !move.isZOrMax && (!move.isLocked || unlocked.contains(move.slug)) && !avoided.contains(move.slug)
        }
        func damage(_ move: BattleMove) -> Double {
            guard move.isDamaging, move.power > 0 else { return 0 }
            var power = Double(move.power)
            if move.charges || move.recharges { power *= 0.5 }
            if move.category == .damageRaise, move.statChanges.contains(where: { $0.change < 0 }) { power *= 0.6 }
            let hits = move.maxHits > 1 ? Double(move.minHits + move.maxHits) / 2 : 1
            let accuracy = Double(move.accuracy == 0 ? 100 : move.accuracy) / 100
            let own = types.contains(move.type) ? 1.5 : 1
            let fits = (move.moveClass == .physical) == physical ? 1 : 0.55
            let coverage = theme.isEmpty ? 1 : theme.reduce(0.0) {
                $0 + PokemonTypeData.effectiveness(attacking: move.type, defending: $1)
            } / Double(theme.count)
            return power * hits * accuracy * own * fits * coverage
        }
        let ranked = candidates.filter { damage($0) > 0 }.sorted { (damage($0), $1.slug) > (damage($1), $0.slug) }
        var chosen: [BattleMove] = []
        for own in types {
            if let best = ranked.first(where: { $0.type == own && !chosen.contains($0) }) { chosen.append(best) }
        }
        let support = candidates.filter { !$0.isDamaging }.max { supportScore($0, physical: physical) < supportScore($1, physical: physical) }
            .flatMap { supportScore($0, physical: physical) > 0 ? $0 : nil }
        let room = support == nil ? 4 : 3
        for move in ranked where chosen.count < room && !chosen.contains(move)
            && !chosen.map(\.type).contains(move.type) {
            chosen.append(move)
        }
        for move in ranked where chosen.count < room && !chosen.contains(move) { chosen.append(move) }
        chosen = Array(chosen.prefix(room)).sorted { damage($0) > damage($1) }
        if let support { chosen.insert(support, at: 0) }
        return chosen.map(\.slug)
    }

    /// Setups that suit the Pokémon's side first, then recovery, then a status that hinders the foe.
    private static func supportScore(_ move: BattleMove, physical: Bool) -> Int {
        let boosts = move.statChanges.filter { $0.change > 0 }
        if move.targetsOwnSide, !boosts.isEmpty {
            let attack = boosts.contains { $0.stat == (physical ? .attack : .specialAttack) }
            let wrong = boosts.contains { $0.stat == (physical ? .specialAttack : .attack) } && !attack
            if wrong { return 0 }
            return attack ? 30 + boosts.reduce(0) { $0 + $1.change } : 10
        }
        if BattleSimulation.statusKind(move) == .heal, move.target == "user" { return 20 }
        if let ailment = move.ailment, [.burn, .paralysis, .sleep, .badPoison, .poison].contains(ailment),
           !move.isDamaging { return move.accuracy == 0 || move.accuracy >= 90 ? 15 : 8 }
        return 0
    }

    /// Moves a loop never suggests: they knock their user out, wait for a setup the loop cannot make, or misfire.
    private static let avoided: Set<String> = ["explosion", "self-destruct", "misty-explosion", "final-gambit",
                                                "memento", "dream-eater", "nightmare", "focus-punch", "struggle",
                                                "belch", "fake-out", "first-impression", "rest", "belly-drum",
                                                "destiny-bond", "future-sight", "doom-desire", "snore", "sleep-talk"]
}
