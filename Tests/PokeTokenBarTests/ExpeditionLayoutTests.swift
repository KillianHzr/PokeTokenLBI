import AppKit
import SwiftUI
import XCTest
@testable import PokeTokenBar

/// The expedition card's journal on Home: a battle's line holds on one line in every language, its words whole.
@MainActor
final class ExpeditionLayoutTests: XCTestCase {
    private func store(_ language: AppLanguage) throws -> CompanionStore {
        var st = CompanionState()
        st.language = language
        st.installBaselineSet = true
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("expedition-layout-\(UUID().uuidString).json")
        try JSONEncoder().encode(st).write(to: url)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return CompanionStore(provider: StubProvider(value: EvoLine(baseID: 16, tree: EvoNode(speciesID: 16, children: []),
                                                                    rarity: .common, names: [:])),
                              fileURL: url, rng: SeededRNG(seed: 3), difficulty: 0.1)
    }

    /// Three sprites a side cut "Horde" and "Replay" in two in English: the line's natural width, every word on one
    /// line, must fit the card, for a full team against a horde, live or not, in every language.
    func testAJournalBattleFitsOnOneLine() throws {
        let ours = [248, 635, 94, 445, 373, 130].compactMap { BattlerSpec.make(id: "o\($0)", speciesID: $0, level: 100) }
        let theirs = [42, 93, 302].compactMap { BattlerSpec.make(id: "t\($0)", speciesID: $0, level: 90) }
        let setup = BattleSetup(sides: [BattleSideSpec(battlers: ours, active: 3), BattleSideSpec(battlers: theirs, active: 3)], seed: 1)
        let available = PopoverMetrics.contentWidth - 2 * Design.cardPadding
        for language in AppLanguage.allCases {
            let s = try store(language)
            for kind in [ExpeditionEventKind.wild, .horde, .trainer, .boss, .shiny] {
                for live in [false, true] {
                    let battle = ExpeditionBattle(kind: kind, setup: setup, won: true, duration: 600_000, foes: [42, 93, 302])
                    let entry = ExpeditionLogEntry(id: 1, floor: 12, date: live ? Date() : Date(timeIntervalSince1970: 0),
                                                   kind: .battle(battle))
                    let row = ExpeditionLogRow(store: s, nav: PopoverNavigation(), entry: entry, team: [])
                    let host = NSHostingView(rootView: row.fixedSize())
                    host.layoutSubtreeIfNeeded()
                    XCTAssertLessThanOrEqual(host.fittingSize.width, available,
                                             "\(language) \(kind) live=\(live): \(host.fittingSize.width) pt for \(available)")
                }
            }
        }
    }
}
