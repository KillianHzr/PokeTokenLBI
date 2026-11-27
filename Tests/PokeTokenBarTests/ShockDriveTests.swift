import XCTest
@testable import PokeTokenBar

/// Single-stage Common lines: one candy is the whole line.
private struct OneStageLine: PokeProviding {
    func line(baseSpeciesID: Int) async throws -> EvoLine {
        EvoLine(baseID: baseSpeciesID, tree: EvoNode(speciesID: baseSpeciesID, children: []), rarity: .common,
                names: [baseSpeciesID: ["en": "P\(baseSpeciesID)"]])
    }
    func baseSpeciesIndex() async throws -> [BaseSpecies] { [BaseSpecies(id: 4, captureRate: 45)] }
    func baseSpecies(id: Int) async throws -> BaseSpecies? { BaseSpecies(id: id, captureRate: 45) }
}

/// Always the same draw: 0 recharges every candy, 1 none.
private struct FixedRNG: RandomNumberGenerator {
    let value: UInt64
    mutating func next() -> UInt64 { value }
}

/// The Shock Drive recharges one Rare Candy in four: it made fossil Pokémon grow faster, which they long were by the
/// time Victini, Meloetta and Genesect graduated.
@MainActor
final class ShockDriveTests: XCTestCase {
    private func store(drive: Bool, roll: UInt64) -> CompanionStore {
        var st = CompanionState()
        st.installBaselineSet = true
        st.inventory = [ItemKind.rareCandy.rawValue: 5]
        if drive { st.inventory[ItemKind.shockDrive.rawValue] = 1 }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("shock-\(UUID().uuidString).json")
        try? JSONEncoder().encode(st).write(to: url)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return CompanionStore(provider: OneStageLine(), fileURL: url, rng: FixedRNG(value: roll))
    }

    func testOneRollInFourRecharges() {
        let rolls = (0..<UInt64(400)).filter(CollectorBonus.shockDriveRecharges(roll:))
        XCTAssertEqual(rolls.count, 100)
    }

    /// A recharged candy gives its XP and stays in the Bag; without the drive, or on another roll, it is used up.
    func testARechargedCandyStaysInTheBag() async {
        for (drive, roll, left, recharged) in [(true, UInt64(0), 5, 1), (true, 1, 4, 0), (false, 0, 4, 0)] {
            let s = store(drive: drive, roll: roll)
            await s.hatch(baseID: 4)
            XCTAssertNotEqual(s.useRareCandy(), .unavailable)
            XCTAssertEqual(s.rareCandyCount, left, "drive \(drive), roll \(roll)")
            XCTAssertEqual(s.candyFeedbackRecharged, recharged)
            XCTAssertEqual(s.state.dex.count, 1, "its XP given all the same: the line graduated")
            // The luck journal: one draw in four for each candy, with the drive only.
            let draws = s.luckJournal.filter { $0.kind == .shockDrive }
            XCTAssertEqual(draws.map(\.trials), drive ? [1] : [])
            XCTAssertEqual(draws.map(\.hits), drive ? [recharged] : [])
            XCTAssertEqual(draws.first?.odds ?? 0.25, 0.25)
        }
    }

    /// The fossil Pokémon no longer grow faster with it.
    func testNoMoreFossilGrowth() async {
        let s = store(drive: true, roll: 1)
        let omanyte = MonState(baseID: 138, pathIDs: [138], stageIndex: 0, usedAtStage: 0, rarity: .rare, totalForms: 2)
        XCTAssertEqual(s.growthSpeedMultiplier(for: omanyte), 1, accuracy: 0.0001)
        XCTAssertEqual(BonusTheme.of(.shockDrive), .candies)
    }
}
