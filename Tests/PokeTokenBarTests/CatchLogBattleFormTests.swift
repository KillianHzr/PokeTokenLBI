import XCTest
@testable import PokeTokenBar

/// The battle forms the daily and weekly dungeons gave, lines of the catch log (the owner, 2026-11-10: "vu que c'est
/// une nouvelle forme faut qu'elle soit dans le journal"), under its filters and sorts.
@MainActor
final class CatchLogBattleFormTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_790_000_000)
    private let day: TimeInterval = 86_400

    private func graduated(_ id: Int, _ fr: String, _ en: String, daysAgo: Double, rarity: Rarity = .common) -> DexEntry {
        var entry = DexEntry(baseID: SpeciesInfo.baseID(of: id), finalID: id, chainOrder: [id], rarity: rarity,
                             caughtAt: now.addingTimeInterval(-daysAgo * day))
        entry.id = "e\(id)"
        entry.names = [id: ["fr": fr, "en": en]]
        entry.namesVersion = DexEntry.currentNamesVersion
        return entry
    }

    private var dex: [DexEntry] {
        [graduated(6, "Dracaufeu", "Charizard", daysAgo: 3), graduated(359, "Absol", "Absol", daysAgo: 1, rarity: .rare)]
    }

    private func store(forms: [String: Date?], history: [DungeonRunRecord] = []) throws -> CompanionStore {
        var st = CompanionState()
        st.installBaselineSet = true
        st.lastDate = "d"
        st.claimedTodayTokensByProvider = ["test": 0]
        st.language = .fr
        st.dex = dex
        st.active = MonState(baseID: 16, pathIDs: [16, 17, 18], stageIndex: 0, usedAtStage: 0, rarity: .common, totalForms: 3)
        st.dungeons.battleForms = Set(forms.keys)
        st.dungeons.battleFormsWonAt = forms.compactMapValues { $0 }
        st.dungeons.history = history
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("catch-log-\(UUID().uuidString).json")
        try JSONEncoder().encode(st).write(to: url)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return CompanionStore(provider: StubProvider(value: EvoLine(baseID: 16, tree: EvoNode(speciesID: 16, children: []),
                                                                    rarity: .common, names: [:])),
                              clock: { self.now }, fileURL: url, rng: SeededRNG(seed: 3), difficulty: 0.1)
    }

    private func ids(_ items: [CatchLogItem]) -> [String] { items.map(\.id) }

    /// Mega Charizard X two days ago, Mega Absol an hour ago: each a line, at its date among the Pokémon raised.
    private func twoForms() throws -> CompanionStore {
        try store(forms: ["6-mega-x": now.addingTimeInterval(-2 * day), "359-mega": now.addingTimeInterval(-3600)])
    }

    func testEachFormIsALineAtItsDate() throws {
        let s = try twoForms()
        let active = try XCTUnwrap(s.dexEntries.first { s.isActiveDexEntry($0) }).id
        XCTAssertEqual(ids(s.catchLogItems()), [active, "form:359-mega", "e359", "form:6-mega-x", "e6"],
                       "the Pokémon raised first, then the latest")
        XCTAssertEqual(ids(s.catchLogItems(sort: .oldestFirst)), ["e6", "form:6-mega-x", "e359", "form:359-mega", active])
        XCTAssertEqual(ids(s.catchLogItems(sort: .numberAsc)), ["e6", "form:6-mega-x", active, "e359", "form:359-mega"],
                       "after its species' records")
        XCTAssertEqual(ids(s.catchLogItems(sort: .numberDesc)), ["e359", "form:359-mega", active, "e6", "form:6-mega-x"])
        XCTAssertEqual(ids(s.catchLogItems(sort: .rarityDesc)).prefix(2), ["form:359-mega", "e359"], "its species' rarity")
        XCTAssertEqual(ids(s.catchLogItems(sort: .countDesc)).suffix(2), ["form:359-mega", "form:6-mega-x"],
                       "no duplicate: after the records counted")
        let byName = ids(s.catchLogItems(sort: .nameAsc))
        XCTAssertEqual(byName.filter { $0 != active }, ["e359", "form:359-mega", "e6", "form:6-mega-x"],
                       "by its species' name: Absol, Dracaufeu")
        XCTAssertEqual(s.dexEntries.count, 3, "the Pokédex counts them apart")
    }

    func testTheFiltersAndTheSearch() throws {
        let s = try twoForms()
        XCTAssertFalse(s.catchLogItems(shinyOnly: true).contains { if case .battleForm = $0 { true } else { false } },
                       "a form is never shiny")
        XCTAssertEqual(ids(s.catchLogItems(rarity: .rare)), ["form:359-mega", "e359"])
        XCTAssertEqual(ids(s.catchLogItems(query: "Dracau")), ["form:6-mega-x", "e6"])
        XCTAssertEqual(ids(s.catchLogItems(query: "Charizard")), ["form:6-mega-x", "e6"], "every language")
        XCTAssertEqual(ids(s.catchLogItems(query: "méga")), ["form:359-mega", "form:6-mega-x"], "the form's own name")
        XCTAssertEqual(ids(s.catchLogItems(query: "#359")), ["form:359-mega", "e359"])
        XCTAssertEqual(ids(s.catchLogItems(query: "Absol", evolutionFamily: true)), ["form:359-mega", "e359"])
    }

    /// A form won before its date was kept takes its challenge's win from the history, or none: last, recent first.
    func testAFormWonBeforeItsDateWasKept() throws {
        let run = DungeonRunRecord(dungeon: .daily, endedAt: now.addingTimeInterval(-10 * day), won: true, left: false,
                                   floor: 8, floors: 8, tokens: 1, candies: 0, eggs: 0, items: 0, bossSpeciesID: 359,
                                   caught: false)
        let lost = DungeonRunRecord(dungeon: .daily, endedAt: now.addingTimeInterval(-4 * day), won: false, left: false,
                                    floor: 8, floors: 8, tokens: 1, candies: 0, eggs: 0, items: 0, bossSpeciesID: 6,
                                    caught: false)
        let s = try store(forms: ["6-mega-x": nil, "359-mega": nil], history: [run, lost])
        XCTAssertEqual(s.dungeonProgress.battleFormsWonAt, ["359-mega": run.endedAt], "a lost run gives no date")
        XCTAssertEqual(ids(s.catchLogItems()).suffix(3), ["e6", "form:359-mega", "form:6-mega-x"])
    }

    func testItsWordsInEveryLanguage() {
        for language in AppLanguage.allCases {
            let text = L(language).battleFormBadge
            XCTAssertFalse(text.isEmpty || text.contains("\u{2014}") || text.contains("\u{2013}"), "\(language)")
        }
    }
}
