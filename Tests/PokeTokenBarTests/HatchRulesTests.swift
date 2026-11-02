import XCTest
@testable import PokeTokenBar

/// The egg roll's rules by the day an egg was rolled (`HatchRules`), as the What's New dates their changes.
final class HatchRulesTests: XCTestCase {
    private let paris = TimeZone(identifier: "Europe/Paris")!

    private func date(_ text: String, _ timeZone: TimeZone) -> Date {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = timeZone
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.date(from: text)!
    }

    /// Each change dates from its What's New entry, the app's own record of its updates.
    func testEachChangeIsAWhatsNewEntry() {
        for change in HatchRules.Change.allCases {
            XCTAssertTrue(Changelog.ids.contains(change.rawValue), change.rawValue)
        }
    }

    /// An egg rolled on an entry's day has its change, by the player's calendar; one rolled the evening before has not.
    func testAChangeCountsFromItsEntrysDay() {
        XCTAssertEqual(HatchRules(rolledAt: date("2026-10-14 12:00", paris), timeZone: paris).changes, [])
        XCTAssertEqual(HatchRules(rolledAt: date("2026-10-19 23:59", paris), timeZone: paris).changes, [.forms])
        XCTAssertEqual(HatchRules(rolledAt: date("2026-10-20 00:00", paris), timeZone: paris).changes,
                       [.forms, .laterGenerations, .unbreedableLegendariesLikeMewtwo])
        XCTAssertEqual(HatchRules(rolledAt: date("2026-10-27 00:00", paris), timeZone: paris), .current)
        XCTAssertEqual(HatchRules(rolledAt: nil), .current, "a roll of unknown date")
        let tokyo = TimeZone(identifier: "Asia/Tokyo")!
        XCTAssertTrue(HatchRules(rolledAt: date("2026-10-19 23:59", paris), timeZone: tokyo).has(.laterGenerations),
                      "already the 20th in Tokyo")
    }

    /// A line's weight before the collection halves it: its capture rate, then like Mewtwo for a legendary no egg
    /// hatches in the games, then one weight per rarity.
    func testALinesWeightByUpdate() {
        let mew = BaseSpecies(id: 151, captureRate: 45, isUnbreedableLegendary: true)
        let phione = BaseSpecies(id: 489, captureRate: 30, isLegendary: true)
        let pidgey = BaseSpecies(id: 16, captureRate: 255)
        XCTAssertEqual([mew, phione, pidgey].map(HatchRules(changes: []).weight), [45, 30, 255])
        XCTAssertEqual([mew, phione, pidgey].map(HatchRules(changes: [.unbreedableLegendariesLikeMewtwo]).weight),
                       [3, 30, 255])
        XCTAssertEqual([mew, phione, pidgey].map(HatchRules.current.weight), [3, 3, 212])
        let draw = HatchDraw(collection: CompanionState(), items: [], rules: HatchRules(changes: []))
        XCTAssertEqual(draw.hatchWeight(for: mew), 45)
        XCTAssertEqual(draw.hatchWeight(for: pidgey, type: .flying), 255)
    }

    /// Generations 6 to 9 from 20 October, fossils in Fossil Eggs only from the 27th, the line hatched last left out
    /// from the 26th.
    func testThePoolOfEachUpdate() {
        let index = [BaseSpecies(id: 16, captureRate: 255), BaseSpecies(id: 661, captureRate: 255),
                     BaseSpecies(id: 138, captureRate: 45), BaseSpecies(id: 19, captureRate: 255)]
        var collection = CompanionState()
        collection.lastHatchedBaseID = 19
        func pool(_ changes: Set<HatchRules.Change>) -> [Int] {
            HatchDraw(collection: collection, items: [], rules: HatchRules(changes: changes))
                .hatchPool(index, egg: .init()).map(\.base.id)
        }
        XCTAssertEqual(pool([]), [16, 138, 19])
        XCTAssertEqual(pool([.laterGenerations]), [16, 661, 138, 19])
        XCTAssertEqual(pool([.fossilEggsOnly]), [16, 19])
        XCTAssertEqual(pool([.stoneEggDuplicates]), [16, 138])
        XCTAssertEqual(pool(HatchRules.current.changes), [16, 661])
    }

