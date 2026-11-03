import XCTest
@testable import PokeTokenBar

private struct TwoLines: PokeProviding {
    let entries: [BaseSpecies]
    func line(baseSpeciesID: Int) async throws -> EvoLine {
        EvoLine(baseID: baseSpeciesID, tree: EvoNode(speciesID: baseSpeciesID, children: []), rarity: .common, names: [:])
    }
    func baseSpeciesIndex() async throws -> [BaseSpecies] { entries }
    func baseSpecies(id: Int) async throws -> BaseSpecies? { entries.first { $0.id == id } }
}

/// Duplicates in a stone's egg: a line is judged by what that egg can hatch, a collected one weighs a quarter, and no
/// egg brings the line hatched last again.
@MainActor
final class StoneEggDuplicateTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_790_000_000)

    private func store(entries: [BaseSpecies] = [], seed: UInt64 = 1,
                       _ edit: (inout CompanionState) -> Void = { _ in }) throws -> CompanionStore {
        var st = CompanionState()
        st.installBaselineSet = true
        st.lastDate = "2026-10-26"
        edit(&st)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("stone-dup-\(UUID().uuidString).json")
        try JSONEncoder().encode(st).write(to: url)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return CompanionStore(provider: TwoLines(entries: entries), clock: { self.now }, fileURL: url,
                              rng: SeededRNG(seed: seed))
    }

    private func graduated(_ chain: [Int], form: PokemonForm? = nil) -> DexEntry {
        DexEntry(baseID: chain[0], finalID: chain.last!, chainOrder: chain, rarity: .common, caughtAt: now, form: form)
    }

    /// A Kantonian Stunfisk graduated: the plain egg still has the Galarian one to give, so the line keeps its whole
    /// weight; a Thunder Stone's egg can only give the Kantonian one, so for it the line is done.
    func testAStoneJudgesALineByWhatItCanHatch() throws {
        let stunfisk = BaseSpecies(id: 618, captureRate: 75)
        let s = try store {
            $0.dex = [self.graduated([618], form: PokemonForm("normal"))]
            $0.collectedFinals = ["618:618"]
        }
        XCTAssertFalse(s.state.isLineComplete(baseID: 618), "the Galarian Stunfisk is missing")
        XCTAssertTrue(s.state.isLineComplete(baseID: 618, type: .electric))
        XCTAssertFalse(s.state.isLineComplete(baseID: 618, type: .ground), "a Ground egg can bring the Galarian one")
        XCTAssertEqual(s.hatchDraw.hatchWeight(for: stunfisk), stunfisk.hatchWeight)
        XCTAssertEqual(s.hatchDraw.hatchWeight(for: stunfisk, type: .electric), stunfisk.hatchWeight / 4)
        XCTAssertEqual(s.hatchDraw.hatchWeight(for: stunfisk, type: .ground), stunfisk.hatchWeight)
    }

    /// A collected line weighs half in a plain egg and a quarter in a stone's; a line still to finish keeps its weight.
    func testACollectedLineWeighsAQuarterInAStonesEgg() throws {
        let electrike = BaseSpecies(id: 309, captureRate: 120)
        let done = try store {
            $0.dex = [self.graduated([309, 310])]
            $0.collectedFinals = ["309:310"]
        }
        XCTAssertEqual(done.hatchDraw.hatchWeight(for: electrike), electrike.hatchWeight / 2)
        XCTAssertEqual(done.hatchDraw.hatchWeight(for: electrike, type: .electric), electrike.hatchWeight / 4)
        let open = try store()
        XCTAssertEqual(open.hatchDraw.hatchWeight(for: electrike, type: .electric), electrike.hatchWeight)
        let legendary = BaseSpecies(id: 145, captureRate: 3, isUnbreedableLegendary: true)
        let zapdos = try store {
            $0.dex = [self.graduated([145])]
            $0.collectedFinals = ["145:145"]
        }
        XCTAssertGreaterThanOrEqual(zapdos.hatchDraw.hatchWeight(for: legendary, type: .electric), 1, "never zero")
    }

    /// No egg brings the line hatched last again while another one is left.
    func testNoEggBringsTheLastLineTwiceInARow() async throws {
        let two = [BaseSpecies(id: 1, captureRate: 45), BaseSpecies(id: 4, captureRate: 45)]
        for seed: UInt64 in 1...12 {
            let s = try store(entries: two, seed: seed) { $0.lastHatchedBaseID = 1 }
            s.setEggUsageForTesting(s.eggHatchThreshold)
            await s.hatchIfNeeded()
            XCTAssertEqual(s.state.active?.baseID, 4, "seed \(seed)")
            XCTAssertEqual(s.state.lastHatchedBaseID, 4, "the hatch remembers its line")
        }
        let alone = try store(entries: [two[0]]) { $0.lastHatchedBaseID = 1 }
        alone.setEggUsageForTesting(alone.eggHatchThreshold)
        await alone.hatchIfNeeded()
        XCTAssertEqual(alone.state.active?.baseID, 1, "the only line left still hatches")
        XCTAssertEqual(CompanionStore.withoutLastHatched(two, last: nil).map(\.id), [1, 4])

        var st = CompanionState()
        st.lastHatchedBaseID = 618
        XCTAssertEqual(try JSONDecoder().decode(CompanionState.self, from: JSONEncoder().encode(st)).lastHatchedBaseID, 618)
    }
}
