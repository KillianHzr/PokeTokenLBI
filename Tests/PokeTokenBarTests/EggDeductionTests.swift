import XCTest
@testable import PokeTokenBar

/// "I don't remember": the egg each unknown hatch most likely came from (`HatchLuck.guessedEggs`), written as a guess the
/// player may still change.
@MainActor
final class EggDeductionTests: XCTestCase {
    private static let start = Date(timeIntervalSince1970: 1_793_534_400)   // 2026-11-01 12:00 UTC
    private static func day(_ n: Double) -> Date { start.addingTimeInterval(n * 86_400) }

    /// Commons, the last after Kanto, an uncommon and a rare, both of them Dragon.
    private let index = [BaseSpecies(id: 16, captureRate: 255), BaseSpecies(id: 10, captureRate: 255),
                         BaseSpecies(id: 263, captureRate: 255),
                         BaseSpecies(id: 610, captureRate: 75), BaseSpecies(id: 147, captureRate: 45)]
    private let dragon = HatchEgg.stone(.dragon), rare = HatchEgg.tier(.rare), uncommon = HatchEgg.tier(.uncommon)
    private var url: URL!

    private func entry(_ base: Int, day: Double, released: Bool = true, record: HatchRecord? = nil) -> DexEntry {
        var e = DexEntry(baseID: base, finalID: base, chainOrder: [base], rarity: .common, caughtAt: Self.day(day),
                         releasedAt: released ? Self.day(day) : nil)
        e.hatch = record
        return e
    }

    private func luck(_ entries: [DexEntry], stones: Int = 0, today: CompanionState = CompanionState(),
                      index: [BaseSpecies]? = nil) -> HatchLuck {
        var today = today
        if stones > 0 {
            today.claimedAchievements.insert("shinyStone")
            today.inventory["shinyStone"] = 5 - stones
        }
        return HatchLuck(entries: entries, includesActive: false, today: today, index: index ?? self.index, now: Self.day(30))
    }

    func testEachHatchTakesTheRarestShopEggItsLineAllows() {
        let entries = [entry(16, day: 1), entry(147, day: 2), entry(610, day: 3)]
        let guesses = luck(entries).guessedEggs()
        XCTAssertEqual(guesses, [entries[1].id: rare, entries[2].id: uncommon], "the first hatch and known eggs left out")
    }

    func testACommonHasNothingToGuess() {
        let entries = [entry(16, day: 1), entry(10, day: 2)]
        XCTAssertEqual(luck(entries).guessedEggs(), [:], "only the Pokémon Egg could bring it: it is sure")
    }

    /// With the Rare Egg, Dratini was the only line; with the stone, one of two. Axew is as likely from either: the stone
    /// goes to it, though Dratini came first.
    func testACountedEggGoesWhereItMakesThePokemonLikeliest() {
        let entries = [entry(16, day: 1), entry(147, day: 2), entry(610, day: 3)]
        let guesses = luck(entries, stones: 1).guessedEggs()
        XCTAssertEqual(guesses[entries[1].id], rare)
        XCTAssertEqual(guesses[entries[2].id], dragon)
    }

    /// As likely from the stone both times: it goes where the Rare Egg made Dratini the least likely, not to the oldest.
    func testTheGainIsAgainstTheShopEgg() {
        let index = self.index + [BaseSpecies(id: 131, captureRate: 45)]
        let entries = [entry(263, day: 1), entry(131, day: 2), entry(147, day: 3), entry(263, day: 4), entry(147, day: 5)]
        let guesses = luck(entries, stones: 1, index: index).guessedEggs()
        XCTAssertEqual(guesses[entries[2].id], rare, "the Rare Egg brought nothing else after the line hatched last")
        XCTAssertEqual(guesses[entries[4].id], dragon)
    }

