import XCTest
@testable import PokeTokenBar

/// The suggested moves and "Compose for me" aim at the boss too (the owner, 2026-11-09: "l'équipe doit toujours aussi
/// viser le boss"; a daily Mega Golurk met a Zacian whose Sacred Sword and Wild Charge could not touch it, and a
/// Slaking with Strength and Brick Break).
@MainActor
final class BossTargetingTests: XCTestCase {
    private func entry(_ id: Int) -> DexEntry {
        var e = DexEntry(baseID: SpeciesInfo.baseID(of: id), finalID: id, chainOrder: [id], rarity: .rare,
                         caughtAt: Date(timeIntervalSince1970: 0))
        e.id = "e\(id)"
        return e
    }

    private let golurk: [[PokemonType]] = [[.ground, .ghost]]

    /// Against a Ground/Ghost boss and no theme, a challenge's case: no move the boss is immune to.
    func testNoMoveTheBossIsImmuneTo() throws {
        for id in [888, 289, 887] {
            let spec = try XCTUnwrap(DungeonTeamBuilder.spec(for: entry(id), bosses: golurk), "\(id)")
            for slug in spec.moves {
                guard let move = MoveTable.move(slug), move.isDamaging else { continue }
                let type = move.type(for: spec)
                let effect = golurk[0].reduce(1.0) { $0 * PokemonTypeData.effectiveness(attacking: type, defending: $1) }
                XCTAssertGreaterThan(effect, 0, "\(id): \(slug) cannot touch the boss")
            }
        }
        let zacian = try XCTUnwrap(DungeonTeamBuilder.spec(for: entry(888), bosses: golurk))
        XCTAssertFalse(zacian.moves.contains("sacred-sword"))
        XCTAssertFalse(zacian.moves.contains("wild-charge"))
    }

    /// The boss weighs as much as the whole theme: with no boss, the theme alone, as before.
    func testTheBossWeighsAsMuchAsTheTheme() throws {
        let alone = try XCTUnwrap(DungeonTeamBuilder.spec(for: entry(888), theme: [.bug, .grass]))
        let same = try XCTUnwrap(DungeonTeamBuilder.spec(for: entry(888), theme: [.bug, .grass], bosses: []))
        XCTAssertEqual(alone.moves, same.moves)
    }

    private func store(clock date: Date) throws -> CompanionStore {
        var st = CompanionState()
        st.installBaselineSet = true
        st.lastDate = "d"
        st.claimedTodayTokensByProvider = ["test": 0]
        st.dex = [6, 9, 3, 25, 143, 130, 445, 623].map { id in
            var e = entry(id)
            e.raising = nil
            return e
        }
        st.active = MonState(baseID: 16, pathIDs: [16, 17, 18], stageIndex: 0, usedAtStage: 0, rarity: .common, totalForms: 3)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("boss-target-\(UUID().uuidString).json")
        try JSONEncoder().encode(st).write(to: url)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return CompanionStore(provider: StubProvider(value: EvoLine(baseID: 16, tree: EvoNode(speciesID: 16, children: []),
                                                                    rarity: .common, names: [:])),
                              clock: { date }, fileURL: url, rng: SeededRNG(seed: 3), difficulty: 0.1)
    }

    /// What each dungeon's moves aim at: a challenge its known boss, a dungeon its theme and each boss it may draw, the
    /// Ruins of Alph (any species for a boss) its theme alone.
    func testWhatEachDungeonAimsAt() throws {
        let s = try store(clock: Date(timeIntervalSince1970: 1_794_394_800))
        let forest = s.moveTargets(.viridianForest)
        XCTAssertEqual(forest.theme, [.bug, .grass])
        XCTAssertEqual(forest.bosses.count, DungeonCatalog.dungeon(.viridianForest).bosses.count)
        XCTAssertTrue(s.moveTargets(.ruinsOfAlph).bosses.isEmpty)
        if let boss = s.challengeBoss(.daily) {
            XCTAssertEqual(s.moveTargets(.daily).bosses, [PokemonTypeData.types(forSpeciesID: boss.speciesID, form: boss.form)])
        } else {
            XCTAssertTrue(s.moveTargets(.daily).bosses.isEmpty)
        }
        XCTAssertTrue(s.moveTargets(nil).theme.isEmpty && s.moveTargets(nil).bosses.isEmpty)
    }
}
