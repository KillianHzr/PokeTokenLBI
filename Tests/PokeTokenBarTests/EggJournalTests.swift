import XCTest
@testable import PokeTokenBar

/// The eggs the app's log names (`EggJournal`), and how they reach the save: every format the writer ever had, each
/// line tied to the release it came with.
@MainActor
final class EggJournalTests: XCTestCase {
    private static let now = Date(timeIntervalSince1970: 1_793_534_400)   // 2026-11-01 12:00 UTC
    private var url: URL!

    private func at(_ hours: Double) -> Date { Self.now.addingTimeInterval(-hours * 3_600) }

    private func line(_ date: Date, _ message: String) -> String {
        "[\(ISO8601DateFormatter().string(from: date))] \(message)"
    }

    private func entry(_ base: Int, hours: Double, released: Bool = false, record: HatchRecord? = nil) -> DexEntry {
        var e = DexEntry(baseID: base, finalID: base, chainOrder: [base], rarity: .common, caughtAt: at(hours),
                         releasedAt: released ? at(hours) : nil)
        e.hatch = record
        return e
    }

    private func store(active: HatchRecord?? = .none, _ dex: [DexEntry]) throws -> CompanionStore {
        var st = CompanionState()
        st.installBaselineSet = true
        st.lastDate = "2026-10-31"
        st.dex = dex
        if let active {
            st.active = MonState(baseID: 37, pathIDs: [37], plannedPathIDs: [37, 38], stageIndex: 0, usedAtStage: 0,
                                 rarity: .uncommon, totalForms: 1, nature: .hardy)
            st.active?.hatch = active
        }
        url = FileManager.default.temporaryDirectory.appendingPathComponent("egg-journal-\(UUID().uuidString).json")
        try JSONEncoder().encode(st).write(to: url)
        addTeardownBlock { [url] in try? FileManager.default.removeItem(at: url!) }
        return relaunched()
    }

    private func relaunched() -> CompanionStore {
        CompanionStore(provider: RosterProvider(), clock: { Self.now }, fileURL: url, difficulty: 1, writer: nil)
    }

    func testEveryLineFormatTheWriterEverHad() {
        let t = Self.now
        let cases: [(String, HatchEgg)] = [
            ("bag egg used: rareEgg, discarded active, tier=rare", .tier(.rare)),
            ("bag egg used: uncommonEgg, discarded active, tier=uncommon", .tier(.uncommon)),
            ("bag egg used: pokemonEgg, discarded active, tier=none", .tier(nil)),
            ("egg purchased: discarded active, tier=rare", .tier(.rare)),
            ("egg purchased: discarded active, tier=none", .tier(nil)),
            ("fresh egg: discarded active, reverted to egg", .tier(nil)),
            ("stone used: fireStone, discarded active, type=fire", .stone(.fire)),
            ("stone purchased: leafStone, discarded active, type=grass", .stone(.grass)),
            ("type null egg used, discarded active", .typeNull),
            ("legendary egg used, discarded active", .legendary),
            ("birthday egg used, discarded active", .birthday),
            ("fossil egg used, discarded active", .fossil),
            ("event egg used: autumn, discarded active", .event(.autumn, key: nil)),
        ]
        for (message, egg) in cases {
            let journal = EggJournal(text: line(t, message))
            XCTAssertEqual(journal.uses, [.init(at: t, egg: egg)], message)
        }
    }

    func testLinesThatNameNoUseAreLeftOut() {
        let t = Self.now
        let text = [
            "egg purchased: rareEgg ×2 to the bag",
            "event egg claimed: autumn@2026",
            "hatch: base=328 rarity=common shiny=false forms=3 boost=true ditto=false form=none",
            "stone used: fireStone, discarded active, type=notAType",
            "event egg used: notAnEvent, discarded active",
            "bag egg used: rareEgg, discarded active, tier=notATier",
            "something else, discarded active",
            "hatch roll: base=5 ditto=true",
        ].map { line(t, $0) }.joined(separator: "\n") + """

            no bracket, discarded active
            [not a date] fossil egg used, discarded active
            x2026-11-01T12:00:00Z] fossil egg used, discarded active

            """
        let journal = EggJournal(text: text)
        XCTAssertEqual(journal.uses, [])
        XCTAssertEqual(journal.disguises, [])
    }

    func testADittoHatchNamesItsDisguise() {
        let t = Self.now
        let journal = EggJournal(text: [
            line(t, "hatch: base=328 rarity=common shiny=false forms=3 boost=true ditto=true form=none"),
            line(t, "hatch: base=16 rarity=common shiny=false forms=3 boost=true ditto=false form=none"),
            line(t, "hatch: base index unavailable, REST fallback"),
        ].joined(separator: "\n"))
        XCTAssertEqual(journal.disguises, [.init(at: t, baseID: 328)])
    }