    /// What the app noted is already off the count.
    func testARecordIsNotTakenOffTheCountTwice() {
        let entries = [entry(263, day: 1), entry(147, day: 2, record: HatchRecord(egg: dragon)), entry(263, day: 3),
                       entry(147, day: 4), entry(263, day: 5), entry(147, day: 6)]
        let guesses = luck(entries, stones: 2).guessedEggs()
        XCTAssertEqual(guesses.values.filter { $0 == dragon }.count, 1)
    }

    func testOnATieTheOldestHatchTakesIt() {
        let entries = [entry(16, day: 1), entry(147, day: 2), entry(16, day: 3), entry(147, day: 4)]
        let guesses = luck(entries, stones: 1).guessedEggs()
        XCTAssertEqual(guesses[entries[1].id], dragon)
        XCTAssertEqual(guesses[entries[3].id], rare)
    }

    func testNeverMoreThanTheCount() {
        let entries = [entry(16, day: 1), entry(147, day: 2), entry(16, day: 3), entry(147, day: 4), entry(16, day: 5),
                       entry(147, day: 6)]
        let guesses = luck(entries, stones: 2).guessedEggs()
        XCTAssertEqual(guesses.values.filter { $0 == dragon }.count, 2)
        XCTAssertEqual(guesses.values.filter { $0 == rare }.count, 1)
    }

    /// One hatch holds one egg: the second counted egg goes to the next best place.
    func testAHatchTakesOneCountedEgg() {
        var today = CompanionState()
        today.claimedEventEggs = ["pokemonDay@2026"]
        let entries = [entry(263, day: 1), entry(147, day: 2), entry(263, day: 3), entry(147, day: 4)]
        let guesses = luck(entries, stones: 1, today: today).guessedEggs()
        XCTAssertEqual(Set(guesses.values), [dragon, .event(.pokemonDay, key: nil)], "one each")
    }

    func testThePlayersWordAndAGuessTakeOffTheCount() {
        for source in [HatchRecord.Source.player, .deduced] {
            let said = HatchRecord(egg: dragon, source: source)
            let entries = [entry(16, day: 1), entry(147, day: 2, record: said), entry(16, day: 3), entry(147, day: 4)]
            let guesses = luck(entries, stones: 1).guessedEggs()
            XCTAssertEqual(guesses, [entries[3].id: rare], "the stone is taken, and what was said stays")
        }
    }

    func testAHatchTheCountSettledTakesOffTheCount() {
        var today = CompanionState()
        today.claimedEventEggs = ["companion@2025", "companion@2026"]
        let friendship = HatchEgg.event(.companion, key: nil)
        let l = luck([entry(16, day: 1), entry(16, day: 2), entry(10, day: 3), entry(16, day: 4), entry(10, day: 5),
                      entry(16, day: 6)], today: today)
        XCTAssertEqual(l.hatches[1].egg, friendship, "no other egg brings back the line hatched last")
        XCTAssertEqual(l.guessedEggs().values.filter { $0 == friendship }.count, 1, "the other is taken")
    }

    func testTheHatchSaysItIsAGuess() {
        let guess = HatchRecord(egg: rare, source: .deduced), said = HatchRecord(egg: rare, source: .player)
        let l = luck([entry(16, day: 1), entry(147, day: 2, record: guess), entry(16, day: 3), entry(147, day: 4, record: said),
                      entry(16, day: 5), entry(147, day: 6)])
        XCTAssertTrue(l.hatches[1].eggDeduced)
        XCTAssertTrue(l.hatches[1].asksEgg, "the player may change it")
        XCTAssertFalse(l.hatches[1].eggChosenByPlayer)
        XCTAssertFalse(l.hatches[3].eggDeduced)
        XCTAssertFalse(l.hatches[5].eggDeduced)
        XCTAssertFalse(l.hatches[0].eggDeduced)
    }

