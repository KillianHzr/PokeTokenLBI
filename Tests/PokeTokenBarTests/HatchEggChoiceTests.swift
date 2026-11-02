import XCTest
@testable import PokeTokenBar

/// What the player says of their hatches from before the record (`HatchRecord.chosenByPlayer`): the egg of a hatch
/// after a release, and since when they own each draw item. Both are written in the save.
@MainActor
final class HatchEggChoiceTests: XCTestCase {
    private static let now = Date(timeIntervalSince1970: 1_790_000_000)
    private var url: URL!

    private func store(active: Bool = true, _ dex: [DexEntry]) throws -> CompanionStore {
        var st = CompanionState()
        st.installBaselineSet = true
        st.lastDate = "2026-10-20"
        st.dex = dex
        if active {
            st.active = MonState(baseID: 37, pathIDs: [37], plannedPathIDs: [37, 38], stageIndex: 0, usedAtStage: 0,
                                 rarity: .uncommon, totalForms: 1, nature: .hardy)
        }
        st.inventory[ItemKind.shinyCharm.rawValue] = 1
        url = FileManager.default.temporaryDirectory.appendingPathComponent("hatch-egg-\(UUID().uuidString).json")
        try JSONEncoder().encode(st).write(to: url)
        addTeardownBlock { [url] in try? FileManager.default.removeItem(at: url!) }
        return CompanionStore(provider: RosterProvider(), clock: { Self.now }, fileURL: url, difficulty: 1, writer: nil)
    }

    private func relaunched() -> CompanionStore {
        CompanionStore(provider: RosterProvider(), clock: { Self.now }, fileURL: url, difficulty: 1, writer: nil)
    }

    private func entry(_ base: Int, days ago: Double, released: Bool = false, record: HatchRecord? = nil) -> DexEntry {
        let at = Self.now.addingTimeInterval(-ago * 86_400)
        var e = DexEntry(baseID: base, finalID: base, chainOrder: [base], rarity: .common, caughtAt: at,
                         releasedAt: released ? at : nil)
        e.hatch = record
        return e
    }

    func testThePlayerSaysTheEggOfAHatchAfterARelease() throws {
        let s = try store([entry(16, days: 9, released: true), entry(10, days: 5)])
        let id = s.state.dex[1].id
        s.chooseHatchEgg(.tier(.rare), forEntry: id)
        XCTAssertEqual(s.state.dex[1].hatch, HatchRecord(egg: .tier(.rare), chosenByPlayer: true))
        XCTAssertEqual(relaunched().state.dex[1].hatch?.egg, .tier(.rare), "written in the save")
        s.chooseHatchEgg(.stone(.normal), forEntry: id)
        XCTAssertEqual(s.state.dex[1].hatch?.egg, .stone(.normal), "the player may change it")
        s.chooseHatchEgg(nil, forEntry: id)
        XCTAssertNil(s.state.dex[1].hatch, "back to an unknown egg")
    }

    func testThePokemonRaisedAfterARelease() throws {
        let s = try store([entry(16, days: 9, released: true)])
        let id = try XCTUnwrap(s.dexEntries.last?.id)
        s.chooseHatchEgg(.fossil, forEntry: id)
        XCTAssertEqual(s.state.active?.hatch, HatchRecord(egg: .fossil, chosenByPlayer: true))
    }

    /// After a graduation the egg was a Pokémon Egg, and what the app noted stays as it noted it.
    func testNoChoiceWhereTheEggIsKnown() throws {
        let noted = HatchRecord(egg: .tier(nil), hatchItems: [.shinyCharm])
        let s = try store([entry(16, days: 9), entry(10, days: 7), entry(16, days: 6, released: true),
                           entry(10, days: 5, record: noted)])
        s.chooseHatchEgg(.tier(.rare), forEntry: s.state.dex[1].id)
        XCTAssertNil(s.state.dex[1].hatch)
        s.chooseHatchEgg(.tier(.rare), forEntry: s.state.dex[3].id)
        XCTAssertEqual(s.state.dex[3].hatch, noted)
        s.chooseHatchEgg(.tier(.rare), forEntry: try XCTUnwrap(s.dexEntries.last?.id))
        XCTAssertNil(s.state.active?.hatch, "raised after a graduation")
    }

    func testNoChoiceForThePokemonRaisedWhenTheAppNotedIt() throws {
        let noted = HatchRecord(egg: .stone(.fire))
        var st = CompanionState()
        st.installBaselineSet = true
        st.dex = [entry(16, days: 9, released: true)]
        st.active = MonState(baseID: 37, pathIDs: [37], plannedPathIDs: [37, 38], stageIndex: 0, usedAtStage: 0,
                             rarity: .uncommon, totalForms: 1, nature: .hardy)
        st.active?.hatch = noted
        url = FileManager.default.temporaryDirectory.appendingPathComponent("hatch-egg-\(UUID().uuidString).json")
        try JSONEncoder().encode(st).write(to: url)
        addTeardownBlock { [url] in try? FileManager.default.removeItem(at: url!) }
        let s = relaunched()
        s.chooseHatchEgg(.tier(.rare), forEntry: try XCTUnwrap(s.dexEntries.last?.id))
        XCTAssertEqual(s.state.active?.hatch, noted)
    }

    /// A draw item's date counts for the eggs started after it, and the replay follows it.
    func testTheDateOfADrawItem() async throws {
        let s = try store([entry(16, days: 9, released: true), entry(10, days: 5), entry(16, days: 2)])
        s.setDrawItemSince(.shinyCharm, Self.now)
        await s.loadHatchLuck()
        let before = try XCTUnwrap(s.hatchLuck?.hatches[2].judged[.shiny]?.odds)
        s.setDrawItemSince(.shinyCharm, Self.now.addingTimeInterval(-6 * 86_400))
        XCTAssertEqual(relaunched().state.drawItemsSince[ItemKind.shinyCharm.rawValue], Self.now.addingTimeInterval(-6 * 86_400))
        await s.loadHatchLuck()
        XCTAssertGreaterThan(try XCTUnwrap(s.hatchLuck?.hatches[2].judged[.shiny]?.odds), before)
        s.setDrawItemSince(.shinyCharm, nil)
        XCTAssertNil(s.state.drawItemsSince[ItemKind.shinyCharm.rawValue])
    }
}
