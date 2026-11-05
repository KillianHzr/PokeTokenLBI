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

    private func shopContentHeight(_ store: CompanionStore) async throws -> CGFloat {
        let host = NSHostingController(rootView: ShopView(store: store, nav: PopoverNavigation())
            .frame(width: PopoverMetrics.width))
        let window = NSWindow(contentRect: NSRect(x: -10000, y: -10000, width: PopoverMetrics.width, height: 520),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        window.contentViewController = host
        window.orderFront(nil)
        defer { window.orderOut(nil) }
        host.view.layoutSubtreeIfNeeded()
        try await Task.sleep(for: .milliseconds(300))
        host.view.layoutSubtreeIfNeeded()
        func scrollViews(in view: NSView) -> [NSScrollView] {
            ((view as? NSScrollView).map { [$0] } ?? []) + view.subviews.flatMap(scrollViews)
        }
        let scroll = try XCTUnwrap(scrollViews(in: host.view).first)
        return try XCTUnwrap(scroll.documentView).frame.height
    }

    func testAdviceIsOnUntilTurnedOffAndTheChoiceIsKept() throws {
        let suite = "OakAdviceToggle-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        XCTAssertTrue(store(defaults).oakAdviceEnabled)
        store(defaults).oakAdviceEnabled = false
        XCTAssertFalse(store(defaults).oakAdviceEnabled)
    }

    func testTurningAdviceOffTakesTheCardOutOfTheShop() async throws {
        let suite = "OakAdviceToggle-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = store(defaults)
        let withCard = try await shopContentHeight(store)
        store.oakAdviceEnabled = false
        let withoutCard = try await shopContentHeight(store)
        XCTAssertGreaterThanOrEqual(withCard - withoutCard, 90, "the card is at least as tall as Prof. Oak's bust")
    }
}
