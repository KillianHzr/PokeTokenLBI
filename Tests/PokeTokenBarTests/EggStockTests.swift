import XCTest
@testable import PokeTokenBar

/// What the Bag's counts say of the eggs no record names (`EggStock`).
final class EggStockTests: XCTestCase {
    private static let start = Date(timeIntervalSince1970: 1_793_534_400)   // 2026-11-01 12:00 UTC
    private static func day(_ n: Double) -> Date { start.addingTimeInterval(n * 86_400) }

    private func entry(_ base: Int, _ chain: [Int]? = nil, day: Double, released: Bool = false,
                       record: HatchRecord? = nil) -> DexEntry {
        let chain = chain ?? [base]
        var e = DexEntry(baseID: base, finalID: chain.last!, chainOrder: chain, rarity: .common, caughtAt: Self.day(day),
                         releasedAt: released ? Self.day(day) : nil)
        e.hatch = record
        return e
    }

    private func raising() -> MonState {
        MonState(baseID: 37, pathIDs: [37], plannedPathIDs: [37, 38], stageIndex: 0, usedAtStage: 0, rarity: .uncommon,
                 totalForms: 1, nature: .hardy)
    }

    private func slot(_ possible: [HatchEgg], said: HatchEgg? = nil, started: Double? = nil) -> EggStock.Slot {
        EggStock.Slot(started: started.map(Self.day), possible: possible, egg: said)
    }

    private let rare = HatchEgg.tier(.rare), plain = HatchEgg.tier(nil)
    private let fire = HatchEgg.stone(.fire), water = HatchEgg.stone(.water)
    private let autumn = HatchEgg.event(.autumn, key: nil)

    // MARK: The counts

    func testWhatLeftTheBag() {
        var s = CompanionState()
        s.active = raising()
        s.claimedAchievements = ["fireStone", "typeNullEgg", "legendaryEgg@1", "legendaryEgg@2", "excavation@1", "shinyCharm"]
        s.inventory = ["fireStone": 3, "legendaryEgg": 1, "fossilEgg": 0, "autumnEgg": 1]
        s.claimedEventEggs = ["autumn@2026", "halloween@2025", "halloween@2026"]
        s.lastBirthdayGiftYear = 2026
        let used = EggStock.used(in: s)
        XCTAssertEqual(used[fire], 2, "five for each claim")
        XCTAssertEqual(used[water], 0, "not claimed")
        XCTAssertEqual(used[.typeNull], 1)
        XCTAssertEqual(used[.legendary], 1, "one for each region")
        XCTAssertEqual(used[.birthday], 1)
        XCTAssertEqual(used[autumn], 0, "still in the Bag")
        XCTAssertEqual(used[.event(.halloween, key: nil)], 2, "one for each year")
        XCTAssertEqual(used[.event(.christmas, key: nil)], 0)
        XCTAssertNil(used[.fossil], "a Fossil Egg comes back: never counted")
        XCTAssertNil(used[plain], "the Shop's are not counted")
        XCTAssertNil(used[rare])
        s.inventory["birthdayEgg"] = 1
        XCTAssertEqual(EggStock.used(in: s)[.birthday], 0)
        s.lastBirthdayGiftYear = nil
        s.inventory["birthdayEgg"] = 0
        XCTAssertEqual(EggStock.used(in: s)[.birthday], 0)
        s.inventory["fireStone"] = 9
        XCTAssertEqual(EggStock.used(in: s)[fire], 0, "never below zero")
    }

