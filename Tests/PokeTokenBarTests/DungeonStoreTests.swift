import XCTest
@testable import PokeTokenBar

/// The dungeons in the game: the save, what opens them, the departure, the tokens walking the team, the answers and
/// the end, its loot in the Bag.
@MainActor
final class DungeonStoreTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_790_000_000)

    private func graduated(_ id: Int, rarity: Rarity = .common) -> DexEntry {
        var entry = DexEntry(baseID: SpeciesInfo.baseID(of: id), finalID: id, chainOrder: [id], rarity: rarity, caughtAt: now)
        entry.id = "e\(id)"
        return entry
    }

    private func store(dex: [DexEntry], inventory: [ItemKind: Int] = [:], used: Int = 0,
                       prepare: (inout CompanionState) -> Void = { _ in }) throws -> CompanionStore {
        var st = CompanionState()
        st.installBaselineSet = true
        st.lastDate = "d"
        st.claimedTodayTokensByProvider = ["test": 0]
        st.usedSinceInstall = used
        st.dex = dex
        st.active = MonState(baseID: 16, pathIDs: [16, 17, 18], stageIndex: 0, usedAtStage: 0, rarity: .common, totalForms: 3)
        st.inventory = Dictionary(uniqueKeysWithValues: inventory.map { ($0.key.rawValue, $0.value) })
        prepare(&st)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("dungeon-\(UUID().uuidString).json")
        try JSONEncoder().encode(st).write(to: url)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return CompanionStore(provider: StubProvider(value: EvoLine(baseID: 16, tree: EvoNode(speciesID: 16, children: []),
                                                                    rarity: .common, names: [:])),
                              clock: { self.now }, fileURL: url, rng: SeededRNG(seed: 3), difficulty: 0.1)
    }

    private var strong: [DexEntry] { [6, 9, 3, 25, 143, 130].map { graduated($0) } }

    private func credit(_ s: CompanionStore, total: Int) {
        s.update(todayTokensByProvider: ["test": total], todayDate: "d", monthTotal: 0, burnTier: .idle,
                 limitWarning: false, hasUsageData: true)
    }

    // MARK: The save

    /// A save from before the dungeons decodes with none, and a dungeon's state comes back whole.
    func testTheSaveKeepsTheDungeons() throws {
        let old = #"{"installBaselineSet":true,"usedSinceInstall":5,"dex":[],"inventory":{}}"#
        let decoded = try JSONDecoder().decode(CompanionState.self, from: Data(old.utf8))
        XCTAssertEqual(decoded.dungeons, DungeonProgress())
        var st = CompanionState()
        st.dungeons.wins["viridianForest"] = 2
        st.dungeons.unlockedMoves = ["earthquake"]
        st.dungeons.moveLoops["e6"] = ["flamethrower"]
        st.dungeons.eggs = [DungeonEgg(id: "x", baseID: 4, form: nil, isShiny: true, sourceSpeciesID: 6)]
        let back = try JSONDecoder().decode(CompanionState.self, from: JSONEncoder().encode(st))
        XCTAssertEqual(back.dungeons, st.dungeons)
        let broken = #"{"dungeons":{"wins":"oops","unlockedMoves":["surf"]}}"#
        let lenient = try JSONDecoder().decode(CompanionState.self, from: Data(broken.utf8))
        XCTAssertEqual(lenient.dungeons.unlockedMoves, ["surf"], "a damaged field costs only itself")
    }

    // MARK: Opening

    func testWhatOpensTheDungeons() throws {
        let five = try store(dex: Array(strong.prefix(5)))
        XCTAssertFalse(five.isDungeonOpen(.viridianForest), "six graduated open the first dungeons")
        let six = try store(dex: strong)
        XCTAssertTrue(six.isDungeonOpen(.viridianForest))
        XCTAssertTrue(six.isDungeonOpen(.diglettsCave))
        XCTAssertFalse(six.isDungeonOpen(.mtMoon))
        let won = try store(dex: strong) { $0.dungeons.wins["viridianForest"] = 1 }
        XCTAssertTrue(won.isDungeonOpen(.mtMoon))
        XCTAssertFalse(won.isDungeonOpen(.victoryRoad), "Mt. Moon and Mt. Ember both")
        let seafoam = try store(dex: strong) { $0.dungeons.wins["dragonsDen"] = 1 }
        XCTAssertTrue(seafoam.isDungeonOpen(.seafoamIslands))
        XCTAssertFalse(seafoam.canEnter(.seafoamIslands), "a T4 takes a Legendary Key")
        let keyed = try store(dex: strong, inventory: [.legendaryKey: 1]) { $0.dungeons.wins["dragonsDen"] = 1 }
        XCTAssertTrue(keyed.canEnter(.seafoamIslands))
        XCTAssertFalse(try store(dex: strong).isDungeonOpen(.ruinsOfAlph))
        XCTAssertTrue(try store(dex: strong, inventory: [.treasureMap: 1]).isDungeonOpen(.ruinsOfAlph))
        let origin = try store(dex: strong) { $0.dungeons.bossesBeaten = ["mtCoronet:483", "mtCoronet:484"] }
        XCTAssertFalse(origin.isDungeonOpen(.hallOfOrigin))
        let all = try store(dex: strong) { $0.dungeons.bossesBeaten = ["mtCoronet:483", "mtCoronet:484", "mtCoronet:487"] }
        XCTAssertTrue(all.isDungeonOpen(.hallOfOrigin))
    }

    // MARK: Departure and tokens

    /// The team sets off with the Bag's berries and Revives; the tokens then walk it and the Pokémon raised stops
    /// growing, while the wallet still counts them (Q1).
    func testTokensWalkTheTeamWhileGrowthPauses() throws {
        let s = try store(dex: strong, inventory: [.oranBerry: 2, .revive: 1])
        let team = Array(strong.prefix(3)).map(\.id)
        XCTAssertFalse(s.startExpedition(.viridianForest, team: Array(team.prefix(2))), "three, the forest's size")
        XCTAssertTrue(s.startExpedition(.viridianForest, team: team))
        XCTAssertFalse(s.startExpedition(.diglettsCave, team: team), "one expedition at a time")
        XCTAssertEqual(s.itemCount(.oranBerry), 0)
        XCTAssertEqual(s.itemCount(.revive), 0)
        XCTAssertEqual(s.expedition?.berries[.oran], 2)
        let growth = s.state.active?.usedAtStage
        credit(s, total: 1_000_000)
        XCTAssertEqual(s.state.active?.usedAtStage, growth, "growth pauses")
        XCTAssertEqual(s.expedition?.tokensIn, 1_000_000)
        XCTAssertEqual(s.availableTokens, 1_000_000, "the Shop still counts them")
    }

    /// The whole dungeon walked: the boss falls to a strong team, the throws end it, its loot goes to the Bag with
    /// what was not used, a first victory doubles the candies, and Mt. Moon opens.
    func testAVictoryFillsTheBag() throws {
        let s = try store(dex: strong, inventory: [.oranBerry: 3, .masterBall: 1])
        XCTAssertTrue(s.startExpedition(.viridianForest, team: Array(strong.prefix(3)).map(\.id)))
        let cost = DungeonTier.t1.cost(difficulty: 0.1)
        var total = 0
        while s.expedition.map({ if case .exploring = $0.phase { return true }; if case .awaitingHeal = $0.phase { return true }; return false }) == true {
            total += cost / 5
            credit(s, total: total)
            if case .awaitingHeal? = s.expedition?.phase { s.answerEmergencyHeal(pay: false) }
        }
        guard case .capture? = s.expedition?.phase else { return XCTFail("the boss should fall: \(String(describing: s.expedition?.phase))") }
        XCTAssertEqual(s.throwAtBoss(.masterBall), true)
        XCTAssertNil(s.expedition)
        let result = try XCTUnwrap(s.dungeonProgress.lastResult)
        XCTAssertTrue(result.won)
        XCTAssertTrue(result.caught)
        XCTAssertTrue(result.firstVictory)
        XCTAssertEqual(result.loot.candies % 2, 0, "doubled")
        XCTAssertEqual(s.dungeonProgress.wins(.viridianForest), 1)
        XCTAssertTrue(result.unlocked.contains(.mtMoon))
        XCTAssertEqual(s.itemCount(.masterBall), 0)
        XCTAssertEqual(s.dungeonProgress.eggs.count, result.loot.eggs.count)
        XCTAssertTrue(s.dungeonProgress.eggs.contains { $0.sourceSpeciesID == result.boss.speciesID })
        XCTAssertGreaterThanOrEqual(s.itemCount(.oranBerry), 0)
        s.dismissExpeditionResult()
        XCTAssertNil(s.dungeonProgress.lastResult)
    }

    /// Q4: leaving loses the loot unless an Escape Rope takes it out.
    func testLeavingKeepsTheLootOnlyWithARope() throws {
        for rope in [false, true] {
            let s = try store(dex: strong, inventory: rope ? [.escapeRope: 1] : [:])
            XCTAssertTrue(s.startExpedition(.viridianForest, team: Array(strong.prefix(3)).map(\.id)))
            s.changeDungeons { $0.expedition?.loot.candies = 4 }
            let candies = s.itemCount(.rareCandy)
            s.abandonExpedition()
            XCTAssertNil(s.expedition)
            XCTAssertEqual(s.itemCount(.rareCandy), candies + (rope ? 4 : 0))
            XCTAssertEqual(s.itemCount(.escapeRope), 0)
            XCTAssertEqual(s.dungeonProgress.lastResult?.roped, rope)
            XCTAssertEqual(s.dungeonProgress.wins(.viridianForest), 0)
        }
    }

    /// R5: the heal costs a quarter of the dungeon's cost, from the wallet; refused without the tokens.
    func testTheEmergencyHealIsPaidFromTheWallet() throws {
        let cost = DungeonTier.t1.cost(difficulty: 0.1)
        let poor = try store(dex: strong)
        XCTAssertTrue(poor.startExpedition(.viridianForest, team: Array(strong.prefix(3)).map(\.id)))
        poor.changeDungeons { $0.expedition?.phase = .awaitingHeal(price: cost / 4) }
        XCTAssertFalse(poor.answerEmergencyHeal(pay: true))
        let rich = try store(dex: strong, used: cost)
        XCTAssertTrue(rich.startExpedition(.viridianForest, team: Array(strong.prefix(3)).map(\.id)))
        rich.changeDungeons { $0.expedition?.phase = .awaitingHeal(price: cost / 4) }
        XCTAssertTrue(rich.answerEmergencyHeal(pay: true))
        XCTAssertEqual(rich.availableTokens, cost - cost / 4)
        XCTAssertEqual(rich.expedition?.healUsed, true)
    }

    /// R4: a loop is set outside an expedition, a locked move refused until unlocked.
    func testMoveLoopsKeepTheLocks() throws {
        let s = try store(dex: strong)
        XCTAssertFalse(s.setMoveLoop(["fire-blast", "flamethrower"], for: "e6"), "Fire Blast, 110, is locked")
        XCTAssertTrue(s.setMoveLoop(["flamethrower", "air-slash"], for: "e6"))
        XCTAssertEqual(s.dungeonProgress.moveLoops["e6"], ["flamethrower", "air-slash"])
        let unlocked = try store(dex: strong) { $0.dungeons.unlockedMoves = ["fire-blast"] }
        XCTAssertTrue(unlocked.setMoveLoop(["fire-blast"], for: "e6"))
        XCTAssertEqual(s.dungeonSpec(graduated(6), for: .mtEmber)?.moves, ["flamethrower", "air-slash"])
    }

    func testVictoryExtras() {
        var random = BattleRandom(seed: 1)
        XCTAssertEqual(CompanionStore.victoryExtras(tier: .t3, firstT3Victory: true, random: &random).items[ItemKind.legendaryKey.rawValue], 1,
                       "the first T3 victory gives a Legendary Key")
        XCTAssertEqual(CompanionStore.technicalCapsuleChance(.t1), 10)
        XCTAssertEqual(CompanionStore.technicalCapsuleChance(.t2), 20)
        XCTAssertEqual(CompanionStore.technicalCapsuleChance(.t3), 35)
    }
}
