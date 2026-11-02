import Foundation

/// How well one Pokémon fares against another, without playing it out: the share of the foe's HP its best move takes
/// per second, minus the share of its own the foe's best move takes. The engine sends in the bench's best with it
/// (Q13), and "Compose for me" builds a team with it.
enum BattleMatchup {
    static func score(_ attacker: BattlerSpec, against defender: BattlerSpec) -> Double {
        pressure(attacker, on: defender) - pressure(defender, on: attacker)
    }

    /// The share of `defender`'s HP `attacker`'s strongest looped move takes per second of casting.
    static func pressure(_ attacker: BattlerSpec, on defender: BattlerSpec) -> Double {
        let moves = attacker.moves.compactMap(MoveTable.move).filter(\.isDamaging)
        guard !moves.isEmpty, defender.stats.hp > 0 else { return 0 }
        let rate = 300 / (100 + Double(attacker.stats.speed)) / Double(BattleRules.speedUp)
        return moves.map { move -> Double in
            let effectiveness = defender.types.reduce(1.0) {
                $0 * PokemonTypeData.effectiveness(attacking: move.type, defending: $1)
            }
            let physical = move.moveClass == .physical
            let attack = Double(physical ? attacker.stats.attack : attacker.stats.specialAttack)
            let defense = Double(max(1, physical ? defender.stats.defense : defender.stats.specialDefense))
            let power = Double(move.power > 0 ? move.power : 60)
            let stab = attacker.types.contains(move.type) ? 1.5 : 1
            let hits = move.maxHits > 1 ? Double(move.minHits + move.maxHits) / 2 : 1
            let level = Double(attacker.level)
            let damage = ((2 * level / 5 + 2) * power * attack / defense / 50 + 2) * stab * effectiveness * hits
                * Double(move.accuracy == 0 ? 100 : move.accuracy) / 100
            let seconds = Double(move.castBase) * rate / 1000
            return damage / Double(defender.stats.hp) / max(0.1, seconds)
        }.max() ?? 0
    }
}
