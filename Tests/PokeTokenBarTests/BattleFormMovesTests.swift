import XCTest
@testable import PokeTokenBar

/// A battle form knows every move of its Pokémon, in every game, and its own (the owner, 2026-11-12: Legends Z-A's
/// Mega Garchomp Z had no special Dragon move, so its Special Attack 141 hit with Fire and Water only).
final class BattleFormMovesTests: XCTestCase {
    /// Its own type in its better attacking class: what its stats are for.
    func testEveryBattleFormHasAMoveOfItsTypeInItsBetterClass() {
        var lacking: [String] = []
        for form in BattleForms.all {
            guard let data = SpeciesBattleTable.data(speciesID: form.speciesID, form: form.form) else { continue }
            let physical = data.baseStats[1] >= data.baseStats[3]
            let own = data.pool.compactMap(MoveTable.move).contains { move in
                move.isDamaging && data.types.contains(move.type) && (move.moveClass == .physical) == physical
            }
            if !own { lacking.append("\(form.speciesID)-\(form.form.rawValue)") }
        }
        XCTAssertTrue(lacking.isEmpty, "\(lacking)")
    }

    func testMegaGarchompZHasItsSpecialDragonMoves() throws {
        let data = try XCTUnwrap(SpeciesBattleTable.data(speciesID: 445, form: PokemonForm("mega-z")))
        XCTAssertTrue(data.pool.contains("dragon-pulse"))
        XCTAssertTrue(data.pool.contains("draco-meteor"))
        XCTAssertTrue(data.pool.contains("earth-power"), "Garchomp's own Ground, special")
    }
}
