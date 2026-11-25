import XCTest
@testable import PokeTokenBar

/// The Wishing Piece (the owner, 2026-11-25): it swaps the daily or weekly dungeon's boss before that day's try.
@MainActor
final class WishingPieceTests: XCTestCase {
    private final class Clock: @unchecked Sendable { var date: Date; init(_ date: Date) { self.date = date } }

    /// Wednesday 2026-11-11, noon.
    private func wednesday(hour: Int = 12, minute: Int = 0, plusDays: Int = 0) throws -> Date {
        var parts = DateComponents(year: 2026, month: 11, day: 11 + plusDays, hour: hour, minute: minute)
        parts.timeZone = .current
        return try XCTUnwrap(Calendar(identifier: .iso8601).date(from: parts))
    }

    private func graduated(_ id: Int) -> DexEntry {
        var entry = DexEntry(baseID: SpeciesInfo.baseID(of: id), finalID: id, chainOrder: [id], rarity: .common, caughtAt: Date(timeIntervalSince1970: 0))
        entry.id = "e\(id)"
        return entry
    }

    /// Five Megas for the day (Charizard X and Y, Blastoise, Venusaur, Gyarados), five Gigantamax for the week.
    private var team: [DexEntry] { [6, 9, 3, 25, 143, 130].map(graduated) }

    private func store(dex: [DexEntry]? = nil, pieces: Int? = nil, clock: Clock,
                       prepare: (inout CompanionState) -> Void = { _ in }) throws -> CompanionStore {
        var st = CompanionState()
        st.installBaselineSet = true
        st.lastDate = "d"
        st.claimedTodayTokensByProvider = ["test": 0]
        st.dex = dex ?? team
        st.active = MonState(baseID: 16, pathIDs: [16, 17, 18], stageIndex: 0, usedAtStage: 0, rarity: .common, totalForms: 3)
        if let pieces {
            st.wishingPiecesGiven = true
            st.inventory[ItemKind.wishingPiece.rawValue] = pieces
        }
        st.dungeons.wins[DungeonID.victoryRoad.rawValue] = 1
        st.dungeons.wins[DungeonID.seafoamIslands.rawValue] = 1
        st.dungeons.villainDay = DungeonProgress.challengePeriod(.daily, at: clock.date)
        prepare(&st)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("wishing-\(UUID().uuidString).json")
        try JSONEncoder().encode(st).write(to: url)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return reopen(url, clock: clock)
    }

    private func reopen(_ url: URL, clock: Clock) -> CompanionStore {
        CompanionStore(provider: StubProvider(value: EvoLine(baseID: 16, tree: EvoNode(speciesID: 16, children: []),
                                                             rarity: .common, names: [:])),
                       clock: { clock.date }, fileURL: url, rng: SeededRNG(seed: 3), difficulty: 0.1)
    }

    // MARK: The starting pieces

