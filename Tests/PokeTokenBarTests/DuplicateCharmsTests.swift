import XCTest
@testable import PokeTokenBar

private struct NoLines: PokeProviding {
    func line(baseSpeciesID: Int) async throws -> EvoLine {
        EvoLine(baseID: baseSpeciesID, tree: EvoNode(speciesID: baseSpeciesID, children: []), rarity: .common, names: [:])
    }
    func baseSpeciesIndex() async throws -> [BaseSpecies] { [] }
    func baseSpecies(id: Int) async throws -> BaseSpecies? { nil }
}

/// Tauros's Four Breeds and Necrozma's Four Forms (the owner, 2026-11-05): a line the player has whole weighs a third,
/// a quarter, a fifth with both, in plain and stone eggs alike; every other line keeps its weight.
@MainActor
final class DuplicateCharmsTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_790_000_000)

    private func store(items: [ItemKind]) throws -> CompanionStore {
        var st = CompanionState()
        st.installBaselineSet = true
        st.lastDate = "2026-11-05"
        st.dex = [DexEntry(baseID: 309, finalID: 310, chainOrder: [309, 310], rarity: .common, caughtAt: now)]
        st.collectedFinals = ["309:310"]
        st.inventory = Dictionary(uniqueKeysWithValues: items.map { ($0.rawValue, 1) })
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("dup-charms-\(UUID().uuidString).json")
        try JSONEncoder().encode(st).write(to: url)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return CompanionStore(provider: NoLines(), clock: { self.now }, fileURL: url, rng: SeededRNG(seed: 1))
    }

    func testTheArtifactsLowerOnlyTheLinesHadWhole() throws {
        let electrike = BaseSpecies(id: 309, captureRate: 120)   // graduated whole
        let bulbasaur = BaseSpecies(id: 1, captureRate: 45)      // still to find
        let cases: [([ItemKind], Int)] = [([], 2), ([.taurosBreeds], 3), ([.necrozmaForms], 4), ([.taurosBreeds, .necrozmaForms], 5)]
        for (items, divisor) in cases {
            let s = try store(items: items)
            let draw = s.hatchDraw
            XCTAssertEqual(draw.completeLineDivisor, divisor, "\(items)")
            XCTAssertEqual(draw.hatchWeight(for: electrike), max(1, electrike.hatchWeight / divisor), "\(items)")
            XCTAssertEqual(draw.hatchWeight(for: electrike, type: .electric), max(1, electrike.hatchWeight / (2 * divisor)),
                           "a stone's egg, twice as low, \(items)")
            XCTAssertEqual(draw.hatchWeight(for: bulbasaur), bulbasaur.hatchWeight, "a line to finish keeps its weight")
            XCTAssertEqual(s.effectHint(for: .taurosBreeds), s.l.completeLinesEffectHint(divisor))
        }
        // A roll from before the change reads the half, whatever the Bag holds.
        let both = try store(items: [.taurosBreeds, .necrozmaForms])
        let before = HatchDraw(collection: both.state, items: [.taurosBreeds, .necrozmaForms],
                               rules: HatchRules(changes: Set(HatchRules.Change.allCases).subtracting([.duplicateCharms])))
        XCTAssertEqual(before.completeLineDivisor, 2)
        XCTAssertEqual(before.hatchWeight(for: electrike), electrike.hatchWeight / 2)
        // The luck replay knows when they arrived.
        XCTAssertEqual(HatchRules.Change.arrival(of: .taurosBreeds), .duplicateCharms)
        XCTAssertEqual(HatchRules.Change.arrival(of: .necrozmaForms), .duplicateCharms)
        XCTAssertTrue(ItemKind.drawItems.contains(.taurosBreeds) && ItemKind.drawItems.contains(.necrozmaForms))
    }
}
