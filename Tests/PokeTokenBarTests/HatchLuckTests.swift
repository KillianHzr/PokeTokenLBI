import XCTest
@testable import PokeTokenBar

/// The Luck screen's replay (`HatchLuck`), on Pokédexes built by hand with odds known in advance.
final class HatchLuckTests: XCTestCase {
    private static let start = Date(timeIntervalSince1970: 1_790_000_000)
    private static func day(_ n: Double) -> Date { start.addingTimeInterval(n * 86_400) }

    /// Two three-stage commons (212 each), a rare (40) and a legendary (3): 467 in all.
    private let index = [BaseSpecies(id: 16, captureRate: 255), BaseSpecies(id: 10, captureRate: 255),
                         BaseSpecies(id: 147, captureRate: 45), BaseSpecies(id: 243, captureRate: 3, isUnbreedableLegendary: true)]

    private func entry(_ base: Int, _ chain: [Int]? = nil, day: Double, released: Bool = false, shiny: Bool = false,
                       record: HatchRecord? = nil) -> DexEntry {
        let chain = chain ?? [base]
        var e = DexEntry(baseID: base, finalID: chain.last!, chainOrder: chain, rarity: .common,
                         caughtAt: Self.day(day), isShiny: shiny, releasedAt: released ? Self.day(day) : nil)
        e.hatch = record
        return e
    }

    private func luck(_ entries: [DexEntry], active: Bool = false, index: [BaseSpecies]? = nil,
                      itemsSince: [ItemKind: Date] = [:]) -> HatchLuck {
        HatchLuck(entries: entries, includesActive: active, today: CompanionState(), index: index ?? self.index,
                  itemsSince: itemsSince, now: Self.day(30))
    }

    /// Of equally placed players, those who did worse, half of those who did as well.
    func testPercentileCountsTiesHalf() {
        XCTAssertEqual(HatchLuck.percentile(odds: [0.5, 0.5], hits: 1), 0.5, accuracy: 1e-12)
        XCTAssertEqual(HatchLuck.percentile(odds: [0.1], hits: 1), 0.95, accuracy: 1e-12)
        XCTAssertEqual(HatchLuck.percentile(odds: [0.1], hits: 0), 0.45, accuracy: 1e-12)
        XCTAssertEqual(HatchLuck.percentile(odds: [0.5, 0.5], hits: 2), 0.875, accuracy: 1e-12)
        XCTAssertEqual(HatchLuck.percentile(odds: [], hits: 0), 0.5, accuracy: 1e-12)
        XCTAssertEqual(HatchLuck.percentile(odds: [0], hits: 1), 1, accuracy: 1e-12, "a hit the odds left out")
    }

    func testARarityIsJudgedAtTheRollsOdds() throws {
        let l = luck([entry(147, day: 1)])
        let h = try XCTUnwrap(l.hatches.first)
        XCTAssertEqual(h.egg, .tier(nil), "the first egg is a Pokémon Egg")
        XCTAssertEqual(h.rarityOdds, .init(low: 40.0 / 467, high: 40.0 / 467))
        XCTAssertEqual(h.lineOdds ?? 0, 40.0 / 467, accuracy: 1e-12)
        XCTAssertEqual(h.judged[.rare], .init(odds: 40.0 / 467, hit: true))
        XCTAssertEqual(h.judged[.uncommon], .init(odds: 0, hit: false))
        XCTAssertEqual(h.judged[.legendary], .init(odds: 3.0 / 467, hit: false))
        XCTAssertEqual(h.judged[.shiny], .init(odds: 1.0 / 64, hit: false))
        let ditto = try XCTUnwrap(h.judged[.ditto])
        XCTAssertEqual(ditto.odds, 424.0 / 467 / 128, accuracy: 1e-12, "hidden in an evolving common")
        let rare = try XCTUnwrap(l.criteria.first { $0.criterion == .rare })
        XCTAssertEqual(rare.hits, 1)
        XCTAssertEqual(rare.expected, 40.0 / 467, accuracy: 1e-12)
        XCTAssertEqual(rare.percentile, 1 - 40.0 / 467 / 2, accuracy: 1e-12)
    }

