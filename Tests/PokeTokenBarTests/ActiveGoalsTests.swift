import AppKit
import SwiftUI
import XCTest
@testable import PokeTokenBar

private struct NoLines: PokeProviding {
    func line(baseSpeciesID: Int) async throws -> EvoLine { throw URLError(.notConnectedToInternet) }
    func baseSpeciesIndex() async throws -> [BaseSpecies] { [] }
    func baseSpecies(id: Int) async throws -> BaseSpecies? { nil }
}

/// What graduating the Pokémon raised would advance (6.1): helps to choose whether to keep it or send it off.
@MainActor
final class ActiveGoalsTests: XCTestCase {
    private func store(active: MonState, dex: [DexEntry] = []) throws -> CompanionStore {
        var state = CompanionState()
        state.installBaselineSet = true
        state.active = active
        state.dex = dex
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("goals-\(UUID().uuidString).json")
        try JSONEncoder().encode(state).write(to: url)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return CompanionStore(provider: NoLines(), fileURL: url)
    }

    private let larvitar = MonState(baseID: 246, pathIDs: [246], plannedPathIDs: [246, 247, 248], stageIndex: 0,
                                    usedAtStage: 0, rarity: .rare, totalForms: 3)

    /// A Larvitar adds three Rock species to the next dig, and to Johto's Rock badge and Legendary Egg.
    func testALarvitarCountsForTheDigTheRockBadgeAndJohto() throws {
        let s = try store(active: larvitar)
        let goals = s.activeGoals
        let dig = try XCTUnwrap(goals.first { $0.item == .excavation })
        XCTAssertEqual(dig.gain, 3)
        XCTAssertEqual(dig.needed, FossilDig.rockPerDig)
        let rockBadge = try XCTUnwrap(ItemKind.allCases.first { $0.badgeType == .rock })
        XCTAssertTrue(goals.contains { $0.item == rockBadge && $0.generation == 2 && $0.gain == 3 })
        XCTAssertTrue(goals.contains { $0.item == .legendaryEgg && $0.generation == 2 })
        XCTAssertEqual(goals.map(\.gain), goals.map(\.gain).sorted(by: >), "the most species first")
        let sentence = try XCTUnwrap(ActiveGoalsList.sentence(s))
        XCTAssertTrue(sentence.contains("+3"))
    }

    /// [Regression] Graduated, an Eevee keeps one branch: it counted Vaporeon, Jolteon and Flareon at once, "+4" for
    /// Kanto's Legendary Egg where it brings 2. The branch that advances a goal most counts.
    func testABranchedLineCountsOneBranch() throws {
        let eevee = MonState(baseID: 133, pathIDs: [133], plannedPathIDs: [133, 134], stageIndex: 0, usedAtStage: 0,
                             rarity: .uncommon, totalForms: 2)
        let s = try store(active: eevee)
        let kanto = try XCTUnwrap(s.activeGoals.first { $0.item == .legendaryEgg && $0.generation == 1 })
        XCTAssertEqual(kanto.gain, 2, "Eevee and one of its Kanto evolutions")
        let water = try XCTUnwrap(ItemKind.allCases.first { $0.badgeType == .water })
        XCTAssertEqual(s.activeGoals.first { $0.item == water && $0.generation == 1 }?.gain, 1, "Vaporeon")
    }

    /// Home lists every goal on a row of its own, however many (the owner, 2026-11-03: all of them, "même si l'encadré
    /// fait 89000px de haut"): the list grows by at least an icon's height per goal, where it used to show three and
    /// fold the others into one caption line.
    func testHomeListsEveryGoalOnItsOwnRow() throws {
        let s = try store(active: larvitar)
        let goals = s.activeGoals
        XCTAssertGreaterThan(goals.count, 4, "enough goals that three rows and a caption would be shorter")
        let width = PopoverMetrics.contentWidth - 2 * Design.cardPadding
        let host = NSHostingView(rootView: ActiveGoalsList(store: s).frame(width: width))
        host.layoutSubtreeIfNeeded()
        let rows = CGFloat(goals.count) * 16 + CGFloat(goals.count - 1) * 4
        XCTAssertGreaterThanOrEqual(host.fittingSize.height, rows, "\(goals.count) goals in \(host.fittingSize.height) pt")
    }

    /// Nothing new, nothing shown: its line graduated already.
    func testADuplicateCountsForNothing() throws {
        let had = DexEntry(baseID: 246, finalID: 248, chainOrder: [246, 247, 248], rarity: .rare, caughtAt: nil)
        let s = try store(active: larvitar, dex: [had])
        XCTAssertEqual(s.activeGoals, [])
        XCTAssertNil(ActiveGoalsList.sentence(s))
    }
}

/// How a missing species comes (7.5), on hovering its silhouette.
@MainActor
final class HowToGetTests: XCTestCase {
    func testTheSourceOfAMissingSpecies() {
        XCTAssertEqual(CompanionStore.source(of: 6), .evolves(from: 5, base: 4))
        XCTAssertEqual(CompanionStore.source(of: 138), .fossil)
        XCTAssertEqual(CompanionStore.source(of: 144), .legendary)
        XCTAssertEqual(CompanionStore.source(of: 151), .mythical)
        XCTAssertEqual(CompanionStore.source(of: 1), .egg)
        XCTAssertEqual(CompanionStore.source(of: 791), .evolves(from: 790, base: 789), "Solgaleo from Cosmoem")
    }

