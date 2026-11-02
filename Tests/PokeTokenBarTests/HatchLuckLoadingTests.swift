import XCTest
@testable import PokeTokenBar

/// The Luck screen's replay as the store keeps it (`CompanionStore.loadHatchLuck`): nothing before the species index,
/// worked out once while the Pokédex stays the same.
@MainActor
final class HatchLuckLoadingTests: XCTestCase {
    private final class Clock: @unchecked Sendable {
        var now = Date(timeIntervalSince1970: 1_790_000_000)
    }

    private struct NoIndexProvider: PokeProviding {
        func line(baseSpeciesID: Int) async throws -> EvoLine { try await RosterProvider().line(baseSpeciesID: baseSpeciesID) }
        func baseSpeciesIndex() async throws -> [BaseSpecies] { [] }
        func baseSpecies(id: Int) async throws -> BaseSpecies? { nil }
    }

    /// An index that arrives when the test lets it.
    private final class GatedProvider: PokeProviding, @unchecked Sendable {
        let gate = AsyncStream<Void>.makeStream()
        func line(baseSpeciesID: Int) async throws -> EvoLine { try await RosterProvider().line(baseSpeciesID: baseSpeciesID) }
        func baseSpeciesIndex() async throws -> [BaseSpecies] {
            for await _ in gate.stream { break }
            return RosterProvider.entries
        }
        func baseSpecies(id: Int) async throws -> BaseSpecies? { nil }
    }

    private func store(provider: any PokeProviding = RosterProvider(), clock: Clock,
                       items: [ItemKind] = [], dex: [DexEntry]? = nil) throws -> CompanionStore {
        var st = CompanionState()
        st.installBaselineSet = true
        st.lastDate = "2026-10-20"
        st.dex = [DexEntry(baseID: 16, finalID: 18, chainOrder: [16, 17, 18], rarity: .common,
                           caughtAt: clock.now.addingTimeInterval(-9 * 86_400)),
                  DexEntry(baseID: 10, finalID: 12, chainOrder: [10, 11, 12], rarity: .common,
                           caughtAt: clock.now.addingTimeInterval(-2 * 86_400))]
        if let dex { st.dex = dex }
        st.active = MonState(baseID: 37, pathIDs: [37], plannedPathIDs: [37, 38], stageIndex: 0, usedAtStage: 0,
                             rarity: .uncommon, totalForms: 1, nature: .hardy)
        st.inventory[ItemKind.pokemonEgg.rawValue] = 1
        for item in items { st.inventory[item.rawValue] = 1 }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("hatch-luck-\(UUID().uuidString).json")
        try JSONEncoder().encode(st).write(to: url)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return CompanionStore(provider: provider, clock: { clock.now }, fileURL: url, rng: SeededRNG(seed: 1),
                              difficulty: 1, writer: nil)
    }

    func testNothingBeforeTheSpeciesIndex() async throws {
        let s = try store(provider: NoIndexProvider(), clock: Clock())
        await s.loadHatchLuck()
        XCTAssertNil(s.hatchLuck)
    }

    /// A Pokédex that changed while it was replayed is not kept: the screen asks again for the new one.
    func testAReplayOfAPokedexThatChangedMeanwhileIsDropped() async throws {
        let provider = GatedProvider()
        let s = try store(provider: provider, clock: Clock())
        let load = Task { await s.loadHatchLuck() }
        for _ in 0..<20 { await Task.yield() }
        XCTAssertTrue(s.useBagEgg(.pokemonEgg))
        provider.gate.continuation.yield()
        await load.value
        XCTAssertNil(s.hatchLuck)
        await s.loadHatchLuck()
        XCTAssertEqual(s.hatchLuck?.hatches.last?.isActive, false)
    }

    /// Every player had the Shiny Charm once Shop prices could go down to 10% (PokeTokenBar v2.5.4, 12 September
    /// 2026): it counts for the eggs started from then.
    func testTheShinyCharmCountsFromTheTenPercentShop() async throws {
        let clock = Clock()
        XCTAssertNil(try store(clock: clock).drawItemSince(.shinyCharm), "not owned")
        let s = try store(clock: clock, items: [.shinyCharm])
        XCTAssertEqual(CompanionStore.shinyCharmForEveryone, ISO8601DateFormatter().date(from: "2026-09-12T14:23:56Z"))
        XCTAssertEqual(s.drawItemSince(.shinyCharm), CompanionStore.shinyCharmForEveryone)
        await s.loadHatchLuck()
        let hatches = try XCTUnwrap(s.hatchLuck?.hatches)
        XCTAssertEqual(try XCTUnwrap(hatches[1].judged[.shiny]?.odds), 1.0 / 64, accuracy: 1e-12,
                       "started ten minutes before the release")
        XCTAssertEqual(try XCTUnwrap(hatches[2].judged[.shiny]?.odds), 1.0 / 48, accuracy: 1e-12)
    }

