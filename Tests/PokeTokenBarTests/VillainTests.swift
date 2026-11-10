import XCTest
@testable import PokeTokenBar

/// The villains' teams (issue #180, the owner, 2026-11-10): the day's ambush, the defense, the theft, the hideout of
/// the item's tier and its leader's three (Giovanni with Mewtwo and Persian at the top).
@MainActor
final class VillainTests: XCTestCase {
    private final class Clock: @unchecked Sendable { var date: Date; init(_ date: Date) { self.date = date } }

    private func graduated(_ id: Int) -> DexEntry {
        var entry = DexEntry(baseID: SpeciesInfo.baseID(of: id), finalID: id, chainOrder: [id], rarity: .common,
                             caughtAt: Date(timeIntervalSince1970: 1_790_000_000))
        entry.id = "g\(id)"
        return entry
    }

    private func store(dex: [DexEntry], clock: Clock, prepare: (inout CompanionState) -> Void = { _ in }) throws -> CompanionStore {
        var st = CompanionState()
        st.installBaselineSet = true
        st.lastDate = "d"
        st.claimedTodayTokensByProvider = ["test": 0]
        st.dex = dex
        st.active = MonState(baseID: 16, pathIDs: [16, 17, 18], stageIndex: 0, usedAtStage: 0, rarity: .common, totalForms: 3)
        prepare(&st)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("villain-\(UUID().uuidString).json")
        try JSONEncoder().encode(st).write(to: url)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return CompanionStore(provider: StubProvider(value: EvoLine(baseID: 16, tree: EvoNode(speciesID: 16, children: []),
                                                                    rarity: .common, names: [:])),
                              clock: { clock.date }, fileURL: url, rng: SeededRNG(seed: 3), difficulty: 0.1)
    }

    private func date(_ day: Int, hour: Int, month: Int = 11) throws -> Date {
        var parts = DateComponents(year: 2026, month: month, day: day, hour: hour)
        parts.timeZone = .current
        return try XCTUnwrap(Calendar(identifier: .iso8601).date(from: parts))
    }

    private var strong: [DexEntry] { [150, 384, 248, 445, 149, 376].map(graduated) }
    private var achievementArtifact: ItemKind {
        ItemKind.allCases.first { $0.isPassive && $0.isAchievement && !$0.isRegional && $0.moreFormsSpecies == nil }!
    }

    func testWhatTheyGoFor() {
        XCTAssertEqual(VillainRules.tier(of: .rareCandy), .t1)
        XCTAssertEqual(VillainRules.tier(of: .leafStone), .t2)
        XCTAssertEqual(VillainRules.tier(of: .rareEgg), .t3)
        XCTAssertEqual(VillainRules.tier(of: .masterBall), .t4)
        XCTAssertEqual(VillainRules.tier(of: achievementArtifact), .t5, "an achievement's artifact, the big prize")
        XCTAssertNil(VillainRules.tier(of: .boulderBadge), "a badge's steps are counted apart")
        XCTAssertNil(VillainRules.tier(of: .discoveryMedal))
        var random = BattleRandom(seed: 1)
        let target = try? XCTUnwrap(VillainRules.target([.rareCandy: 7, .boulderBadge: 1], random: &random))
        XCTAssertEqual(target?.kind, .rareCandy)
        XCTAssertEqual(target?.count, 3, "up to three of an everyday item")
        XCTAssertNil(VillainRules.target([.boulderBadge: 1], random: &random), "nothing they would take")
    }

    /// One day in three, at an hour from 9 to 21, the same on every launch.
    func testTheDaysDraw() throws {
        let calendar = Calendar(identifier: .iso8601)
        let days = (0..<3000).map { n -> String in
            let c = calendar.dateComponents([.year, .month, .day], from: Date(timeIntervalSince1970: 1_790_000_000 + Double(n) * 86_400))
            return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
        }
        let draws = days.map(VillainRules.day)
        let comes = draws.filter(\.comes).count
        XCTAssertTrue((850...1150).contains(comes), "\(comes) in 3000")
        XCTAssertTrue(draws.allSatisfy { (9...21).contains($0.hour) })
        XCTAssertEqual(Set(draws.map(\.team)).count, VillainTeam.allCases.count)
        XCTAssertEqual(VillainRules.day("2026-11-10").hour, VillainRules.day("2026-11-10").hour)
    }

