import XCTest
@testable import PokeTokenBar

/// The Capsule screen's search, shiny filter and sort (the owner, 2026-11-09: "il manque une barre de recherche, de
/// tri etc").
@MainActor
final class CapsuleSearchTests: XCTestCase {
    /// `ivs`: HP, Attack, Defense, Special Attack, Special Defense, Speed.
    private func entry(_ id: Int, ivs: [Int], shiny: Bool = false, name: String? = nil, day: Double = 0) -> DexEntry {
        var e = DexEntry(baseID: SpeciesInfo.baseID(of: id), finalID: id, chainOrder: [id], rarity: .rare,
                         caughtAt: Date(timeIntervalSince1970: 1_790_000_000 + day * 86_400), isShiny: shiny)
        e.id = "e\(id)"
        e.raising = nil
        var profile = PokemonProfile.generate(seed: UInt64(id))
        for (path, value) in zip(CompanionStore.ivKeyPaths, ivs) { profile.ivs[keyPath: path] = value }
        e.profile = profile
        if let name { e.names = [id: ["en": name, "fr": name]]; e.namesVersion = DexEntry.currentNamesVersion }
        return e
    }

    private func store(_ dex: [DexEntry]) throws -> CompanionStore {
        var st = CompanionState()
        st.installBaselineSet = true
        st.lastDate = "d"
        st.claimedTodayTokensByProvider = ["test": 0]
        st.dex = dex
        st.active = MonState(baseID: 16, pathIDs: [16, 17, 18], stageIndex: 0, usedAtStage: 0, rarity: .common, totalForms: 3)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("capsule-search-\(UUID().uuidString).json")
        try JSONEncoder().encode(st).write(to: url)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return CompanionStore(provider: StubProvider(value: EvoLine(baseID: 16, tree: EvoNode(speciesID: 16, children: []),
                                                                    rarity: .common, names: [:])),
                              clock: { Date(timeIntervalSince1970: 1_794_394_800) }, fileURL: url,
                              rng: SeededRNG(seed: 3), difficulty: 0.1)
    }

    /// Pikachu (320 base) far from 31, Rayquaza (680) halfway, Mewtwo (680) nearly done, Snorlax (540) shiny, a
    /// perfect Dragonite left out: no Capsule raises it.
    private func dex() -> [DexEntry] {
        [entry(25, ivs: [0, 0, 0, 0, 0, 0], name: "Pikachu", day: 4),
         entry(384, ivs: [15, 15, 15, 15, 15, 15], name: "Rayquaza", day: 1),
         entry(150, ivs: [30, 30, 30, 30, 30, 30], name: "Mewtwo", day: 3),
         entry(143, ivs: [10, 10, 10, 10, 10, 10], shiny: true, name: "Snorlax", day: 2),
         entry(149, ivs: [31, 31, 31, 31, 31, 31], name: "Dragonite", day: 5)]
    }

    func testTheStrongestFirstThenTheMostToGain() throws {
        let s = try store(dex())
        XCTAssertEqual(s.capsuleCandidates(query: "", shinyOnly: false, sort: .strongest).map(\.finalID), [384, 150, 143, 25],
                       "Rayquaza and Mewtwo share 680: Rayquaza has more to gain")
        XCTAssertEqual(s.capsuleCandidates(query: "", shinyOnly: false, sort: .mostToGain).map(\.finalID), [25, 143, 384, 150])
    }

    func testTheOtherSortsAreThePokedexOnes() throws {
        let s = try store(dex())
        XCTAssertEqual(s.capsuleCandidates(query: "", shinyOnly: false, sort: .numberAsc).map(\.finalID), [25, 143, 150, 384])
        XCTAssertEqual(s.capsuleCandidates(query: "", shinyOnly: false, sort: .recentFirst).map(\.finalID), [25, 150, 143, 384])
        XCTAssertEqual(s.capsuleCandidates(query: "", shinyOnly: false, sort: .nameAsc).map(\.finalID), [150, 25, 384, 143])
    }

    func testTheSearchAndTheShinyFilter() throws {
        let s = try store(dex())
        XCTAssertEqual(s.capsuleCandidates(query: "ray", shinyOnly: false, sort: .strongest).map(\.finalID), [384])
        XCTAssertEqual(s.capsuleCandidates(query: "#150", shinyOnly: false, sort: .strongest).map(\.finalID), [150])
        XCTAssertEqual(s.capsuleCandidates(query: "", shinyOnly: true, sort: .strongest).map(\.finalID), [143])
        XCTAssertTrue(s.capsuleCandidates(query: "dragonite", shinyOnly: false, sort: .strongest).isEmpty,
                      "a Pokémon with every IV at 31 is no Capsule's")
        XCTAssertTrue(s.capsuleCandidates(query: "mew", shinyOnly: true, sort: .strongest).isEmpty)
    }

    func testEverySortHasALabelInEveryLanguage() {
        for language in AppLanguage.allCases {
            let labels = CompanionStore.CapsuleSortOption.allCases.map { L(language).label(for: $0) }
            XCTAssertEqual(Set(labels).count, labels.count, "\(language)")
            XCTAssertFalse(labels.contains { $0.isEmpty || $0.contains("\u{2014}") || $0.contains("\u{2013}") }, "\(language)")
        }
    }
}
