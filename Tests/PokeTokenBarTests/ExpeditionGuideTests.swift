import XCTest
@testable import PokeTokenBar

/// Home while a team explores, as Prof. Oak's card (the owner, 2026-11-10, choice C): a circle a floor with what happened
/// there, its journal line on hover, nothing for a floor ahead; the guide's words.
@MainActor
final class ExpeditionGuideTests: XCTestCase {
    private func battle(_ kind: ExpeditionEventKind, won: Bool, foes: Int) throws -> ExpeditionBattle {
        let ours = try XCTUnwrap(BattlerSpec.make(id: "a", speciesID: 248, level: 100))
        let theirs = try (0..<foes).map { try XCTUnwrap(BattlerSpec.make(id: "f\($0)", speciesID: 41, level: 50)) }
        let setup = BattleSetup(sides: [BattleSideSpec(battlers: [ours], active: 1), BattleSideSpec(battlers: theirs, active: 1)],
                                seed: 1)
        return ExpeditionBattle(kind: kind, setup: setup, won: won, duration: 1000, foes: theirs.map(\.speciesID))
    }

    private func entry(_ floor: Int, _ kind: ExpeditionLogKind) -> ExpeditionLogEntry {
        ExpeditionLogEntry(id: floor * 10, floor: floor, date: Date(timeIntervalSince1970: 0), kind: kind)
    }

    func testEachFloorShowsWhatHappenedThere() throws {
        let log = [entry(1, .battle(try battle(.wild, won: true, foes: 1))),
                   entry(2, .battle(try battle(.horde, won: true, foes: 4))),
                   entry(2, .chest(ExpeditionLoot(candies: 2))),
                   entry(3, .trap(percent: 10, item: nil)),
                   entry(4, .shiny(speciesID: 41, caught: true)),
                   entry(4, .battle(try battle(.trainer, won: false, foes: 3)))]
        XCTAssertEqual(ExpeditionLogText.symbol(floor: 1, log: log)?.0, "bolt.fill")
        XCTAssertEqual(ExpeditionLogText.symbol(floor: 2, log: log)?.0, "shippingbox.fill", "a find before a fight")
        XCTAssertEqual(ExpeditionLogText.symbol(floor: 3, log: log)?.0, "exclamationmark.triangle.fill")
        XCTAssertEqual(ExpeditionLogText.symbol(floor: 4, log: log)?.0, "sparkles", "a shiny first")
        XCTAssertNil(ExpeditionLogText.symbol(floor: 5, log: log), "nothing written there")
    }

    func testTheTooltipIsTheFloorsJournal() throws {
        var s = CompanionState()
        s.language = .fr
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("guide-\(UUID()).json")
        try JSONEncoder().encode(s).write(to: file)
        addTeardownBlock { try? FileManager.default.removeItem(at: file) }
        let store = CompanionStore(provider: StubProvider(value: EvoLine(baseID: 16, tree: EvoNode(speciesID: 16, children: []),
                                                                         rarity: .common, names: [:])), fileURL: file)
        let log = [entry(2, .battle(try battle(.horde, won: true, foes: 4))), entry(2, .chest(ExpeditionLoot(candies: 2)))]
        XCTAssertEqual(ExpeditionLogText.floor(2, log: log, floors: 12, store: store),
                       "Horde · 4 adversaires · Victoire\nCoffre · Super Bonbon ×2")
        XCTAssertEqual(ExpeditionLogText.floor(3, log: log, floors: 12, store: store), "", "a floor ahead says nothing")
    }

    func testTheGuidesWordsInEveryLanguage() {
        for language in AppLanguage.allCases {
            let l = L(language)
            let words = [l.guideFloors(done: 0), l.guideFloors(done: 5), l.guideFainted(["A"]), l.guideFainted(["A", "B"]),
                         l.guideWeak(["A"]), l.guideWeak(["A", "B", "C"]), l.guideBoss(at: 12), l.guideNeedsHeal, l.guideFoes(1),
                         l.guideFoes(4), l.guideResult(won: true, roped: false), l.guideResult(won: false, roped: true),
                         l.guideResult(won: false, roped: false), l.listed(["A", "B", "C"])]
            for text in words {
                XCTAssertFalse(text.isEmpty || text.contains("\u{2014}") || text.contains("\u{2013}"), "\(language): \(text)")
            }
        }
        XCTAssertEqual(L(.fr).listed(["Léviator", "Mégagnathe", "Ectoplasma"]), "Léviator, Mégagnathe et Ectoplasma")
    }
}