    /// The log line comes right after the release: the same second, or the next.
    func testAnEggGoesToTheHatchAfterItsRelease() throws {
        let s = try store(active: .some(nil), [entry(16, hours: 9, released: true), entry(10, hours: 8),
                                               entry(19, hours: 7, released: true), entry(21, hours: 6),
                                               entry(23, hours: 5, released: true)])
        s.absorb(EggJournal(text: [
            line(at(9), "bag egg used: rareEgg, discarded active, tier=rare"),
            line(at(7).addingTimeInterval(1), "fossil egg used, discarded active"),
            line(at(5), "event egg used: autumn, discarded active"),
        ].joined(separator: "\n")))
        XCTAssertEqual(s.state.dex[1].hatch, HatchRecord(egg: .tier(.rare), source: .journal))
        XCTAssertEqual(s.state.dex[3].hatch, HatchRecord(egg: .fossil, source: .journal))
        XCTAssertEqual(s.state.active?.hatch, HatchRecord(egg: .event(.autumn, key: nil), source: .journal),
                       "the Pokémon raised, after the last release")
        XCTAssertNil(s.state.dex[0].hatch)
        XCTAssertEqual(relaunched().state.dex[1].hatch?.egg, .tier(.rare), "written in the save")
    }

    func testALineTiedToNoReleaseIsLeftOut() throws {
        let s = try store([entry(16, hours: 9, released: true), entry(10, hours: 8), entry(19, hours: 7)])
        s.absorb(EggJournal(text: [
            line(at(9).addingTimeInterval(2), "fossil egg used, discarded active"),
            line(at(9).addingTimeInterval(-1), "fossil egg used, discarded active"),
            line(at(7), "fossil egg used, discarded active"),
        ].joined(separator: "\n")))
        XCTAssertEqual(s.state.dex.map(\.hatch), [nil, nil, nil], "two seconds off, or a graduation's")
    }

    /// The same second wins over the next one, the release before it.
    func testTheExactSecondWinsOverTheNextOne() throws {
        let oneSecondLater = DexEntry(baseID: 10, finalID: 10, chainOrder: [10], rarity: .common, caughtAt: at(8),
                                      releasedAt: at(9).addingTimeInterval(1))
        let s = try store([entry(16, hours: 9, released: true), oneSecondLater, entry(19, hours: 7)])
        s.absorb(EggJournal(text: line(at(9).addingTimeInterval(1), "fossil egg used, discarded active")))
        XCTAssertNil(s.state.dex[1].hatch)
        XCTAssertEqual(s.state.dex[2].hatch?.egg, .fossil)
    }

    func testTheJournalReplacesOnlyWhatIsNotARecord() throws {
        let noted = HatchRecord(egg: .tier(nil), hatchItems: [.shinyCharm])
        let read = HatchRecord(egg: .legendary, source: .journal)
        let s = try store([entry(16, hours: 12, released: true), entry(10, hours: 11, released: true, record: noted),
                           entry(19, hours: 10, released: true, record: read),
                           entry(21, hours: 9, released: true, record: HatchRecord(egg: .tier(.rare), source: .player)),
                           entry(23, hours: 8, released: true, record: HatchRecord(egg: .tier(.rare), source: .deduced)),
                           entry(25, hours: 7)])
        s.absorb(EggJournal(text: [12, 11, 9, 8].map { line(at($0), "fossil egg used, discarded active") }
            .joined(separator: "\n")))
        XCTAssertEqual(s.state.dex[1].hatch, noted)
        XCTAssertEqual(s.state.dex[2].hatch, read)
        XCTAssertEqual(s.state.dex[4].hatch, HatchRecord(egg: .fossil, source: .journal))
        XCTAssertEqual(s.state.dex[5].hatch, HatchRecord(egg: .fossil, source: .journal))
    }

    /// Read again at every launch, a journal already written changes nothing.
    func testReadingTheSameJournalAgainWritesNothing() throws {
        let ditto = PokemonOdds.dittoSpeciesID
        let s = try store([entry(16, hours: 9, released: true), entry(ditto, hours: 8)])
        let journal = EggJournal(text: [
            line(at(9), "fossil egg used, discarded active"),
            line(at(8.5), "hatch: base=328 rarity=common shiny=false forms=3 boost=false ditto=true form=none"),
        ].joined(separator: "\n"))
        s.absorb(journal)
        XCTAssertEqual(s.state.dex[1].hatch, HatchRecord(egg: .fossil, source: .journal, rolledBaseID: 328))
        try FileManager.default.removeItem(at: url)
        s.absorb(journal)
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
    }

    /// The replay runs again when an egg leaves the Bag, not only when the Pokédex changes.
    func testTheCountsAreAnInputOfTheReplay() throws {
        var st = CompanionState()
        st.installBaselineSet = true
        st.claimedEventEggs = ["autumn@2026"]
        url = FileManager.default.temporaryDirectory.appendingPathComponent("egg-journal-\(UUID().uuidString).json")
        try JSONEncoder().encode(st).write(to: url)
        addTeardownBlock { [url] in try? FileManager.default.removeItem(at: url!) }
        XCTAssertEqual(relaunched().luckInputs.eggsUsed[.event(.autumn, key: nil)], 1)
    }

