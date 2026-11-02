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
        XCTAssertTrue(s.growthPaused, "Prof. Oak reads the pause")
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

    /// R13: the dungeon waits for the player while the heal or the throws wait, and while the return is not closed;
    /// not while the team walks. The menu bar shows the floor of the expedition under way.
    func testWhatWaitsForThePlayer() throws {
        let s = try store(dex: strong)
        XCTAssertFalse(s.dungeonNeedsAttention)
        XCTAssertNil(s.dungeonMenuFloor)
        XCTAssertTrue(s.startExpedition(.viridianForest, team: Array(strong.prefix(3)).map(\.id)))
        XCTAssertFalse(s.dungeonNeedsAttention, "the team walks on its own")
        XCTAssertEqual(s.dungeonMenuFloor, s.l.dungeonFloorTag(1, DungeonTier.t1.floors))
        s.changeDungeons { $0.expedition?.phase = .awaitingHeal(price: 1) }
        XCTAssertTrue(s.dungeonNeedsAttention, "the heal waits for its answer")
        s.changeDungeons { $0.expedition?.phase = .capture(throwsLeft: 3) }
        XCTAssertTrue(s.dungeonNeedsAttention, "the throws wait")
        s.endCapture()
        XCTAssertNil(s.expedition)
        XCTAssertNotNil(s.dungeonProgress.lastResult)
        XCTAssertTrue(s.dungeonNeedsAttention, "the return waits to be seen")
        XCTAssertNil(s.dungeonMenuFloor)
        s.dismissExpeditionResult()
        XCTAssertFalse(s.dungeonNeedsAttention)
    }

    /// A Silver Capsule raises the one IV chosen to 31, a Gold Capsule all six; neither is spent for nothing.
    func testCapsulesRaiseIVs() throws {
        var low = graduated(143)
        low.profile = PokemonProfile.generate(seed: 1)
        low.profile?.ivs = PokemonIVs(hp: 3, attack: 31, defense: 10, specialAttack: 0, specialDefense: 31, speed: 7)
        var perfect = graduated(130)
        perfect.profile = PokemonProfile.generate(seed: 2)
        perfect.profile?.ivs = PokemonIVs(hp: 31, attack: 31, defense: 31, specialAttack: 31, specialDefense: 31, speed: 31)
        let s = try store(dex: [low, perfect], inventory: [.silverCapsule: 1, .goldCapsule: 1])
        XCTAssertEqual(s.capsuleCandidates.map(\.id), [low.id], "only an IV under 31 can be raised")
        XCTAssertFalse(s.useCapsule(.silverCapsule, on: low.id, stat: 1), "Attack is already 31")
        XCTAssertFalse(s.useCapsule(.silverCapsule, on: perfect.id, stat: 0))
        XCTAssertFalse(s.useCapsule(.silverCapsule, on: low.id), "a Silver Capsule needs its IV")
        XCTAssertEqual(s.itemCount(.silverCapsule), 1)
        XCTAssertTrue(s.useCapsule(.silverCapsule, on: low.id, stat: 3))
        var ivs = try XCTUnwrap(s.state.dex.first { $0.id == low.id }?.profile?.ivs)
        XCTAssertEqual([ivs.hp, ivs.attack, ivs.defense, ivs.specialAttack, ivs.specialDefense, ivs.speed], [3, 31, 10, 31, 31, 7])
        XCTAssertEqual(s.itemCount(.silverCapsule), 0)
        XCTAssertFalse(s.useCapsule(.silverCapsule, on: low.id, stat: 0), "none left")
        XCTAssertTrue(s.useCapsule(.goldCapsule, on: low.id))
        ivs = try XCTUnwrap(s.state.dex.first { $0.id == low.id }?.profile?.ivs)
        XCTAssertEqual([ivs.hp, ivs.attack, ivs.defense, ivs.specialAttack, ivs.specialDefense, ivs.speed], Array(repeating: 31, count: 6))
        XCTAssertTrue(s.capsuleCandidates.isEmpty)
        XCTAssertEqual(s.itemCount(.goldCapsule), 0)
        // The battle self follows: every IV at 31.
        let spec = try XCTUnwrap(s.dungeonSpec(try XCTUnwrap(s.state.dex.first { $0.id == low.id }), for: .viridianForest))
        XCTAssertEqual(spec.stats, BattlerSpec.make(id: "x", speciesID: 143, level: 100, nature: low.nature)?.stats)
    }

    /// Q23: an Explorer's Chest gives one of the Explorer Kit's treasures and is gone.
    func testAnExplorersChestHoldsAKitTreasure() throws {
        let s = try store(dex: strong, inventory: [.explorerChest: 1])
        let before = Dictionary(uniqueKeysWithValues: [ItemKind.rareCandy, .uncommonEgg, .rareEgg, .legendaryEgg].map { ($0, s.itemCount($0)) })
        let found = try XCTUnwrap(s.openExplorerChest())
        XCTAssertEqual(s.itemCount(.explorerChest), 0)
        XCTAssertTrue([ItemKind.rareCandy, .uncommonEgg, .rareEgg, .legendaryEgg].contains(found.kind))
        XCTAssertEqual(s.itemCount(found.kind), (before[found.kind] ?? 0) + found.count)
        XCTAssertNil(s.openExplorerChest(), "no chest left")
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

    // MARK: Eggs

    /// Builds each line asked for, so a hatch is the line rolled.
    private struct LineProvider: PokeProviding {
        let index: [BaseSpecies]
        func line(baseSpeciesID id: Int) async throws -> EvoLine {
            EvoLine(baseID: id, tree: EvoNode(speciesID: id, children: []), rarity: SpeciesInfo.lineRarity(of: id), names: [:])
        }
        func baseSpecies(id: Int) async throws -> BaseSpecies? { index.first { $0.id == id } }
        func baseSpeciesIndex() async throws -> [BaseSpecies] { index }
    }

    private func hatchingStore(index: [BaseSpecies], prepare: (inout CompanionState) -> Void) throws -> CompanionStore {
        var st = CompanionState()
        st.installBaselineSet = true
        st.lastDate = "d"
        st.dex = strong
        prepare(&st)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("dungeon-egg-\(UUID().uuidString).json")
        try JSONEncoder().encode(st).write(to: url)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return CompanionStore(provider: LineProvider(index: index), clock: { self.now }, fileURL: url, rng: SeededRNG(seed: 5),
                              difficulty: 0.1)
    }

    /// Q20 B, R9 B: a boss's egg sends the Pokémon raised off and hatches the boss's line, shiny as the boss was.
    func testADungeonEggHatchesItsLine() async throws {
        let s = try hatchingStore(index: [BaseSpecies(id: 1, captureRate: 45)]) {
            $0.active = MonState(baseID: 16, pathIDs: [16], stageIndex: 0, usedAtStage: 0, rarity: .common, totalForms: 3)
            $0.dungeons.eggs = [DungeonEgg(id: "dratini", baseID: 147, form: nil, isShiny: true, sourceSpeciesID: 149)]
        }
        XCTAssertTrue(s.useDungeonEgg("dratini"))
        XCTAssertNil(s.state.active)
        XCTAssertTrue(s.dungeonProgress.eggs.isEmpty)
        XCTAssertEqual(s.eggKind, .dungeon(149))
        XCTAssertEqual(s.incubatingEggName, s.l.dungeonEggName)
        s.setEggUsageForTesting(s.eggHatchThreshold)
        await s.hatchIfNeeded()
        XCTAssertEqual(s.state.active?.baseID, 147)
        XCTAssertEqual(s.state.active?.isShiny, true)
        XCTAssertNil(s.state.eggFromDungeon)
    }

    /// R13: Arceus hatches from no egg: not a plain one, not a Legendary Egg, not a Birthday Egg.
    func testArceusHatchesFromNoEgg() throws {
        let index = [BaseSpecies(id: 493, captureRate: 3, isLegendary: true), BaseSpecies(id: 150, captureRate: 3, isLegendary: true),
                     BaseSpecies(id: 16, captureRate: 255)]
        let s = try hatchingStore(index: index) { _ in }
        XCTAssertFalse(s.hatchPool(index, egg: CompanionStore.EggSpec()).contains { $0.base.id == 493 })
        XCTAssertFalse(s.hatchPool(index, egg: CompanionStore.EggSpec(legendaryEgg: true)).contains { $0.base.id == 493 })
        XCTAssertFalse(BirthdayGift.pool(index, graduated: []).lines.contains { $0.id == 493 })
    }

    /// A save that pre-rolled Arceus rolls again.
    func testAPreRolledArceusRollsAgain() async throws {
        let s = try hatchingStore(index: [BaseSpecies(id: 16, captureRate: 255)]) {
            $0.pendingHatchID = 493
            $0.eggUsage = 10_000_000
        }
        await s.hatchIfNeeded()
        XCTAssertNotEqual(s.state.active?.baseID, 493)
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
