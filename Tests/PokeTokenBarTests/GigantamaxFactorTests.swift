import XCTest
@testable import PokeTokenBar

private let pichu = 172, pikachu = 25, raichu = 26, eevee = 133, vaporeon = 134, meowth = 52, persian = 53

private func line(_ tree: EvoNode) -> EvoLine {
    func ids(_ n: EvoNode) -> [Int] { [n.speciesID] + n.children.flatMap(ids) }
    return EvoLine(baseID: tree.speciesID, tree: tree, rarity: .common,
                   names: Dictionary(uniqueKeysWithValues: ids(tree).map { ($0, ["en": "P\($0)"]) }))
}
private let pichuLine = line(EvoNode(speciesID: pichu, children: [EvoNode(speciesID: pikachu, children: [EvoNode(speciesID: raichu, children: [])])]))
private let eeveeLine = line(EvoNode(speciesID: eevee, children: [EvoNode(speciesID: vaporeon, children: [])]))
private let charLine = line(EvoNode(speciesID: 4, children: [EvoNode(speciesID: 5, children: [EvoNode(speciesID: 6, children: [])])]))

private struct FixedRNG: RandomNumberGenerator {
    let value: UInt64
    mutating func next() -> UInt64 { value }
}

private final class DrawLogRNG: RandomNumberGenerator, @unchecked Sendable {
    var inner = SeededRNG(seed: 11)
    var drawn: [UInt64] = []
    func next() -> UInt64 { let v = inner.next(); drawn.append(v); return v }
}

private func graduated(_ final: Int, chain: [Int]? = nil, rolled: Bool = false, form: PokemonForm? = nil) -> DexEntry {
    var e = DexEntry(baseID: (chain ?? [final])[0], finalID: final, chainOrder: chain ?? [final], rarity: .common,
                     caughtAt: Date(timeIntervalSince1970: 0), form: form)
    e.rolledGigantamaxFactor = rolled
    return e
}

private let raichuInEveryForm = PokemonForm.lineForms(baseID: pichu).map { graduated(raichu, chain: [pichu, pikachu, raichu], form: $0) }

@MainActor
final class GigantamaxFactorTests: XCTestCase {
    private func store(_ line: EvoLine, dex: [DexEntry] = [], rng: any RandomNumberGenerator) -> CompanionStore {
        var st = CompanionState()
        st.installBaselineSet = true
        st.dex = dex
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("gmax-\(UUID().uuidString).json")
        try? JSONEncoder().encode(st).write(to: url)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return CompanionStore(provider: StubProvider(value: line), fileURL: url, rng: rng, difficulty: 1)
    }

    private func gmax(_ speciesID: Int) throws -> BattleForm {
        try XCTUnwrap(BattleForms.forms(speciesID: speciesID).first { $0.kind == .gigantamax })
    }

    // Criterion 1

    func testALineEndingOnAGigantamaxSpeciesHasTheFactorWithoutBeingRolled() {
        XCTAssertTrue(graduated(6, chain: [4, 5, 6]).hasGigantamaxFactor)
        XCTAssertTrue(graduated(eevee).hasGigantamaxFactor)
        XCTAssertTrue(graduated(pikachu, chain: [pikachu]).hasGigantamaxFactor)
        XCTAssertFalse(graduated(raichu, chain: [pichu, pikachu, raichu]).hasGigantamaxFactor)
        XCTAssertFalse(graduated(2, chain: [1, 2]).hasGigantamaxFactor)
        let planned = MonState(baseID: 4, pathIDs: [4], plannedPathIDs: [4, 5, 6], stageIndex: 0, usedAtStage: 0, rarity: .common, totalForms: 3)
        XCTAssertTrue(planned.hasGigantamaxFactor)
        let plain = MonState(baseID: 1, pathIDs: [1], plannedPathIDs: [1, 2], stageIndex: 0, usedAtStage: 0, rarity: .common, totalForms: 2)
        XCTAssertFalse(plain.hasGigantamaxFactor)
    }

    func testASaveFromBeforeGivesTheFactorToItsGraduatedCharizardPartnerEeveeAndCostumedPikachu() throws {
        let json = #"[{"baseID":4,"finalID":6,"chainOrder":[4,5,6],"rarity":"common"},"#
            + #"{"baseID":133,"finalID":133,"chainOrder":[133],"rarity":"common"},"#
            + #"{"baseID":25,"finalID":25,"chainOrder":[25],"rarity":"common"},"#
            + #"{"baseID":172,"finalID":26,"chainOrder":[172,25,26],"rarity":"common"}]"#
        let entries = try JSONDecoder().decode([DexEntry].self, from: Data(json.utf8))
        XCTAssertEqual(entries.map(\.hasGigantamaxFactor), [true, true, true, false])
        XCTAssertEqual(entries.map(\.rolledGigantamaxFactor), [false, false, false, false])
    }