    func testTheTipNamesOnlyWhatIsOwnedAndTheGoals() {
        let l = L(.en)
        let goal = CompanionStore.ActiveGoal(item: .legendaryEgg, generation: 1, gain: 1, count: 140, needed: 151)
        let tip = l.dexHowToGet(6, source: .evolves(from: 5, base: 4), name: { $0 == 5 ? "Charmeleon (#5)" : "#\($0)" },
                                goals: [goal], nextDig: nil)
        XCTAssertEqual(tip.components(separatedBy: "\n").first, "#6 · evolves from Charmeleon (#5)")
        XCTAssertTrue(tip.contains("140/151"))
        let fossil = l.dexHowToGet(138, source: .fossil, name: { "#\($0)" }, goals: [], nextDig: (2, 4))
        XCTAssertTrue(fossil.contains("(2/4)"))
        XCTAssertEqual(fossil.components(separatedBy: "\n").count, 2, "no goal, no goal line")
    }
}

/// The events' calendar (7.6): what is on, what comes, what was taken, and what each egg taken hatched.
@MainActor
final class EventCalendarTests: XCTestCase {
    private let utc: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = .current
        return c
    }()

    func testTheCalendarSaysWhatIsOnWhatComesAndWhatWasTaken() throws {
        let now = utc.date(from: DateComponents(year: 2026, month: 10, day: 29, hour: 12))!
        var state = CompanionState()
        state.installBaselineSet = true
        state.claimedEventEggs = ["autumn@2026", "pokemonDay@2026"]
        state.eventEggHatches = ["autumn@2026": 92]
        state.dex = [DexEntry(baseID: 92, finalID: 94, chainOrder: [92, 93, 94], rarity: .uncommon,
                              caughtAt: utc.date(from: DateComponents(year: 2026, month: 3, day: 1)))]
        state.birthday = Birthday(month: 1, day: 14)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("calendar-\(UUID().uuidString).json")
        try JSONEncoder().encode(state).write(to: url)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        let s = CompanionStore(provider: StubProvider(value: EvoLine(baseID: 1, tree: EvoNode(speciesID: 1, children: []),
                                                                      rarity: .common, names: [:])),
                               clock: { now }, fileURL: url)
        let calendar = s.eventCalendar()
        XCTAssertTrue(calendar.now.contains { $0.source == .event(.halloween) && $0.status == .toTake })
        XCTAssertTrue(calendar.now.contains { $0.source == .event(.autumn) && $0.status == .taken(hatched: 92) })
        XCTAssertEqual(calendar.upcoming.first?.source, .event(.christmas), "the next event first")
        XCTAssertTrue(calendar.upcoming.contains { $0.source == .birthday })
        XCTAssertEqual(calendar.upcoming.filter { $0.source == .event(.winter) }.count, 1, "within a year, once")
        XCTAssertTrue(calendar.taken.contains { $0.source == .event(.pokemonDay) && $0.year == 2026 })
        XCTAssertFalse(calendar.taken.contains { $0.source == .event(.autumn) }, "on now, not in the past ones")
    }
}

/// The Stats split by model and what the cache saved (7.3), net of what writing it cost more.
final class StatsByModelTests: XCTestCase {
    func testTheSplitByModelAndTheNetCacheSavings() throws {
        let day = DailyUsage(date: "2026-10-28", inputTokens: 0, outputTokens: 0, cacheCreationTokens: 0,
                             cacheReadTokens: 0, totalTokens: 1_100_000, totalCost: 0,
                             modelUsage: ["claude-sonnet-5": ModelUsage(input: 0, output: 0, cacheWrite: 100_000,
                                                                          cacheRead: 1_000_000, cost: 1),
                                          "unknown-model": ModelUsage(input: 5, output: 0, cacheWrite: 0, cacheRead: 0,
                                                                      cost: nil)])
        let split = StatsReport.modelSplit([day])
        XCTAssertEqual(split.models.map(\.id), ["claude-sonnet-5", "unknown-model"])
        XCTAssertNil(split.models[1].cost)
        let rate = ModelPricing.rate(for: "claude-sonnet-5")
        XCTAssertGreaterThan(rate.input, 0, "a priced model")
        let expected = 1_000_000 * (rate.input - rate.cacheRead) - 100_000 * max(0, rate.cacheWrite - rate.input)
        XCTAssertEqual(try XCTUnwrap(split.savings), expected, accuracy: 0.000_001)

        let unsplit = DailyUsage(date: "2026-10-29", inputTokens: 10, outputTokens: 0, cacheCreationTokens: 0,
                                 cacheReadTokens: 0, totalTokens: 10, totalCost: 0)
        XCTAssertTrue(StatsReport.modelSplit([day, unsplit]).models.isEmpty, "a day without the split: none")
    }
}
