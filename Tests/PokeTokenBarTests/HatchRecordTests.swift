import XCTest
@testable import PokeTokenBar

/// The record of each hatch (`HatchRecord`): the egg and the draw items its rolls met, kept with the Pokémon from its
/// hatch to its graduation or release, for the Luck screen.
@MainActor
final class HatchRecordTests: XCTestCase {
    private static let day = Date(timeIntervalSince1970: 1_790_000_000)
    private var lastURL: URL?

    private func store(seed: UInt64 = 1, _ setUp: (inout CompanionState) -> Void) throws -> CompanionStore {
        var st = CompanionState()
        st.installBaselineSet = true
        st.lastDate = "2026-10-20"
        setUp(&st)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("hatch-record-\(UUID().uuidString).json")
        try JSONEncoder().encode(st).write(to: url)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        lastURL = url
        return CompanionStore(provider: RosterProvider(), clock: { Self.day }, fileURL: url, rng: SeededRNG(seed: seed),
                              difficulty: 1, writer: nil)
    }

    private func hatched(_ setUp: (inout CompanionState) -> Void) async throws -> CompanionStore {
        let s = try store(setUp)
        s.setEggUsageForTesting(s.eggHatchThreshold)
        await s.hatchIfNeeded()
        return s
    }

    func testEachEggIsNoted() async throws {
        let eggs: [(HatchEgg, (inout CompanionState) -> Void)] = [
            (.tier(nil), { _ in }),
            (.tier(.uncommon), { $0.eggTier = .uncommon }),
            (.tier(.rare), { $0.eggTier = .rare }),
            (.stone(.fire), { $0.eggTypeGuarantee = .fire }),
            (.legendary, { $0.eggFromLegendaryEgg = true }),
            (.typeNull, { st in
                st.eggFromTypeNullEgg = true
                st.pendingHatchID = PokemonForm.typeNullSpeciesID
            }),
            (.birthday, { $0.eggFromBirthdayEgg = true }),
            (.fossil, { $0.eggFromFossilEgg = true }),
            (.event(.summer, key: "summer@2026"), { st in
                st.eggEvent = .summer
                st.eggEventKey = "summer@2026"
                st.eggTier = EventEgg.summer.tier
            }),
            (.event(.christmas, key: nil), { st in
                st.eggEvent = .christmas
                st.eggTier = EventEgg.christmas.tier
                st.eggTypeGuarantee = EventEgg.christmas.type
            }),
        ]
        for (egg, setUp) in eggs {
            let s = try await hatched(setUp)
            XCTAssertNotNil(s.state.active, "\(egg)")
            XCTAssertEqual(s.state.active?.hatch?.egg, egg)
            XCTAssertEqual(s.state.active?.hatch?.chosenByPlayer, false)
        }
    }

    /// The species, and its form with it, are rolled as the egg starts, its shiny and Ditto as it hatches: each with the
    /// draw items owned then. Rolled at the hatch, both are the same.
    func testItemsAreNotedWhenEachRollIsMade() async throws {
        let prerolled = try await hatched { st in
            st.pendingHatchID = 37
            st.pendingHatchItems = [.ovalCharm]
            st.inventory[ItemKind.shinyCharm.rawValue] = 1
            st.inventory[ItemKind.rareCandy.rawValue] = 3
        }
        XCTAssertEqual(prerolled.state.active?.hatch?.rollItems, [.ovalCharm])
        XCTAssertEqual(prerolled.state.active?.hatch?.hatchItems, [.shinyCharm], "only the draw items")

        let rolledNow = try await hatched { st in
            st.pendingHatchItems = [.ovalCharm]
            st.inventory[ItemKind.legendCharm.rawValue] = 1
        }
        XCTAssertEqual(rolledNow.state.active?.hatch?.rollItems, [.legendCharm], "no species waiting: rolled now")
        XCTAssertEqual(rolledNow.state.active?.hatch?.hatchItems, [.legendCharm])
    }