    // Criterion 2

    func testTheChanceIsOneInTwoWithoutAWearerAndOneInTenWithOne() {
        XCTAssertTrue(GigantamaxFactor.rolls(roll: 0, hasWearer: false))
        XCTAssertFalse(GigantamaxFactor.rolls(roll: 1, hasWearer: false))
        XCTAssertTrue(GigantamaxFactor.rolls(roll: 2, hasWearer: false))
        XCTAssertTrue(GigantamaxFactor.rolls(roll: 10, hasWearer: true))
        XCTAssertFalse(GigantamaxFactor.rolls(roll: 2, hasWearer: true))
        XCTAssertFalse(GigantamaxFactor.rolls(roll: 1, hasWearer: true))
    }

    func testAnIndividualHoldsAtTheGigantamaxSpeciesOnlyWhereTheLineGoesFurtherAndTheMeowthIsKantonian() {
        XCTAssertEqual(GigantamaxFactor.stopIndex(in: [pichu, pikachu, raichu], form: nil), 1)
        XCTAssertEqual(GigantamaxFactor.stopIndex(in: [pikachu, raichu], form: nil), 0)
        XCTAssertEqual(GigantamaxFactor.stopIndex(in: [eevee, vaporeon], form: nil), 0)
        XCTAssertEqual(GigantamaxFactor.stopIndex(in: [884, 1018], form: nil), 0)
        XCTAssertEqual(GigantamaxFactor.stopIndex(in: [meowth, persian], form: PokemonForm("normal")), 0)
        XCTAssertNil(GigantamaxFactor.stopIndex(in: [meowth, persian], form: PokemonForm("alola")))
        XCTAssertNil(GigantamaxFactor.stopIndex(in: [meowth, 863], form: PokemonForm("galar")))
        XCTAssertNil(GigantamaxFactor.stopIndex(in: [pikachu], form: nil))
        XCTAssertNil(GigantamaxFactor.stopIndex(in: [4, 5, 6], form: nil))
    }

    func testNoFactorWhileTheFinalSpeciesItWouldReachIsMissing() async throws {
        let s = store(pichuLine, rng: FixedRNG(value: 0))
        await s.hatch(baseID: pichu)
        XCTAssertFalse(s.state.active!.rolledGigantamaxFactor)
        XCTAssertEqual(s.state.active!.plannedPathIDs, [pichu, pikachu, raichu])
    }

    func testAPichuMayHoldFactorOnceItsFinalSpeciesIsInThePokedexAndStopsAtPikachu() async throws {
        let s = store(pichuLine, dex: raichuInEveryForm, rng: FixedRNG(value: 0))
        await s.hatch(baseID: pichu)
        XCTAssertTrue(s.state.active!.rolledGigantamaxFactor)
        XCTAssertEqual(s.state.active!.plannedPathIDs, [pichu, pikachu])
        XCTAssertEqual(s.state.active!.totalForms, 2)
    }

    func testAnEeveeWithTheFactorStaysEevee() async throws {
        let s = store(eeveeLine, dex: [graduated(vaporeon, chain: [eevee, vaporeon], form: PokemonForm("starter"))], rng: FixedRNG(value: 2))
        await s.hatch(baseID: eevee)
        XCTAssertNotEqual(s.state.active!.form, PokemonForm("starter"))
        XCTAssertTrue(s.state.active!.rolledGigantamaxFactor)
        XCTAssertEqual(s.state.active!.plannedPathIDs, [eevee])
    }

    func testALosingRollGivesNoFactor() async throws {
        let s = store(pichuLine, dex: raichuInEveryForm, rng: FixedRNG(value: 1))
        await s.hatch(baseID: pichu)
        XCTAssertFalse(s.state.active!.rolledGigantamaxFactor)
        XCTAssertEqual(s.state.active!.plannedPathIDs, [pichu, pikachu, raichu])
    }

    func testAGraduatedWearerOfTheSpeciesLowersTheOddsToOneInTen() async throws {
        let dex = raichuInEveryForm + [graduated(pikachu, chain: [pichu, pikachu], rolled: true)]
        let s = store(pichuLine, dex: dex, rng: FixedRNG(value: 2))
        await s.hatch(baseID: pichu)
        XCTAssertFalse(s.state.active!.rolledGigantamaxFactor)
        let lone = store(pichuLine, dex: raichuInEveryForm, rng: FixedRNG(value: 2))
        await lone.hatch(baseID: pichu)
        XCTAssertTrue(lone.state.active!.rolledGigantamaxFactor)
    }

    func testTheFactorRollIsDrawnLastAndOnlyWhereItApplies() async throws {
        let missing = DrawLogRNG()
        await store(pichuLine, rng: missing).hatch(baseID: pichu)
        let applies = DrawLogRNG()
        await store(pichuLine, dex: raichuInEveryForm, rng: applies).hatch(baseID: pichu)
        XCTAssertEqual(applies.drawn.count, missing.drawn.count + 1)
        XCTAssertEqual(Array(applies.drawn.dropLast()), missing.drawn)
    }

