import XCTest
@testable import PokeTokenBar

private struct OfflineProvider: PokeProviding {
    func line(baseSpeciesID: Int) async throws -> EvoLine { throw URLError(.notConnectedToInternet) }
    func baseSpeciesIndex() async throws -> [BaseSpecies] { [] }
    func baseSpecies(id: Int) async throws -> BaseSpecies? { nil }
}

/// How many of each Pokémon the Pokédex holds (2026-11-04, asked by the owner): "×N" on the grid, "Duplicate ×N" in
/// the catch log and on the repeat's Home badge, and a "Most caught" sort in both lists.
@MainActor
final class DexCatchCountTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_700_000_000)

    private func store(_ dex: [DexEntry], active: MonState? = nil) -> CompanionStore {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("dex-count-\(UUID().uuidString).json")
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        var state = CompanionState()
        state.dex = dex
        state.active = active
        state.language = .en
        try? JSONEncoder().encode(state).write(to: url)
        return CompanionStore(provider: OfflineProvider(), clock: { self.start }, fileURL: url, rng: SeededRNG(seed: 42))
    }

    private func caught(_ id: String, _ chain: [Int], hoursIn: Double, released: Bool = false) -> DexEntry {
        var entry = DexEntry(id: id, baseID: chain[0], finalID: chain.last!, chainOrder: chain, rarity: .common,
                             caughtAt: start.addingTimeInterval(hoursIn * 3600))
        if released { entry.releasedAt = entry.caughtAt }
        return entry
    }

    /// Three Bulbasaur lines, one sent off at Ivysaur, and an Eevee: each species counts the records that reached it.
    private var dex: [DexEntry] {
        [caught("b1", [1, 2, 3], hoursIn: 1), caught("b2", [1, 2, 3], hoursIn: 2), caught("b3", [1, 2], hoursIn: 3, released: true),
         caught("e1", [133], hoursIn: 4)]
    }

    func testEachSpeciesCountsTheRecordsThatReachedIt() {
        let counts = store(dex).dexCatchCounts
        XCTAssertEqual(counts[1], 3)
        XCTAssertEqual(counts[2], 3)
        XCTAssertEqual(counts[3], 2, "the one sent off never reached Venusaur")
        XCTAssertEqual(counts[133], 1)
    }

    /// The rank is the record's place among those of its species, in catch order: the second Venusaur is "×2".
    func testADuplicateKnowsWhichOneItIs() {
        let s = store(dex)
        let ranks = s.dexCatchRanks
        XCTAssertEqual(ranks["b1"], 1)
        XCTAssertEqual(ranks["b2"], 2)
        XCTAssertEqual(ranks["b3"], 3, "the third to reach Ivysaur")
        XCTAssertEqual(ranks["e1"], 1)
        XCTAssertTrue(s.isDuplicateCatch(dex[1]))
    }

    /// The one being raised comes last: a fourth Bulbasaur is "×4", and it is not counted on the grid yet.
    func testTheOneBeingRaisedComesLast() {
        let raising = MonState(baseID: 1, pathIDs: [1], plannedPathIDs: [1, 2, 3], stageIndex: 0, usedAtStage: 0, rarity: .common,
                               totalForms: 1)
        let s = store(dex, active: raising)
        XCTAssertEqual(s.activeCatchRank, 4)
        XCTAssertEqual(s.dexCatchCounts[1], 3)
        XCTAssertEqual(L(.fr).repeatGrowthBoost(2, rank: 4), "Doublon ×4 · Croissance ×2")
        XCTAssertEqual(L(.en).repeatGrowthBoost(2, rank: 1), "Repeat · 2× growth", "no count on the first")
    }

    func testMostCaughtComesFirstInBothLists() {
        let s = store(dex)
        let species = s.sortDexSpecies(s.dexSpecies, by: .countDesc).map(\.id)
        XCTAssertEqual(Array(species.prefix(3)), [1, 2, 3])
        XCTAssertEqual(species.last, 133)
        let log = s.sortDexEntries(s.dexEntries, by: .countDesc).map(\.id)
        // Ivysaur (3) before Venusaur (2) before Eevee (1), the latest first within a species.
        XCTAssertEqual(log, ["b3", "b2", "b1", "e1"])
        XCTAssertEqual(L(.fr).label(for: CompanionStore.DexSortOption.countDesc), "Les plus capturés")
        XCTAssertEqual(L(.fr).label(for: CompanionStore.CatchLogSortOption.countDesc), "Les plus capturés")
    }
}

/// Each rarity's species in all: every species of each line of the index, at its line's rarity (2026-11-04).
@MainActor
final class RaritySpeciesTotalTests: XCTestCase {
    func testEachLineCountsAllItsSpeciesAtItsRarity() {
        let index = [BaseSpecies(id: 1, captureRate: 45), BaseSpecies(id: 133, captureRate: 45),
                     BaseSpecies(id: 150, captureRate: 3, isLegendary: true), BaseSpecies(id: 16, captureRate: 255)]
        let totals = CompanionStore.speciesTotals(index)
        let line = { (root: Int) in PokemonAssets.animatedSpeciesIDs.filter { PokemonEvolutionData.root(of: $0) == root }.count }
        XCTAssertEqual(line(1), 3)
        XCTAssertEqual(line(133), 9, "Eevee and its eight evolutions")
        XCTAssertEqual(totals[.legendary], 1)
        XCTAssertEqual(totals[index[0].rarity], line(1) + line(133) + (index[3].rarity == index[0].rarity ? line(16) : 0))
        XCTAssertEqual(totals.values.reduce(0, +), line(1) + line(133) + 1 + line(16))
    }
}