    /// From 26 October a stone's egg lowers a line complete in its type to a quarter; before, to a half like any egg.
    func testAStonesEggQuartersACompleteLineFromItsUpdate() {
        var collection = CompanionState()
        collection.dex = [DexEntry(baseID: 16, finalID: 18, chainOrder: [16, 17, 18], rarity: .common, caughtAt: nil)]
        collection.collectedFinals = ["16:18"]
        let pidgey = BaseSpecies(id: 16, captureRate: 255)
        func weight(_ changes: Set<HatchRules.Change>) -> Int {
            HatchDraw(collection: collection, items: [], rules: HatchRules(changes: changes)).hatchWeight(for: pidgey, type: .flying)
        }
        XCTAssertEqual(weight([.rarityWeights]), 106)
        XCTAssertEqual(weight([.rarityWeights, .stoneEggDuplicates]), 53)
    }

    /// Before 15 October no line hatched in an alternate form.
    func testNoFormBeforeTheFormsCame() {
        XCTAssertFalse(HatchDraw(collection: CompanionState(), items: []).lineFormDraw(baseID: 19, types: []).forms.isEmpty)
        let before = HatchDraw(collection: CompanionState(), items: [], rules: HatchRules(changes: []))
        XCTAssertTrue(before.lineFormDraw(baseID: 19, types: []).forms.isEmpty)
    }

    /// An egg counts from the day of its entry; the Shop's, the stones' and the Type: Null Egg, which no entry brings,
    /// always.
    func testAnEggCountsFromItsEntrysDay() {
        let always: [HatchEgg] = [.tier(nil), .tier(.rare), .stone(.fire), .typeNull]
        let eggs = always + [.legendary, .birthday, .fossil, .event(.halloween, key: nil)]
        XCTAssertEqual(eggs.filter(HatchRules(changes: []).allows), always)
        XCTAssertEqual(eggs.filter(HatchRules.current.allows), eggs)
        let arrivals: [(HatchRules.Change, HatchEgg)] = [(.legendaryEgg, .legendary), (.birthdayEgg, .birthday),
                                                         (.fossilEgg, .fossil), (.eventEggs, .event(.halloween, key: nil))]
        for (change, egg) in arrivals {
            XCTAssertEqual(eggs.filter(HatchRules(changes: [change]).allows), always + [egg], change.rawValue)
        }
    }

    /// The egg menu of a hatch only offers the eggs there were the day it was rolled: no Fossil Egg before the dig.
    func testAnEggThatDidNotExistYetIsNotOffered() throws {
        func at(_ day: String) -> Date { ISO8601DateFormatter().date(from: day + "T12:00:00Z")! }
        let index = [BaseSpecies(id: 16, captureRate: 255), BaseSpecies(id: 140, captureRate: 45)]
        let entries = [DexEntry(baseID: 16, finalID: 16, chainOrder: [16], rarity: .common, caughtAt: at("2026-10-21"),
                                releasedAt: at("2026-10-21")),
                       DexEntry(baseID: 140, finalID: 140, chainOrder: [140], rarity: .rare, caughtAt: at("2026-10-22"))]
        let kabuto = try XCTUnwrap(HatchLuck(entries: entries, includesActive: false, today: CompanionState(), index: index,
                                             now: at("2026-10-23")).hatches.last)
        XCTAssertTrue(kabuto.asksEgg)
        XCTAssertTrue(kabuto.possibleEggs.contains(.tier(nil)))
        XCTAssertFalse(kabuto.possibleEggs.contains(.fossil))
    }

    /// The Luck screen replays an egg with the rules of the day it was rolled: the day the Pokémon before it left, or
    /// its own for the first.
    func testAnEggIsReplayedWithTheRulesOfTheDayItWasRolled() throws {
        let index = [BaseSpecies(id: 16, captureRate: 255), BaseSpecies(id: 661, captureRate: 255)]
        func at(_ day: String) -> Date { ISO8601DateFormatter().date(from: day + "T12:00:00Z")! }
        func entry(_ base: Int, _ day: String) -> DexEntry {
            DexEntry(baseID: base, finalID: base, chainOrder: [base], rarity: .common, caughtAt: at(day))
        }
        let l = HatchLuck(entries: [entry(16, "2026-10-19"), entry(16, "2026-10-21"), entry(661, "2026-10-22")],
                          includesActive: false, today: CompanionState(), index: index, now: at("2026-10-23"))
        XCTAssertEqual(l.hatches[0].lineOdds, 1, "the first, of the 19th: no Generation 6 yet")
        XCTAssertEqual(l.hatches[1].lineOdds, 1, "rolled on the 19th")
        XCTAssertEqual(try XCTUnwrap(l.hatches[2].lineOdds), 0.5, accuracy: 1e-12, "rolled on the 21st")
    }
}
