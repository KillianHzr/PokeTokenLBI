import AppKit
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

    /// One day in three, at an hour from 9 to 21, the same on every launch; one team a tier, Team Rocket at the top.
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
        XCTAssertEqual(VillainRules.day("2026-11-10").hour, VillainRules.day("2026-11-10").hour)
        XCTAssertEqual(DungeonTier.allCases.map(VillainTeam.team), [.skull, .magma, .aqua, .galactic, .rocket])
        XCTAssertTrue(VillainTeam.allCases.allSatisfy { VillainTeam.team(for: $0.tier) == $0 })
    }

    /// A day whose team comes, from 2026-11-10 on.
    private func comingDay() throws -> (day: Int, hour: Int) {
        for day in 10...30 {
            let draw = VillainRules.day(String(format: "2026-11-%02d", day))
            if draw.comes { return (day, draw.hour) }
        }
        throw XCTSkip("no team in November")
    }

    private func ambush(_ team: VillainTeam, _ item: ItemKind, count: Int = 1, at: Date) -> VillainAmbush {
        VillainAmbush(id: "x-\(item.rawValue)", team: team, item: item.rawValue, count: count, at: at, seed: 7, grunts: team.grunts.prefix(3).map { $0 })
    }

    /// They come at their hour and take the item as they come (the owner, 2026-11-10: else no one would fight them).
    func testTheyTakeItAsTheyCome() throws {
        let (day, hour) = try comingDay()
        let clock = Clock(try date(day, hour: hour - 1))
        let s = try store(dex: strong, clock: clock) {
            $0.dungeons.wins[DungeonID.viridianForest.rawValue] = 1
            $0.inventory = ["rareCandy": 5]
        }
        s.settleVillainAmbush()
        XCTAssertTrue(s.villainAmbushes.isEmpty, "before their hour")
        clock.date = try date(day, hour: hour)
        s.settleVillainAmbush()
        let theft = try XCTUnwrap(s.villainAmbushes.first)
        XCTAssertEqual(theft.kind, .rareCandy)
        XCTAssertEqual(theft.team, .skull, "a T1 item, Team Skull")
        XCTAssertEqual(theft.count, 3)
        XCTAssertEqual(s.itemCount(.rareCandy), 2, "taken as they came")
        XCTAssertEqual(s.villainStash(.skull)?.items, ["rareCandy": 3])
        XCTAssertTrue(s.isDungeonOpen(.skullHideout), "their hideout opens at once")
        XCTAssertFalse(s.isDungeonOpen(.rocketHideout))
        s.settleVillainAmbush()
        XCTAssertEqual(s.villainAmbushes.count, 1, "once a day")
        // No dungeon won yet: no team comes, and the day is settled.
        let newcomer = try store(dex: strong, clock: clock) { $0.inventory = ["rareCandy": 5] }
        newcomer.settleVillainAmbush()
        XCTAssertTrue(newcomer.villainAmbushes.isEmpty)
        XCTAssertEqual(newcomer.itemCount(.rareCandy), 5)
        XCTAssertEqual(newcomer.dungeonProgress.villainDay, String(format: "2026-11-%02d", day))
    }

    /// "Later" folds the card to a banner; it stays until the theft is settled (the owner, 2026-11-10).
    func testLaterFoldsItNeverDrops() throws {
        let clock = Clock(try date(10, hour: 12))
        let s = try store(dex: strong, clock: clock) {
            $0.dungeons.stashes = [VillainStash(team: .skull, items: ["rareCandy": 3])]
            $0.dungeons.ambushes = [self.ambush(.skull, .rareCandy, count: 3, at: clock.date)]
        }
        let id = try XCTUnwrap(s.villainAmbushes.first?.id)
        s.setVillainAmbushCollapsed(id, true)
        XCTAssertEqual(s.villainAmbushes.first?.collapsed, true)
        s.dismissVillainAmbush(id)
        XCTAssertEqual(s.villainAmbushes.count, 1, "not settled: it stays, folded")
        s.setVillainAmbushCollapsed(id, false)
        XCTAssertNil(s.villainAmbushes.first?.collapsed)
        XCTAssertEqual(s.defendAgainstAmbush(id), true)
        s.dismissVillainAmbush(id)
        XCTAssertTrue(s.villainAmbushes.isEmpty, "settled: it goes")
    }

    /// Thefts add up, ignored or not, each team to its hideout; never two days in a row; none once nothing is left to
    /// take, and a team only for what it is after (no Team Rocket without an achievement's artifact).
    func testTheftsAddUp() throws {
        var days: [(day: Int, hour: Int)] = []
        for day in 10...60 {
            let key = Calendar(identifier: .iso8601).date(byAdding: .day, value: day - 10, to: try date(10, hour: 0))
                .map { DungeonProgress.challengePeriod(.daily, at: $0) } ?? ""
            let draw = VillainRules.day(key)
            if draw.comes { days.append((day - 10, draw.hour)) }
        }
        let clock = Clock(try date(10, hour: 0))
        let s = try store(dex: strong, clock: clock) {
            $0.dungeons.wins[DungeonID.viridianForest.rawValue] = 1
            $0.inventory = ["rareCandy": 2, "leafStone": 1]
        }
        var thefts: [String] = []
        var lastDay: Int?
        for (offset, hour) in days {
            clock.date = try date(10, hour: hour).addingTimeInterval(Double(offset) * 86_400)
            let before = s.villainAmbushes.count
            s.settleVillainAmbush()
            if s.villainAmbushes.count > before {
                if let lastDay { XCTAssertGreaterThan(offset - lastDay, 1, "never two days in a row") }
                lastDay = offset
                thefts.append(s.villainAmbushes[0].item)
            }
        }
        XCTAssertEqual(Set(thefts), ["rareCandy", "leafStone"], "both taken, the first theft never chased")
        XCTAssertEqual(s.itemCount(.rareCandy) + s.itemCount(.leafStone), 0, "nothing left: no one comes any more")
        XCTAssertEqual(Set(s.villainStashes.map(\.team)), [.skull, .magma], "each team to its hideout")
        XCTAssertFalse(s.villainAmbushes.contains { $0.team == .rocket }, "no artifact, no Team Rocket")
    }

    /// The chase lost: the item stays at the hideout, with no key. Won: it comes back and the hideout closes.
    func testTheChase() throws {
        let artifact = achievementArtifact
        let clock = Clock(try date(10, hour: 12))
        let weak = [129, 349, 10].map(graduated)
        func stolen(_ dex: [DexEntry]) throws -> CompanionStore {
            try store(dex: dex, clock: clock) {
                $0.dungeons.stashes = [VillainStash(team: .rocket, items: [artifact.rawValue: 1])]
                $0.dungeons.ambushes = [self.ambush(.rocket, artifact, at: clock.date)]
            }
        }
        let s = try stolen(weak)
        let id = try XCTUnwrap(s.villainAmbushes.first?.id)
        XCTAssertEqual(s.defendAgainstAmbush(id), false, "three Magikarp and kin against Team Rocket's grunts")
        XCTAssertEqual(s.itemCount(artifact), 0)
        XCTAssertEqual(s.villainStash(.rocket)?.items, [artifact.rawValue: 1])
        XCTAssertTrue(s.isDungeonOpen(.rocketHideout))
        XCTAssertEqual(s.keysToEnter(.rocketHideout), 0)
        XCTAssertEqual(s.dungeonInfo(.rocketHideout).tier, .t5)
        XCTAssertEqual(s.dungeonInfo(.rocketHideout).bosses, [150], "Giovanni's Mewtwo")
        XCTAssertNotNil(s.villainAmbushes.first?.battle, "the fight can be watched")
        XCTAssertNil(s.defendAgainstAmbush(id), "chased once")
        // Team Skull's grunts (T1) against Mewtwo, Rayquaza and kin: a chase they win nine times in ten, here with seed 7.
        let caught = try store(dex: strong, clock: clock) {
            $0.inventory = ["rareCandy": 2]
            $0.dungeons.stashes = [VillainStash(team: .skull, items: ["rareCandy": 3])]
            $0.dungeons.ambushes = [self.ambush(.skull, .rareCandy, count: 3, at: clock.date)]
        }
        XCTAssertEqual(caught.defendAgainstAmbush(try XCTUnwrap(caught.villainAmbushes.first?.id)), true)
        XCTAssertEqual(caught.itemCount(.rareCandy), 5, "back in the Bag")
        XCTAssertNil(caught.villainStash(.skull))
        XCTAssertFalse(caught.isDungeonOpen(.skullHideout))
    }

    /// An achievement's artifact taken as they come stays claimed: never claimed twice.
    func testAStolenArtifactStaysClaimed() throws {
        let artifact = achievementArtifact
        let (day, hour) = try comingDay()
        let clock = Clock(try date(day, hour: hour))
        let s = try store(dex: strong, clock: clock) {
            $0.dungeons.wins[DungeonID.viridianForest.rawValue] = 1
            $0.inventory = [artifact.rawValue: 1]
            $0.claimedAchievements = []
        }
        s.settleVillainAmbush()
        XCTAssertEqual(s.villainAmbushes.first?.team, .rocket, "an achievement's artifact, Team Rocket")
        XCTAssertEqual(s.itemCount(artifact), 0)
        XCTAssertTrue(s.isClaimed(artifact))
    }

    /// The hideout's leader beaten gives everything back, settles its team's thefts and closes it; it counts for no
    /// dungeon's wins nor bosses.
    func testTheHideoutGivesItAllBack() throws {
        let clock = Clock(try date(10, hour: 12))
        let s = try store(dex: strong, clock: clock) {
            $0.dungeons.stashes = [VillainStash(team: .rocket, items: ["shinyCharm": 1, "masterBall": 1]),
                                   VillainStash(team: .skull, items: ["rareCandy": 3])]
            $0.dungeons.ambushes = [self.ambush(.rocket, .shinyCharm, at: clock.date)]
        }
        XCTAssertTrue(s.startExpedition(.rocketHideout, team: strong.map(\.id)))
        XCTAssertEqual(s.expedition?.boss.speciesID, 150, "Giovanni's Mewtwo leads")
        XCTAssertEqual(s.expedition?.boss.form, ArmoredMewtwo.form)
        XCTAssertEqual(s.expedition?.floors, DungeonTier.t5.floors)
        XCTAssertNil(s.expedition?.bossReward)
        s.changeDungeons { $0.expedition?.phase = .capture(throwsLeft: 3) }
        s.endCapture()
        XCTAssertEqual(s.itemCount(.shinyCharm), 1)
        XCTAssertEqual(s.itemCount(.masterBall), 1)
        XCTAssertNil(s.villainStash(.rocket))
        XCTAssertNotNil(s.villainStash(.skull), "another team's hideout stays")
        XCTAssertTrue(s.villainAmbushes.isEmpty, "its theft is settled with it")
        XCTAssertFalse(s.isDungeonOpen(.rocketHideout))
        XCTAssertEqual(s.dungeonProgress.lastResult?.recovered, ["shinyCharm": 1, "masterBall": 1])
        XCTAssertEqual(s.dungeonProgress.lastResult?.villain, .rocket)
        XCTAssertEqual(s.dungeonProgress.wins(.rocketHideout), 0)
        XCTAssertTrue(s.dungeonProgress.bossesBeaten.isEmpty, "Giovanni's Mewtwo opens nothing")
    }

    func testTheLeaderComesWithThree() throws {
        var random = BattleRandom(seed: 3)
        let giovanni = VillainRules.leaderSpecs(.rocket, tier: .t5, random: &random)
        XCTAssertEqual(giovanni.map(\.speciesID), [150, 53, 34], "Mewtwo, Persian and Nidoking (the owner)")
        XCTAssertEqual(giovanni.first?.form, ArmoredMewtwo.form, "Team Rocket's armored Mewtwo")
        let plain = try XCTUnwrap(BattlerSpec.make(id: "m", speciesID: 150, level: 100))
        let armored = try XCTUnwrap(BattlerSpec.make(id: "m", speciesID: 150, form: ArmoredMewtwo.form, level: 100))
        XCTAssertEqual(armored.stats, plain.stats, "Mewtwo's own battle data")
        XCTAssertEqual(SpriteStore.spriteURLs(speciesID: 150, animated: true, shiny: false, form: ArmoredMewtwo.form).first?.absoluteString,
                       ArmoredMewtwo.spriteURL)
        XCTAssertTrue(giovanni.allSatisfy(\.isBoss))
        for team in VillainTeam.allCases {
            XCTAssertEqual(VillainRules.leaderSpecs(team, tier: team.tier, random: &random).count, 3, "\(team)")
            XCTAssertTrue(team.grunts.allSatisfy { SpeciesBattleTable.data(speciesID: $0, form: nil) != nil }, "\(team)")
            XCTAssertNotNil(VillainTeam.portraitURLs[team.gruntPortrait])
            XCTAssertNotNil(VillainTeam.portraitURLs[team.leaderPortrait])
        }
    }

    /// Each team's hideout has its own diorama (the owner, 2026-11-10), for its card and the menu bar.
    func testEachHideoutHasItsDiorama() throws {
        var seen: [Data] = []
        for team in VillainTeam.allCases {
            let image = try XCTUnwrap(DungeonSprites.hideoutImage(team), "\(team)")
            XCTAssertNotNil(DungeonSprites.trimmedHideoutImage(team), "\(team)")
            let data = try XCTUnwrap(NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]))
            XCTAssertFalse(seen.contains(data), "\(team) drawn as another")
            seen.append(data)
        }
    }

    func testTheHideoutCountsForNothingElse() throws {
        for tier in DungeonTier.allCases {
            XCTAssertFalse(DungeonMedals.dungeons(tier).contains { $0.isHideout })
        }
        let s = try store(dex: strong, clock: Clock(try date(10, hour: 12))) { $0.dungeons.wins[DungeonID.skullHideout.rawValue] = 3 }
        XCTAssertFalse(s.isMet(.wonTier(.t1)))
        XCTAssertFalse(s.isDungeonOpen(.skullHideout), "no stash, no hideout")
        XCTAssertEqual(VillainTeam.allCases.map { DungeonCatalog.dungeon($0.hideoutID).tier }, DungeonTier.allCases)
    }

    func testTheirWordsInEveryLanguage() {
        for language in AppLanguage.allCases {
            let l = L(language)
            var words = [l.villainAmbushBubble, l.villainTheirPokemon, l.villainDefend, l.villainDefendWith, l.villainLater, l.villainSeeFight,
                         l.villainToHideout, l.villainKeeps, l.villainTakenBack] + VillainTeam.allCases.map { l.dungeonName($0.hideoutID) }
            for team in VillainTeam.allCases {
                words += [l.villainTeamName(team), l.villainLeaderName(team), l.villainAmbushTitle(team),
                          l.villainStoleLine(team, item: "X"), l.villainBeaten(team, item: "X"), l.villainGotAway(team, item: "X"),
                          l.villainHideoutName(team), l.villainWaitsAtTheEnd(team)]
            }
            for text in words {
                XCTAssertFalse(text.isEmpty || text.contains("\u{2014}") || text.contains("\u{2013}"), "\(language): \(text)")
            }
        }
    }
}
