import XCTest
@testable import PokeTokenBar

@MainActor
final class OakDungeonTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_790_000_000)

    private func graduated(_ id: Int, rarity: Rarity = .common, shiny: Bool = false) -> DexEntry {
        var entry = DexEntry(baseID: SpeciesInfo.baseID(of: id), finalID: id, chainOrder: [id], rarity: rarity, caughtAt: now)
        entry.id = "e\(id)"
        entry.isShiny = shiny
        return entry
    }

    private var strong: [DexEntry] { [6, 9, 3, 25, 143, 130].map { graduated($0) } }

    private func store(dex: [DexEntry]? = nil, inventory: [ItemKind: Int] = [:], used: Int = 0,
                       prepare: (inout CompanionState) -> Void = { _ in }) throws -> CompanionStore {
        var st = CompanionState()
        st.installBaselineSet = true
        st.lastDate = "d"
        st.claimedTodayTokensByProvider = ["test": 0]
        st.usedSinceInstall = used
        st.dex = dex ?? strong
        st.active = MonState(baseID: 16, pathIDs: [16, 17, 18], stageIndex: 0, usedAtStage: 0, rarity: .common, totalForms: 3)
        st.inventory = Dictionary(uniqueKeysWithValues: inventory.map { ($0.key.rawValue, $0.value) })
        prepare(&st)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("oak-dungeon-\(UUID().uuidString).json")
        try JSONEncoder().encode(st).write(to: url)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return CompanionStore(provider: StubProvider(value: EvoLine(baseID: 16, tree: EvoNode(speciesID: 16, children: []),
                                                                    rarity: .common, names: [:])),
                              clock: { self.now }, fileURL: url, rng: SeededRNG(seed: 3), difficulty: 0.1)
    }

    private func credit(_ s: CompanionStore, total: Int) {
        s.update(todayTokensByProvider: ["test": total], todayDate: "d", monthTotal: 0, burnTier: .idle,
                 limitWarning: false, hasUsageData: true)
    }

    // MARK: The Dungeon Budget's count

    func testTheDungeonBudgetCountsFromTheFirstTokensOfThisBuild() throws {
        let before = DungeonRunRecord(dungeon: .viridianForest, endedAt: now, won: true, left: false, floor: 5, floors: 5,
                                      tokens: 9_000_000, candies: 0, eggs: 0, items: 0, bossSpeciesID: 15, caught: false,
                                      log: nil, team: nil)
        let s = try store(used: 5_000_000) { $0.dungeons.history = [before] }
        XCTAssertNil(s.state.dungeons.budget)
        credit(s, total: 1_000_000)
        XCTAssertEqual(s.state.dungeons.budget, DungeonBudget(start: 5_000_000, dungeonTokens: 0),
                       "the runs before it are not counted")
        XCTAssertTrue(s.startExpedition(.viridianForest, team: Array(strong.prefix(3)).map(\.id)))
        credit(s, total: 1_400_000)
        XCTAssertEqual(s.state.dungeons.budget, DungeonBudget(start: 5_000_000, dungeonTokens: 400_000))
        let back = try JSONDecoder().decode(CompanionState.self, from: JSONEncoder().encode(s.state))
        XCTAssertEqual(back.dungeons.budget, s.state.dungeons.budget)
    }
}
