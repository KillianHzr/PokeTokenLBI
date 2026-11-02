import XCTest
@testable import PokeTokenBar

private struct ZeroRNG: RandomNumberGenerator {
    mutating func next() -> UInt64 { 0 }
}

/// The hatch's own random sequence, pinned: same seed, same Pokémon, form, shiny and Ditto. Written before the draw
/// became pure functions (`HatchDraw`), so that moving it changes nothing a player could see.
@MainActor
final class HatchDrawSequenceTests: XCTestCase {
    private static let day = Date(timeIntervalSince1970: 1_790_000_000)

    private func graduated(_ base: Int, _ final: Int, chain: [Int], form: String? = nil) -> DexEntry {
        DexEntry(baseID: base, finalID: final, chainOrder: chain, rarity: .common, caughtAt: Self.day,
                 form: form.map { PokemonForm($0) })
    }

    /// Hatches one egg per seed and writes what came out: `base/form`, `*` when shiny, `~` when a Ditto hides in it.
    private func hatches(_ seeds: Range<UInt64>, zero: Bool = false,
                         _ setUp: (inout CompanionState) -> Void) async throws -> [String] {
        var out: [String] = []
        for seed in seeds {
            var st = CompanionState()
            st.installBaselineSet = true
            st.lastDate = "2026-10-20"
            setUp(&st)
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("draw-seq-\(UUID().uuidString).json")
            try JSONEncoder().encode(st).write(to: url)
            defer { try? FileManager.default.removeItem(at: url) }
            let s = CompanionStore(provider: RosterProvider(), clock: { Self.day }, fileURL: url,
                                   rng: zero ? ZeroRNG() as any RandomNumberGenerator : SeededRNG(seed: seed),
                                   dittoDisguiseRollingEnabled: true, writer: nil)
            s.setEggUsageForTesting(s.eggHatchThreshold)
            await s.hatchIfNeeded()
            guard let a = s.state.active else { out.append("-"); continue }
            out.append("\(a.baseID)" + (a.form.map { "/\($0.rawValue)" } ?? "") + (a.isShiny ? "*" : "")
                       + (a.dittoDisguise != nil ? "~" : ""))
        }
        return out
    }

    private func seedsWhere(_ mark: Character, _ outcomes: [String]) -> [Int] {
        outcomes.indices.filter { outcomes[$0].contains(mark) }
    }

    func testPlainEggs() async throws {
        let empty = try await hatches(0..<24) { _ in }
        XCTAssertEqual(empty.joined(separator: " "), "585/spring 10 50/alola 37/normal 50/alola 50/normal 37/normal 370 370 618/galar 74/normal 585/autumn 618/normal 102/alola 74/normal 50/alola 370 10 370 74/normal 58/hisui 370 50/normal 618/galar")
        let collected = try await hatches(0..<24) { st in
            st.dex = [graduated(19, 20, chain: [19, 20], form: "normal"), graduated(16, 18, chain: [16, 17, 18])]
            st.collectedFinals = ["19:20", "16:18"]
            st.lastHatchedBaseID = 10
        }
        XCTAssertEqual(collected.joined(separator: " "), "37/normal 19/normal 585/winter 37/normal 370 74/alola 16 133/starter 16 370 585/autumn 370 133/normal 74/normal 133/starter 585/summer 37/alola 58/normal 19/normal 74/normal 58/hisui 37/alola 1 50/normal")
        let flute = try await hatches(0..<24) { st in st.inventory[ItemKind.legendCharm.rawValue] = 1 }
        XCTAssertEqual(flute.joined(separator: " "), "10 74/normal 16 585/spring 370 370 16 102/alola 618/normal 37/normal 37/normal 585/autumn 618/normal 370 370 150 10 19/normal 74/alola 37/normal 19/alola 58/hisui 50/normal 10")
    }