    func testADittoKeepsTheLineItsEggRolled() throws {
        let ditto = PokemonOdds.dittoSpeciesID
        func hatch(_ hours: Double, _ base: Int) -> String {
            line(at(hours), "hatch: base=\(base) rarity=common shiny=false forms=3 boost=false ditto=true form=none")
        }
        let s = try store([entry(16, hours: 20),
                           entry(ditto, hours: 19),                         // after a graduation
                           entry(10, hours: 18, released: true),
                           entry(ditto, hours: 17, released: true),         // its egg named by the journal
                           entry(ditto, hours: 16, released: true),         // its egg unknown
                           entry(ditto, hours: 15, record: HatchRecord(egg: .tier(nil), rolledBaseID: 7)),
                           entry(ditto, hours: 14, released: true, record: HatchRecord(egg: .tier(.rare), source: .player)),
                           entry(19, hours: 13)])
        s.absorb(EggJournal(text: [
            hatch(19.5, 328),
            line(at(18), "bag egg used: pokemonEgg, discarded active, tier=none"),
            hatch(17.5, 974),
            hatch(16.5, 21),
            hatch(15.5, 23),
            hatch(14.5, 25),
            hatch(1, 29),
        ].joined(separator: "\n")))
        XCTAssertEqual(s.state.dex[1].hatch, HatchRecord(egg: .tier(nil), source: .journal, rolledBaseID: 328))
        XCTAssertEqual(s.state.dex[3].hatch, HatchRecord(egg: .tier(nil), source: .journal, rolledBaseID: 974))
        XCTAssertNil(s.state.dex[4].hatch, "its egg stays unknown")
        XCTAssertEqual(s.state.dex[5].hatch?.rolledBaseID, 7, "what the app noted stays")
        XCTAssertNil(s.state.dex[6].hatch?.rolledBaseID, "the player's word stays as it is")
    }

    /// Sent off before its reveal, a Ditto stays in the Pokédex as its disguise: the line is its, not the next Ditto's.
    func testADittoSentOffInDisguiseLeavesTheNextDittoAlone() throws {
        let ditto = PokemonOdds.dittoSpeciesID
        func hatch(_ date: Date, _ base: Int) -> String {
            line(date, "hatch: base=\(base) rarity=common shiny=false forms=3 boost=false ditto=true form=none")
        }
        let s = try store([entry(16, hours: 20), entry(328, hours: 19, released: true), entry(10, hours: 18),
                           entry(ditto, hours: 17)])
        s.absorb(EggJournal(text: [hatch(at(19.5), 328), hatch(at(17.5), 974)].joined(separator: "\n")))
        XCTAssertNil(s.state.dex[1].hatch)
        XCTAssertEqual(s.state.dex[3].hatch?.rolledBaseID, 974)
    }

    /// A catch-up may graduate a Pokémon and hatch the next in the same second: the one before is not it.
    func testADittoIsNotThePokemonThatLeftThatSecond() throws {
        let ditto = PokemonOdds.dittoSpeciesID
        let s = try store([entry(ditto, hours: 20), entry(ditto, hours: 19)])
        s.absorb(EggJournal(text: line(at(20), "hatch: base=328 rarity=common shiny=false forms=3 boost=false ditto=true form=none")))
        XCTAssertNil(s.state.dex[0].hatch)
        XCTAssertEqual(s.state.dex[1].hatch?.rolledBaseID, 328)
    }

    /// Both files: the log rotates at 2 MB, the older half in `.old.log`.
    func testReadsTheLogAndItsOlderFile() async throws {
        let s = try store(active: .some(nil), [entry(16, hours: 9, released: true), entry(10, hours: 8, released: true)])
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("egg-journal-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: dir) }
        let log = dir.appendingPathComponent("PokeTokenBar.log")
        try (line(at(8), "fossil egg used, discarded active") + "\n").write(to: log, atomically: true, encoding: .utf8)
        try (line(at(9), "legendary egg used, discarded active") + "\n")
            .write(to: dir.appendingPathComponent("PokeTokenBar.old.log"), atomically: true, encoding: .utf8)
        await s.readEggJournal(from: log)
        XCTAssertEqual(s.state.dex[1].hatch?.egg, .legendary)
        XCTAssertEqual(s.state.active?.hatch?.egg, .fossil)
    }

    func testAMissingLogChangesNothing() async throws {
        let s = try store([entry(16, hours: 9, released: true), entry(10, hours: 8)])
        await s.readEggJournal(from: FileManager.default.temporaryDirectory.appendingPathComponent("no-\(UUID().uuidString).log"))
        XCTAssertNil(s.state.dex[1].hatch)
    }
}
