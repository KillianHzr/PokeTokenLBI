import XCTest
@testable import PokeTokenBar

/// What the texts promise is what the code does (#58): the fossils that count, the per-form discounts, the Prison
/// Bottle's forms, claimed badge regions, a candy's EXP with the Soul Dew, a charmed shiny without odds.
@MainActor
final class PromiseTextTests: XCTestCase {
    private func store(_ inventory: [ItemKind]) throws -> CompanionStore {
        var st = CompanionState()
        st.installBaselineSet = true
        st.inventory = Dictionary(uniqueKeysWithValues: inventory.map { ($0.rawValue, 1) })
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("promise-\(UUID().uuidString).json")
        try JSONEncoder().encode(st).write(to: url)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return CompanionStore(provider: PokeAPIClient.shared, fileURL: url)
    }

    func testTheTextsSayWhatCounts() {
        let l = L(.en)
        XCTAssertEqual(l.fossilsGoal(4), "Any 4 fully evolved fossil Pokémon")
        // The Old Amber asks for every one: "any" read as a choice.
        XCTAssertEqual(l.allFossilsGoal(15), "All 15 fully evolved fossil Pokémon")
        XCTAssertTrue(l.itemDescription(.magmaStone).hasSuffix("already graduated in this form."))
        XCTAssertTrue(l.itemDescription(.libertyPass).hasSuffix("never graduated in this form."))
        XCTAssertTrue(l.libertyPassEffectHint.hasPrefix("Not graduated yet"))
        XCTAssertTrue(l.itemDescription(.prisonBottle).contains("a form its line hasn't collected yet"))
        XCTAssertTrue(l.itemDescription(.volcanoBadge).hasPrefix("Each region claimed"))
        XCTAssertTrue(l.itemDescription(.plainBadge).hasPrefix("Each region claimed"))
    }

    /// The Soul Dew's candy grants 112.5M: the description says so where the Bag shows "+112.5M XP".
    func testTheRareCandySaysItsOwnEXP() throws {
        let dew = try store([.soulDew])
        XCTAssertEqual(dew.rareCandyXP, 150_000_000)
        XCTAssertTrue(dew.l.itemDescription(.rareCandy, rareCandyXP: dew.rareCandyXP).contains("150M"))
        XCTAssertTrue(L(.en).itemDescription(.rareCandy).contains("100M"))
    }

    /// With the Glimmering Charm every hatch is shiny: the notification tells no odds.
    func testACharmedShinyTellsNoOdds() throws {
        XCTAssertEqual(try store([]).shinyHatchNotificationOdds(64), 64)
        XCTAssertNil(try store([.glimmeringCharm]).shinyHatchNotificationOdds(64))
        for language in AppLanguage.allCases {
            let body = L(language).notifShinyHatchBody("Pikachu", odds: nil)
            XCTAssertTrue(body.contains("Pikachu"), "\(language)")
            XCTAssertFalse(body.contains("64"), "\(language): \(body)")
        }
    }
}