    /// The egg's warm-up keeps the items its species roll met, for the hatch to note.
    func testWarmUpKeepsTheItemsOfItsRoll() async throws {
        let s = try await hatched { st in
            st.inventory[ItemKind.ovalCharm.rawValue] = 1
            st.inventory[ItemKind.pokemonEgg.rawValue] = 1
        }
        XCTAssertTrue(s.useBagEgg(.pokemonEgg))
        let deadline = Date().addingTimeInterval(2)
        while s.state.pendingHatchID == nil, Date() < deadline { try await Task.sleep(nanoseconds: 1_000_000) }
        XCTAssertNotNil(s.state.pendingHatchID)
        XCTAssertEqual(s.state.pendingHatchItems, [.ovalCharm])
    }

    func testGraduationAndReleaseKeepTheRecord() async throws {
        let s = try await hatched { st in
            st.eggTier = .uncommon
            st.inventory[ItemKind.pokemonEgg.rawValue] = 1
        }
        let record = try XCTUnwrap(s.state.active?.hatch)
        XCTAssertEqual(s.dexEntries.last?.hatch, record, "the Pokémon raised, as the Pokédex shows it")
        let relaunched = CompanionStore(provider: RosterProvider(), clock: { Self.day }, fileURL: try XCTUnwrap(lastURL),
                                        difficulty: 1, writer: nil)
        XCTAssertEqual(relaunched.state.active?.hatch, record, "read back at the next launch")
        XCTAssertTrue(s.useBagEgg(.pokemonEgg))
        XCTAssertEqual(s.state.dex.last?.isReleased, true)
        XCTAssertEqual(s.state.dex.last?.hatch, record, "released")

        let luvdisc = try await hatched { st in
            st.eggEvent = .valentine
            st.inventory[ItemKind.glimmeringCharm.rawValue] = 1
        }
        let graduating = try XCTUnwrap(luvdisc.state.active)
        XCTAssertEqual(graduating.baseID, 370)
        luvdisc.applyUsage(luvdisc.stageThreshold(for: graduating))
        XCTAssertNil(luvdisc.state.active)
        XCTAssertEqual(luvdisc.state.dex.last?.isReleased, false)
        XCTAssertEqual(luvdisc.state.dex.last?.hatch, graduating.hatch, "graduated")
        XCTAssertEqual(luvdisc.state.dex.last?.hatch?.hatchItems, [.glimmeringCharm])
    }

    /// Saved before the record, or by a build that knows an egg this one does not: the Pokémon is kept without it.
    func testAPokemonWithoutARecordReads() throws {
        let old = #"{"baseID":16,"finalID":18,"chainOrder":[16,17,18],"rarity":"common"}"#
        XCTAssertNil(try JSONDecoder().decode(DexEntry.self, from: Data(old.utf8)).hatch)
        let unknown = #"{"baseID":16,"finalID":18,"chainOrder":[16,17,18],"rarity":"common","hatch":{"egg":{"moonEgg":{}},"rollItems":[],"hatchItems":[]}}"#
        let entry = try JSONDecoder().decode(DexEntry.self, from: Data(unknown.utf8))
        XCTAssertEqual(entry.chainOrder, [16, 17, 18])
        XCTAssertNil(entry.hatch)
        let newItem = #"{"egg":{"tier":{"_0":"rare"}},"rollItems":["shinyCharm","moonCharm"],"hatchItems":["moonCharm"]}"#
        let record = try JSONDecoder().decode(HatchRecord.self, from: Data(newItem.utf8))
        XCTAssertEqual(record.rollItems, [.shinyCharm], "an item this build does not know is left out")
        XCTAssertEqual(record.hatchItems, [])
    }

    func testExportAndImportKeepTheRecord() async throws {
        let s = try await hatched { st in
            st.eggTypeGuarantee = .ice
            st.inventory[ItemKind.revealGlass.rawValue] = 1
            st.inventory[ItemKind.pokemonEgg.rawValue] = 1
        }
        XCTAssertTrue(s.useBagEgg(.pokemonEgg))
        let data = try SaveTransfer.encode(state: s.state, appVersion: "test", deviceName: "test", now: Self.day)
        let back = try SaveTransfer.decode(data).state
        XCTAssertEqual(back.dex.last?.hatch?.egg, .stone(.ice))
        XCTAssertEqual(back.dex.last?.hatch, s.state.dex.last?.hatch)
    }
}