    /// A day whose team comes, from 2026-11-10 on.
    private func comingDay() throws -> (day: Int, hour: Int) {
        for day in 10...30 {
            let draw = VillainRules.day(String(format: "2026-11-%02d", day))
            if draw.comes { return (day, draw.hour) }
        }
        throw XCTSkip("no team in November")
    }

    func testTheyComeAtTheirHourOnceADay() throws {
        let (day, hour) = try comingDay()
        let clock = Clock(try date(day, hour: hour - 1))
        let s = try store(dex: strong, clock: clock) {
            $0.dungeons.wins[DungeonID.viridianForest.rawValue] = 1
            $0.inventory = ["rareCandy": 5]
        }
        s.settleVillainAmbush()
        XCTAssertNil(s.villainAmbush, "before its hour")
        clock.date = try date(day, hour: hour)
        s.settleVillainAmbush()
        let ambush = try XCTUnwrap(s.villainAmbush)
        XCTAssertEqual(ambush.kind, .rareCandy)
        XCTAssertEqual(ambush.count, 3)
        XCTAssertEqual(ambush.grunts.count, 3)
        XCTAssertNil(ambush.won)
        s.changeDungeons { $0.ambush = nil }
        s.settleVillainAmbush()
        XCTAssertNil(s.villainAmbush, "once a day")
        // No dungeon won yet: no team comes, and the day is settled.
        let newcomer = try store(dex: strong, clock: clock) { $0.inventory = ["rareCandy": 5] }
        newcomer.settleVillainAmbush()
        XCTAssertNil(newcomer.villainAmbush)
        XCTAssertEqual(newcomer.dungeonProgress.villainDay, String(format: "2026-11-%02d", day))
    }

    /// Lost: the item goes to the team's hideout, of its tier, with no key; an achievement's artifact stays claimed.
    func testLosingSendsTheItemToTheHideout() throws {
        let artifact = achievementArtifact
        let clock = Clock(try date(10, hour: 12))
        let weak = [129, 349, 10].map(graduated)
        let s = try store(dex: weak, clock: clock) {
            $0.inventory = [artifact.rawValue: 1]
            $0.dungeons.ambush = VillainAmbush(team: .rocket, item: artifact.rawValue, count: 1, at: clock.date, seed: 7,
                                               grunts: [24, 110, 42])
        }
        XCTAssertEqual(s.defendAgainstAmbush(), false, "three Magikarp and kin against grunts of a T5 theft")
        XCTAssertEqual(s.itemCount(artifact), 0)
        XCTAssertTrue(s.isClaimed(artifact), "never claimed twice")
        let stash = try XCTUnwrap(s.villainStash)
        XCTAssertEqual(stash.items, [artifact.rawValue: 1])
        XCTAssertEqual(stash.tier, .t5)
        XCTAssertTrue(s.isDungeonOpen(.hideout))
        XCTAssertEqual(s.keysToEnter(.hideout), 0)
        XCTAssertEqual(s.dungeonInfo(.hideout).tier, .t5)
        XCTAssertEqual(s.dungeonInfo(.hideout).bosses, [150], "Giovanni's Mewtwo")
        XCTAssertNotNil(s.villainAmbush?.battle, "the fight can be watched")
        XCTAssertNil(s.defendAgainstAmbush(), "fought once")
        s.dismissVillainAmbush()
        XCTAssertNil(s.villainAmbush)
        // While the hideout keeps it, no other team comes.
        let (day, hour) = try comingDay()
        clock.date = try date(day, hour: hour)
        s.changeDungeons { $0.wins[DungeonID.viridianForest.rawValue] = 1 }
        s.settleVillainAmbush()
        XCTAssertNil(s.villainAmbush)
    }

    func testWinningKeepsTheItem() throws {
        let clock = Clock(try date(10, hour: 12))
        let s = try store(dex: strong, clock: clock) {
            $0.inventory = ["rareCandy": 5]
            $0.dungeons.ambush = VillainAmbush(team: .rocket, item: "rareCandy", count: 3, at: clock.date, seed: 7,
                                               grunts: [20, 24, 42])
        }
        XCTAssertEqual(s.defendAgainstAmbush(), true, "Mewtwo, Kyogre and kin against three grunts")
        XCTAssertEqual(s.itemCount(.rareCandy), 5)
        XCTAssertNil(s.villainStash)
        XCTAssertFalse(s.isDungeonOpen(.hideout))
    }

