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

    /// A player's Pokémon in a battle form is stronger (the owner, 2026-11-12): a Mega or a Primal every stat ×1.25, a
    /// Gigantamax its HP ×2 and the rest ×1.25, its HP full; in its usual form, as it was.
    func testABattleFormIsStrongerForThePlayer() throws {
        func entry(_ species: Int, _ form: String?) -> DexEntry {
            var e = DexEntry(baseID: SpeciesInfo.baseID(of: species), finalID: species, chainOrder: [species], rarity: .rare,
                             caughtAt: nil)
            e.form = form.map { PokemonForm($0) }
            e.nature = .hardy
            return e
        }
        func plain(_ species: Int, _ form: String?) throws -> BattleStats {
            try XCTUnwrap(BattlerSpec.make(id: "x", speciesID: species, form: form.map { PokemonForm($0) }, level: 100,
                                           ivs: Array(repeating: 15, count: 6), nature: .hardy)).stats
        }
        let mega = try XCTUnwrap(DungeonTeamBuilder.spec(for: entry(445, "mega-z")))
        XCTAssertEqual(mega.stats, try plain(445, "mega-z").scaled(hp: 1.25, stats: 1.25))
        XCTAssertEqual(mega.hp, mega.stats.hp)
        let gmax = try XCTUnwrap(DungeonTeamBuilder.spec(for: entry(6, "gmax")))
        XCTAssertEqual(gmax.stats, try plain(6, "gmax").scaled(hp: 2, stats: 1.25))
        let primal = try XCTUnwrap(DungeonTeamBuilder.spec(for: entry(382, "primal")))
        XCTAssertEqual(primal.stats, try plain(382, "primal").scaled(hp: 1.25, stats: 1.25))
        let usual = try XCTUnwrap(DungeonTeamBuilder.spec(for: entry(445, nil)))
        XCTAssertEqual(usual.stats, try plain(445, nil))
    }
}
