import Foundation

/// What a team's types say against a dungeon's (#139, the owner's "Compose for me" doubts of 2026-11-06): the
/// multiplier its moves reach on each theme type, the members each one hits twice, and a fit for each candidate. The
/// team screen shows them; the choice itself is the simulation's (`DungeonTeamBuilder.ComposeChoice`).
enum TeamMatchup {
    enum Fit: Equatable, Sendable {
        /// A move hits a theme type twice, and no theme type hits it twice.
        case strong
        /// A theme type hits it twice and none of its moves hits one twice, or its moves do little to every one.
        case weak
        case neutral
    }

    /// The best multiplier its damaging moves reach on a single type.
    static func best(_ spec: BattlerSpec, against type: PokemonType) -> Double {
        spec.moves.compactMap(MoveTable.move).filter(\.isDamaging)
            .map { PokemonTypeData.effectiveness(attacking: $0.type(for: spec), defending: type) }.max() ?? 0
    }

    /// What a type's attacks do to it: the type against each of its own.
    static func taken(_ spec: BattlerSpec, from type: PokemonType) -> Double {
        spec.types.reduce(1) { $0 * PokemonTypeData.effectiveness(attacking: type, defending: $1) }
    }

    static func fit(_ spec: BattlerSpec, against types: [PokemonType]) -> Fit {
        guard !types.isEmpty else { return .neutral }
        let hits = types.contains { best(spec, against: $0) >= 2 }
        let weak = types.contains { taken(spec, from: $0) >= 2 }
        if hits && !weak { return .strong }
        if weak && !hits { return .weak }
        if !hits && types.allSatisfy({ best(spec, against: $0) < 1 }) { return .weak }
        return .neutral
    }

    /// For each theme type, the best multiplier the team's moves reach on it, and how many members it hits twice.
    struct Line: Equatable, Sendable {
        let type: PokemonType
        let best: Double
        let weakMembers: Int
    }

    static func summary(team: [BattlerSpec], against types: [PokemonType]) -> [Line] {
        types.map { type in
            Line(type: type, best: team.map { best($0, against: type) }.max() ?? 0,
                 weakMembers: team.filter { taken($0, from: type) >= 2 }.count)
        }
    }

    /// "×2", "×½", "×0": the multiplier written.
    static func multiplierText(_ value: Double) -> String {
        switch value {
        case 0: "×0"
        case 0.25: "×¼"
        case 0.5: "×½"
        default: "×\(value == value.rounded() ? String(Int(value)) : String(value))"
        }
    }

    /// The types a team faces: the theme's, or a challenge's boss's when it has no theme.
    static func facedTypes(_ dungeon: Dungeon, boss: BattleForm?) -> [PokemonType] {
        if !dungeon.themeTypes.isEmpty { return dungeon.themeTypes }
        guard let boss else { return [] }
        return PokemonTypeData.types(forSpeciesID: boss.speciesID, form: boss.form)
    }
}
