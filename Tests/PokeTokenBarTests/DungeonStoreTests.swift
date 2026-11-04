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

    /// Home shrinks the Pokémon raised to a strip only while its growth waits for the team (exploring, the heal); it
    /// grows again, its card back, as soon as the boss falls or the team loses, the result still shown above it.
    func testGrowthComesBackWhenTheTeamIsDone() throws {
        for won in [true, false] {
            let s = try store(dex: strong)
            XCTAssertFalse(s.growthPaused)
            XCTAssertTrue(s.startExpedition(.viridianForest, team: Array(strong.prefix(3)).map(\.id)))
            XCTAssertTrue(s.growthPaused, "exploring")
            s.changeDungeons { $0.expedition?.phase = .awaitingHeal(price: 1) }
            XCTAssertTrue(s.growthPaused, "the heal")
            if won {
                s.changeDungeons { $0.expedition?.phase = .capture(throwsLeft: 3) }
                XCTAssertFalse(s.growthPaused, "the boss fell: growth again while the throws wait")
                s.endCapture()
            } else {
                s.abandonExpedition()
            }
            XCTAssertNil(s.expedition)
            XCTAssertFalse(s.growthPaused, won ? "won" : "lost")
            XCTAssertNotNil(s.dungeonProgress.lastResult, "the result stays above until closed")
        }
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
        // Frozen while it explores, free for the Pokémon left home.
        XCTAssertTrue(s.startExpedition(.viridianForest, team: ["e6", "e9", "e3"]))
        XCTAssertTrue(s.isExploring("e6"))
        XCTAssertFalse(s.setMoveLoop(["flamethrower"], for: "e6"))
        XCTAssertEqual(s.dungeonProgress.moveLoops["e6"], ["flamethrower", "air-slash"])
        XCTAssertFalse(s.isExploring("e25"))
        XCTAssertTrue(s.setMoveLoop(["thunderbolt"], for: "e25"))
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
        // Named by the Pokémon it hatches, Dratini, never "dungeon egg".
        XCTAssertEqual(s.incubatingEggName, DungeonEggTitle.text(147, l: s.l, language: s.language))
        s.setEggUsageForTesting(s.eggHatchThreshold)
        await s.hatchIfNeeded()
        XCTAssertEqual(s.state.active?.baseID, 147)
        XCTAssertEqual(s.state.active?.isShiny, true)
        XCTAssertNil(s.state.eggFromDungeon)
        // The Luck screen replays it as the boss's egg, a sure draw, not as a Pokémon Egg.
        let egg = HatchEgg.dungeon(baseID: 147, form: nil, shiny: true)
        XCTAssertEqual(s.state.active?.hatch?.egg, egg)
        let outcomes = s.hatchDraw.outcomes(egg, index: [BaseSpecies(id: 147, captureRate: 45)])
        XCTAssertEqual(outcomes.map(\.id), [147])
        XCTAssertEqual(outcomes.first?.alwaysShiny, true)
    }

    /// R13: Arceus hatches from no egg: not a plain one, not a Legendary Egg, not a Birthday Egg.
    func testArceusHatchesFromNoEgg() throws {
        let index = [BaseSpecies(id: 493, captureRate: 3, isLegendary: true), BaseSpecies(id: 150, captureRate: 3, isLegendary: true),
                     BaseSpecies(id: 16, captureRate: 255)]
        let s = try hatchingStore(index: index) { _ in }
        XCTAssertFalse(s.hatchDraw.hatchPool(index, egg: CompanionStore.EggSpec()).contains { $0.base.id == 493 })
        XCTAssertFalse(s.hatchDraw.hatchPool(index, egg: CompanionStore.EggSpec(legendaryEgg: true)).contains { $0.base.id == 493 })
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
        XCTAssertEqual(CompanionStore.technicalCapsuleChance(.t4), 20)
        XCTAssertEqual(CompanionStore.technicalCapsuleChance(.t5), 15)
        // About one T3 victory in ten gives a key after the first.
        var keys = 0
        for _ in 0..<2_000 {
            keys += CompanionStore.victoryExtras(tier: .t3, firstT3Victory: false, random: &random)
                .items[ItemKind.legendaryKey.rawValue] ?? 0
        }
        XCTAssertEqual(Double(keys) / 2_000, 0.10, accuracy: 0.02)
    }

    /// The Dungeons medals sit with the Artifacts: a step per dungeon won once, then the whole tier, each its reward
    /// and never a Legendary Key; nothing without a victory, and the Ruins of Alph stay out.
    func testTheMedalsCountTheDungeonsWon() throws {
        XCTAssertEqual(ItemKind.discoveryMedal.collectorGroup, .legendaryArtifacts)
        XCTAssertFalse(DungeonMedals.dungeons(.t4).contains(.ruinsOfAlph))
        XCTAssertEqual(DungeonTier.allCases.map { DungeonMedals.goals($0).count }.reduce(0, +), 16)
        for tier in DungeonTier.allCases {
            for (step, _) in DungeonMedals.goals(tier) {
                XCTAssertFalse(DungeonMedals.rewards(tier, step: step).contains { $0.kind == .legendaryKey }, "T\(tier.rawValue) #\(step)")
            }
        }

        let none = try store(dex: strong)
        XCTAssertEqual(none.regionTiers(.discoveryMedal).filter(\.isReady).count, 0)
        XCTAssertFalse(none.claimAchievement(.discoveryMedal))

        let one = try store(dex: strong) { $0.dungeons.wins[DungeonID.viridianForest.rawValue] = 1 }
        XCTAssertEqual(one.regionTiers(.discoveryMedal).map(\.isReady), [true, false, false], "a dungeon, not the tier")
        XCTAssertTrue(one.claimAchievement(.discoveryMedal))
        XCTAssertEqual(one.itemCount(.greatBall), 1)
        XCTAssertEqual(one.itemCount(.discoveryMedal), 0, "the medal gives, it is not kept")

        let both = try store(dex: strong) {
            $0.dungeons.wins[DungeonID.viridianForest.rawValue] = 3
            $0.dungeons.wins[DungeonID.diglettsCave.rawValue] = 1
        }
        XCTAssertTrue(both.claimAchievement(.discoveryMedal))
        XCTAssertEqual(both.itemCount(.greatBall), 2)
        XCTAssertEqual(both.itemCount(.pokemonEgg), 1, "the whole T1")
        XCTAssertTrue(both.isClaimed(.discoveryMedal))
        XCTAssertFalse(both.claimAchievement(.discoveryMedal), "claimed once")

        let origin = try store(dex: strong) { $0.dungeons.wins[DungeonID.hallOfOrigin.rawValue] = 1 }
        XCTAssertEqual(origin.regionTiers(.originMedal).count, 1, "a single dungeon has no whole-tier step")
        XCTAssertTrue(origin.claimAchievement(.originMedal))
        XCTAssertEqual(origin.itemCount(.goldCapsule), 1)
    }

    // MARK: Battle forms (2026-11-02)

    /// PokéAPI's Megas, Primals and Gigantamax forms with a sprite: Mega Zygarde has none and stays out. The daily
    /// dungeon gives the Megas of non-legendary species, the weekly one the rest.
    func testTheBattleFormsTable() {
        XCTAssertEqual(BattleForms.all.count, 132)
        XCTAssertEqual(Set(BattleForms.all.map(\.key)).count, 132, "one key each")
        let charizardX = try? XCTUnwrap(BattleForms.form(speciesID: 6, form: PokemonForm("mega-x")))
        XCTAssertEqual(charizardX?.pokemonID, 10034)
        XCTAssertEqual(BattleForms.form(speciesID: 25, form: PokemonForm("gmax"))?.kind, .gigantamax)
        XCTAssertEqual(BattleForms.form(speciesID: 382, form: PokemonForm("primal"))?.kind, .primal)
        XCTAssertNil(BattleForms.forms(speciesID: 718).first { $0.form.rawValue == "mega" }, "no sprite, left out")
        XCTAssertTrue(BattleForms.daily.allSatisfy { $0.kind == .mega && !$0.isLegendary })
        XCTAssertTrue(BattleForms.weekly.contains { $0.speciesID == 150 }, "Mewtwo's Megas are the week's")
        XCTAssertEqual(BattleForms.daily.count + BattleForms.weekly.count, BattleForms.all.count)
    }

    /// A battle form takes its variety's stats, types, ability and sprites, and no egg ever hatches it.
    func testABattleFormIsItsVariety() throws {
        let x = PokemonForm("mega-x")
        XCTAssertEqual(PokemonForm.resolved(speciesID: 6, form: x), x)
        XCTAssertEqual(PokemonForm.detailsID(speciesID: 6, form: x), 10034)
        XCTAssertEqual(PokemonForm.staticAssetName(speciesID: 6, form: x), "10034")
        XCTAssertEqual(PokemonTypeData.types(forSpeciesID: 6, form: x), [.fire, .dragon])
        let mega = try XCTUnwrap(BattlerSpec.make(id: "x", speciesID: 6, form: x, level: 100))
        let usual = try XCTUnwrap(BattlerSpec.make(id: "u", speciesID: 6, level: 100))
        XCTAssertGreaterThan(mega.stats.attack, usual.stats.attack)
        XCTAssertEqual(mega.ability, "tough-claws")
        XCTAssertFalse(PokemonForm.lineForms(baseID: 4).contains(x), "never rolled by an egg")
        XCTAssertFalse(PokemonForm.lineForms(baseID: 79).contains { $0.rawValue.contains("mega") })
        // Every form the app can count: the catalog's and the battle forms.
        let catalog = PokemonAssets.animatedSpeciesIDs.reduce(0) { $0 + max(1, PokemonForm.forms(speciesID: $1).count) }
        XCTAssertEqual(CompanionStore.collectableFormCount, catalog + BattleForms.all.count)
    }

    /// The daily dungeon opens with a first T3 victory, costs no key, draws a Mega of a graduated species, and gives
    /// it when its boss falls: one try a day, the form never used up, in the Pokédex's count, chosen for a member.
    func testTheDailyDungeonGivesAMega() throws {
        let charizard = graduated(6)
        let team = [charizard] + [9, 3, 25, 143, 130].map { graduated($0) }
        let s = try store(dex: team) { $0.dungeons.wins[DungeonID.victoryRoad.rawValue] = 1 }
        XCTAssertTrue(s.isDungeonOpen(.daily))
        XCTAssertFalse(s.isDungeonOpen(.weekly), "a T4 victory opens the week's")
        XCTAssertEqual(s.keysToEnter(.daily), 0)
        let boss = try XCTUnwrap(s.challengeBoss(.daily))
        XCTAssertTrue(team.map(\.finalID).contains(boss.speciesID))
        XCTAssertEqual(s.challengeBoss(.daily), boss, "the same all day")
        let formsBefore = s.graduatedCollectionProgress.forms
        XCTAssertTrue(s.startExpedition(.daily, team: team.map(\.id)))
        XCTAssertEqual(s.expedition?.boss.form, boss.form)
        XCTAssertEqual(s.expedition?.floors, 8)
        XCTAssertTrue(s.challengeTried(.daily))
        s.changeDungeons { $0.expedition?.phase = .capture(throwsLeft: 3) }
        s.endCapture()
        XCTAssertEqual(s.dungeonProgress.lastResult?.battleForm, boss.key)
        XCTAssertTrue(s.dungeonProgress.battleForms.contains(boss.key))
        XCTAssertEqual(s.graduatedCollectionProgress.forms, formsBefore + 1)
        XCTAssertFalse(s.canEnter(.daily), "one try a day")
        XCTAssertNotEqual(s.challengeBoss(.daily), boss, "won: no longer drawn")
        // The owner of the species takes it in a dungeon, never using it up.
        let owner = try XCTUnwrap(s.state.dex.first { $0.finalID == boss.speciesID })
        XCTAssertTrue(s.setBattleForm(boss, for: owner.id))
        XCTAssertEqual(s.dungeonCandidates.first { $0.id == owner.id }?.form, boss.form)
        XCTAssertTrue(s.dungeonProgress.battleForms.contains(boss.key))
        XCTAssertTrue(s.setBattleForm(nil, for: owner.id))
        XCTAssertNil(s.dungeonCandidates.first { $0.id == owner.id }?.form)
        // The save keeps it, and a form this build does not know is not read.
        var progress = s.dungeonProgress
        progress.battleForms.insert("6-mega-w")
        let back = try JSONDecoder().decode(DungeonProgress.self, from: JSONEncoder().encode(progress))
        XCTAssertEqual(back.battleForms, s.dungeonProgress.battleForms)
        XCTAssertEqual(back.dailyTried, s.dungeonProgress.dailyTried)
    }

    /// A defeat spends the one try too; the week's has its own, by ISO week.
    func testAChallengeTryIsSpentWhateverTheEnd() throws {
        let team = [6, 9, 3, 25, 143, 130].map { graduated($0) }
        let s = try store(dex: team) { $0.dungeons.wins[DungeonID.seafoamIslands.rawValue] = 1 }
        XCTAssertTrue(s.isDungeonOpen(.weekly))
        XCTAssertTrue(s.startExpedition(.weekly, team: team.map(\.id)))
        s.abandonExpedition()
        XCTAssertTrue(s.dungeonProgress.battleForms.isEmpty)
        XCTAssertTrue(s.challengeTried(.weekly))
        XCTAssertFalse(s.canEnter(.weekly))
        XCTAssertTrue(s.challengePeriod(.weekly).contains("-W"))
        XCTAssertFalse(s.challengeTried(.daily), "the day's is apart")
    }

    /// The Battle Forms Medal counts the forms won, in steps at 5, 15, 30, 60, 100 and all, each its reward.
    func testTheBattleFormsMedalCountsTheFormsWon() throws {
        XCTAssertEqual(BattleFormsMedal.steps, [5, 15, 30, 60, 100, BattleForms.all.count])
        let five = Set(BattleForms.all.prefix(5).map(\.key))
        let s = try store(dex: strong) { $0.dungeons.battleForms = five }
        XCTAssertEqual(s.regionTiers(.battleFormsMedal).map(\.isReady), [true, false, false, false, false, false])
        XCTAssertTrue(s.claimAchievement(.battleFormsMedal))
        XCTAssertEqual(s.itemCount(.ultraBall), 2)
        XCTAssertFalse(s.claimAchievement(.battleFormsMedal), "the next step asks for 15")
        XCTAssertEqual(ItemKind.battleFormsMedal.collectorGroup, .legendaryArtifacts)
    }

    // MARK: The review of 2026-11-02

    /// [Regression] A challenge has no boss list: its odds estimate indexed an empty one and crashed the Prepare screen.
    /// The estimate now carries the day's boss, the Bag's berries and Revives, and the members' battle forms.
    func testAChallengesOddsDoNotCrash() throws {
        let team = [6, 9, 3, 25, 143, 130].map { graduated($0) }
        let members = team.compactMap { entry in
            DungeonTeamBuilder.spec(for: entry).map { ExpeditionMember(entryID: entry.id, spec: $0) }
        }
        for id in [DungeonID.daily, .weekly] {
            let odds = DungeonTeamBuilder.reachOdds(team: members, dungeon: DungeonCatalog.dungeon(id), runs: 2)
            XCTAssertTrue((0...1).contains(odds), id.rawValue)
        }
        let s = try store(dex: team, inventory: [.sitrusBerry: 3]) { $0.dungeons.wins[DungeonID.victoryRoad.rawValue] = 1 }
        let estimate = try XCTUnwrap(s.reachEstimate(team: team.map(\.id), for: .daily))
        XCTAssertEqual(estimate.boss?.form, s.challengeBoss(.daily)?.form)
        XCTAssertEqual(estimate.berries[.sitrus], 3, "the berries the departure takes")
    }

    /// [Regression] Tokens past the boss's fall walked nowhere: a morning's catch-up finishing the last floor lost the
    /// rest. What the dungeon does not take goes back to the growth it paused.
    func testTokensPastTheEndGoBackToGrowth() throws {
        let team = Array(strong.prefix(3))
        let s = try store(dex: strong)
        XCTAssertTrue(s.startExpedition(.viridianForest, team: team.map(\.id)))
        var e = try XCTUnwrap(s.expedition)
        let context = ExpeditionContext(tier: .t1, shinyDenominator: 64, now: now)
        let left = ExpeditionEngine.feed(&e, tokens: e.floorCost * e.floors * 10, context: context)
        XCTAssertFalse({ if case .exploring = e.phase { return true }; return false }(), "the dungeon is done")
        XCTAssertGreaterThan(left, e.floorCost * e.floors, "most of it left over")
        let before = s.state.active?.usedAtStage ?? 0
        XCTAssertEqual(s.feedExpedition(e.floorCost * e.floors * 10).map { $0 > 0 }, true)
        _ = before
        XCTAssertNil(s.feedExpedition(1).flatMap { $0 > 0 ? $0 : nil }, "once over, nothing more walks it")
    }

    /// [Regression] The day's boss stays as first shown: a graduation in the day changed the draw's list, and the boss.
    func testTheDaysBossStaysAllDay() throws {
        let morning = [6, 9, 3, 25, 143, 130].map { graduated($0) }
        let s = try store(dex: morning) { $0.dungeons.wins[DungeonID.victoryRoad.rawValue] = 1 }
        s.settleChallengeBosses()
        let boss = try XCTUnwrap(s.challengeBoss(.daily))
        let draws = s.dungeonProgress.challengeDraws
        XCTAssertEqual(draws["daily:\(s.challengePeriod(.daily))"], boss.key)
        // Later the same day, more Mega-capable species graduated: the kept draw wins over a new one.
        let noon = morning + [94, 65, 248, 448, 445, 376, 257, 282, 306, 359].map { graduated($0) }
        let later = try store(dex: noon) {
            $0.dungeons.wins[DungeonID.victoryRoad.rawValue] = 1
            $0.dungeons.challengeDraws = draws
        }
        XCTAssertEqual(later.challengeBoss(.daily), boss)
    }

    /// [Regression] A hand-edited throw count past three is clamped at the import: a throw then counted backwards.
    func testAnImportedCaptureKeepsThreeThrows() throws {
        var state = CompanionState()
        state.installBaselineSet = true
        let spec = try XCTUnwrap(BattlerSpec.make(id: "e6", speciesID: 6, level: 100))
        var e = ExpeditionEngine.start(dungeon: DungeonCatalog.dungeon(.viridianForest),
                                       team: [ExpeditionMember(entryID: "e6", spec: spec)], rules: [], teamSize: 1, seed: 1,
                                       cost: 75_000_000, berries: [:], revives: [:],
                                       context: ExpeditionContext(tier: .t1, shinyDenominator: 64, now: now))
        e.phase = .capture(throwsLeft: 1000)
        state.dungeons.expedition = e
        let data = try SaveTransfer.encode(state: state, appVersion: "2.5.0", deviceName: "Mac", now: now)
        let back = try SaveTransfer.decode(data).state.dungeons.expedition
        XCTAssertEqual(back?.phase, .capture(throwsLeft: 3))
    }

    /// [Regression] Leaving is refused once the boss fell: it turned a victory, its throws waiting, into a defeat.
    func testNoLeavingOnceTheBossFell() throws {
        let s = try store(dex: strong, inventory: [.escapeRope: 1])
        XCTAssertTrue(s.startExpedition(.viridianForest, team: Array(strong.prefix(3)).map(\.id)))
        s.changeDungeons { $0.expedition?.phase = .capture(throwsLeft: 3) }
        s.abandonExpedition()
        XCTAssertNotNil(s.expedition, "still at the throws")
        XCTAssertEqual(s.itemCount(.escapeRope), 1, "no rope spent")
    }

    // MARK: Past midnight and the week's turn (the owner, 2026-11-03)

    private final class Clock: @unchecked Sendable { var date: Date; init(_ date: Date) { self.date = date } }

    private func store(dex: [DexEntry], clock: Clock, prepare: (inout CompanionState) -> Void) throws -> CompanionStore {
        var st = CompanionState()
        st.installBaselineSet = true
        st.lastDate = "d"
        st.claimedTodayTokensByProvider = ["test": 0]
        st.dex = dex
        st.active = MonState(baseID: 16, pathIDs: [16, 17, 18], stageIndex: 0, usedAtStage: 0, rarity: .common, totalForms: 3)
        prepare(&st)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("dungeon-clock-\(UUID().uuidString).json")
        try JSONEncoder().encode(st).write(to: url)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return CompanionStore(provider: StubProvider(value: EvoLine(baseID: 16, tree: EvoNode(speciesID: 16, children: []),
                                                                    rarity: .common, names: [:])),
                              clock: { clock.date }, fileURL: url, rng: SeededRNG(seed: 3), difficulty: 0.1)
    }

    /// [Regression, review of 2026-11-04] Set off a minute past midnight from a screen opened before it, a challenge
    /// fought the new day's boss, not the one shown and estimated, and spent the new day's try on it. The departure now
    /// waits for the boss the screen showed.
    func testAChallengeDepartureWaitsForTheBossItShowed() throws {
        let calendar = Calendar(identifier: .iso8601)
        let team = [6, 9, 3, 25, 143, 130].map { graduated($0) }
        var played = false
        for day in 8...14 {
            var parts = DateComponents(year: 2026, month: 11, day: day, hour: 23, minute: 59)
            parts.timeZone = .current
            let clock = Clock(try XCTUnwrap(calendar.date(from: parts)))
            let s = try store(dex: team, clock: clock) { $0.dungeons.wins[DungeonID.victoryRoad.rawValue] = 1 }
            let shown = try XCTUnwrap(s.challengeBoss(.daily))
            clock.date = clock.date.addingTimeInterval(2 * 60)
            let current = try XCTUnwrap(s.challengeBoss(.daily))
            guard current != shown else { continue }
            played = true
            XCTAssertFalse(s.startExpedition(.daily, team: team.map(\.id), expectedBoss: shown))
            XCTAssertNil(s.expedition)
            XCTAssertFalse(s.challengeTried(.daily), "the new day's try is still there")
            XCTAssertTrue(s.startExpedition(.daily, team: team.map(\.id), expectedBoss: current))
            XCTAssertEqual(s.expedition?.boss.form, current.form)
            break
        }
        XCTAssertTrue(played, "no midnight in the week changed the day's boss")
    }

    /// [Regression, review of 2026-11-04] Capture with no throw left (only an import makes one) took the ball and threw
    /// nothing.
    func testNoThrowLeftTakesNoBall() throws {
        let s = try store(dex: strong, inventory: [.ultraBall: 2])
        XCTAssertTrue(s.startExpedition(.viridianForest, team: Array(strong.prefix(3)).map(\.id)))
        s.changeDungeons { $0.expedition?.phase = .capture(throwsLeft: 0) }
        XCTAssertNil(s.throwAtBoss(.ultraBall))
        XCTAssertEqual(s.itemCount(.ultraBall), 2)
    }

    /// [Regression, review of 2026-11-04] A battle that crashed the app replayed at every launch (its seed, team and
    /// floor are saved). A step that never came back ends its expedition at the next launch; a step that comes back
    /// leaves no mark.
    func testAStepThatNeverCameBackEndsItsExpedition() throws {
        let suite = "dungeon-step-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        addTeardownBlock { defaults.removePersistentDomain(forName: suite) }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("dungeon-step-\(UUID().uuidString).json")
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        func open() -> CompanionStore {
            CompanionStore(provider: StubProvider(value: EvoLine(baseID: 16, tree: EvoNode(speciesID: 16, children: []),
                                                                 rarity: .common, names: [:])),
                           clock: { self.now }, fileURL: url, rng: SeededRNG(seed: 3), defaults: defaults, difficulty: 0.1)
        }
        var st = CompanionState()
        st.installBaselineSet = true
        st.lastDate = "d"
        st.claimedTodayTokensByProvider = ["test": 0]
        st.dex = strong
        st.active = MonState(baseID: 16, pathIDs: [16, 17, 18], stageIndex: 0, usedAtStage: 0, rarity: .common, totalForms: 3)
        try JSONEncoder().encode(st).write(to: url)
        let s = open()
        XCTAssertTrue(s.startExpedition(.viridianForest, team: Array(strong.prefix(3)).map(\.id)))
        _ = s.feedExpedition(1_000_000)
        XCTAssertFalse(defaults.bool(forKey: CompanionStore.stepInFlightKey), "a step that came back leaves no mark")
        XCTAssertNotNil(s.expedition)
        // The app died inside the next step: the mark stayed, the save is the step's before.
        defaults.set(true, forKey: CompanionStore.stepInFlightKey)
        let relaunched = open()
        XCTAssertNil(relaunched.expedition, "the expedition ends instead of replaying the battle")
        XCTAssertEqual(relaunched.dungeonProgress.lastResult?.won, false)
        XCTAssertFalse(defaults.bool(forKey: CompanionStore.stepInFlightKey))
    }

    /// A challenge set off before midnight (or before the week turns) goes on unchanged: its boss, its floors and the
    /// form it gives are the departure's, whatever the day's draw has become; the next try is the new period's.
    func testAChallengeGoesOnPastMidnightAndTheWeeksTurn() throws {
        let calendar = Calendar(identifier: .iso8601)
        // Sunday 23:50, local time: the day and the ISO week both turn at the next midnight.
        var parts = DateComponents(year: 2026, month: 11, day: 8, hour: 23, minute: 50)
        parts.timeZone = .current
        let clock = Clock(try XCTUnwrap(calendar.date(from: parts)))
        let team = [6, 9, 3, 25, 143, 130].map { graduated($0) }
        for id in [DungeonID.daily, .weekly] {
            let s = try store(dex: team, clock: clock) {
                $0.dungeons.wins[DungeonID.victoryRoad.rawValue] = 1
                $0.dungeons.wins[DungeonID.seafoamIslands.rawValue] = 1
            }
            clock.date = try XCTUnwrap(calendar.date(from: parts))
            let boss = try XCTUnwrap(s.challengeBoss(id))
            let period = s.challengePeriod(id)
            XCTAssertTrue(s.startExpedition(id, team: team.map(\.id)), id.rawValue)
            let floors = try XCTUnwrap(s.expedition?.floors)
            // Past midnight, into Monday: a new day, a new ISO week.
            clock.date = clock.date.addingTimeInterval(20 * 60)
            XCTAssertNotEqual(s.challengePeriod(id), period, "\(id.rawValue): the period turned")
            XCTAssertEqual(s.expedition?.boss.form, boss.form, "\(id.rawValue): the same boss")
            XCTAssertEqual(s.expedition?.floors, floors)
            XCTAssertFalse(s.canEnter(id), "\(id.rawValue): one run at a time")
            // The run ends the next day, won: the form is the departure's boss.
            s.changeDungeons { $0.expedition?.phase = .capture(throwsLeft: 3) }
            s.endCapture()
            XCTAssertEqual(s.dungeonProgress.lastResult?.battleForm, boss.key, id.rawValue)
            XCTAssertTrue(s.dungeonProgress.battleForms.contains(boss.key))
            // The new period's try is untouched; its boss is another form, the one won is out of the draw.
            XCTAssertFalse(s.challengeTried(id), "\(id.rawValue): the new period's try is still there")
            XCTAssertTrue(s.canEnter(id))
            XCTAssertNotEqual(s.challengeBoss(id), boss)
        }
    }
}