    func testTierStoneAndLegendaryEggs() async throws {
        let uncommon = try await hatches(0..<24) { st in st.eggTier = .uncommon }
        XCTAssertEqual(uncommon.joined(separator: " "), "618/galar 1 102/alola 102/normal 1 58/normal 618/normal 618/normal 4 618/galar 618/galar 133/normal 102/normal 58/hisui 618/galar 1 618/normal 133/normal 1 58/normal 618/galar 1 58/normal 58/normal")
        let rare = try await hatches(0..<24) { st in st.eggTier = .rare }
        XCTAssertEqual(rare.joined(separator: " "), "133/normal 1 133/starter 1 1 133/normal 4 133/starter 4 133/normal 4 133/normal 4 4 133/starter 1 133/starter 133/normal 1 1 133/starter 1 4 1")
        let fire = try await hatches(0..<24) { st in
            st.eggTypeGuarantee = .fire
            st.dex = [graduated(37, 38, chain: [37, 38], form: "normal")]
            st.collectedFinals = ["37:38"]
        }
        XCTAssertEqual(fire.joined(separator: " "), "58/normal 37/normal 58/hisui 37/normal 58/hisui 58/normal 4 4 58/hisui 4 4 4 58/normal 58/hisui 58/hisui 4 58/hisui 37/normal 58/hisui 58/normal 58/hisui 58/hisui 58/normal 58/normal")
        let ice = try await hatches(0..<24) { st in st.eggTypeGuarantee = .ice }
        XCTAssertEqual(ice.joined(separator: " "), "37/alola 37/alola 37/alola 37/alola 37/alola 37/alola 37/alola 37/alola 37/alola 37/alola 37/alola 37/alola 37/alola 37/alola 37/alola 37/alola 37/alola 37/alola 37/alola 37/alola 37/alola 37/alola 37/alola 37/alola")
        let legendary = try await hatches(0..<24) { st in
            st.eggFromLegendaryEgg = true
            st.lastHatchedBaseID = 150
        }
        XCTAssertEqual(legendary.joined(separator: " "), "490 151 772/normal 772/normal 772/normal 144/normal 490 151 772/normal 151 772/normal 772/normal 151 490 144/galar 151 772/normal 151 772/normal 144/galar 144/galar 490 144/normal 772/normal")
    }

    func testOvalCharm() async throws {
        let oval = try await hatches(0..<24) { st in
            st.inventory[ItemKind.ovalCharm.rawValue] = 1
            st.dex = [graduated(37, 38, chain: [37, 38], form: "normal"), graduated(50, 51, chain: [50, 51], form: "normal")]
            st.collectedFinals = ["37:38", "50:51"]
        }
        XCTAssertEqual(oval.joined(separator: " "), "19/normal 74/normal 585/winter 37/alola 37/alola 19/normal 585/autumn 52/galar 58/hisui 74/normal 37/alola 74/alola 618/normal 585/winter 50/alola 74/alola 618/normal 37/alola 585/summer 19/normal 50/alola 102/alola 52/alola 585/autumn")
    }

    func testFossilBirthdayAndTypeNullEggs() async throws {
        let fossil = try await hatches(0..<24) { st in
            st.eggFromFossilEgg = true
            st.dex = [graduated(138, 139, chain: [138, 139])]
            st.lastHatchedBaseID = 142
        }
        XCTAssertEqual(fossil.joined(separator: " "), "696 696 696 696 696 696 696 696 696 696 696 696 696 696 696 696 696 696 696 696 696 696 696 696")
        let birthday = try await hatches(0..<24) { st in
            st.eggFromBirthdayEgg = true
            st.dex = [graduated(151, 151, chain: [151])]
        }
        XCTAssertEqual(birthday.joined(separator: " "), "490 490 490 490 490 490 490 490 490 490 490 490 490 490 490 490 490 490 490 490 490 490 490 490")
        let everyLegend = try await hatches(0..<24) { st in
            st.eggFromBirthdayEgg = true
            st.dex = [151, 490, 144, 150].map { graduated($0, $0, chain: [$0]) }
                + [graduated(772, 773, chain: [772, 773])]
        }
        XCTAssertEqual(everyLegend.joined(separator: " "), "490* 150* 490* 150* 772/normal* 151* 144/galar* 772/normal* 151* 772/normal* 144/galar* 150* 150* 490* 151* 490* 150* 490* 490* 151* 490* 772/normal* 490* 144/galar*")
        let typeNull = try await hatches(0..<6) { st in
            st.eggFromTypeNullEgg = true
            st.pendingHatchID = PokemonForm.typeNullSpeciesID
            st.pendingForm = PokemonForm.resolved(baseID: PokemonForm.typeNullSpeciesID, form: nil)
        }
        XCTAssertEqual(typeNull.joined(separator: " "), "772/normal 772/normal 772/normal 772/normal 772/normal 772/normal")
    }

