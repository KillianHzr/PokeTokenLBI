import XCTest
@testable import PokeTokenBar

/// Single-stage Common lines: a graduation is one `applyUsage(threshold)` away.
private struct OneStageLines: PokeProviding {
    func line(baseSpeciesID: Int) async throws -> EvoLine {
        EvoLine(baseID: baseSpeciesID, tree: EvoNode(speciesID: baseSpeciesID, children: []), rarity: .common,
                names: [baseSpeciesID: ["en": "P\(baseSpeciesID)", "fr": "P\(baseSpeciesID)"]])
    }
    func baseSpeciesIndex() async throws -> [BaseSpecies] { [BaseSpecies(id: 4, captureRate: 45)] }
    func baseSpecies(id: Int) async throws -> BaseSpecies? { BaseSpecies(id: id, captureRate: 45) }
}

/// The Old Amber (every fossil line graduated) and the Explorer Kit (the five explorers of the depths and Heatran).
@MainActor
final class TreasureAndAmberTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_793_300_000)

    private func store(dex: [DexEntry] = [], active: MonState? = nil, inventory: [String: Int] = [:]) -> CompanionStore {
        var st = CompanionState()
        st.installBaselineSet = true
        st.dex = dex
        st.active = active
        st.inventory = inventory
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("treasure-\(UUID().uuidString).json")
        try? JSONEncoder().encode(st).write(to: url)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return CompanionStore(provider: OneStageLines(), clock: { self.now }, fileURL: url, rng: SeededRNG(seed: 7))
    }

    private func entries(_ ids: [Int], rarity: Rarity = .rare) -> [DexEntry] {
        ids.map { DexEntry(baseID: $0, finalID: $0, chainOrder: [$0], rarity: rarity, caughtAt: now) }
    }

    /// Every fossil line for the Amber, all six of the Kit: one missing keeps it locked.
    func testBothAskForTheWholeSet() {
        XCTAssertEqual(ItemKind.oldAmber.collectorGroup, .legendaryArtifacts, "an artifact, as in the games, not a stone")
        XCTAssertEqual(ItemKind.explorerKit.collectorGroup, .legendaryArtifacts)
        XCTAssertTrue(ItemKind.oldAmber.isPassive)
        XCTAssertTrue(ItemKind.explorerKit.isPassive)
        XCTAssertTrue(store(dex: entries(SpeciesGoal.fossils)).isUnlocked(.oldAmber))
        XCTAssertFalse(store(dex: entries(Array(SpeciesGoal.fossils.dropLast()))).isUnlocked(.oldAmber))
        XCTAssertEqual(SpeciesGoal.explorers.count, 6)
        XCTAssertTrue(SpeciesGoal.explorers.contains(485), "Heatran, the legendary that balances the Kit")
        XCTAssertTrue(store(dex: entries(SpeciesGoal.explorers)).isUnlocked(.explorerKit))
        XCTAssertFalse(store(dex: entries(Array(SpeciesGoal.explorers.dropLast()))).isUnlocked(.explorerKit),
                       "all six, not five of them")
    }

    /// One roll in ten thousand is the Legendary Egg, 300 a Rare Egg, 1,200 an Uncommon Egg, the rest one Rare Candy
    /// (the owner's choice on DyRize's #107, 2026-11-05).
    func testTheTreasureTable() {
        var counts: [ItemKind: Int] = [:]
        for roll in 0..<ExplorerKit.rollRange {
            let treasure = ExplorerKit.treasure(roll: roll)
            counts[treasure.kind, default: 0] += 1
            XCTAssertEqual(treasure.count, 1, "\(treasure.kind)")
        }
        XCTAssertEqual(counts, [.legendaryEgg: 1, .rareEgg: 300, .uncommonEgg: 1_200, .rareCandy: 8_499])
    }

    /// Owned, every fifth graduation digs up one treasure, put in the Bag and kept for the news strip until seen; not
    /// owned, nothing is counted.
    func testTheKitDigsATreasureEveryFifthGraduation() async {
        let s = store(inventory: [ItemKind.explorerKit.rawValue: 1])
        func graduate() async {
            await s.hatch(baseID: 4)
            s.applyUsage(s.threshold)
        }
        for _ in 0..<4 { await graduate() }
        XCTAssertEqual(s.state.dex.count, 4, "graduated")
        XCTAssertTrue(s.unseenTreasures.isEmpty, "four is not five")
        XCTAssertEqual(s.state.graduationsTowardTreasure, 4)
        await graduate()
        let treasure = try? XCTUnwrap(s.unseenTreasures.first)
        XCTAssertEqual(s.unseenTreasures.count, 1)
        XCTAssertEqual(s.state.graduationsTowardTreasure, 0)
        if let treasure { XCTAssertEqual(s.itemCount(treasure.kind), treasure.count, "in the Bag") }
        s.markTreasuresSeen()
        XCTAssertTrue(s.unseenTreasures.isEmpty)

        let without = store()
        await without.hatch(baseID: 4)
        without.applyUsage(without.threshold)
        XCTAssertEqual(without.state.dex.count, 1)
        XCTAssertEqual(without.state.graduationsTowardTreasure, 0)
    }

    /// Owned, a Pokémon sent off for an egg gives half its stage's EXP to the one that hatches, never enough to evolve
    /// or graduate it at once; not owned, the egg's Pokémon starts from nothing.
    func testTheAmberPassesHalfTheStageShortOfEvolving() async {
        func sentOff(usedAtStage: Int, amber: Bool) async -> CompanionStore {
            let active = MonState(baseID: 25, pathIDs: [25], stageIndex: 0, usedAtStage: usedAtStage, rarity: .common,
                                  totalForms: 1)
            var inventory = [ItemKind.fireStone.rawValue: 1]
            if amber { inventory[ItemKind.oldAmber.rawValue] = 1 }
            let s = store(active: active, inventory: inventory)
            XCTAssertTrue(s.useStone(.fireStone))
            await s.hatch(baseID: 4)
            return s
        }
        let small = await sentOff(usedAtStage: 1_000_000, amber: true)
        XCTAssertEqual(small.state.active?.usedAtStage, 500_000)
        XCTAssertEqual(small.state.amberCarry, 0, "given once")
        let large = await sentOff(usedAtStage: 4_000_000_000, amber: true)
        XCTAssertEqual(large.state.active?.usedAtStage, large.threshold - 1, "short of its first step")
        XCTAssertEqual(large.state.dex.filter { !$0.isReleased }.count, 0, "not graduated at once")
        let none = await sentOff(usedAtStage: 1_000_000, amber: false)
        XCTAssertEqual(none.state.active?.usedAtStage, 0)
    }

    /// [Regression] A hand-edited count near Int.max trapped at the treasure's add, at every fifth graduation, at every
    /// launch. Counts are capped at load, far above any real one, no item dropped.
    func testAHandEditedCountNoLongerTraps() async {
        let s = store(inventory: [ItemKind.explorerKit.rawValue: 1, ItemKind.rareCandy.rawValue: Int.max,
                                  ItemKind.rareEgg.rawValue: Int.max, ItemKind.uncommonEgg.rawValue: Int.max,
                                  ItemKind.legendaryEgg.rawValue: Int.max])
        XCTAssertEqual(s.itemCount(.rareCandy), SaveTransfer.maxItemCount)
        for _ in 0..<ExplorerKit.graduationsPerTreasure {
            await s.hatch(baseID: 4)
            s.applyUsage(s.threshold)
        }
        XCTAssertEqual(s.unseenTreasures.count, 1, "dug up, no trap")
        XCTAssertEqual(s.itemCount(.explorerKit), 1, "no item dropped")
    }
}