    // Criterion 3

    func testAnIndividualWithTheFactorGraduatesAtItsGigantamaxSpecies() async throws {
        let s = store(pichuLine, dex: raichuInEveryForm, rng: FixedRNG(value: 0))
        await s.hatch(baseID: pichu)
        s.applyUsage(10_000_000_000_000)
        XCTAssertNil(s.state.active)
        let entry = try XCTUnwrap(s.state.dex.last)
        XCTAssertEqual(entry.finalID, pikachu)
        XCTAssertEqual(entry.chainOrder, [pichu, pikachu])
        XCTAssertTrue(entry.rolledGigantamaxFactor)
    }

    func testARestartKeepsTheStopForAnIndividualWithTheFactor() async throws {
        var st = CompanionState()
        st.installBaselineSet = true
        var mon = MonState(baseID: pichu, pathIDs: [pichu, pikachu], plannedPathIDs: [pichu, pikachu], stageIndex: 1, usedAtStage: 0,
                           rarity: .common, totalForms: 2)
        mon.rolledGigantamaxFactor = true
        st.active = mon
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("gmax-\(UUID().uuidString).json")
        try JSONEncoder().encode(st).write(to: url)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        let counting = DrawLogRNG()
        let s = CompanionStore(provider: StubProvider(value: pichuLine), fileURL: url, rng: counting, difficulty: 1)
        s.update(todayTokensByProvider: ["test": 0], todayDate: "d1", monthTotal: 0, burnTier: .idle, limitWarning: false, hasUsageData: true)
        for _ in 0..<50 where s.currentLine == nil { await Task.yield() }
        XCTAssertNotNil(s.currentLine)
        XCTAssertEqual(s.state.active?.plannedPathIDs, [pichu, pikachu])
        XCTAssertTrue(counting.drawn.isEmpty)
    }

    // Criterion 4

    func testTheFactorSurvivesTheSaveTheExportAndTheImport() throws {
        var mon = MonState(baseID: pichu, pathIDs: [pichu], plannedPathIDs: [pichu, pikachu], stageIndex: 0, usedAtStage: 0,
                           rarity: .common, totalForms: 2)
        mon.rolledGigantamaxFactor = true
        var st = CompanionState()
        st.active = mon
        st.dex = [graduated(pikachu, chain: [pichu, pikachu], rolled: true)]
        let data = try SaveTransfer.encode(state: st, appVersion: "t", deviceName: "d", now: Date(timeIntervalSince1970: 0))
        let imported = try SaveTransfer.decode(data).state
        XCTAssertTrue(imported.active!.rolledGigantamaxFactor)
        XCTAssertTrue(imported.dex[0].rolledGigantamaxFactor)
        let plain = try JSONDecoder().decode(DexEntry.self, from: Data(#"{"baseID":1,"finalID":3,"chainOrder":[1,2,3],"rarity":"common"}"#.utf8))
        XCTAssertFalse(plain.rolledGigantamaxFactor)
        let oldMon = try JSONDecoder().decode(MonState.self, from: Data(#"{"baseID":1,"pathIDs":[1],"stageIndex":0,"usedAtStage":0,"rarity":"common","totalForms":1}"#.utf8))
        XCTAssertFalse(oldMon.rolledGigantamaxFactor)
    }

    // Criterion 5

    func testOnlyAnIndividualWithTheFactorWearsAGigantamaxForm() throws {
        let s = store(charLine, rng: FixedRNG(value: 1))
        let charizard = graduated(6, chain: [4, 5, 6])
        let raichuEntry = graduated(raichu, chain: [pichu, pikachu, raichu])
        let pikachuEntry = graduated(pikachu, chain: [pichu, pikachu], rolled: true)
        XCTAssertTrue(s.wears(charizard, try gmax(6)))
        XCTAssertFalse(s.wears(raichuEntry, try gmax(pikachu)))
        XCTAssertTrue(s.wears(pikachuEntry, try gmax(pikachu)))
        XCTAssertTrue(s.wears(graduated(eevee), try gmax(eevee)))
        XCTAssertTrue(s.wears(graduated(pikachu), try gmax(pikachu)))
    }

    func testTheHallAndChensAdviceCountOnlyWearers() throws {
        let s = store(charLine, dex: raichuInEveryForm, rng: FixedRNG(value: 1))
        XCTAssertFalse(s.hasWearer(try gmax(pikachu)))
        let with = store(charLine, dex: [graduated(pikachu, chain: [pichu, pikachu], rolled: true)], rng: FixedRNG(value: 1))
        XCTAssertTrue(with.hasWearer(try gmax(pikachu)))
    }
}
