import XCTest
@testable import PokeTokenBar

/// The Pokédex header shows what is collected and what is left: species, then every form of every species.
@MainActor
final class CollectionProgressTests: XCTestCase {
    private let date = Date(timeIntervalSince1970: 1_790_000_000)

    private func entry(_ id: Int, _ form: String? = nil, rarity: Rarity = .common) -> DexEntry {
        DexEntry(baseID: id, finalID: id, chainOrder: [id], rarity: rarity, caughtAt: date, form: form.map { PokemonForm($0) })
    }

    func testTotalsCoverEverySpeciesAndForm() {
        let extraForms = PokemonAssets.animatedSpeciesIDs.reduce(0) { $0 + max(0, PokemonForm.forms(speciesID: $1).count - 1) }
        XCTAssertEqual(CompanionStore.collectableFormCount, 1025 + extraForms)
        XCTAssertEqual(CompanionStore.collectableFormCount, 1280)
    }

    func testProgressCountsSpeciesAndTheirForms() throws {
        var st = CompanionState()
        st.installBaselineSet = true
        st.lastDate = "2026-10-21"
        // Pikachu (one appearance), three Unown letters, an Arceus with the Fire Plate (Normal and Fire).
        st.dex = [entry(25), entry(201, "a"), entry(201, "b"), entry(201, "question"), entry(25),
                  entry(493, "normal", rarity: .legendary)]
        st.claimedAchievements = [CompanionState.regionTierKey(.volcanoBadge, generation: 1)]
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("progress-\(UUID().uuidString).json")
        try JSONEncoder().encode(st).write(to: url)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        let s = CompanionStore(provider: StubIndexProvider(), clock: { self.date }, fileURL: url, rng: SeededRNG(seed: 1))
        XCTAssertEqual(s.collectionProgress,
                       .init(species: 3, speciesTotal: 1025, forms: 6, formsTotal: CompanionStore.collectableFormCount))
    }
}

private struct StubIndexProvider: PokeProviding {
    func line(baseSpeciesID: Int) async throws -> EvoLine {
        EvoLine(baseID: baseSpeciesID, tree: EvoNode(speciesID: baseSpeciesID, children: []), rarity: .common, names: [:])
    }
    func baseSpeciesIndex() async throws -> [BaseSpecies] { [] }
    func baseSpecies(id: Int) async throws -> BaseSpecies? { nil }
}
