import XCTest
@testable import PokeTokenBar

private struct ArceusProvider: PokeProviding {
    let entries = [BaseSpecies(id: 493, captureRate: 3, isUnbreedableLegendary: true, isLegendary: true)]
    func line(baseSpeciesID: Int) async throws -> EvoLine {
        EvoLine(baseID: 493, tree: EvoNode(speciesID: 493, children: []), rarity: .legendary,
                names: [493: ["en": "Arceus"]])
    }
    func baseSpeciesIndex() async throws -> [BaseSpecies] { entries }
    func baseSpecies(id: Int) async throws -> BaseSpecies? { entries.first { $0.id == id } }
}

/// Arceus's 17 type forms used to be rolled at hatch, one Arceus in about 21,600 hatches each, so no player
/// could collect them. As in the games, they come from Plates: the gym badge of each type gives one, and an
/// Arceus in the Pokédex shows every form its Plates unlock.
@MainActor
final class PlateFormTests: XCTestCase {
    private let date = Date(timeIntervalSince1970: 1_790_000_000)
    private let fire = PokemonForm("fire"), water = PokemonForm("water"), ice = PokemonForm("ice")
    private let normal = PokemonForm("normal")

    private func store(_ st: CompanionState, seed: UInt64 = 1) throws -> CompanionStore {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("plates-\(UUID().uuidString).json")
        try JSONEncoder().encode(st).write(to: url)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return CompanionStore(provider: ArceusProvider(), clock: { self.date }, fileURL: url, rng: SeededRNG(seed: seed))
    }

    private func state(plates: [PokemonType] = [], arceus: PokemonForm? = nil) -> CompanionState {
        var st = CompanionState()
        st.installBaselineSet = true
        st.lastDate = "2026-10-21"
        st.claimedAchievements = Set(plates.map {
            CompanionState.regionTierKey($0.badgeItem, generation: PokemonTypeData.badgeGenerations(for: $0)[0])
        })
        if let arceus { st.dex = [arceusEntry(arceus)] }
        return st
    }

    private func arceusEntry(_ form: PokemonForm) -> DexEntry {
        DexEntry(baseID: 493, finalID: 493, chainOrder: [493], rarity: .legendary, caughtAt: date,
                 profile: PokemonProfile.generate(seed: 7), form: form)
    }

    /// Every species of one regional tier of a badge, graduated, so that tier is ready to claim.
    private func badgeRegion(_ type: PokemonType) -> [DexEntry] {
        PokemonTypeData.badgeSpecies(for: type, generation: PokemonTypeData.badgeGenerations(for: type)[0]).map {
            DexEntry(baseID: $0, finalID: $0, chainOrder: [$0], rarity: .common, caughtAt: date)
        }
    }

    func testArceusHatchesInItsNormalForm() async throws {
        XCTAssertEqual(PokemonForm.rollableLineForms(baseID: 493), [normal])
        XCTAssertEqual(PokemonForm.lineForms(baseID: 493).count, 18, "saved forms stay valid")
        XCTAssertFalse(PokemonTypeData.canHatch(baseID: 493, as: .fire), "a Fire Stone egg does not hatch Arceus")
        for seed: UInt64 in 1...12 {
            let s = try store(state(), seed: seed)
            await s.hatch(baseID: 493)
            XCTAssertEqual(s.state.active?.form, normal, "seed \(seed)")
        }
    }

    func testPlatesUnlockArceusFormsOnceArceusIsInThePokedex() throws {
        let waiting = state(plates: [.fire, .water])
        XCTAssertEqual(waiting.itemUnlockedForms(speciesID: 493), [fire, water])
        XCTAssertEqual(waiting.collectedForms(speciesID: 493), [], "no Arceus yet")

        let owned = state(plates: [.fire, .water], arceus: normal)
        XCTAssertEqual(owned.collectedForms(speciesID: 493), [normal, fire, water])
        XCTAssertTrue(owned.ownsSpecies(493, form: fire))
        XCTAssertFalse(owned.ownsSpecies(493, form: ice))

        // A form an older save hatched stays, and the Normal form comes with any Arceus.
        let legacy = state(plates: [.water], arceus: PokemonForm("dragon"))
        XCTAssertEqual(legacy.collectedForms(speciesID: 493), [normal, water, PokemonForm("dragon")])

        // The Plain Badge stands for Normal, Arceus's default form: no Plate needed.
        XCTAssertEqual(state(plates: [.normal]).itemUnlockedForms(speciesID: 493), [])
    }