    func testEventEggs() async throws {
        func event(_ egg: EventEgg) -> (inout CompanionState) -> Void {
            { st in
                st.eggEvent = egg
                st.eggTier = egg.tier
                st.eggTypeGuarantee = egg.type
                st.dex = [self.graduated(52, 53, chain: [52, 53])]
            }
        }
        for (egg, expected) in [
            (EventEgg.summer, "618/normal 58/normal 618/normal 585/summer 58/hisui 618/normal 618/normal 585/summer 58/hisui 58/normal 4 585/summer 585/summer 4 58/normal 618/normal 58/normal 585/summer 618/normal 585/summer 585/summer 58/normal 58/normal 4"),
            (EventEgg.winter, "618/galar 618/galar 618/galar 585/winter 618/galar 618/galar 618/galar 585/winter 618/galar 618/galar 618/galar 585/winter 585/winter 618/galar 618/galar 618/galar 618/galar 585/winter 618/galar 585/winter 585/winter 618/galar 618/galar 618/galar"),
            (EventEgg.christmas, "144/normal* 144/normal* 144/normal* 144/normal* 144/normal* 144/normal* 144/normal* 144/normal* 144/normal* 144/normal* 144/normal* 144/normal* 144/normal* 144/normal* 144/normal* 144/normal* 144/normal* 144/normal* 144/normal* 144/normal* 144/normal* 144/normal* 144/normal* 144/normal*"),
            (EventEgg.valentine, "370* 370* 370* 370* 370* 370* 370* 370* 370* 370* 370* 370* 370* 370* 370* 370* 370* 370* 370* 370* 370* 370* 370* 370*"),
            (EventEgg.companion, "52/galar* 52/normal* 52/alola* 52/alola* 52/galar* 52/galar* 52/normal* 52/galar* 52/galar* 52/galar* 52/galar* 52/alola* 52/alola* 52/galar* 52/normal* 52/galar* 52/galar* 52/galar* 52/galar* 52/alola* 52/alola* 52/normal* 52/galar* 52/alola*"),
            (EventEgg.newYear, "490 150 490 150 772/normal 151 144/normal 772/normal 151 772/normal 144/galar 150 150 490 151 490 150 490 490 151 490 772/normal 490 144/galar"),
        ] {
            let out = try await hatches(0..<24, event(egg))
            XCTAssertEqual(out.joined(separator: " "), expected, "\(egg)")
        }
    }

    /// Shiny is one in tens: the seeds where it comes out, over many.
    func testShinySeeds() async throws {
        let plain = try await hatches(0..<256) { _ in }
        XCTAssertEqual(seedsWhere("*", plain), [])
        let charm = try await hatches(0..<256) { st in st.inventory[ItemKind.shinyCharm.rawValue] = 1 }
        XCTAssertEqual(seedsWhere("*", charm), [114, 169, 180, 242])
        let glass = try await hatches(0..<256) { st in st.inventory[ItemKind.revealGlass.rawValue] = 1 }
        XCTAssertEqual(seedsWhere("*", glass), [169, 194])
        let glimmering = try await hatches(0..<8) { st in st.inventory[ItemKind.glimmeringCharm.rawValue] = 1 }
        XCTAssertEqual(seedsWhere("*", glimmering), Array(0..<8))
    }

    /// Every roll at 0 makes every chance come true: a Ditto hides in each egg that lets one.
    func testDittoHidesOnlyWhereAnEggLetsIt() async throws {
        let plain = try await hatches(0..<1, zero: true) { _ in }
        XCTAssertEqual(plain, ["16*~"])
        let rare = try await hatches(0..<1, zero: true) { st in st.eggTier = .rare }
        XCTAssertEqual(rare, ["1*"])
        let stone = try await hatches(0..<1, zero: true) { st in st.eggTypeGuarantee = .normal }
        XCTAssertEqual(stone, ["16*"])
        let oval = try await hatches(0..<1, zero: true) { st in st.inventory[ItemKind.ovalCharm.rawValue] = 1 }
        XCTAssertEqual(oval, ["19/normal*"])
        let event = try await hatches(0..<1, zero: true) { st in st.eggEvent = .pokemonDay }
        XCTAssertEqual(event, ["16*"])
        let fossil = try await hatches(0..<1, zero: true) { st in st.eggFromFossilEgg = true }
        XCTAssertEqual(fossil, ["138*"])
    }
}