    /// An achievement's draw item is owned from the What's New day of the update that brought it, or from the
    /// graduation that met its condition when later: never a date to ask the player.
    func testADrawItemCountsFromItsUpdateOrFromTheGraduationThatEarnedIt() throws {
        func at(_ text: String) -> Date {
            let f = DateFormatter()
            f.locale = Locale(identifier: "en_US_POSIX")
            f.dateFormat = "yyyy-MM-dd HH:mm"
            return f.date(from: text)!
        }
        func legendary(_ id: Int, _ day: String, released: Bool = false) -> DexEntry {
            DexEntry(baseID: id, finalID: id, chainOrder: [id], rarity: .legendary, caughtAt: at(day),
                     releasedAt: released ? at(day) : nil)
        }
        let clock = Clock()
        func since(_ item: ItemKind, _ dex: [DexEntry]) throws -> Date? {
            try store(clock: clock, items: [item], dex: dex).drawItemSince(item)
        }
        let flute = [legendary(144, "2026-10-24 09:00"), legendary(145, "2026-10-25 10:00"),
                     legendary(144, "2026-10-27 11:00"), legendary(144, "2026-10-29 12:00")]
        XCTAssertEqual(try since(.legendCharm, flute), at("2026-10-27 11:00"), "the second Articuno")
        XCTAssertNil(try store(clock: clock, dex: flute).drawItemSince(.legendCharm), "not owned")
        XCTAssertEqual(try since(.legendCharm, [legendary(144, "2026-10-02 09:00"), legendary(144, "2026-10-03 09:00")]),
                       at("2026-10-20 00:00"), "earned before the update that brought it")
        XCTAssertEqual(try since(.legendCharm, [legendary(144, "2026-10-24 09:00"), legendary(144, "2026-10-26 09:00", released: true),
                                                legendary(144, "2026-10-28 09:00")]),
                       at("2026-10-28 09:00"), "a released copy was never raised to the end")
        let forces = [legendary(641, "2026-10-22 09:00"), legendary(905, "2026-10-23 09:00"),
                      legendary(645, "2026-10-24 09:00"), legendary(642, "2026-10-25 09:00")]
        XCTAssertEqual(try since(.revealGlass, forces), at("2026-10-24 09:00"), "three Forces of Nature")
        XCTAssertEqual(try since(.revealGlass, [legendary(641, "2026-10-02 09:00"), legendary(642, "2026-10-03 09:00"),
                                                legendary(645, "2026-10-04 09:00")]), at("2026-10-20 00:00"))
        XCTAssertEqual(try since(.ovalCharm, forces), at("2026-10-21 00:00"),
                       "owned, from a Pokédex smaller than today's")
        XCTAssertEqual(try since(.glimmeringCharm, forces), at("2026-10-21 00:00"))
        let everySpecies = PokemonAssets.animatedSpeciesIDs.sorted().enumerated().map { i, id in
            DexEntry(baseID: id, finalID: id, chainOrder: [id], rarity: .common,
                     caughtAt: at("2026-10-22 09:00").addingTimeInterval(Double(i) * 60))
        }
        XCTAssertEqual(try since(.ovalCharm, everySpecies), everySpecies.last?.caughtAt, "the last species")
    }

    func testTheReplayIsKeptWhileThePokedexStaysTheSame() async throws {
        let clock = Clock()
        let s = try store(clock: clock)
        await s.loadHatchLuck()
        let first = try XCTUnwrap(s.hatchLuck)
        XCTAssertEqual(first.hatches.count, 3)
        XCTAssertEqual(first.hatches.last?.isActive, true, "the Pokémon raised counts as the last hatch")
        let pace = try XCTUnwrap(first.hatchesPerWeek)

        clock.now = clock.now.addingTimeInterval(7 * 86_400)
        await s.loadHatchLuck()
        XCTAssertEqual(s.hatchLuck?.hatchesPerWeek, pace, "not worked out again")

        XCTAssertTrue(s.useBagEgg(.pokemonEgg))
        await s.loadHatchLuck()
        XCTAssertEqual(s.hatchLuck?.hatches.count, 3)
        XCTAssertEqual(s.hatchLuck?.hatches.last?.isActive, false, "the Pokédex changed: worked out again")
        XCTAssertNotEqual(s.hatchLuck?.hatchesPerWeek, pace)
    }
}