    func testThePokedexShowsPlateFormsWithTheSameArceus() throws {
        let s = try store(state(plates: [.fire], arceus: normal))
        XCTAssertEqual(s.formSpecies(speciesID: 493).compactMap(\.form), [normal, fire])
        XCTAssertEqual(s.pokemonIndividuals(speciesID: 493, form: fire).count, 1, "the Arceus holds the Plate")
        XCTAssertTrue(s.setRepresentativeSpeciesID(493, form: fire))
        XCTAssertFalse(s.setRepresentativeSpeciesID(493, form: ice))
        XCTAssertTrue(s.state.isLineComplete(baseID: 493) == false, "not graduated yet")
        var graduated = state(arceus: normal)
        graduated.collectedFinals = ["493:493"]
        XCTAssertTrue(graduated.isLineComplete(baseID: 493), "an egg has nothing more to give")
    }

    /// A Plate changes the look, not the individual: a shiny Arceus is shiny in each form it has, in the form
    /// picker and for the menu-bar representative alike.
    func testAShinyArceusIsShinyInEveryFormItHas() throws {
        var st = state(plates: [.water])
        st.dex = [DexEntry(baseID: 493, finalID: 493, chainOrder: [493], rarity: .legendary, caughtAt: date,
                           isShiny: true, form: normal)]
        let s = try store(st)
        XCTAssertEqual(s.formSpecies(speciesID: 493).map(\.isShiny), [true, true])
        XCTAssertTrue(s.state.ownsShinySpecies(493, form: water))
        XCTAssertFalse(s.state.ownsShinySpecies(493, form: ice), "no Ice Plate")
        XCTAssertTrue(s.setRepresentativeSpeciesID(493, form: water))
        XCTAssertEqual(s.representativeSubject.isShiny, true)

        let plain = state(plates: [.water], arceus: normal)
        XCTAssertFalse(plain.ownsShinySpecies(493, form: water))
    }

    func testClaimingABadgeAnnouncesItsArceusForm() throws {
        var st = state(arceus: normal)
        st.dex += badgeRegion(.fire)
        let s = try store(st)
        XCTAssertEqual(s.claimRegionTiers(.volcanoBadge), 1)
        XCTAssertEqual(s.formUnlockNews, [.init(speciesID: 493, forms: [fire])])
        s.dismissFormUnlockNews()
        XCTAssertEqual(s.formUnlockNews, [])
    }

    /// "Claim all" shows one message with every form it unlocked; a Plate already won announces nothing.
    func testClaimAllAnnouncesEveryNewFormInOneMessage() throws {
        var st = state(plates: [.water], arceus: normal)
        st.dex += badgeRegion(.fire) + badgeRegion(.ice) + badgeRegion(.water)
        st.claimedAchievements.remove(CompanionState.regionTierKey(.cascadeBadge, generation: 1))
        st.claimedAchievements.insert(CompanionState.regionTierKey(.cascadeBadge, generation: 2))
        let s = try store(st)
        XCTAssertGreaterThanOrEqual(s.claimAllAchievements(), 3)
        XCTAssertEqual(s.formUnlockNews, [.init(speciesID: 493, forms: [fire, ice])],
                       "Water was already unlocked by Johto")
    }

    /// Without Arceus no form is announced: its Plates wait, silent, for the first one.
    func testPlatesWonWithoutArceusAnnounceNothing() throws {
        var st = state()
        st.dex += badgeRegion(.fire)
        let s = try store(st)
        XCTAssertEqual(s.claimRegionTiers(.volcanoBadge), 1)
        XCTAssertEqual(s.formUnlockNews, [])
        XCTAssertEqual(s.state.itemUnlockedForms(speciesID: 493), [fire], "the Plate is still won")
    }

    func testTheFirstArceusBringsThePlatesAlreadyWon() async throws {
        let s = try store(state(plates: [.fire, .water]))
        await s.hatch(baseID: 493)
        XCTAssertEqual(s.formUnlockNews, [.init(speciesID: 493, forms: [fire, water])])

        let again = try store(state(plates: [.fire], arceus: normal))
        await again.hatch(baseID: 493)
        XCTAssertEqual(again.formUnlockNews, [], "a second Arceus unlocks nothing new")
    }
}