    /// The hideout's leader beaten gives everything back and closes it; it counts for no dungeon's wins nor bosses.
    func testTheHideoutGivesItAllBack() throws {
        let clock = Clock(try date(10, hour: 12))
        let s = try store(dex: strong, clock: clock) {
            $0.dungeons.stash = VillainStash(team: .rocket, items: ["rareCandy": 3, "masterBall": 1], tier: .t4)
        }
        XCTAssertTrue(s.startExpedition(.hideout, team: strong.map(\.id)))
        XCTAssertEqual(s.expedition?.hideout?.tier, .t4)
        XCTAssertEqual(s.expedition?.boss.speciesID, 53, "Persian leads below T5")
        XCTAssertEqual(s.expedition?.floors, DungeonTier.t4.floors)
        XCTAssertNil(s.expedition?.bossReward)
        s.changeDungeons { $0.expedition?.phase = .capture(throwsLeft: 3) }
        s.endCapture()
        XCTAssertEqual(s.itemCount(.rareCandy), 3)
        XCTAssertEqual(s.itemCount(.masterBall), 1)
        XCTAssertNil(s.villainStash)
        XCTAssertFalse(s.isDungeonOpen(.hideout))
        XCTAssertEqual(s.dungeonProgress.lastResult?.recovered, ["rareCandy": 3, "masterBall": 1])
        XCTAssertEqual(s.dungeonProgress.wins(.hideout), 0)
        XCTAssertTrue(s.dungeonProgress.bossesBeaten.isEmpty, "Giovanni's Persian opens nothing")
    }

    func testTheLeaderComesWithThree() {
        var random = BattleRandom(seed: 3)
        let giovanni = VillainRules.leaderSpecs(.rocket, tier: .t5, random: &random)
        XCTAssertEqual(giovanni.map(\.speciesID), [150, 53, 34], "Mewtwo, Persian and Nidoking (the owner)")
        XCTAssertTrue(giovanni.allSatisfy(\.isBoss))
        for team in VillainTeam.allCases {
            for tier in DungeonTier.allCases {
                XCTAssertEqual(VillainRules.leaderSpecs(team, tier: tier, random: &random).count, 3, "\(team) \(tier)")
            }
            XCTAssertTrue(team.grunts.allSatisfy { SpeciesBattleTable.data(speciesID: $0, form: nil) != nil }, "\(team)")
            XCTAssertNotNil(VillainTeam.portraitURLs[team.gruntPortrait])
            XCTAssertNotNil(VillainTeam.portraitURLs[team.leaderPortrait])
        }
    }

    func testTheHideoutCountsForNothingElse() throws {
        for tier in DungeonTier.allCases { XCTAssertFalse(DungeonMedals.dungeons(tier).contains(.hideout)) }
        let s = try store(dex: strong, clock: Clock(try date(10, hour: 12))) { $0.dungeons.wins[DungeonID.hideout.rawValue] = 3 }
        XCTAssertFalse(s.isMet(.wonTier(.t1)))
        XCTAssertFalse(s.isDungeonOpen(.hideout), "no stash, no hideout")
    }

    func testTheirWordsInEveryLanguage() {
        for language in AppLanguage.allCases {
            let l = L(language)
            var words = [l.villainTarget, l.villainTheirPokemon, l.villainDefend, l.villainDefendWith, l.villainSeeFight,
                         l.villainToHideout, l.villainKeeps, l.villainTakenBack, l.dungeonName(.hideout)]
            for team in VillainTeam.allCases {
                words += [l.villainTeamName(team), l.villainLeaderName(team), l.villainAmbushTitle(team),
                          l.villainAmbushLine(team, item: "X"), l.villainBeaten(team), l.villainGotAway(team, item: "X"),
                          l.villainHideoutName(team), l.villainWaitsAtTheEnd(team, tier: .t1),
                          l.villainWaitsAtTheEnd(team, tier: .t5)]
            }
            for text in words {
                XCTAssertFalse(text.isEmpty || text.contains("\u{2014}") || text.contains("\u{2013}"), "\(language): \(text)")
            }
        }
    }
}
