import XCTest
@testable import PokeTokenBar

/// A coming evolution whose forms the current stage doesn't show reads as one stage: the individual rolled its form
/// when it hatched.
@MainActor
final class EvolutionFormBranchTests: XCTestCase {
    private let date = Date(timeIntervalSince1970: 1_790_000_000)

    private func line(_ ids: [Int]) -> EvoLine {
        let tree = ids.reversed().reduce(nil as EvoNode?) { child, id in
            EvoNode(speciesID: id, children: child.map { [$0] } ?? [])
        }!
        return EvoLine(baseID: ids[0], tree: tree, rarity: .common,
                       names: Dictionary(uniqueKeysWithValues: ids.map { ($0, ["en": "P\($0)"]) }))
    }

    private func hatched(_ ids: [Int], dex: [DexEntry] = []) async throws -> CompanionStore {
        var st = CompanionState()
        st.installBaselineSet = true
        st.lastDate = "2026-10-21"
        st.dex = dex
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("form-branch-\(UUID().uuidString).json")
        try JSONEncoder().encode(st).write(to: url)
        let s = CompanionStore(provider: StubProvider(value: line(ids)), clock: { self.date }, fileURL: url,
                               rng: SeededRNG(seed: 1))
        await s.hatch(baseID: ids[0])
        return s
    }

    func testDudunsparceIsOneStageUnderDunsparce() async throws {
        let s = try await hatched([206, 982])
        XCTAssertEqual(s.lineNodes, [EvoLineItem(.species(206), .current), EvoLineItem(.species(982), .future)])
    }

    /// Shellos already shows its form (west or east), and Gastrodon keeps it.
    func testAFormAlreadyShownStaysASingleStage() async throws {
        let s = try await hatched([422, 423])
        XCTAssertEqual(s.lineNodes.last, EvoLineItem(.species(423), .future))
    }

    /// The forms can sit two stages ahead: Pichu, Pikachu, then Raichu in its Kanto or Alolan form.
    func testFormsTwoStagesAheadAreOneStage() async throws {
        let s = try await hatched([172, 25, 26])
        XCTAssertEqual(s.lineNodes, [EvoLineItem(.species(172), .current), EvoLineItem(.species(25), .future),
                                     EvoLineItem(.species(26), .future)])
    }
}
