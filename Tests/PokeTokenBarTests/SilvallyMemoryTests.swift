import XCTest
@testable import PokeTokenBar

private struct MemoryProvider: PokeProviding {
    let entries = [BaseSpecies(id: 772, captureRate: 3, isUnbreedableLegendary: true, isLegendary: true),
                   BaseSpecies(id: 146, captureRate: 3, isUnbreedableLegendary: true, isLegendary: true)]
    func line(baseSpeciesID: Int) async throws -> EvoLine {
        if baseSpeciesID == 772 {
            return EvoLine(baseID: 772, tree: EvoNode(speciesID: 772, children: [EvoNode(speciesID: 773, children: [])]),
                           rarity: .legendary, names: [772: ["en": "Type: Null"], 773: ["en": "Silvally"]])
        }
        return EvoLine(baseID: 146, tree: EvoNode(speciesID: 146, children: []), rarity: .legendary,
                       names: [146: ["en": "Moltres"]])
    }
    func baseSpeciesIndex() async throws -> [BaseSpecies] { entries }
    func baseSpecies(id: Int) async throws -> BaseSpecies? { entries.first { $0.id == id } }
}

/// Silvally's 17 type forms used to be rolled when Type: Null hatched, as rare as Arceus, so they could not be
/// collected. As in the games they come from Memories: a legendary or mythical Pokémon of each type in the
/// Pokédex gives that type's Memory, and all 17 earn a Type: Null Egg.
@MainActor
final class SilvallyMemoryTests: XCTestCase {
    private let date = Date(timeIntervalSince1970: 1_790_000_000)
    private let normal = PokemonForm("normal"), fire = PokemonForm("fire"), flying = PokemonForm("flying")

    private func store(_ st: CompanionState, seed: UInt64 = 1) throws -> CompanionStore {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("memories-\(UUID().uuidString).json")
        try JSONEncoder().encode(st).write(to: url)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return CompanionStore(provider: MemoryProvider(), clock: { self.date }, fileURL: url, rng: SeededRNG(seed: seed))
    }

    private func state(legendaries: [Int] = [], extra: [DexEntry] = []) -> CompanionState {
        var st = CompanionState()
        st.installBaselineSet = true
        st.lastDate = "2026-10-21"
        st.dex = legendaries.map { entry($0) } + extra
        return st
    }

    private func entry(_ id: Int, chain: [Int]? = nil, rarity: Rarity = .legendary, released: Bool = false,
                       form: PokemonForm? = nil) -> DexEntry {
        DexEntry(baseID: chain?.first ?? id, finalID: id, chainOrder: chain ?? [id], rarity: rarity, caughtAt: date,
                 profile: PokemonProfile.generate(seed: 3), releasedAt: released ? date : nil, form: form)
    }

    /// One legendary or mythical of every type but Normal: Genesect is the only Bug one.
    private let everyMemory = [146, 245, 145, 251, 144, 638, 890, 383, 649, 377, 487, 491, 716]

    func testLegendariesGiveTheMemoriesOfTheirTypes() {
        XCTAssertEqual(state(legendaries: [146]).silvallyMemoryTypes, [.fire, .flying], "Moltres")
        XCTAssertEqual(state(extra: [entry(649, released: true)]).silvallyMemoryTypes, [.bug, .steel],
                       "a released Genesect still counts")
        XCTAssertEqual(state(extra: [entry(794, rarity: .rare)]).silvallyMemoryTypes, [], "an Ultra Beast is no legendary")
        XCTAssertEqual(state(extra: [entry(493, form: fire), entry(773, chain: [772, 773], form: fire)]).silvallyMemoryTypes,
                       [], "Arceus and Silvally give their Normal type, even saved in a type form")
        XCTAssertEqual(state(legendaries: everyMemory).silvallyMemoryTypes, Set(PokemonForm.memoryTypes))
    }

    /// A legendary in a form of its own gives that form's types: a Galarian Moltres is Dark and Flying, a Crowned
    /// Zacian Fairy and Steel. Before, every form gave its default form's types.
    func testALegendaryFormGivesItsOwnTypes() {
        XCTAssertEqual(state(extra: [entry(146, form: PokemonForm("galar"))]).silvallyMemoryTypes, [.dark, .flying])
        XCTAssertEqual(state(extra: [entry(888, form: PokemonForm("crowned"))]).silvallyMemoryTypes, [.fairy, .steel])
        var raising = state()
        raising.active = MonState(baseID: 144, pathIDs: [144], stageIndex: 0, usedAtStage: 0, rarity: .legendary,
                                  totalForms: 1, form: PokemonForm("galar"))
        XCTAssertEqual(raising.silvallyMemoryTypes, [.psychic, .flying], "the Galarian Articuno being raised")
    }

