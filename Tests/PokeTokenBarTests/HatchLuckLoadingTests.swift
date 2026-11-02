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

    private func store(provider: any PokeProviding = RosterProvider(), clock: Clock) throws -> CompanionStore {
        var st = CompanionState()
        st.installBaselineSet = true
        st.lastDate = "2026-10-20"
        st.dex = [DexEntry(baseID: 16, finalID: 18, chainOrder: [16, 17, 18], rarity: .common,
                           caughtAt: clock.now.addingTimeInterval(-9 * 86_400)),
                  DexEntry(baseID: 10, finalID: 12, chainOrder: [10, 11, 12], rarity: .common,
                           caughtAt: clock.now.addingTimeInterval(-2 * 86_400))]
        st.active = MonState(baseID: 37, pathIDs: [37], plannedPathIDs: [37, 38], stageIndex: 0, usedAtStage: 0,
                             rarity: .uncommon, totalForms: 1, nature: .hardy)
        st.inventory[ItemKind.pokemonEgg.rawValue] = 1
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