    /// Each hatch is judged against the Pokédex of its moment: a line hatched last is left out of the next egg, a line
    /// whose every final graduated weighs half.
    func testEachHatchMeetsThePokedexOfItsMoment() throws {
        let l = luck([entry(16, [16, 17, 18], day: 1), entry(147, day: 2), entry(10, day: 3)])
        XCTAssertEqual(l.hatches[1].lineOdds ?? 0, 40.0 / 255, accuracy: 1e-12, "no Pidgey right after one")
        XCTAssertEqual(l.hatches[2].lineOdds ?? 0, 212.0 / 321, accuracy: 1e-12, "Pidgey halved, no Dratini")
        XCTAssertEqual(l.criteria.first { $0.criterion == .rare }?.sinceLast, 1)
        XCTAssertNil(l.criteria.first { $0.criterion == .legendary }?.sinceLast)
    }

    /// Something new is judged on what hatched, not on what it became: a Poliwag after a Poliwrath still has Politoed.
    func testSomethingNewCountsEveryBranch() throws {
        let index = self.index + [BaseSpecies(id: 60, captureRate: 255)]
        let open = luck([entry(60, [60, 61, 62], day: 1), entry(60, day: 2)], active: true, index: index)
        XCTAssertTrue(open.hatches[1].isActive)
        XCTAssertEqual(open.hatches[1].judged[.new]?.hit, true)
        let done = luck([entry(60, [60, 61, 62], day: 1), entry(60, [60, 61, 186], day: 2), entry(60, day: 3)],
                        active: true, index: index)
        XCTAssertEqual(done.hatches[1].judged[.new]?.hit, true)
        XCTAssertEqual(done.hatches[2].judged[.new]?.hit, false)
        let odds = try XCTUnwrap(done.hatches[2].judged[.new]?.odds)
        XCTAssertEqual(odds, 467.0 / 573, accuracy: 1e-12, "all but Poliwag, halved")
        XCTAssertEqual(done.hatches[2].newOdds, .init(low: 1 - odds, high: 1 - odds), "the odds of nothing new")
    }

    /// After a release, the egg the record does not name is unknown: only the shiny judges it, and its odds span the
    /// eggs that could have brought it.
    func testAnUnknownEggOnlyCountsForTheShiny() throws {
        let l = luck([entry(16, day: 1, released: true), entry(147, day: 2)])
        let h = l.hatches[1]
        XCTAssertNil(h.egg)
        XCTAssertEqual(Set(h.judged.keys), [.shiny])
        XCTAssertNil(h.lineOdds)
        XCTAssertTrue(h.possibleEggs.contains(.tier(nil)))
        XCTAssertTrue(h.possibleEggs.contains(.tier(.rare)))
        XCTAssertFalse(h.possibleEggs.contains(.legendary))
        XCTAssertFalse(h.possibleEggs.contains(.typeNull))
        XCTAssertEqual(h.rarityOdds.low, 40.0 / 255, accuracy: 1e-12)
        XCTAssertGreaterThanOrEqual(h.rarityOdds.high, 40.0 / 43)
        XCTAssertEqual(l.hatches[0].egg, .tier(nil))
    }

    func testAnEggThePlayerChoseCountsEverywhere() throws {
        let chosen = HatchRecord(egg: .tier(.rare), chosenByPlayer: true)
        let l = luck([entry(16, day: 1, released: true), entry(147, day: 2, record: chosen)])
        let h = l.hatches[1]
        XCTAssertEqual(h.egg, .tier(.rare))
        XCTAssertTrue(h.eggChosenByPlayer)
        XCTAssertEqual(Set(h.judged.keys), Set(HatchLuck.Criterion.allCases))
        XCTAssertEqual(h.judged[.rare], .init(odds: 40.0 / 43, hit: true))
    }

    /// Without a record, a draw item counts from the date the player gave for it, for the eggs started after.
    func testADatedItemCountsForTheEggsStartedAfter() {
        let l = luck([entry(16, day: 1), entry(10, day: 3), entry(147, day: 4)], active: true,
                     itemsSince: [.shinyCharm: Self.day(2)])
        for (h, odds) in zip(l.hatches, [1.0 / 64, 1.0 / 64, 1.0 / 48]) {
            XCTAssertEqual(h.judged[.shiny]?.odds ?? 0, odds, accuracy: 1e-12, "hatch \(h.number)")
        }
    }