    /// What the app noted, the journal read and the egg incubating are not left to find.
    func testRecordsAndTheIncubatingEggComeOffTheCount() {
        var s = CompanionState()
        s.active = raising()
        s.claimedEventEggs = ["autumn@2026"]
        s.claimedAchievements = ["fireStone"]
        let entries = [entry(16, day: 1, record: HatchRecord(egg: .event(.autumn, key: "autumn@2026"))),
                       entry(10, day: 2, record: HatchRecord(egg: fire)),
                       entry(19, day: 3, record: HatchRecord(egg: fire, source: .journal)),
                       entry(21, day: 4, record: HatchRecord(egg: fire, source: .player)),
                       entry(23, day: 5, record: HatchRecord(egg: fire, source: .deduced))]
        var stock = EggStock(today: s, entries: entries)
        XCTAssertEqual(stock.left[autumn], 0, "a claim's key names the same egg")
        XCTAssertEqual(stock.left[fire], 3, "the player's word is not a record")
        s.claimedEventEggs = []
        stock = EggStock(today: s, entries: entries)
        XCTAssertEqual(stock.left[autumn], 0, "the surplus is left out")
        s.active = nil
        s.eggTypeGuarantee = .fire
        XCTAssertEqual(EggStock(today: s, entries: entries).left[fire], 2, "the egg incubating")
        s.active = raising()
        XCTAssertEqual(EggStock(today: s, entries: entries).left[fire], 3, "a leftover of no egg")
    }

    func testWhenADatedEggCouldFirstBeUsed() throws {
        var s = CompanionState()
        s.active = raising()
        s.claimedEventEggs = ["autumn@2026", "autumn@2025", "christmas@2030"]
        let at = Self.day(-3)
        s.lastBirthdayGiftClaimedAt = at
        let stock = EggStock(today: s, entries: [entry(16, day: 1)])
        let calendar = LocalUsageReader.gregorianCalendar()
        XCTAssertEqual(stock.earliest[.birthday], at)
        XCTAssertEqual(stock.earliest[autumn], EventEgg.autumn.days(in: 2025, firstCatch: nil, calendar: calendar)?.start)
        XCTAssertEqual(stock.earliest[.event(.christmas, key: nil)],
                       EventEgg.christmas.days(in: 2030, firstCatch: nil, calendar: calendar)?.start)
        XCTAssertNil(stock.earliest[.event(.easter, key: nil)])
    }

    // MARK: What the counts settle

    private func stock(_ left: [HatchEgg: Int], earliest: [HatchEgg: Date] = [:], floors: Set<HatchEgg> = []) -> EggStock {
        EggStock(left: left, earliest: earliest, floors: floors)
    }

    func testAnEggNoneOfLeavesTheLists() {
        let out = stock([fire: 0]).settle([slot([plain, rare, fire]), slot([plain, fire], said: fire)])
        XCTAssertEqual(out[0].possible, [plain, rare])
        XCTAssertNil(out[0].egg)
        XCTAssertFalse(out[0].isSure)
        XCTAssertEqual(out[1].possible, [plain], "the only one left is sure")
        XCTAssertEqual(out[1].egg, plain, "the player's word gives way")
        XCTAssertTrue(out[1].isSure)
    }

    /// Something brought it: an egg that would leave no other stays.
    func testAnEggThatWouldEmptyAListStays() {
        let out = stock([fire: 0, water: 0]).settle([slot([fire, water])])
        XCTAssertEqual(out[0].possible.count, 1, "down to one, which is sure")
        XCTAssertTrue(out[0].isSure)
    }

    func testAsManyEggsAsHatchesMakesThemSure() {
        let out = stock([fire: 2]).settle([slot([plain, fire]), slot([plain, fire], said: plain), slot([plain])])
        XCTAssertEqual(out.map(\.egg), [fire, fire, plain], "even against the player's word")
        XCTAssertEqual(out.map(\.isSure), [true, true, true])
    }

    func testMoreEggsThanHatchesLeaveTheSurplusOut() {
        let out = stock([fire: 5]).settle([slot([plain, fire])])
        XCTAssertEqual(out[0].egg, fire)
        XCTAssertTrue(out[0].isSure)
    }

    func testFewerEggsThanHatchesSettleNothing() {
        let out = stock([fire: 1]).settle([slot([plain, fire]), slot([rare, fire], said: fire)])
        XCTAssertEqual(out.map(\.isSure), [false, false])
        XCTAssertEqual(out[0].possible, [plain, fire])
        XCTAssertNil(out[0].egg)
        XCTAssertEqual(out[1].egg, fire, "the player's word stands")
    }

