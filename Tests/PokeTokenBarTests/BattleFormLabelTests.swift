import XCTest
@testable import PokeTokenBar

/// A species' battle forms read apart in every language: Tatsugiri's three Megas all read "Mega", Urshifu's two
/// Gigantamax "Gigantamax" (2026-11-04), so the team screen's chooser offered the same button thrice.
@MainActor
final class BattleFormLabelTests: XCTestCase {
    func testEverySpeciesBattleFormsReadApart() {
        let species = Set(BattleForms.all.map(\.speciesID))
        for language in AppLanguage.allCases {
            for id in species {
                let forms = BattleForms.forms(speciesID: id)
                let labels = forms.map { PokemonForm.label(speciesID: id, form: $0.form, language: language) ?? "" }
                XCTAssertEqual(Set(labels).count, forms.count, "\(language) #\(id): \(labels)")
                let names = forms.map { PokemonForm.displayName("#\(id)", speciesID: id, form: $0.form, language: language) }
                XCTAssertEqual(Set(names).count, forms.count, "\(language) #\(id): \(names)")
            }
        }
    }

    /// The base form named only where it tells forms apart: Charizard's Megas keep their X and Y alone.
    func testTheBaseFormOnlyWhereItTellsApart() throws {
        let tatsugiri = try XCTUnwrap(BattleForms.forms(speciesID: 978).first { $0.form.rawValue == "curly-mega" })
        XCTAssertEqual(PokemonForm.battleBase(tatsugiri), PokemonForm("curly"))
        let charizard = try XCTUnwrap(BattleForms.forms(speciesID: 6).first { $0.form.rawValue == "mega-x" })
        XCTAssertNil(PokemonForm.battleBase(charizard))
        XCTAssertEqual(PokemonForm.label(speciesID: 6, form: charizard.form, language: .en), L(.en).battleFormLabel(charizard))
    }
}