    func testMemoriesUnlockSilvallysFormsOnceSilvallyIsInThePokedex() throws {
        let waiting = state(legendaries: [146])
        XCTAssertEqual(waiting.itemUnlockedForms(speciesID: 773), [fire, flying])
        XCTAssertEqual(waiting.collectedForms(speciesID: 773), [])
        let owned = state(legendaries: [146], extra: [entry(773, chain: [772, 773], form: normal)])
        XCTAssertEqual(owned.collectedForms(speciesID: 773), [normal, fire, flying])
        XCTAssertEqual(try store(owned).formSpecies(speciesID: 773).compactMap(\.form), [normal, flying, fire])
    }

    func testTypeNullHatchesNormalAndEvolvesWithItsMemories() async throws {
        XCTAssertEqual(PokemonForm.rollableLineForms(baseID: 772), [normal])
        let s = try store(state(legendaries: [146]))
        await s.hatch(baseID: 772)
        XCTAssertEqual(s.state.active?.form, normal)
        XCTAssertEqual(s.formUnlockNews, [], "a Type: Null brings no Memory")
        s.applyUsage(s.threshold)
        XCTAssertEqual(s.currentSpeciesID, 773)
        XCTAssertEqual(s.formUnlockNews, [.init(speciesID: 773, forms: [flying, fire])],
                       "the first Silvally takes the Memories already won")
    }

    /// A legendary hatched with Silvally in the Pokédex announces the Memories of its form; without Silvally, nothing.
    func testHatchingALegendaryAnnouncesItsMemoriesOnlyWithSilvally() async throws {
        func hatched(_ form: PokemonForm, silvally: Bool) async throws -> CompanionStore {
            var st = state(extra: silvally ? [entry(773, chain: [772, 773], form: normal)] : [])
            st.pendingHatchID = 146
            st.pendingForm = form
            let s = try store(st)
            s.setEggUsageForTesting(s.eggHatchThreshold)
            await s.hatchIfNeeded()
            XCTAssertEqual(s.state.active?.form, form)
            return s
        }
        let kanto = try await hatched(normal, silvally: true)
        XCTAssertEqual(kanto.formUnlockNews, [.init(speciesID: 773, forms: [flying, fire])])
        let galar = try await hatched(PokemonForm("galar"), silvally: true)
        XCTAssertEqual(galar.formUnlockNews, [.init(speciesID: 773, forms: [flying, PokemonForm("dark")])],
                       "a Galarian Moltres is Dark and Flying")

        let alone = try await hatched(normal, silvally: false)
        XCTAssertEqual(alone.formUnlockNews, [], "no Silvally yet: the Memories wait, silent")
        XCTAssertEqual(alone.state.silvallyMemoryTypes, [.fire, .flying])
    }

    /// All 17 Memories unlock the Type: Null Egg, used like a stone to hatch a Type: Null.
    func testEveryMemoryEarnsATypeNullEgg() throws {
        let missingBug = try store(state(legendaries: everyMemory.filter { $0 != 649 }))
        XCTAssertEqual(missingBug.silvallyMemoryCount, 16)
        XCTAssertFalse(missingBug.isUnlocked(.typeNullEgg), "Genesect is the only Bug legendary")
        // Only graduated legendaries count for the egg: a released Genesect, or one being raised, gives Silvally its
        // form but not the achievement.
        let released = try store(state(legendaries: everyMemory.filter { $0 != 649 }, extra: [entry(649, released: true)]))
        XCTAssertEqual(released.state.silvallyMemoryTypes, Set(PokemonForm.memoryTypes))
        XCTAssertEqual(released.silvallyMemoryCount, 16)
        XCTAssertFalse(released.isUnlocked(.typeNullEgg))
        var raising = state(legendaries: everyMemory.filter { $0 != 649 })
        raising.active = MonState(baseID: 649, pathIDs: [649], stageIndex: 0, usedAtStage: 0, rarity: .legendary,
                                  totalForms: 1)
        XCTAssertFalse(try store(raising).isUnlocked(.typeNullEgg))

        var st = state(legendaries: everyMemory)
        st.active = MonState(baseID: 25, pathIDs: [25], stageIndex: 0, usedAtStage: 0, rarity: .common, totalForms: 1)
        let s = try store(st)
        XCTAssertTrue(s.isUnlocked(.typeNullEgg))
        XCTAssertTrue(s.claimAchievement(.typeNullEgg))
        XCTAssertEqual(s.itemCount(.typeNullEgg), 1)
        XCTAssertFalse(s.claimAchievement(.typeNullEgg), "claimed once")
        XCTAssertTrue(s.useTypeNullEgg())
        XCTAssertNil(s.state.active)
        XCTAssertEqual(s.state.pendingHatchID, 772)
        XCTAssertEqual(s.state.pendingForm, normal)
        XCTAssertEqual(s.itemCount(.typeNullEgg), 0)
        XCTAssertEqual(s.state.dex.last?.finalID, 25, "the companion is sent off, not lost")
        XCTAssertFalse(s.useTypeNullEgg())
    }
}