    func testAGuessTheCountSettlesIsNoLongerOne() {
        let guess = HatchRecord(egg: rare, source: .deduced)
        let l = luck([entry(16, day: 1), entry(10, day: 2, record: guess)])
        XCTAssertFalse(l.hatches[1].eggDeduced)
        XCTAssertEqual(l.hatches[1].egg, .tier(nil))
        let out = luck([entry(16, day: 1), entry(147, day: 2, record: HatchRecord(egg: dragon, source: .deduced))])
        XCTAssertFalse(out.hatches[1].eggDeduced, "ruled out: unknown again")
        XCTAssertNil(out.hatches[1].egg)
    }

    func testAKnownEggOffersTheOddsOfEachPossibleOne() throws {
        let dratini = try XCTUnwrap(luck([entry(16, day: 1), entry(147, day: 2)]).hatches.last)
        XCTAssertEqual(dratini.lineOddsByEgg[rare], 1)
        XCTAssertEqual(dratini.lineOddsByEgg[uncommon] ?? 0, 40.0 / 130, accuracy: 1e-12)
    }

    // MARK: The store

    private func store(active: Bool = false, _ dex: [DexEntry], _ edit: (inout CompanionState) -> Void = { _ in }) throws -> CompanionStore {
        var st = CompanionState()
        st.installBaselineSet = true
        st.lastDate = "2026-11-20"
        st.dex = dex
        if active {
            st.active = MonState(baseID: 147, pathIDs: [147], plannedPathIDs: [147, 148], stageIndex: 0, usedAtStage: 0,
                                 rarity: .rare, totalForms: 2, nature: .hardy)
        }
        edit(&st)
        url = FileManager.default.temporaryDirectory.appendingPathComponent("egg-deduction-\(UUID().uuidString).json")
        try JSONEncoder().encode(st).write(to: url)
        addTeardownBlock { [url] in try? FileManager.default.removeItem(at: url!) }
        return relaunched()
    }

    private func relaunched() -> CompanionStore {
        CompanionStore(provider: StockedProvider(index: index), clock: { Self.day(20) }, fileURL: url, difficulty: 1, writer: nil)
    }

    func testTheButtonWritesGuessesOnlyOnUnknownEggs() async throws {
        let said = HatchRecord(egg: uncommon, source: .player)
        let s = try store(active: true, [entry(16, day: 1), entry(147, day: 2), entry(16, day: 3), entry(147, day: 4, record: said),
                                         entry(16, day: 5)])
        await s.loadHatchLuck()
        s.deduceUnknownEggs()
        XCTAssertEqual(s.state.dex[1].hatch, HatchRecord(egg: rare, source: .deduced))
        XCTAssertEqual(s.state.dex[3].hatch, said, "the player's word is left alone")
        XCTAssertEqual(s.state.active?.hatch, HatchRecord(egg: rare, source: .deduced), "the Pokémon raised")
        XCTAssertEqual(relaunched().state.dex[1].hatch?.source, .deduced, "written in the save")
    }

    func testCorrectingAGuessMakesItThePlayersWord() async throws {
        let s = try store([entry(16, day: 1), entry(147, day: 2)])
        await s.loadHatchLuck()
        s.deduceUnknownEggs()
        s.chooseHatchEgg(uncommon, forEntry: s.state.dex[1].id)
        XCTAssertEqual(s.state.dex[1].hatch, HatchRecord(egg: uncommon, source: .player))
        await s.loadHatchLuck()
        s.deduceUnknownEggs()
        XCTAssertEqual(s.state.dex[1].hatch?.source, .player, "the button no longer touches it")
    }

    func testNothingToGuessWritesNothing() async throws {
        let s = try store([entry(16, day: 1), entry(10, day: 2)])
        s.deduceUnknownEggs()
        await s.loadHatchLuck()
        try FileManager.default.removeItem(at: url)
        s.deduceUnknownEggs()
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
    }
}

private struct StockedProvider: PokeProviding {
    struct Nope: Error {}
    let index: [BaseSpecies]
    func line(baseSpeciesID: Int) async throws -> EvoLine { throw Nope() }
    func baseSpeciesIndex() async throws -> [BaseSpecies] { index }
}
