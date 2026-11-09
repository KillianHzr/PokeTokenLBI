import AppKit
import SwiftUI
import XCTest
@testable import PokeTokenBar

private struct NoLinesProvider: PokeProviding {
    func line(baseSpeciesID: Int) async throws -> EvoLine { throw URLError(.notConnectedToInternet) }
    func baseSpeciesIndex() async throws -> [BaseSpecies] { [] }
    func baseSpecies(id: Int) async throws -> BaseSpecies? { nil }
}

@MainActor
final class OakAdviceToggleTests: XCTestCase {
    private func store(_ defaults: UserDefaults) -> CompanionStore {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("oak-toggle-\(UUID().uuidString).json")
        return CompanionStore(provider: NoLinesProvider(), fileURL: url, defaults: defaults)
    }

    func testAdviceIsOnUntilTurnedOffAndTheChoiceIsKept() throws {
        let suite = "OakAdviceToggle-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        XCTAssertTrue(store(defaults).oakAdviceEnabled)
        store(defaults).oakAdviceEnabled = false
        XCTAssertFalse(store(defaults).oakAdviceEnabled)
    }

    /// Turned off, Prof. Oak's card leaves the top of the Shop. A travelling merchant comes every day since 2026-11-09
    /// (his card is about as tall as Prof. Oak's, so the Shop's height no longer tells them apart): he stands alone
    /// there then; with the advice on, Prof. Oak's card comes first, the merchant behind the arrow.
    func testTurningAdviceOffTakesTheCardOutOfTheShop() throws {
        let suite = "OakAdviceToggle-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        XCTAssertNotNil(store(defaults).merchantWare, "a merchant every day")
        XCTAssertEqual(ShopHeadCards.cards(oakAdvice: true, merchant: true), [.oak, .merchant])
        XCTAssertEqual(ShopHeadCards.cards(oakAdvice: false, merchant: true), [.merchant])
        XCTAssertEqual(ShopHeadCards.cards(oakAdvice: true, merchant: false), [.oak])
    }
}
