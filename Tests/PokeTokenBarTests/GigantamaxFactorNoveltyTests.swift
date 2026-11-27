import XCTest
@testable import PokeTokenBar

private let duraludon = 884, archaludon = 1018

private struct NoveltyProvider: PokeProviding {
    func line(baseSpeciesID: Int) async throws -> EvoLine {
        EvoLine(baseID: baseSpeciesID, tree: EvoNode(speciesID: baseSpeciesID, children: []), rarity: .common, names: [:])
    }
    func baseSpecies(id: Int) async throws -> BaseSpecies? { nil }
    func baseSpeciesIndex() async throws -> [BaseSpecies] { [] }
}

/// A Pokémon with the Gigantamax Factor brings something new while no Wearer of its species has graduated.
@MainActor
final class GigantamaxFactorNoveltyTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_790_000_000)

    private func graduated(_ chain: [Int], day: Double = 0, released: Bool = false) -> DexEntry {
        var e = DexEntry(baseID: chain[0], finalID: chain.last!, chainOrder: chain, rarity: .common,
                         caughtAt: now.addingTimeInterval(day * 86_400), releasedAt: released ? now : nil)
        e.id = "e\(day)-\(chain.last!)"
        return e
    }

    private var duraludonWithFactor: MonState {
        var m = MonState(baseID: duraludon, pathIDs: [duraludon], plannedPathIDs: [duraludon], stageIndex: 0, usedAtStage: 0,
                         rarity: .common, totalForms: 1)
        m.rolledGigantamaxFactor = true
        return m
    }

    private func store(active: MonState?, dex: [DexEntry]) throws -> CompanionStore {
        var st = CompanionState()
        st.installBaselineSet = true
        st.lastDate = "2026-10-29"
        st.active = active
        st.dex = dex
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("novelty-\(UUID().uuidString).json")
        try JSONEncoder().encode(st).write(to: url)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return CompanionStore(provider: NoveltyProvider(), clock: { self.now }, fileURL: url, rng: SeededRNG(seed: 1), difficulty: 0.1)
    }

    private var lineWithoutFactor: DexEntry { graduated([duraludon, archaludon], day: -2) }

    // Chen

    func testChenKeepsAnIndividualWithTheFactorWhileNoWearerHasGraduated() throws {
        let control = try store(active: duraludonWithFactor, dex: [lineWithoutFactor, graduated([duraludon], day: -1)])
        XCTAssertEqual(control.activeVerdict, .spare, "a Wearer graduated: the control setup is a Spare")
        let s = try store(active: duraludonWithFactor, dex: [lineWithoutFactor])
        XCTAssertEqual(s.activeVerdict, .wearerToKeep)
        XCTAssertFalse(s.oakSteps.contains { if case .release = $0 { true } else { false } })
    }

    func testChenTreatsAnIndividualWithTheFactorAsASpareOnceAWearerGraduated() throws {
        let s = try store(active: duraludonWithFactor, dex: [lineWithoutFactor, graduated([duraludon], day: -1)])
        XCTAssertEqual(s.activeVerdict, .spare)
        XCTAssertTrue(s.activeNews?.isDuplicate == true)
    }

    // Hatch

    func testAFreshHatchWithTheFactorIsNotADuplicateWhileNoWearerHasGraduated() throws {
        let s = try store(active: duraludonWithFactor, dex: [lineWithoutFactor])
        XCTAssertEqual(s.activeNews?.firstGigantamaxWearer, true)
        XCTAssertEqual(s.activeNews?.isDuplicate, false)
    }

    func testAFreshHatchWithTheFactorIsADuplicateOnceAWearerGraduated() throws {
        let s = try store(active: duraludonWithFactor, dex: [lineWithoutFactor, graduated([duraludon], day: -1)])
        XCTAssertEqual(s.activeNews?.firstGigantamaxWearer, false)
        XCTAssertEqual(s.activeNews?.isDuplicate, true)
    }

    // Catch log

    func testTheLogDoesNotMarkAnIndividualWithTheFactorAsADuplicateWhileNoWearerHasGraduated() throws {
        let first = graduated([duraludon], day: -1)
        let s = try store(active: nil, dex: [lineWithoutFactor, first])
        XCTAssertFalse(s.isDuplicateCatch(first))
        let active = try store(active: duraludonWithFactor, dex: [lineWithoutFactor])
        XCTAssertTrue(active.duplicateCatchEntryIDs.isEmpty)
    }

    func testTheLogMarksANewIndividualWithTheFactorAsADuplicateOnceAWearerGraduated() throws {
        let first = graduated([duraludon], day: -1), second = graduated([duraludon], day: 0)
        let s = try store(active: nil, dex: [lineWithoutFactor, first, second])
        XCTAssertFalse(s.isDuplicateCatch(first))
        XCTAssertTrue(s.isDuplicateCatch(second))
        let active = try store(active: duraludonWithFactor, dex: [lineWithoutFactor, first])
        XCTAssertEqual(active.duplicateCatchEntryIDs.count, 1)
    }

    func testAReleasedIndividualBringsNoWearer() throws {
        var released = graduated([duraludon], day: -1, released: true)
        released.rolledGigantamaxFactor = true
        let s = try store(active: nil, dex: [lineWithoutFactor, released])
        XCTAssertTrue(s.isDuplicateCatch(released))
    }
}