    /// Each hatch settled takes its egg off the count, which may settle the next.
    func testASureHatchTakesItsEggOffTheCount() {
        let out = stock([fire: 1, water: 1]).settle([slot([fire]), slot([plain, fire]), slot([plain, water])])
        XCTAssertEqual(out[0].egg, fire)
        XCTAssertEqual(out[1].possible, [plain], "the one fire stone went to the first")
        XCTAssertEqual(out[1].egg, plain)
        XCTAssertEqual(out[2].egg, water)
    }

    func testAnEggIsNotUsedBeforeItsDate() {
        let out = stock([autumn: 2], earliest: [autumn: Self.day(5)]).settle([
            slot([plain, autumn], started: 4), slot([plain, autumn], started: 6), slot([autumn], started: 1),
        ])
        XCTAssertEqual(out[0].possible, [plain], "the egg was not out yet")
        XCTAssertEqual(out[1].egg, autumn, "the only one left to have it")
        XCTAssertEqual(out[2].possible, [autumn], "something brought it")
    }

    func testAnEggWithoutADateStaysWhateverTheStart() {
        let out = stock([autumn: 1], earliest: [autumn: Self.day(5)]).settle([slot([plain, autumn], started: 6),
                                                                              slot([rare, autumn], started: 6)])
        XCTAssertEqual(out.map(\.possible), [[plain, autumn], [rare, autumn]])
        XCTAssertEqual(out.map(\.isSure), [false, false])
    }

    func testAnEggUsedTheMomentItCameCounts() {
        let out = stock([autumn: 1], earliest: [autumn: Self.day(5)]).settle([slot([plain, autumn], started: 5)])
        XCTAssertEqual(out[0].egg, autumn)
    }

    func testAHatchOfUnknownStartKeepsADatedEgg() {
        let out = stock([autumn: 2], earliest: [autumn: Self.day(5)]).settle([slot([plain, autumn])])
        XCTAssertEqual(out[0].egg, autumn)
    }

    func testAnEggFromElsewhereStaysPossibleButSureWhenCountReaches() {
        let legendary = HatchEgg.legendary
        var out = stock([legendary: 0], floors: [legendary]).settle([slot([plain, legendary])])
        XCTAssertEqual(out[0].possible, [plain, legendary], "the Explorer Kit may have dug one up")
        out = stock([legendary: 1], floors: [legendary]).settle([slot([plain, legendary])])
        XCTAssertEqual(out[0].egg, legendary, "the count is at least that")
    }

    func testAFossilEggIsNotUsedOnAFossilEggsPokemon() {
        let out = stock([:]).settle([slot([.fossil]), slot([.fossil, plain]), slot([.fossil])])
        XCTAssertEqual(out[0].egg, .fossil)
        XCTAssertEqual(out[1].egg, plain)
        XCTAssertEqual(out[2].egg, .fossil, "after a Pokémon Egg")
        let noted = EggStock.Slot(started: nil, possible: [], egg: .fossil, asked: false)
        let after = stock([:]).settle([noted, slot([.fossil])])
        XCTAssertEqual(after[1].possible, [], "nothing else could bring it")
        XCTAssertNil(after[1].egg)
    }

    func testAHatchNotAskedStaysAsItIs() {
        let noted = EggStock.Slot(started: nil, possible: [], egg: fire, asked: false)
        let out = stock([fire: 0]).settle([noted])
        XCTAssertEqual(out[0].egg, fire)
        XCTAssertFalse(out[0].isSure)
    }

    func testTheKitMakesTheLegendaryCountAFloor() {
        var s = CompanionState()
        s.active = raising()
        XCTAssertEqual(EggStock(today: s, entries: []).floors, [])
        s.inventory[ItemKind.explorerKit.rawValue] = 1
        XCTAssertEqual(EggStock(today: s, entries: []).floors, [.legendary])
    }

    // MARK: The replay

    /// A common only the Pokémon Egg admits, unless a stone came; a rare the Shop's three eggs admit.
    private let index = [BaseSpecies(id: 16, captureRate: 255), BaseSpecies(id: 25, captureRate: 190),
                         BaseSpecies(id: 147, captureRate: 45)]

