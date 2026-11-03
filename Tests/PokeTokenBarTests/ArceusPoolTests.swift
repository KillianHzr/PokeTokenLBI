import XCTest
@testable import PokeTokenBar

/// Arceus hatches from no egg for now (`PokemonOdds.dungeonOnly`, 2026-11-03): it is kept for a big update to come.
@MainActor
final class ArceusPoolTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_793_000_000)

    /// Hatches each line asked for; without an index when `index` is nil, as when GraphQL is down.
    private struct Provider: PokeProviding {
        let index: [BaseSpecies]?
        func line(baseSpeciesID id: Int) async throws -> EvoLine {
            EvoLine(baseID: id, tree: EvoNode(speciesID: id, children: []), rarity: .legendary, names: [:])
        }
        func baseSpeciesIndex() async throws -> [BaseSpecies] {
            guard let index else { throw URLError(.badServerResponse) }
            return index
        }
        func baseSpecies(id: Int) async throws -> BaseSpecies? {
            if let index { return index.first { $0.id == id } }
            let legendary = SpeciesGoal.mythicals.contains(id) || SpeciesGoal.legendaries.contains(id)
            return BaseSpecies(id: id, captureRate: legendary ? 3 : 45, isUnbreedableLegendary: legendary,
                               isLegendary: legendary)
        }
    }

    private func store(index: [BaseSpecies]?, seed: UInt64 = 5,
                       prepare: (inout CompanionState) -> Void) throws -> CompanionStore {
        var st = CompanionState()
        st.installBaselineSet = true
        st.lastDate = "2026-11-03"
        prepare(&st)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("arceus-\(UUID().uuidString).json")
        try JSONEncoder().encode(st).write(to: url)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return CompanionStore(provider: Provider(index: index), clock: { self.now }, fileURL: url, rng: SeededRNG(seed: seed))
    }

    private func graduated(_ ids: [Int]) -> [DexEntry] {
        ids.map { DexEntry(baseID: $0, finalID: $0, chainOrder: [$0], rarity: .legendary, caughtAt: now) }
    }

    /// Not a plain egg, not a Legendary Egg, not a Birthday Egg: the odds shown are the roll's (`hatchPool`).
    func testArceusHatchesFromNoEgg() throws {
        let index = [BaseSpecies(id: 493, captureRate: 3, isLegendary: true),
                     BaseSpecies(id: 150, captureRate: 3, isLegendary: true), BaseSpecies(id: 16, captureRate: 255)]
        let s = try store(index: index) { _ in }
        XCTAssertFalse(s.hatchDraw.hatchPool(index, egg: CompanionStore.EggSpec()).contains { $0.base.id == 493 })
        XCTAssertFalse(s.hatchDraw.hatchPool(index, egg: CompanionStore.EggSpec(legendaryEgg: true)).contains { $0.base.id == 493 })
        XCTAssertTrue(s.hatchDraw.hatchPool(index, egg: CompanionStore.EggSpec(legendaryEgg: true)).contains { $0.base.id == 150 })
        XCTAssertFalse(BirthdayGift.pool(index, graduated: []).lines.contains { $0.id == 493 })
    }

    /// The Birthday Egg without the index: Arceus the only mythical left, it goes on to the legendary still missing.
    func testTheBirthdayEggFallbackSkipsArceus() async throws {
        let s = try store(index: nil, seed: 4) {
            $0.dex = graduated(SpeciesGoal.mythicals.filter { $0 != 493 } + SpeciesGoal.legendaries.filter { $0 != 150 })
            $0.active = MonState(baseID: 1, pathIDs: [1], stageIndex: 0, usedAtStage: 0, rarity: .common, totalForms: 1)
            $0.inventory = [ItemKind.birthdayEgg.rawValue: 1]
        }
        XCTAssertTrue(s.useBirthdayEgg())
        s.setEggUsageForTesting(s.eggHatchThreshold)
        await s.hatchIfNeeded()
        XCTAssertEqual(s.state.active?.baseID, 150)
    }

    /// A save that pre-rolled Arceus before this update rolls again.
    func testAPreRolledArceusRollsAgain() async throws {
        let s = try store(index: [BaseSpecies(id: 16, captureRate: 255)]) {
            $0.pendingHatchID = 493
            $0.eggUsage = 10_000_000
        }
        await s.hatchIfNeeded()
        XCTAssertEqual(s.state.active?.baseID, 16)
    }

    /// Hovering its silhouette says where it comes from, the Hall of Origin, not from eggs that can't hatch it.
    func testThePokedexSaysWhereArceusComesFrom() {
        XCTAssertEqual(CompanionStore.source(of: 493), .dungeon(.hallOfOrigin))
        XCTAssertEqual(CompanionStore.source(of: 494), .mythical)
        let text = L(.fr).dexHowToGet(493, source: .dungeon(.hallOfOrigin), name: { "#\($0)" }, goals: [], nextDig: nil)
        XCTAssertTrue(text.contains("Salle Originelle"))
        XCTAssertFalse(text.contains(L(.fr).itemName(.legendaryEgg)))
    }
}
