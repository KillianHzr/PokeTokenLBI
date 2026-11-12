import AppKit
import SwiftUI
import XCTest
@testable import PokeTokenBar

/// The Collection's statistics (the owner, 2026-11-10): the map of generations by types, the categories, the battle
/// forms and what is closest to done, from the graduated Pokémon.
@MainActor
final class CollectionStatsTests: XCTestCase {
    private func entry(_ id: Int, released: Bool = false) -> DexEntry {
        var e = DexEntry(baseID: SpeciesInfo.baseID(of: id), finalID: id, chainOrder: [id], rarity: .common, caughtAt: nil)
        e.id = "e\(id)"
        if released { e.releasedAt = Date(timeIntervalSince1970: 0) }
        return e
    }

    private func store(_ dex: [DexEntry], language: AppLanguage = .fr,
                       prepare: (inout CompanionState) -> Void = { _ in }) throws -> CompanionStore {
        var st = CompanionState()
        st.language = language
        st.installBaselineSet = true
        st.dex = dex
        prepare(&st)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("stats-\(UUID().uuidString).json")
        try JSONEncoder().encode(st).write(to: url)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return CompanionStore(provider: StubProvider(value: EvoLine(baseID: 16, tree: EvoNode(speciesID: 16, children: []),
                                                                    rarity: .common, names: [:])),
                              fileURL: url, rng: SeededRNG(seed: 3), difficulty: 0.1)
    }

    /// Every species is in one generation, and each cell holds the species of its generation with its type.
    func testTheMapCoversThePokedex() throws {
        let stats = try store([]).collectionStats
        let generations = (1...CollectionStats.generationCount).map { stats.tally(.generation($0)).total }
        XCTAssertEqual(generations.reduce(0, +), 1025)
        XCTAssertEqual(generations.first, 151)
        XCTAssertEqual(stats.tally(.cell(generation: 1, type: .fire)).total,
                       (1...151).filter { PokemonTypeData.types(forSpeciesID: $0).contains(.fire) }.count)
        for generation in 1...CollectionStats.generationCount {
            let cells = PokemonType.allCases.map { stats.tally(.cell(generation: generation, type: $0)).total }.reduce(0, +)
            XCTAssertGreaterThanOrEqual(cells, stats.tally(.generation(generation)).total, "a species has one or two types")
        }
        XCTAssertEqual(stats.tally(.category(.ultraBeasts)).total, 11)
        XCTAssertEqual(stats.tally(.category(.starters)).total, 27)
        XCTAssertEqual(CollectionStats.battleKinds.map { stats.tally(.battle($0)).total }.reduce(0, +), BattleForms.all.count)
        XCTAssertEqual(stats.species.total, 1025)
        XCTAssertEqual(stats.forms.total, CompanionStore.collectableFormCount)
    }

    /// Graduated Pokémon count where they belong and leave the lists of the missing; a released one counts nowhere, as
    /// in the counter; a battle form won counts in its kind.
    func testWhatIsOwnedAndWhatIsMissing() throws {
        let mega = try XCTUnwrap(BattleForms.all.first { $0.kind == .mega })
        let s = try store([entry(4), entry(6), entry(150), entry(25, released: true)]) {
            $0.dungeons.battleForms = [mega.key]
        }
        let stats = s.collectionStats
        let fire = stats.tally(.cell(generation: 1, type: .fire))
        XCTAssertEqual(fire.owned, 2, "Charmander and Charizard")
        XCTAssertFalse(fire.missing.contains(.init(speciesID: 4)))
        XCTAssertTrue(fire.missing.contains(.init(speciesID: 5)), "Charmeleon still missing")
        XCTAssertEqual(stats.tally(.generation(1)).owned, 3)
        XCTAssertTrue(stats.tally(.type(.electric)).missing.contains(.init(speciesID: 25)), "released, not owned")
        XCTAssertEqual(stats.tally(.category(.legendaries)).owned, 1)
        XCTAssertEqual(stats.species.owned, s.graduatedCollectionProgress.species)
        let megas = stats.tally(.battle(.mega))
        XCTAssertEqual(megas.owned, 1)
        XCTAssertFalse(megas.missing.contains(.init(speciesID: mega.speciesID, form: mega.form)))
        XCTAssertEqual(megas.missing.count, megas.total - 1)
    }

    /// Almost done: the fewest left among the sets at least half done; a small set with none owned is not, and a
    /// complete one is gone.
    func testAlmostDoneIsHalfDoneAtLeast() throws {
        let ultraBeasts = SpeciesGoal.ultraBeasts
        let gen1 = Array(1...151)
        // Every Ultra Beast but one, every Kanto species but 10, every fossil.
        let dex = (ultraBeasts.dropLast() + gen1.dropLast(10) + SpeciesGoal.fossils).map { entry($0) }
        let stats = try store(Array(Set(dex.map(\.finalID))).sorted().map { entry($0) }).collectionStats
        let almost = stats.almostDone()
        XCTAssertEqual(almost.first, .category(.ultraBeasts), "one left")
        XCTAssertTrue(almost.contains(.generation(1)))
        XCTAssertFalse(almost.contains(.category(.fossils)), "complete")
        XCTAssertFalse(almost.contains(.battle(.primal)), "two left, none won: not almost done")
        XCTAssertTrue(almost.allSatisfy { stats.tally($0).fraction >= 0.5 && !stats.tally($0).isDone })
        let lefts = almost.map { stats.tally($0).left }
        XCTAssertEqual(lefts, lefts.sorted())
    }

    /// The screen holds in the popover's width in every language, a cell open.
    func testTheScreenFits() throws {
        let available = PopoverMetrics.width
        for language in AppLanguage.allCases {
            let s = try store([entry(4), entry(6)], language: language)
            let used = NSHostingController(rootView: CollectionStatsScreen(store: s) {})
                .sizeThatFits(in: CGSize(width: available, height: 10_000)).width
            XCTAssertLessThanOrEqual(used, available + 0.5, "\(language): \(used) pt for \(available)")
        }
    }
}
