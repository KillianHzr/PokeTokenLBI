import XCTest
@testable import PokeTokenBar

private struct FossilProvider: PokeProviding {
    var entries: [BaseSpecies] = FossilDig.lines.map { BaseSpecies(id: $0, captureRate: 45) } + [BaseSpecies(id: 1, captureRate: 45)]
    var indexDown = false
    struct Down: Error {}
    func line(baseSpeciesID: Int) async throws -> EvoLine {
        EvoLine(baseID: baseSpeciesID, tree: EvoNode(speciesID: baseSpeciesID, children: []),
                rarity: entries.first { $0.id == baseSpeciesID }?.rarity ?? .common, names: [:])
    }
    func baseSpeciesIndex() async throws -> [BaseSpecies] {
        if indexDown { throw Down() }
        return entries
    }
    func baseSpecies(id: Int) async throws -> BaseSpecies? {
        guard indexDown else { return entries.first { $0.id == id } }
        // The REST fallback can be held to the entries' ids, so that what it finds is no accident of the draw.
        if restKnowsEntriesOnly, !entries.contains(where: { $0.id == id }) { return nil }
        return BaseSpecies(id: id, captureRate: 45)
    }
    var restKnowsEntriesOnly = false
}

/// The excavation: a Fossil Egg for every 4 Rock-type species graduated, one dig per fossil line, the lines graduated
/// some other way counting as dug; a Fossil Egg hatches a fossil line still missing, at random.
@MainActor
final class FossilDigTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_790_000_000)

    private func store(dex: [DexEntry] = [], inventory: [ItemKind: Int] = [:], seed: UInt64 = 1, indexDown: Bool = false,
                       restKnowsEntriesOnly: Bool = false, url fileURL: URL? = nil,
                       _ edit: (inout CompanionState) -> Void = { _ in }) throws -> CompanionStore {
        var st = CompanionState()
        st.installBaselineSet = true
        st.lastDate = "2026-10-27"
        st.dex = dex
        st.inventory = Dictionary(uniqueKeysWithValues: inventory.map { ($0.key.rawValue, $0.value) })
        edit(&st)
        let url = fileURL ?? FileManager.default.temporaryDirectory.appendingPathComponent("fossil-\(UUID().uuidString).json")
        try JSONEncoder().encode(st).write(to: url)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        var provider = FossilProvider(indexDown: indexDown)
        provider.restKnowsEntriesOnly = restKnowsEntriesOnly
        return CompanionStore(provider: provider, clock: { self.now }, fileURL: url,
                              rng: SeededRNG(seed: seed))
    }

    private func graduated(_ id: Int, form: String? = nil) -> DexEntry {
        DexEntry(baseID: id, finalID: id, chainOrder: [id], rarity: .common, caughtAt: now, form: form.map { PokemonForm($0) })
    }

    /// Rock species that are not fossils, so graduating them never counts a fossil line as dug.
    private var rocks: [Int] {
        let fossilSpecies = CollectorBonus.fossilLines
        return FossilDig.rockSpecies.filter { !fossilSpecies.contains($0) && !PokemonForm.hasForms(speciesID: $0) }
    }

    func testFifteenDigsEachFourMoreRockPokemon() {
        XCTAssertEqual(FossilDig.lines.count, 15)
        XCTAssertEqual(SpeciesGoal.fossils.count, FossilDig.lines.count, "one line per fossil final")
        let goals = ItemKind.excavation.regionGoals ?? []
        XCTAssertEqual(goals.map(\.generation), Array(1...15))
        XCTAssertEqual(goals.map(\.goal.needed), (1...15).map { $0 * 4 })
        XCTAssertGreaterThanOrEqual(FossilDig.rockSpecies.count, 60, "enough Rock species for every dig")
        XCTAssertTrue(FossilDig.rockSpecies.contains(59), "Hisuian Arcanine is Rock")
        XCTAssertEqual(ItemKind.excavation.collectorGroup, .evolutionStones)
        XCTAssertNil(ItemKind.fossilEgg.shopPrice)
    }

    /// Four Rock species graduated: the first dig gives a Fossil Egg, once.
    func testADigGivesAFossilEgg() throws {
        let s = try store(dex: rocks.prefix(9).map { graduated($0) })
        let tiers = s.regionTiers(.excavation)
        XCTAssertEqual(tiers.filter(\.isReady).map(\.generation), [1, 2])
        XCTAssertTrue(s.claimAchievement(.excavation))
        XCTAssertEqual(s.itemCount(.fossilEgg), 2)
        XCTAssertEqual(s.itemCount(.excavation), 0, "the dig itself is not an item")
        XCTAssertFalse(s.claimAchievement(.excavation), "the third dig needs 12")
        XCTAssertEqual(s.regionTiers(.excavation).filter(\.isClaimed).count, 2)
    }

    /// A Rock form counts its species: a Hisuian Growlithe and Arcanine, not a Kanto one.
    func testARockFormCounts() throws {
        func arcanine(_ form: String?) -> DexEntry {
            DexEntry(baseID: 58, finalID: 59, chainOrder: [58, 59], rarity: .common, caughtAt: now,
                     form: form.map { PokemonForm($0) })
        }
        let hisui = try store(dex: [arcanine("hisui")])
        XCTAssertTrue(hisui.rockSpeciesGraduated.isSuperset(of: [58, 59]))
        let kanto = try store(dex: [arcanine(nil)])
        XCTAssertTrue(kanto.rockSpeciesGraduated.isDisjoint(with: [58, 59]))
    }

    /// Fossil lines graduated some other way count as dug: the last digs are done with nothing to claim, so the eggs
    /// to claim match the lines missing. Lines hatched from Fossil Eggs do not.
    /// [Regression] A species with forms counts by the forms it graduated in: a Galarian Corsola (Ghost) counted as
    /// Rock, Corsola's usual type. A Corsola of the usual form still counts.
    func testAFormThatIsNotRockDoesNotCount() throws {
        let galar = try store(dex: [DexEntry(baseID: 222, finalID: 864, chainOrder: [222, 864], rarity: .common,
                                             caughtAt: nil, form: PokemonForm("galar"))])
        XCTAssertFalse(galar.rockSpeciesGraduated.contains(222), "Galarian Corsola is Ghost")
        let usual = try store(dex: [DexEntry(baseID: 222, finalID: 222, chainOrder: [222], rarity: .common, caughtAt: nil)])
        XCTAssertTrue(usual.rockSpeciesGraduated.contains(222), "Corsola is Water and Rock")
    }

    func testLinesAlreadyGraduatedCountAsDug() throws {
        let owned = [138, 140, 142].map { graduated($0) }
        let s = try store(dex: owned + rocks.prefix(60).map { graduated($0) })
        let tiers = s.regionTiers(.excavation)
        XCTAssertEqual(tiers.filter(\.isWaived).map(\.generation), [13, 14, 15])
        XCTAssertEqual(tiers.filter(\.isReady).count, 12, "one egg per line still missing")
        XCTAssertEqual(s.claimRegionTiers(.excavation), 12)
        XCTAssertEqual(s.itemCount(.fossilEgg), 12)
        XCTAssertTrue(s.isClaimed(.excavation), "every dig done")

        let hatched = try store(dex: owned + rocks.prefix(12).map { graduated($0) }) { $0.fossilLinesBeforeDigs = [] }
        XCTAssertEqual(hatched.regionTiers(.excavation).filter(\.isWaived).count, 0,
                       "lines that came after the digs, from Fossil Eggs, were not had before")
    }

    /// What the card tells: 15 eggs, the claimed ones opened or still in the Bag, the ones ready, those not claimable
    /// for the lines had before the digs, and the Rock-type Pokémon the next one still wants out of 4.
    func testTheCardCountsFifteenEggsAndTheRockPokemonTowardTheNext() throws {
        // Omanyte and Kabuto, had before the digs and Rock themselves, plus 9 more Rock: 11 in all.
        let dex = [138, 140].map { graduated($0) } + rocks.prefix(9).map { graduated($0) }
        let firstClaimed: (inout CompanionState) -> Void = {
            $0.claimedAchievements = [CompanionState.regionTierKey(.excavation, generation: 1)]
        }
        let progress = try store(dex: dex, firstClaimed).excavationProgress
        XCTAssertEqual(progress.total, 15, "one egg per fossil line, always")
        XCTAssertEqual([progress.opened, progress.inBag], [1, 0], "the first one claimed and used")
        XCTAssertEqual(progress.ready, 1, "8 Rock reached, not claimed yet")
        XCTAssertEqual(progress.notClaimable, 2, "Omanyte and Kabuto were had before")
        XCTAssertEqual(progress.toEarn, 11)
        XCTAssertEqual(progress.towardNext, 3, "the third egg wants 12: 11 is 3 of its 4")
        XCTAssertEqual(progress.linesGraduated, 2)
        let kept = try store(dex: dex, inventory: [.fossilEgg: 1], firstClaimed).excavationProgress
        XCTAssertEqual([kept.opened, kept.inBag], [0, 1], "claimed and still in the Bag")

        let every = try store(dex: FossilDig.lines.map { graduated($0) }).excavationProgress
        XCTAssertEqual([every.total, every.notClaimable, every.toEarn], [15, 15, 0], "every line had before")
        XCTAssertNil(every.towardNext)
        XCTAssertEqual(try store().excavationProgress.towardNext, 0, "nothing yet: 0 of 4")
    }

    /// Regression: hatching a Fossil Egg gave a sixth egg for five missing lines. The lines had before the digs were
    /// counted again as the lines graduated minus the eggs hatched, so an egg hatched, its line not graduated yet,
    /// freed a dig. They are taken once now.
    func testHatchingAFossilEggFreesNoDig() async throws {
        let had = [138, 140, 142, 345, 408, 564, 566, 696, 698, 881]
        let claimed = Set((1...5).map { CompanionState.regionTierKey(.excavation, generation: $0) })
        // 29 Rock species with 9 of the lines (Arctozolt is not Rock): the sixth dig is met, the one the old count freed.
        let s = try store(dex: had.map { graduated($0) } + rocks.prefix(20).map { graduated($0) },
                          inventory: [.fossilEgg: 5]) {
            $0.claimedAchievements = claimed
            $0.active = MonState(baseID: 1, pathIDs: [1], stageIndex: 0, usedAtStage: 0, rarity: .common, totalForms: 1)
        }
        XCTAssertEqual(s.state.fossilLinesBeforeDigs, Set(had), "taken when the save first meets the digs")
        XCTAssertEqual(s.excavationProgress.ready, 0)
        XCTAssertTrue(s.useFossilEgg())
        s.setEggUsageForTesting(s.eggHatchThreshold)
        await s.hatchIfNeeded()
        XCTAssertEqual(s.state.fossilEggsHatched, 1)
        XCTAssertEqual(s.excavationProgress.ready, 0, "no sixth egg while the hatched line is raised")
        XCTAssertFalse(s.claimAchievement(.excavation))

        let line = try XCTUnwrap(s.state.active).baseID
        let graduatedLater = try store(dex: (had + [line]).map { graduated($0) } + rocks.prefix(20).map { graduated($0) }) {
            $0.claimedAchievements = claimed
            $0.fossilLinesBeforeDigs = Set(had)
        }
        XCTAssertEqual(graduatedLater.excavationProgress.ready, 0, "nor once it graduates")
        XCTAssertEqual(graduatedLater.excavationProgress.notClaimable, 10)
    }

    /// A save from the first version of the digs, or its export: a line its Fossil Egg brought, first graduated
    /// after the digs came, is not "had before". Nothing is taken back, and no dig is done for that line (#77).
    func testALineFromAFossilEggIsNotCountedAsHadBefore() throws {
        let had = [138, 140, 142, 345, 408, 564, 566, 696, 698, 881]
        let anorith = DexEntry(baseID: 347, finalID: 347, chainOrder: [347], rarity: .common,
                               caughtAt: FossilDig.introduced.addingTimeInterval(3 * 86_400))
        let five = Set((1...5).map { CompanionState.regionTierKey(.excavation, generation: $0) })
        let dex = had.map { graduated($0) } + [anorith] + rocks.prefix(20).map { graduated($0) }
        let s = try store(dex: dex, inventory: [.fossilEgg: 4]) {
            $0.claimedAchievements = five
        }
        XCTAssertEqual(s.state.fossilLinesBeforeDigs, Set(had))
        XCTAssertEqual(s.itemCount(.fossilEgg), 4, "nothing taken")
        XCTAssertEqual(s.excavationProgress.notClaimable, 10)

        // The same save after #75 took the set with Anorith in it, then took an egg back: mended, the dig returns.
        let taken = try store(dex: dex, inventory: [.fossilEgg: 3]) {
            $0.claimedAchievements = Set((1...4).map { CompanionState.regionTierKey(.excavation, generation: $0) })
            $0.fossilLinesBeforeDigs = Set(had + [347])
        }
        XCTAssertEqual(taken.state.fossilLinesBeforeDigs, Set(had), "mended")
        XCTAssertEqual(taken.excavationProgress.ready, 1, "the egg taken back is to claim again")
    }

    /// A save that got the extra egg: 10 lines had, 6 digs claimed for 5 missing lines. The extra egg leaves the Bag
    /// and its dig is done again with nothing to claim; with every egg already used, nothing is taken.
    func testTheExtraEggIsTakenBackFromTheBag() throws {
        let had = [138, 140, 142, 345, 408, 564, 566, 696, 698, 881]
        let six = Set((1...6).map { CompanionState.regionTierKey(.excavation, generation: $0) })
        let dex = had.map { graduated($0) } + rocks.prefix(20).map { graduated($0) }
        let s = try store(dex: dex, inventory: [.fossilEgg: 5]) {
            $0.claimedAchievements = six
        }
        XCTAssertEqual(s.itemCount(.fossilEgg), 4, "five missing lines: one hatched, four left in the Bag")
        let progress = s.excavationProgress
        XCTAssertEqual([progress.opened, progress.inBag, progress.ready, progress.notClaimable], [1, 4, 0, 10])

        let used = try store(dex: dex) {
            $0.claimedAchievements = six
        }
        XCTAssertEqual(used.itemCount(.fossilEgg), 0)
        XCTAssertEqual(used.regionTiers(.excavation).filter(\.isClaimed).count, 6, "an egg already used stays used")
    }

    /// The Excavation is not a stone: it closes the stones of its own state, never below one claimed (the owner,
    /// 2026-11-02). With an egg to claim it comes up with what is ready; every dig done, it sinks with what is claimed.
    func testTheExcavationClosesTheStonesOfItsState() throws {
        let ready = try store(dex: rocks.prefix(4).map { graduated($0) })
        XCTAssertTrue(ready.regionTiers(.excavation).contains(where: \.isReady))
        XCTAssertEqual(ready.achievementItems(in: .evolutionStones).first, .excavation, "the only reward ready")
        let done = try store(dex: FossilDig.lines.map { graduated($0) })
        XCTAssertEqual(done.achievementItems(in: .evolutionStones).last, .excavation, "done, with the claimed")
    }

    /// A Fossil Egg hatches a missing fossil line, each as likely; once every line graduated, any of them.
    func testAFossilEggHatchesAMissingLine() async throws {
        let owned = FossilDig.lines.dropFirst(2).map { graduated($0) }   // Omanyte and Kabuto missing
        var hatched = Set<Int>()
        for seed: UInt64 in 1...10 {
            let s = try store(dex: Array(owned), inventory: [.fossilEgg: 1], seed: seed) {
                $0.active = MonState(baseID: 1, pathIDs: [1], stageIndex: 0, usedAtStage: 0, rarity: .common, totalForms: 1)
            }
            XCTAssertTrue(s.useFossilEgg())
            XCTAssertEqual(s.eggKind, .fossil)
            s.setEggUsageForTesting(s.eggHatchThreshold)
            await s.hatchIfNeeded()
            let mon = try XCTUnwrap(s.state.active, "seed \(seed)")
            XCTAssertTrue([138, 140].contains(mon.baseID), "seed \(seed): \(mon.baseID)")
            XCTAssertFalse(s.state.eggFromFossilEgg)
            XCTAssertEqual(s.state.fossilEggsHatched, 1)
            hatched.insert(mon.baseID)
        }
        XCTAssertEqual(hatched, [138, 140], "both missing lines come")

        let all = try store(dex: FossilDig.lines.map { graduated($0) }, inventory: [.fossilEgg: 1]) {
            $0.active = MonState(baseID: 1, pathIDs: [1], stageIndex: 0, usedAtStage: 0, rarity: .common, totalForms: 1)
        }
        XCTAssertTrue(all.useFossilEgg())
        all.setEggUsageForTesting(all.eggHatchThreshold)
        await all.hatchIfNeeded()
        XCTAssertTrue(FossilDig.lines.contains(try XCTUnwrap(all.state.active).baseID), "every line graduated: any of them")
    }

    /// A Fossil Egg's Pokémon sent off before it graduates gives its egg back: its line hatches from no other egg (#77).
    /// Any other Pokémon sent off gives nothing, and the mark survives a restart.
    func testAFossilEggsPokemonSentOffGivesTheEggBack() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("fossil-\(UUID().uuidString).json")
        let s = try store(inventory: [.fossilEgg: 1, .fireStone: 1], url: url) {
            $0.active = MonState(baseID: 1, pathIDs: [1], stageIndex: 0, usedAtStage: 0, rarity: .common, totalForms: 1)
        }
        XCTAssertTrue(s.useFossilEgg())
        XCTAssertEqual(s.itemCount(.fossilEgg), 0, "Bulbasaur came from no Fossil Egg")
        s.setEggUsageForTesting(s.eggHatchThreshold)
        await s.hatchIfNeeded()
        let fossil = try XCTUnwrap(s.state.active)
        XCTAssertTrue(FossilDig.lines.contains(fossil.baseID))
        XCTAssertTrue(fossil.fromFossilEgg)
        let reloaded = CompanionStore(provider: FossilProvider(), clock: { self.now }, fileURL: url, rng: SeededRNG(seed: 1))
        XCTAssertEqual(reloaded.state.active?.fromFossilEgg, true, "kept by the save")

        XCTAssertTrue(s.useStone(.fireStone))
        XCTAssertEqual(s.itemCount(.fossilEgg), 1, "back in the Bag")
        XCTAssertEqual([s.excavationProgress.opened, s.excavationProgress.inBag], [0, 0], "no dig claimed here")
    }

    /// Regression (#90): a Fossil Egg used on a Fossil Egg's own Pokémon gave that egg back, so fossil hatches rerolled
    /// for free, shiny roll included. It is greyed out while such a Pokémon grows; a stone or a Shop egg still sends it
    /// off, and gives its egg back (#77).
    func testAFossilEggWaitsWhileAFossilEggsPokemonGrows() throws {
        var fossil = MonState(baseID: 138, pathIDs: [138], stageIndex: 0, usedAtStage: 0, rarity: .common, totalForms: 1)
        fossil.fromFossilEgg = true
        let s = try store(inventory: [.fossilEgg: 2, .fireStone: 1]) { $0.active = fossil }
        XCTAssertTrue(s.isRaisingFossilEggPokemon)
        XCTAssertFalse(s.canUseFossilEgg())
        XCTAssertFalse(s.useFossilEgg())
        XCTAssertEqual(s.itemCount(.fossilEgg), 2, "not spent")
        XCTAssertEqual(s.state.active?.baseID, 138, "still raised")
        XCTAssertTrue(s.useStone(.fireStone))
        XCTAssertEqual(s.itemCount(.fossilEgg), 3, "its egg back (#77)")
        XCTAssertFalse(s.isRaisingFossilEggPokemon)

        let other = try store(inventory: [.fossilEgg: 1]) {
            $0.active = MonState(baseID: 1, pathIDs: [1], stageIndex: 0, usedAtStage: 0, rarity: .common, totalForms: 1)
        }
        XCTAssertFalse(other.isRaisingFossilEggPokemon)
        XCTAssertTrue(other.canUseFossilEgg(), "any other Pokémon can be sent off for one")
    }

    /// The base index down, a Fossil Egg's REST fallback asks for its lines themselves: it hatches one on every try,
    /// not the line hatched last while another is left. It used to draw 32 random numbers and seldom met one.
    func testTheRestFallbackFindsAFossilLineEveryTime() async throws {
        for seed: UInt64 in 1...12 {
            let s = try store(inventory: [.fossilEgg: 1], seed: seed, indexDown: true) {
                $0.active = MonState(baseID: 1, pathIDs: [1], stageIndex: 0, usedAtStage: 0, rarity: .common, totalForms: 1)
                $0.lastHatchedBaseID = 138
            }
            XCTAssertTrue(s.useFossilEgg())
            s.setEggUsageForTesting(s.eggHatchThreshold)
            await s.hatchIfNeeded()
            let mon = try XCTUnwrap(s.state.active, "seed \(seed): the egg found no line")
            XCTAssertTrue(FossilDig.lines.contains(mon.baseID), "seed \(seed): \(mon.baseID)")
            XCTAssertNotEqual(mon.baseID, 138, "not the line hatched last, seed \(seed)")
        }
        // One line left, hatched last: still hatched rather than kept.
        let last = FossilDig.lines.filter { $0 != 883 }.map { graduated($0) }
        let s = try store(dex: last, inventory: [.fossilEgg: 1], indexDown: true) {
            $0.active = MonState(baseID: 1, pathIDs: [1], stageIndex: 0, usedAtStage: 0, rarity: .common, totalForms: 1)
            $0.lastHatchedBaseID = 883
        }
        XCTAssertTrue(s.useFossilEgg())
        s.setEggUsageForTesting(s.eggHatchThreshold)
        await s.hatchIfNeeded()
        XCTAssertEqual(s.state.active?.baseID, 883)
    }

    /// The REST fallback of any other egg leaves out a fossil line not graduated, and keeps one graduated (#75). Held
    /// to Bulbasaur and the fossil lines, its draws can only meet those.
    func testTheRestFallbackOfOtherEggsFollowsTheFossilRule() async throws {
        var withGraduated: Set<Int> = []
        for seed: UInt64 in 1...64 {
            let s = try store(seed: seed, indexDown: true, restKnowsEntriesOnly: true)
            s.setEggUsageForTesting(s.eggHatchThreshold)
            await s.hatchIfNeeded()
            if let base = s.state.active?.baseID { XCTAssertEqual(base, 1, "seed \(seed)") }
            let omanyte = try store(dex: [graduated(138)], seed: seed, indexDown: true, restKnowsEntriesOnly: true)
            omanyte.setEggUsageForTesting(omanyte.eggHatchThreshold)
            await omanyte.hatchIfNeeded()
            if let base = omanyte.state.active?.baseID {
                XCTAssertTrue([1, 138].contains(base), "seed \(seed): \(base)")
                withGraduated.insert(base)
            }
        }
        XCTAssertTrue(withGraduated.contains(138), "a graduated Omanyte comes back from a plain egg")
    }

    /// A fossil line not graduated yet hatches from Fossil Eggs only: a plain egg, a rarity's egg, a stone's egg or an
    /// event's never brings one, nor does the REST fallback.
    func testFossilLinesHatchFromFossilEggsOnly() async throws {
        func hatch(seed: UInt64, indexDown: Bool = false, _ edit: (inout CompanionState) -> Void = { _ in }) async throws -> Int? {
            let s = try store(seed: seed, indexDown: indexDown, edit)
            s.setEggUsageForTesting(s.eggHatchThreshold)
            await s.hatchIfNeeded()
            return s.state.active?.baseID
        }
        for seed: UInt64 in 1...8 {
            let plain = try await hatch(seed: seed)
            XCTAssertEqual(plain, 1, "a plain egg: seed \(seed)")
            let rare = try await hatch(seed: seed) { $0.eggTier = .rare }
            XCTAssertEqual(rare, 1, "a Rare Egg: seed \(seed)")
            // Omanyte, Kabuto, Tirtouga and Dracovish are Water: a Water Stone's egg has no other candidate here.
            let water = try await hatch(seed: seed) { $0.eggTypeGuarantee = .water }
            XCTAssertNil(water, "no fossil for a Water Stone's egg: it waits")
            let kanto = try await hatch(seed: seed) { $0.eggEvent = .pokemonDay }
            XCTAssertEqual(kanto, 1, "Pokémon Day's Kanto pool without Omanyte, Kabuto, Aerodactyl")
        }
    }

    /// Once graduated, a fossil line hatches from any egg like every other species: a Water Stone's egg brings the
    /// Omanyte already graduated, never Kabuto, Tirtouga or Dracovish, still missing.
    func testAGraduatedFossilLineJoinsEveryEgg() async throws {
        var plain: Set<Int> = []
        for seed: UInt64 in 1...16 {
            let water = try store(dex: [graduated(138)], seed: seed) { $0.eggTypeGuarantee = .water }
            water.setEggUsageForTesting(water.eggHatchThreshold)
            await water.hatchIfNeeded()
            XCTAssertEqual(water.state.active?.baseID, 138, "seed \(seed)")

            let egg = try store(dex: [graduated(138)], seed: seed)
            egg.setEggUsageForTesting(egg.eggHatchThreshold)
            await egg.hatchIfNeeded()
            plain.insert(try XCTUnwrap(egg.state.active).baseID)
        }
        XCTAssertEqual(plain, [1, 138], "a plain egg: Bulbasaur or Omanyte, never a fossil line still missing")
    }

    func testTheSaveKeepsTheDigs() throws {
        var st = CompanionState()
        st.eggFromFossilEgg = true
        st.fossilEggsHatched = 4
        st.fossilLinesBeforeDigs = [138]
        let kept = try JSONDecoder().decode(CompanionState.self, from: JSONEncoder().encode(st))
        XCTAssertTrue(kept.eggFromFossilEgg)
        XCTAssertEqual(kept.fossilEggsHatched, 4)
        XCTAssertEqual(kept.fossilLinesBeforeDigs, [138], "a lost key would take the lines again at every load")
        st.active = MonState(baseID: 1, pathIDs: [1], stageIndex: 0, usedAtStage: 0, rarity: .common, totalForms: 1)
        XCTAssertFalse(SaveTransfer.sanitized(st).eggFromFossilEgg, "no egg beside a Pokémon being raised")
        XCTAssertEqual(SaveTransfer.sanitized(st).fossilEggsHatched, 4)
        XCTAssertEqual(SaveTransfer.sanitized(st).fossilLinesBeforeDigs, [138])
    }
}
