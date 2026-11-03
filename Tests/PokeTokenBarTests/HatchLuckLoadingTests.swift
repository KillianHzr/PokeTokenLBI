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
                       items: [ItemKind] = [], dex: [DexEntry]? = nil, active: MonState? = nil) throws -> CompanionStore {
        var st = CompanionState()
        st.installBaselineSet = true
        st.lastDate = "2026-10-20"
        st.dex = [DexEntry(baseID: 16, finalID: 18, chainOrder: [16, 17, 18], rarity: .common,
                           caughtAt: clock.now.addingTimeInterval(-9 * 86_400)),
                  DexEntry(baseID: 10, finalID: 12, chainOrder: [10, 11, 12], rarity: .common,
                           caughtAt: clock.now.addingTimeInterval(-2 * 86_400))]
        if let dex { st.dex = dex }
        st.active = active ?? MonState(baseID: 37, pathIDs: [37], plannedPathIDs: [37, 38], stageIndex: 0, usedAtStage: 0,
                                       rarity: .uncommon, totalForms: 1, nature: .hardy)
        st.inventory[ItemKind.pokemonEgg.rawValue] = 1
        for item in items { st.inventory[item.rawValue] = 1 }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("hatch-luck-\(UUID().uuidString).json")
        try JSONEncoder().encode(st).write(to: url)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return CompanionStore(provider: provider, clock: { clock.now }, fileURL: url, rng: SeededRNG(seed: 1),
                              difficulty: 1, writer: nil)
    }

    func testTheReplayKeepsTheDatesOfTheDrawItems() async throws {
        let s = try store(clock: Clock(), items: [.shinyCharm])
        await s.loadHatchLuck()
        XCTAssertEqual(s.hatchLuck?.itemsSince, [.shinyCharm: CompanionStore.shinyCharmForEveryone])
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
        XCTAssertEqual(try store(clock: clock, items: [.clearBell]).luckInputs.drawItems, [.clearBell], "weighed for a while")
        let s = try store(clock: clock, items: [.shinyCharm])
        XCTAssertEqual(CompanionStore.shinyCharmForEveryone, ISO8601DateFormatter().date(from: "2026-09-12T14:23:56Z"))
        XCTAssertEqual(s.drawItemSince(.shinyCharm), CompanionStore.shinyCharmForEveryone)
        await s.loadHatchLuck()
        let hatches = try XCTUnwrap(s.hatchLuck?.hatches)
        XCTAssertEqual(try XCTUnwrap(hatches[1].judged[.shiny]?.odds), 1.0 / 64, accuracy: 1e-12,
                       "started ten minutes before the release")
        XCTAssertEqual(try XCTUnwrap(hatches[2].judged[.shiny]?.odds), 1.0 / 48, accuracy: 1e-12)
    }

    /// An achievement's draw item is owned from the publication of the update that brought it, or from the
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
                       HatchRules.Change.collectorItems.publishedAt, "earned before the update that brought it")
        XCTAssertEqual(try since(.legendCharm, [legendary(144, "2026-10-24 09:00"), legendary(144, "2026-10-26 09:00", released: true),
                                                legendary(144, "2026-10-28 09:00")]),
                       at("2026-10-28 09:00"), "a released copy was never raised to the end")
        let forces = [legendary(641, "2026-10-22 09:00"), legendary(905, "2026-10-23 09:00"),
                      legendary(645, "2026-10-24 09:00"), legendary(642, "2026-10-25 09:00")]
        XCTAssertEqual(try since(.revealGlass, forces), at("2026-10-23 09:00"), "the third Force of Nature hatched")
        XCTAssertEqual(try since(.revealGlass, [legendary(641, "2026-10-02 09:00"), legendary(642, "2026-10-03 09:00"),
                                                legendary(645, "2026-10-04 09:00")]), HatchRules.Change.collectorItems.publishedAt)
        XCTAssertEqual(try since(.ovalCharm, forces), HatchRules.Change.charms.publishedAt,
                       "owned, from a Pokédex smaller than today's")
        XCTAssertEqual(try since(.glimmeringCharm, forces), HatchRules.Change.charms.publishedAt)
        let everySpecies = PokemonAssets.animatedSpeciesIDs.sorted().enumerated().map { i, id in
            DexEntry(baseID: id, finalID: id, chainOrder: [id], rarity: .common,
                     caughtAt: at("2026-10-22 09:00").addingTimeInterval(Double(i) * 60))
        }
        XCTAssertEqual(try since(.ovalCharm, everySpecies), everySpecies.dropLast().last?.caughtAt, "the last species hatched")
    }

    private func utc(_ text: String) -> Date { ISO8601DateFormatter().date(from: text)! }

    private func raised(_ chain: [Int], base: Int? = nil, hatched: String, left: String, released: Bool = false,
                        form: PokemonForm? = nil) -> DexEntry {
        var entry = DexEntry(baseID: base ?? chain[0], finalID: chain[chain.count - 1], chainOrder: chain, rarity: .legendary,
                             caughtAt: utc(left), releasedAt: released ? utc(left) : nil, form: form)
        entry.raising = RaisingRecord(hatchedAt: utc(hatched))
        return entry
    }

    private func since(_ item: ItemKind, _ dex: [DexEntry], active: MonState? = nil) throws -> Date? {
        try store(clock: Clock(), items: [item], dex: dex, active: active).drawItemSince(item)
    }

    func testTheRevealGlassAskedForThreeForcesUntilItsGoalLoosened() throws {
        XCTAssertEqual(HatchRules.Change.onlyFluteWeighs.publishedAt, utc("2026-10-20T22:33:19Z"))
        let two = [raised([641], hatched: "2026-10-20T15:00:00Z", left: "2026-10-20T16:00:00Z"),
                   raised([642], hatched: "2026-10-20T16:00:00Z", left: "2026-10-20T17:00:00Z")]
        XCTAssertEqual(try since(.revealGlass, two + [raised([645], hatched: "2026-10-20T17:00:00Z", left: "2026-10-20T18:00:00Z")]),
                       utc("2026-10-20T17:00:00Z"), "the three, at the third's hatch")
        XCTAssertEqual(try since(.revealGlass, two + [raised([905], hatched: "2026-10-20T17:00:00Z", left: "2026-10-20T18:00:00Z")]),
                       HatchRules.Change.onlyFluteWeighs.publishedAt, "two of them and the fourth, once it counted")
        XCTAssertEqual(try since(.revealGlass, two + [raised([905], hatched: "2026-10-21T08:00:00Z", left: "2026-10-21T09:00:00Z")]),
                       utc("2026-10-21T08:00:00Z"), "three of the four")
    }

    func testAPokemonCountedRegisteredUntilTheRarityWeightsUpdate() throws {
        XCTAssertEqual(HatchRules.Change.rarityWeights.publishedAt, utc("2026-10-26T07:10:49Z"))
        let released = [raised([641], hatched: "2026-10-22T09:00:00Z", left: "2026-10-22T10:00:00Z", released: true),
                        raised([642], hatched: "2026-10-22T10:00:00Z", left: "2026-10-22T11:00:00Z", released: true),
                        raised([645], hatched: "2026-10-22T11:00:00Z", left: "2026-10-22T12:00:00Z", released: true)]
        XCTAssertEqual(try since(.revealGlass, released), utc("2026-10-22T11:00:00Z"),
                       "met then, not today: three sent off count as registered")
        XCTAssertEqual(try since(.revealGlass, [raised([641], hatched: "2026-10-26T06:00:00Z", left: "2026-10-26T07:00:00Z"),
                                                raised([642], hatched: "2026-10-26T07:00:00Z", left: "2026-10-26T07:10:00Z"),
                                                raised([645], hatched: "2026-10-26T07:10:48Z", left: "2026-10-26T09:00:00Z")]),
                       utc("2026-10-26T07:10:48Z"), "hatched a second before the update")
        XCTAssertEqual(try since(.revealGlass, [raised([641], hatched: "2026-10-26T06:00:00Z", left: "2026-10-26T07:00:00Z"),
                                                raised([642], hatched: "2026-10-26T07:00:00Z", left: "2026-10-26T07:10:00Z"),
                                                raised([645], hatched: "2026-10-26T07:10:49Z", left: "2026-10-26T09:00:00Z")]),
                       utc("2026-10-26T09:00:00Z"), "hatched as it came out: from its graduation")
        XCTAssertEqual(try since(.revealGlass, [raised([641], hatched: "2026-10-27T09:00:00Z", left: "2026-10-27T10:00:00Z"),
                                                raised([642], hatched: "2026-10-27T10:00:00Z", left: "2026-10-27T11:00:00Z"),
                                                raised([645], hatched: "2026-10-27T11:00:00Z", left: "2026-10-27T12:00:00Z", released: true)]),
                       HatchRules.Change.collectorItems.publishedAt, "no condition ever met: from its arrival")
    }

    /// The base species counts at its hatch, the stages after it at the date the Pokémon left: at the latest, never too early.
    func testAStageCountsWhenThePokemonLeft() throws {
        let rayquaza = raised([384], hatched: "2026-10-21T09:00:00Z", left: "2026-10-22T09:00:00Z")
        let dragonite = raised([147, 148, 149], hatched: "2026-10-22T09:00:00Z", left: "2026-10-23T09:00:00Z")
        let salamence = raised([371, 372, 373], hatched: "2026-10-23T09:00:00Z", left: "2026-10-24T09:00:00Z")
        XCTAssertEqual(try since(.shinyStone, [rayquaza, dragonite, salamence]), utc("2026-10-24T09:00:00Z"))
        XCTAssertEqual(try since(.shinyStone, [rayquaza, dragonite, salamence,
                                               raised([16], hatched: "2026-10-24T11:00:00Z", left: "2026-10-24T12:00:00Z")]),
                       utc("2026-10-24T09:00:00Z"), "the next egg hatched later")
    }

    func testThePokemonRaisedCountsOnItsBaseSpeciesOnly() throws {
        let two = [raised([641], hatched: "2026-10-22T09:00:00Z", left: "2026-10-22T10:00:00Z"),
                   raised([642], hatched: "2026-10-22T10:00:00Z", left: "2026-10-22T11:00:00Z")]
        var landorus = MonState(baseID: 645, pathIDs: [645], plannedPathIDs: [645], stageIndex: 0, usedAtStage: 0,
                                rarity: .legendary, totalForms: 1, nature: .hardy)
        landorus.raising = RaisingRecord(hatchedAt: utc("2026-10-23T09:00:00Z"))
        XCTAssertEqual(try since(.revealGlass, two, active: landorus), utc("2026-10-23T09:00:00Z"))
        var dragonite = MonState(baseID: 147, pathIDs: [147, 148, 149], plannedPathIDs: [147, 148, 149], stageIndex: 2, usedAtStage: 0,
                                 rarity: .rare, totalForms: 3, nature: .hardy)
        dragonite.raising = RaisingRecord(hatchedAt: utc("2026-10-23T09:00:00Z"))
        XCTAssertEqual(try since(.shinyStone, [raised([384], hatched: "2026-10-21T09:00:00Z", left: "2026-10-22T09:00:00Z"),
                                               raised([371, 372, 373], hatched: "2026-10-22T09:00:00Z", left: "2026-10-23T09:00:00Z")],
                                 active: dragonite),
                       HatchRules.Change.collectorItems.publishedAt, "no date for a stage reached before it leaves")
    }

    func testTheAzureFluteAlwaysCountedGraduatedCopies() throws {
        let articuno = raised([144], hatched: "2026-10-22T09:00:00Z", left: "2026-10-22T10:00:00Z")
        XCTAssertEqual(try since(.legendCharm, [articuno, raised([144], hatched: "2026-10-22T10:00:00Z", left: "2026-10-23T10:00:00Z")]),
                       utc("2026-10-23T10:00:00Z"), "the second graduated, not hatched")
        XCTAssertEqual(try since(.legendCharm, [articuno, raised([144], hatched: "2026-10-22T10:00:00Z", left: "2026-10-23T10:00:00Z", released: true)]),
                       HatchRules.Change.collectorItems.publishedAt, "a copy sent off never counted")
    }

    func testTheCharmsCountedRegisteredPokemonToo() throws {
        func every(from day: String, released: Bool) -> [DexEntry] {
            let start = utc(day)
            var i = 0.0
            func next() -> (String, String) {
                defer { i += 1 }
                let f = ISO8601DateFormatter()
                return (f.string(from: start.addingTimeInterval(i * 60)), f.string(from: start.addingTimeInterval(i * 60 + 30)))
            }
            return PokemonAssets.animatedSpeciesIDs.sorted().flatMap { id -> [DexEntry] in
                let forms = PokemonForm.forms(speciesID: id)
                return (forms.isEmpty ? [nil] : forms.map(Optional.some)).map { form in
                    let (hatched, left) = next()
                    return raised([id], base: PokemonForm.lineBase(of: id), hatched: hatched, left: left,
                                  released: released, form: form)
                }
            }
        }
        for item in [ItemKind.ovalCharm, .glimmeringCharm] {
            let sentOff = every(from: "2026-10-22T09:00:00Z", released: true)
            XCTAssertEqual(try since(item, sentOff), sentOff.last?.raising?.hatchedAt, "\(item): the last one hatched")
            let graduated = every(from: "2026-10-27T09:00:00Z", released: false)
            XCTAssertEqual(try since(item, graduated), graduated.last?.caughtAt, "\(item): the last one graduated")
        }
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
