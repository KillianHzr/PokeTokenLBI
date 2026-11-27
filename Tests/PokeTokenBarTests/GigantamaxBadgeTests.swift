import XCTest
@testable import PokeTokenBar

@MainActor
final class GigantamaxBadgeTests: XCTestCase {
    private let charmanderLine = EvoLine(
        baseID: 4, tree: EvoNode(speciesID: 4, children: [EvoNode(speciesID: 5, children: [EvoNode(speciesID: 6, children: [])])]),
        rarity: .common, names: [:])

    private func store(active: MonState?) throws -> CompanionStore {
        var st = CompanionState()
        st.installBaselineSet = true
        st.active = active
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("gmax-badge-\(UUID().uuidString).json")
        try JSONEncoder().encode(st).write(to: url)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return CompanionStore(provider: StubProvider(value: charmanderLine), fileURL: url)
    }

    func testTheActiveCardReadsTheFactorAtTheEggAndAtEveryStage() throws {
        for stage in 0...2 {
            let s = try store(active: MonState(baseID: 4, pathIDs: [4, 5, 6], stageIndex: stage, usedAtStage: 0, rarity: .common, totalForms: 3))
            XCTAssertTrue(s.currentHasGigantamaxFactor, "stage \(stage)")
        }
        let rolled = { () -> MonState in
            var m = MonState(baseID: 172, pathIDs: [172, 25], stageIndex: 0, usedAtStage: 0, rarity: .common, totalForms: 2)
            m.rolledGigantamaxFactor = true
            return m
        }()
        XCTAssertTrue(try store(active: rolled).currentHasGigantamaxFactor)
    }

    func testTheActiveCardShowsNoFactorWithoutOne() throws {
        let plain = MonState(baseID: 16, pathIDs: [16, 17, 18], stageIndex: 0, usedAtStage: 0, rarity: .common, totalForms: 3)
        XCTAssertFalse(try store(active: plain).currentHasGigantamaxFactor)
        XCTAssertFalse(try store(active: nil).currentHasGigantamaxFactor)
    }

    func testTheFactorIsNamedInEveryLanguage() {
        let names: [AppLanguage: String] = [
            .en: "Gigantamax Factor", .fr: "Facteur Gigamax", .es: "Factor Gigamax", .pt: "Fator Gigantamax",
            .de: "Gigadynamax-Faktor", .ru: "фактор гигантамакса", .ko: "거다이맥스 가능", .ja: "キョダイマックスできる",
        ]
        XCTAssertEqual(Set(names.keys), Set(AppLanguage.allCases))
        for (language, name) in names { XCTAssertEqual(L(language).gigantamaxFactorName, name, "\(language)") }
    }

    private func form(_ speciesID: Int, _ kind: BattleFormKind) throws -> BattleForm {
        try XCTUnwrap(BattleForms.forms(speciesID: speciesID).first { $0.kind == kind })
    }

    func testMegaFloetteNamesItsWearer() throws {
        let mega = try form(670, .mega)
        XCTAssertEqual(L(.en).battleFormWearer(mega, species: "Floette"), "Wearer: Eternal Flower Floette")
        XCTAssertEqual(L(.fr).battleFormWearer(mega, species: "Floette"), "Porteur : Floette Fleur Éternelle")
    }

    func testAGigantamaxNamesItsWearer() throws {
        let pikachu = try form(25, .gigantamax)
        XCTAssertEqual(L(.en).battleFormWearer(pikachu, species: "Pikachu"), "Wearer: a Pikachu with the Gigantamax Factor")
        XCTAssertEqual(L(.fr).battleFormWearer(pikachu, species: "Pikachu"), "Porteur : un Pikachu avec le Facteur Gigamax")
        XCTAssertEqual(L(.en).battleFormWearer(try form(133, .gigantamax), species: "Eevee"),
                       "Wearer: an Eevee with the Gigantamax Factor")
    }

    func testOtherBattleFormsNameNoWearer() throws {
        XCTAssertNil(L(.en).battleFormWearer(try form(6, .mega), species: "Charizard"))
        XCTAssertNil(L(.en).battleFormWearer(try form(382, .primal), species: "Kyogre"))
    }

    func testTheGigantamaxWearerLineInEveryLanguage() throws {
        let pikachu = try form(25, .gigantamax)
        let lines: [AppLanguage: String] = [
            .en: "Wearer: a Pikachu with the Gigantamax Factor", .fr: "Porteur : un Pikachu avec le Facteur Gigamax",
            .es: "Portador: un Pikachu con el Factor Gigamax", .pt: "Portador: um Pikachu com o Fator Gigantamax",
            .de: "Träger: ein Pikachu mit dem Gigadynamax-Faktor", .ru: "Носитель: Pikachu с фактором гигантамакса",
            .ko: "이 폼이 될 수 있는 포켓몬: 거다이맥스할 수 있는 Pikachu", .ja: "この姿になれるポケモン: キョダイマックスできるPikachu",
        ]
        for (language, line) in lines { XCTAssertEqual(L(language).battleFormWearer(pikachu, species: "Pikachu"), line, "\(language)") }
    }

    func testMegaFloetteWearerReadsInEveryLanguage() throws {
        let floette = try form(670, .mega)
        for language in AppLanguage.allCases {
            let l = L(language)
            let line = try XCTUnwrap(l.battleFormWearer(floette, species: "Floette"), "\(language)")
            XCTAssertTrue(line.contains("Floette") && line.contains(l.formEternalFlower), "\(language): \(line)")
        }
    }
}
