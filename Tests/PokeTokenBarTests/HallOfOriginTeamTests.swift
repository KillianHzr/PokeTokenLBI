import XCTest
@testable import PokeTokenBar

/// The Hall of Origin's team (the owner, 2026-11-10): a Mega or a Primal, a Gigantamax and four shinies, the forms
/// shiny or not; six shinies before.
@MainActor
final class HallOfOriginTeamTests: XCTestCase {
    private let rules = DungeonCatalog.dungeon(.hallOfOrigin).rules

    /// A form of that kind, each kind of its own species (Venusaur has both a Mega and a Gigantamax).
    private func form(_ kind: BattleFormKind) throws -> BattleForm {
        let species: [BattleFormKind: Int] = [.mega: 6, .gigantamax: 94, .primal: 382]
        return try XCTUnwrap(BattleForms.all.first { $0.kind == kind && $0.speciesID == species[kind] })
    }

    private func member(_ id: String, _ speciesID: Int, form: BattleForm? = nil, shiny: Bool = false) -> DungeonCandidate {
        DungeonCandidate(entryID: id, speciesID: form?.speciesID ?? speciesID, baseID: form?.speciesID ?? speciesID,
                         form: form?.form, rarity: .rare, isShiny: shiny)
    }

    private func shinies(_ ids: [Int]) -> [DungeonCandidate] { ids.map { member("s\($0)", $0, shiny: true) } }

    func testWhoMayJoin() throws {
        XCTAssertFalse(DungeonTeamRules.admits(member("p", 445), rules: rules), "neither shiny nor in a battle form")
        XCTAssertTrue(DungeonTeamRules.admits(member("s", 445, shiny: true), rules: rules))
        XCTAssertTrue(DungeonTeamRules.admits(member("m", 0, form: try form(.mega)), rules: rules), "a Mega, not shiny")
        XCTAssertEqual(member("g", 0, form: try form(.gigantamax)).battleFormKind, .gigantamax)
    }

    func testAMegaOrAPrimalAGigantamaxAndFourShinies() throws {
        let mega = member("m", 0, form: try form(.mega)), primal = member("p", 0, form: try form(.primal))
        let gmax = member("g", 0, form: try form(.gigantamax))
        let four = shinies([445, 248, 376, 373])
        XCTAssertTrue(DungeonTeamRules.isValid([mega, gmax] + four, size: 6, rules: rules))
        XCTAssertTrue(DungeonTeamRules.isValid([primal, gmax] + four, size: 6, rules: rules), "a Primal does as a Mega")
        XCTAssertFalse(DungeonTeamRules.isValid([mega] + shinies([445, 248, 376, 373, 149]), size: 6, rules: rules),
                       "no Gigantamax")
        XCTAssertFalse(DungeonTeamRules.isValid([gmax] + shinies([445, 248, 376, 373, 149]), size: 6, rules: rules),
                       "no Mega nor Primal")
        XCTAssertFalse(DungeonTeamRules.isValid([mega, gmax, primal] + shinies([445, 248, 376]), size: 6, rules: rules),
                       "three shinies")
        let shinyMega = member("m", 0, form: try form(.mega), shiny: true)
        XCTAssertTrue(DungeonTeamRules.isValid([shinyMega, gmax, primal] + shinies([445, 248, 376]), size: 6, rules: rules),
                      "a shiny Mega counts as a shiny too")
    }

    /// "Compose for me" sets the forms in first, then the shinies, though the shinies alone would score higher.
    func testComposeForMeMeetsIt() throws {
        let mega = member("m", 0, form: try form(.mega)), gmax = member("g", 0, form: try form(.gigantamax))
        let strong = shinies([445, 248, 376, 373, 149, 635, 150])
        var pool: [(candidate: DungeonCandidate, spec: BattlerSpec)] = []
        for candidate in [mega, gmax] + strong + [member("x", 384)] {
            let spec = try XCTUnwrap(BattlerSpec.make(id: candidate.entryID, speciesID: candidate.speciesID,
                                                      form: candidate.form, level: 100))
            pool.append((candidate, spec))
        }
        let dungeon = DungeonCatalog.dungeon(.hallOfOrigin)
        let teams = DungeonTeamBuilder.candidateTeams(pool, dungeon: dungeon, size: 6, rules: rules)
        let first = try XCTUnwrap(teams.first)
        let picked = first.compactMap { id in pool.first { $0.candidate.entryID == id }?.candidate }
        XCTAssertTrue(DungeonTeamRules.isValid(picked, size: 6, rules: rules), "\(first)")
        XCTAssertTrue(first.contains("m") && first.contains("g"))
        XCTAssertFalse(first.contains("x"), "neither shiny nor in a form")
    }

    func testItsWordsInEveryLanguage() {
        for language in AppLanguage.allCases {
            let l = L(language)
            let words = rules.map(l.dungeonRule) + [l.challengeTryTomorrow]
            XCTAssertEqual(Set(words).count, words.count, "\(language)")
            for text in words {
                XCTAssertFalse(text.isEmpty || text.contains("\u{2014}") || text.contains("\u{2013}"), "\(language): \(text)")
            }
        }
    }
}