    /// A record's items: those of the species roll for the pool, those of the hatch for the shiny.
    func testARecordsItemsAreTheRolls() throws {
        let record = HatchRecord(egg: .tier(nil), rollItems: [.legendCharm], hatchItems: [.shinyCharm])
        let h = try XCTUnwrap(luck([entry(243, day: 1, record: record)]).hatches.first)
        XCTAssertEqual(h.lineOdds ?? 0, 6.0 / 470, accuracy: 1e-12, "the Azure Flute doubles a legendary")
        XCTAssertEqual(h.judged[.shiny]?.odds ?? 0, 1.0 / 48, accuracy: 1e-12)
        XCTAssertEqual(h.judged[.legendary]?.hit, true)
    }

    func testARevealedDittoIsJudgedAsADitto() throws {
        let h = try XCTUnwrap(luck([entry(PokemonOdds.dittoSpeciesID, day: 1)]).hatches.first)
        XCTAssertTrue(h.isDitto)
        XCTAssertEqual(h.judged[.ditto]?.hit, true)
        XCTAssertEqual(h.rarityOdds.low, 424.0 / 467 / 128, accuracy: 1e-12)
        XCTAssertEqual(h.judged[.rare]?.hit, false)
        XCTAssertEqual(h.judged[.uncommon]?.hit, false)
        XCTAssertNil(h.judged[.new])
        XCTAssertNil(h.newOdds)
    }

    /// The score after each hatch is the mean of the six percentiles then; each hatch's effect is what it moved.
    func testScoreAfterEachHatchAndItsEffect() {
        let l = luck([entry(16, day: 1, shiny: true), entry(147, day: 2), entry(10, day: 3)])
        XCTAssertEqual(l.hatches.count, 3)
        for h in l.hatches {
            XCTAssertEqual(h.percentiles.count, 6)
            XCTAssertEqual(h.score, h.percentiles.values.reduce(0, +) / 6 * 100, accuracy: 1e-9)
        }
        XCTAssertEqual(l.hatches.last?.score ?? 0, l.score, accuracy: 1e-9)
        XCTAssertEqual(l.hatches[0].effect, l.hatches[0].score - 50, accuracy: 1e-9)
        XCTAssertEqual(l.hatches[2].effect, l.hatches[2].score - l.hatches[1].score, accuracy: 1e-9)
        XCTAssertGreaterThan(l.hatches[0].effect, 0, "a shiny at 1 in 64")
    }

    /// The draws least likely, from eggs known, rarest first.
    func testImprobableDraws() {
        let l = luck([entry(243, day: 1), entry(16, day: 2, released: true), entry(147, day: 3), entry(10, day: 4),
                      entry(147, day: 5)])
        XCTAssertEqual(l.improbable.map(\.number), [1, 5, 2], "not the third, whose egg is unknown")
        XCTAssertEqual(l.hatchesPerWeek ?? 0, 5 / (29.0 / 7), accuracy: 1e-9)
    }

    /// The eggs an unknown hatch may have come from are exactly those whose draw holds its line: the quick check that
    /// spares the others' odds leaves none out.
    func testPossibleEggsAreThoseWhoseDrawHoldsTheLine() {
        let index = RosterProvider.entries
        var seen = Set<HatchEgg>()
        let bagEggs = ItemKind.allCases.compactMap(HatchEgg.init(item:)).filter { seen.insert($0).inserted }
        let before = [entry(52, [52, 53], day: 1), entry(138, [138, 139], day: 2), entry(16, day: 3, released: true)]
        var collection = CompanionState()
        collection.dex = before
        collection.collectedFinals = ["52:53", "138:139"]
        collection.lastHatchedBaseID = 16
        let draw = HatchDraw(collection: collection, items: [.ovalCharm])
        for species in index where species.id != 16 {
            let l = HatchLuck(entries: before + [entry(species.id, day: 4)], includesActive: false, today: CompanionState(),
                              index: index, itemsSince: [.ovalCharm: Self.day(0)], now: Self.day(5))
            let expected = bagEggs.filter { egg in draw.outcomes(egg, index: index).contains { $0.id == species.id } }
            XCTAssertEqual(l.hatches[3].possibleEggs, expected, "#\(species.id)")
        }
    }
}