    /// Three once, to a save from before as to a new one; launched again, none come back.
    func testTheStartingPiecesComeOnce() throws {
        let clock = Clock(try wednesday())
        var raw = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(CompanionState())) as? [String: Any])
        raw["wishingPiecesGiven"] = nil
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("wishing-\(UUID().uuidString).json")
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        try JSONSerialization.data(withJSONObject: raw).write(to: url)
        let old = reopen(url, clock: clock)
        XCTAssertEqual(old.itemCount(.wishingPiece), 3)
        old.persist()
        XCTAssertEqual(reopen(url, clock: clock).itemCount(.wishingPiece), 3, "once")
        let fresh = FileManager.default.temporaryDirectory.appendingPathComponent("wishing-\(UUID().uuidString).json")
        XCTAssertEqual(reopen(fresh, clock: clock).itemCount(.wishingPiece), 3, "a new player too")
        XCTAssertFalse(FileManager.default.fileExists(atPath: fresh.path), "a fresh state touches no file on launch")
    }

    /// An export from before the pieces, imported where they were given, brings none again.
    func testAnImportGivesNoSecondStart() throws {
        var imported = CompanionState()
        imported.installBaselineSet = true
        var current = imported
        current.wishingPiecesGiven = true
        let merged = SaveTransfer.rebasedForThisDevice(imported, current: current, todayTokensByProvider: [:],
                                                       todayDate: "d", hasUsageData: false)
        XCTAssertTrue(merged.wishingPiecesGiven)
    }

    // MARK: The swap

    /// One piece for the day's boss, three for the week's; each swap brings another boss.
    func testASwapCostsOneForTheDayAndThreeForTheWeek() throws {
        let s = try store(pieces: 4, clock: Clock(try wednesday()))
        let day = try XCTUnwrap(s.challengeBoss(.daily))
        let week = try XCTUnwrap(s.challengeBoss(.weekly))
        let newDay = try XCTUnwrap(s.swapChallengeBoss(.daily))
        XCTAssertNotEqual(newDay, day)
        XCTAssertEqual(s.challengeBoss(.daily), newDay)
        XCTAssertEqual(s.itemCount(.wishingPiece), 3)
        XCTAssertEqual(s.challengeBoss(.weekly), week, "the day's swap leaves the week's boss")
        let newWeek = try XCTUnwrap(s.swapChallengeBoss(.weekly))
        XCTAssertNotEqual(newWeek, week)
        XCTAssertEqual(s.itemCount(.wishingPiece), 0)
        XCTAssertEqual(s.challengeBoss(.daily), newDay, "the week's swap leaves the day's boss")
        XCTAssertTrue(s.startExpedition(.daily, team: team.map(\.id), expectedBoss: newDay), "the team fights the new boss")
        XCTAssertEqual(s.expedition?.boss.form, newDay.form)
        XCTAssertEqual(s.expedition?.boss.speciesID, newDay.speciesID)
    }

    /// Not enough pieces: offered, refused, nothing spent.
    func testNotEnoughPiecesIsRefused() throws {
        let s = try store(pieces: 2, clock: Clock(try wednesday()))
        let week = s.challengeBoss(.weekly)
        XCTAssertTrue(s.canSwapChallengeBoss(.weekly))
        XCTAssertNil(s.swapChallengeBoss(.weekly))
        XCTAssertEqual(s.challengeBoss(.weekly), week)
        XCTAssertEqual(s.itemCount(.wishingPiece), 2)
    }

    /// Never after the day's try, nor once the challenge is won.
    func testNoSwapAfterTheTryOrTheWin() throws {
        let s = try store(pieces: 9, clock: Clock(try wednesday()))
        XCTAssertTrue(s.startExpedition(.daily, team: team.map(\.id)))
        XCTAssertFalse(s.canSwapChallengeBoss(.daily), "under way")
        s.abandonExpedition()
        XCTAssertFalse(s.canSwapChallengeBoss(.daily), "tried today")
        XCTAssertNil(s.swapChallengeBoss(.daily))
        let week = try XCTUnwrap(s.challengeBoss(.weekly))
        let today = try wednesday()
        let won = try store(pieces: 9, clock: Clock(today)) {
            $0.dungeons.challengeWins[DungeonProgress.challengeKey(.weekly, at: today)] = week.key
            $0.dungeons.battleForms.insert(week.key)
        }
        XCTAssertFalse(won.canSwapChallengeBoss(.weekly), "won this week")
        XCTAssertNil(won.swapChallengeBoss(.weekly))
        XCTAssertEqual(won.itemCount(.wishingPiece), 9)
    }

    /// [Regression] A challenge set off before midnight still runs past it: the new day's try is there, and the swap is
    /// not, during the challenge itself.
    func testNoSwapWhileItsRunGoesPastMidnight() throws {
        let clock = Clock(try wednesday(hour: 23, minute: 59))
        let s = try store(pieces: 9, clock: clock)
        XCTAssertTrue(s.startExpedition(.daily, team: team.map(\.id)))
        clock.date = clock.date.addingTimeInterval(2 * 60)
        XCTAssertFalse(s.challengeTried(.daily), "the new day's try")
        XCTAssertFalse(s.canSwapChallengeBoss(.daily))
        XCTAssertTrue(s.canSwapChallengeBoss(.weekly), "another expedition leaves the other challenge's swap")
    }

    /// With a single form left, there is nothing to swap for.
    func testOneFormLeftIsNoSwap() throws {
        let s = try store(dex: [graduated(130)], pieces: 9, clock: Clock(try wednesday()))
        XCTAssertEqual(s.challengeCandidates(.daily).count, 1)
        XCTAssertNotNil(s.challengeBoss(.daily))
        XCTAssertFalse(s.canSwapChallengeBoss(.daily))
        XCTAssertNil(s.swapChallengeBoss(.daily))
    }

    /// A swap excludes only the boss it swaps away: with two forms, A, B, then A again.
    func testASwapExcludesOnlyTheBossItSwapsAway() throws {
        let s = try store(dex: [graduated(6)], pieces: 2, clock: Clock(try wednesday()))
        XCTAssertEqual(s.challengeCandidates(.daily).count, 2)
        let a = try XCTUnwrap(s.challengeBoss(.daily))
        let b = try XCTUnwrap(s.swapChallengeBoss(.daily))
        XCTAssertNotEqual(a, b)
        XCTAssertEqual(s.swapChallengeBoss(.daily), a)
    }

    /// The week's boss swapped stays until Monday; the day's goes the next day, for the boss that day draws.
    func testASwappedBossStaysForItsPeriod() throws {
        let clock = Clock(try wednesday())
        let s = try store(pieces: 4, clock: clock)
        let control = try store(pieces: 0, clock: clock)
        let week = try XCTUnwrap(s.swapChallengeBoss(.weekly))
        let day = try XCTUnwrap(s.swapChallengeBoss(.daily))
        s.settleChallengeBosses()
        XCTAssertEqual(s.challengeBoss(.daily), day, "kept once settled")
        clock.date = try wednesday(plusDays: 4)
        s.settleChallengeBosses()
        control.settleChallengeBosses()
        XCTAssertEqual(s.challengeBoss(.weekly), week, "Sunday: still the week's")
        XCTAssertEqual(s.challengeBoss(.daily), control.challengeBoss(.daily), "the next day: that day's own boss")
        clock.date = try wednesday(plusDays: 5)
        XCTAssertEqual(s.challengeBoss(.weekly), control.challengeBoss(.weekly), "Monday: the new week's own boss")
    }

    // MARK: Where they come from

    /// 5% of the daily dungeons won, 15% of the weekly ones, from the victory's own roll.
    func testAChallengeWonMayDropOne() throws {
        func roll(_ seed: UInt64) -> Int {
            var random = BattleRandom(seed: seed ^ 0xFEED_F00D)
            return random.below(10_000)
        }
        let both = try XCTUnwrap((0..<10_000 as Range<UInt64>).first { roll($0) < 500 })
        let weekOnly = try XCTUnwrap((0..<10_000 as Range<UInt64>).first { (500..<1_500).contains(roll($0)) })
        for (id, seed, drops) in [(DungeonID.daily, both, true), (.daily, weekOnly, false), (.weekly, weekOnly, true)] {
            let s = try store(pieces: 0, clock: Clock(try wednesday()))
            XCTAssertTrue(s.startExpedition(id, team: team.map(\.id)))
            s.changeDungeons {
                $0.expedition?.seed = seed
                $0.expedition?.phase = .capture(throwsLeft: 3)
            }
            s.endCapture()
            XCTAssertEqual(s.dungeonProgress.lastResult?.won, true)
            XCTAssertEqual(s.itemCount(.wishingPiece), drops ? 1 : 0, "\(id) \(seed)")
            XCTAssertEqual(s.dungeonProgress.lastResult?.loot.items[ItemKind.wishingPiece.rawValue] ?? 0, drops ? 1 : 0)
        }
    }

    /// Fifty in a thousand of the T4 and T5 leaders' chests, taken from the Rare Egg; every table still adds up to a
    /// thousand. Nothing in an ordinary dungeon's loot, the Explorer Kit or the Shop.
    func testTheOtherSources() {
        for tier in DungeonTier.allCases {
            let table = VillainRules.leaderChestTable(tier)
            XCTAssertEqual(table.reduce(0) { $0 + $1.weight }, 1_000, "\(tier)")
            let piece = table.first { $0.drop == .items(.wishingPiece, 1) }?.weight
            let rareEgg = table.first { $0.drop == .items(.rareEgg, 1) }?.weight
            switch tier {
            case .t4, .t5:
                XCTAssertEqual(piece, 50)
                XCTAssertEqual(rareEgg, 400)
            default:
                XCTAssertNil(piece)
            }
            XCTAssertFalse(CompanionStore.victoryExtraOdds(tier).contains { $0.item == .wishingPiece })
            XCTAssertFalse(ExpeditionEngine.itemTable(tier).contains(.wishingPiece))
        }
        XCTAssertFalse((0..<ExplorerKit.rollRange).contains { ExplorerKit.treasure(roll: $0).kind == .wishingPiece })
        XCTAssertNil(ItemKind.wishingPiece.shopPrice)
        XCTAssertFalse(ItemKind.wishingPiece.isPassive)
    }

    /// A team of the fourth tier may steal one; the merchant does not buy it back for now (the owner, 2026-11-25).
    func testTheftAndMerchant() {
        XCTAssertEqual(VillainRules.tier(of: .wishingPiece), .t4)
        XCTAssertFalse(TravellingMerchant.sellable.contains(.wishingPiece))
        XCTAssertNil(TravellingMerchant.buyBackBase(.wishingPiece))
    }
}