    private func replay(_ today: CompanionState, _ entries: [DexEntry], active: Bool = false) -> HatchLuck {
        HatchLuck(entries: entries, includesActive: active, today: today, index: index, now: Self.day(30))
    }

    func testAStoneOnlyOneHatchCouldHaveUsedCountsWithoutAsking() throws {
        var s = CompanionState()
        s.claimedAchievements = ["thunderStone"]
        s.inventory = ["thunderStone": 4]
        let l = replay(s, [entry(16, day: 1, released: true), entry(25, day: 2)])
        let pikachu = try XCTUnwrap(l.hatches.last)
        XCTAssertEqual(pikachu.egg, .stone(.electric))
        XCTAssertFalse(pikachu.asksEgg)
        XCTAssertNotNil(pikachu.lineOdds)
    }

    func testAStoneNeverClaimedIsNotOffered() throws {
        let l = replay(CompanionState(), [entry(16, day: 1, released: true), entry(147, day: 2)])
        let dratini = try XCTUnwrap(l.hatches.last)
        XCTAssertNil(dratini.egg)
        XCTAssertTrue(dratini.asksEgg)
        XCTAssertFalse(dratini.possibleEggs.contains(.stone(.dragon)))
        XCTAssertTrue(dratini.possibleEggs.contains(.tier(nil)))
    }

    func testACommonNoSpecialEggCouldBringIsAPokemonEgg() throws {
        let l = replay(CompanionState(), [entry(16, day: 1, released: true), entry(25, day: 2)])
        let pikachu = try XCTUnwrap(l.hatches.last)
        XCTAssertEqual(pikachu.egg, .tier(nil))
        XCTAssertFalse(pikachu.asksEgg)
    }

    /// Claimed after this hatch started, the egg of an event was not it, however many are out of the Bag.
    func testAClaimAfterTheHatchIsNotItsEgg() throws {
        var s = CompanionState()
        s.claimedEventEggs = ["pokemonDay@2027"]
        let dratini = try XCTUnwrap(replay(s, [entry(16, day: 1, released: true), entry(147, day: 2)]).hatches.last)
        XCTAssertNil(dratini.egg)
        XCTAssertFalse(dratini.possibleEggs.contains(.event(.pokemonDay, key: nil)))
    }

    func testAChoiceTheCountRulesOutBecomesUnknown() throws {
        let said = HatchRecord(egg: .stone(.dragon), source: .player)
        let l = replay(CompanionState(), [entry(16, day: 1, released: true), entry(147, day: 2, record: said)])
        let dratini = try XCTUnwrap(l.hatches.last)
        XCTAssertNil(dratini.egg)
        XCTAssertFalse(dratini.eggChosenByPlayer)
        XCTAssertTrue(dratini.asksEgg)
    }

    func testAnEggTheJournalNamedAsksNothingAndTakesItsItemsFromTheirDates() throws {
        let read = HatchRecord(egg: .tier(nil), source: .journal)
        let l = HatchLuck(entries: [entry(16, day: 1, released: true), entry(25, day: 2, record: read)], includesActive: false,
                          today: CompanionState(), index: index, itemsSince: [.shinyCharm: Self.day(0)], now: Self.day(30))
        let pikachu = try XCTUnwrap(l.hatches.last)
        XCTAssertEqual(pikachu.egg, .tier(nil))
        XCTAssertFalse(pikachu.asksEgg)
        XCTAssertTrue(pikachu.possibleEggs.isEmpty)
        XCTAssertEqual(pikachu.judged[.shiny]?.odds ?? 0, 1.0 / 48, accuracy: 1e-12)
    }

    /// An event egg with none of its Pokémon in the pool hatches as a plain egg: it can bring what a plain egg brings.
    func testAnEventEggWithoutAPoolCanBringAPlainLine() throws {
        var s = CompanionState()
        s.claimedEventEggs = ["easter@2026"]
        let l = replay(s, [entry(16, day: 1, released: true), entry(25, day: 2)])
        XCTAssertEqual(l.hatches.last?.egg, .event(.easter, key: nil))
    }
}
