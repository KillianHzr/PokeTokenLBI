import XCTest
@testable import PokeTokenBar

/// A Battle Form is fought by its Wearer: a graduated, unreleased Pokémon whose final species is the form's.
@MainActor
final class WearerTests: XCTestCase {
    private final class Clock: @unchecked Sendable { var date: Date; init(_ date: Date) { self.date = date } }

    private func wednesday() throws -> Date {
        var parts = DateComponents(year: 2026, month: 11, day: 11, hour: 12)
        parts.timeZone = .current
        return try XCTUnwrap(Calendar(identifier: .iso8601).date(from: parts))
    }

    private func graduated(_ final: Int, chain: [Int]? = nil, released: Bool = false) -> DexEntry {
        let order = chain ?? [final]
        var entry = DexEntry(baseID: order[0], finalID: final, chainOrder: order, rarity: .common, caughtAt: Date(timeIntervalSince1970: 0))
        entry.id = "e\(final)"
        if released { entry.releasedAt = Date(timeIntervalSince1970: 1) }
        return entry
    }

    private var florges: DexEntry { graduated(671, chain: [669, 670, 671]) }
    private var megaFloette: BattleForm { BattleForms.daily.first { $0.speciesID == 670 }! }
    private var megaCharizardX: BattleForm { BattleForms.daily.first { $0.speciesID == 6 && $0.form.rawValue.hasSuffix("x") }! }

    private func store(dex: [DexEntry], clock: Clock, prepare: (inout CompanionState) -> Void = { _ in }) throws -> CompanionStore {
        var st = CompanionState()
        st.installBaselineSet = true
        st.lastDate = "d"
        st.claimedTodayTokensByProvider = ["test": 0]
        st.dex = dex
        st.active = MonState(baseID: 16, pathIDs: [16, 17, 18], stageIndex: 0, usedAtStage: 0, rarity: .common, totalForms: 3)
        st.dungeons.wins[DungeonID.victoryRoad.rawValue] = 1
        st.dungeons.wins[DungeonID.seafoamIslands.rawValue] = 1
        st.dungeons.villainDay = DungeonProgress.challengePeriod(.daily, at: clock.date)
        prepare(&st)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("wearer-\(UUID().uuidString).json")
        try JSONEncoder().encode(st).write(to: url)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return CompanionStore(provider: StubProvider(value: EvoLine(baseID: 16, tree: EvoNode(speciesID: 16, children: []),
                                                                    rarity: .common, names: [:])),
                              clock: { clock.date }, fileURL: url, rng: SeededRNG(seed: 3), difficulty: 0.1)
    }

    func testOnlyFlorgesNeverDrawMegaFloetteButACharizardDrawsMegaCharizardX() throws {
        let clock = Clock(try wednesday())
        let onlyFlorges = try store(dex: [florges], clock: clock)
        XCTAssertFalse(onlyFlorges.challengeCandidates(.daily).contains(megaFloette))
        let charizard = try store(dex: [graduated(6, chain: [4, 5, 6])], clock: clock)
        XCTAssertTrue(charizard.challengeCandidates(.daily).contains(megaCharizardX))
        XCTAssertFalse(charizard.challengeCandidates(.daily).contains(megaFloette))
    }

    func testAReleasedPokemonIsNoWearer() throws {
        let s = try store(dex: [graduated(6, chain: [4, 5, 6], released: true)], clock: Clock(try wednesday()))
        XCTAssertTrue(s.challengeCandidates(.daily).isEmpty)
    }

    func testADrawnBossWithoutWearerIsReplaced() throws {
        let clock = Clock(try wednesday())
        let s = try store(dex: [florges, graduated(6, chain: [4, 5, 6])], clock: clock) {
            $0.dungeons.challengeDraws[DungeonProgress.challengeKey(.daily, at: clock.date)] = self.megaFloette.key
        }
        XCTAssertNotEqual(s.challengeBoss(.daily), megaFloette)
        XCTAssertNotNil(s.challengeBoss(.daily))
        s.settleChallengeBosses()
        XCTAssertNotEqual(s.dungeonProgress.challengeDraws[DungeonProgress.challengeKey(.daily, at: clock.date)], megaFloette.key)
    }

    func testABossBeatenInThePeriodStaysShownWonWithoutWearer() throws {
        let clock = Clock(try wednesday())
        let key = DungeonProgress.challengeKey(.daily, at: clock.date)
        let s = try store(dex: [florges], clock: clock) {
            $0.dungeons.challengeWins[key] = self.megaFloette.key
            $0.dungeons.battleForms.insert(self.megaFloette.key)
        }
        XCTAssertEqual(s.challengeBoss(.daily), megaFloette)
        s.settleChallengeBosses()
        XCTAssertEqual(s.challengeBoss(.daily), megaFloette)
    }

    func testChenNeverOffersAChallengeWhoseBossHasNoWearer() throws {
        let clock = Clock(try wednesday())
        let rest = BattleForms.daily.filter { $0.speciesID != 670 }.map(\.key)
        let s = try store(dex: [florges], clock: clock) { $0.dungeons.battleForms.formUnion(rest) }
        XCTAssertNil(s.challengeBoss(.daily))
        XCTAssertNotEqual(s.oakDungeon?.reason, .challenge)
        XCTAssertNotEqual(s.oakDungeon?.id, .daily)
    }

    func testChensHallPlanSkipsAFormNoWearerCanFight() throws {
        let s = try store(dex: [florges, graduated(6, chain: [4, 5, 6])], clock: Clock(try wednesday())) {
            $0.dungeons.battleForms = [self.megaFloette.key]
        }
        XCTAssertNil(s.oakHallForms)
    }

    func testTheTeamScreenOffersOnlyWhatTheEntryWears() throws {
        let s = try store(dex: [florges, graduated(6, chain: [4, 5, 6], released: true)], clock: Clock(try wednesday())) {
            $0.dungeons.battleForms = [self.megaFloette.key, self.megaCharizardX.key]
        }
        XCTAssertTrue(s.wonBattleForms(for: florges).isEmpty)
        XCTAssertTrue(s.wonBattleForms(for: graduated(6, released: true)).isEmpty)
        XCTAssertFalse(s.setBattleForm(megaFloette, for: florges.id))
        XCTAssertFalse(s.matches(florges, .megaOrPrimal))
    }

    func testAWearerFightsItsForm() throws {
        let charizard = graduated(6, chain: [4, 5, 6])
        let s = try store(dex: [charizard], clock: Clock(try wednesday())) { $0.dungeons.battleForms = [self.megaCharizardX.key] }
        XCTAssertTrue(s.wears(charizard, megaCharizardX))
        XCTAssertTrue(s.hasWearer(megaCharizardX))
        XCTAssertEqual(s.wonBattleForms(for: charizard), [megaCharizardX])
        XCTAssertTrue(s.setBattleForm(megaCharizardX, for: charizard.id))
        XCTAssertEqual(s.battleFormChoice(for: charizard), megaCharizardX)
        XCTAssertTrue(s.matches(charizard, .megaOrPrimal))
    }
}
