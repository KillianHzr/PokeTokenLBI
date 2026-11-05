import XCTest
@testable import PokeTokenBar

/// Pikachu's costumes: each Pikachu that arrives brings one the player doesn't have yet and wears it while it grows;
/// the one equipped on Pikachu's Pokédex page shows on every other Pikachu; all fifteen unlock the Light Ball.
@MainActor
final class PikachuCostumeTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_790_000_000)
    private let line = EvoLine(baseID: 172, tree: EvoNode(speciesID: 172, children: [
        EvoNode(speciesID: 25, children: [EvoNode(speciesID: 26, children: [])]),
    ]), rarity: .common, names: [:])

    /// Async, so it runs on the main actor: CI's Swift 6.0 treats a sync `tearDown` as nonisolated, and refuses
    /// `super.tearDown()` from it (it would send the non-Sendable test case off the main actor).
    override func tearDown() async throws {
        PikachuCostume.equipped = nil
    }

    private func store(seed: UInt64 = 3, _ edit: (inout CompanionState) -> Void = { _ in }) throws -> CompanionStore {
        var st = CompanionState()
        st.installBaselineSet = true
        st.lastDate = "2026-10-26"
        edit(&st)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("pikachu-\(UUID().uuidString).json")
        try JSONEncoder().encode(st).write(to: url)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return CompanionStore(provider: StubProvider(value: line), clock: { self.now }, fileURL: url,
                              rng: SeededRNG(seed: seed))
    }

    /// Pichu grows into a Pikachu: it brings a costume the player lacks and wears that one, not the equipped one, on
    /// Home and in the menu bar; as a Raichu it wears none.
    func testAPikachuWearsTheCostumeItBrings() async throws {
        let missing: Set<PikachuCostume> = [.belle, .phd]
        let s = try store {
            $0.pikachuCostumes = Set(PikachuCostume.allCases).subtracting(missing)
            $0.equippedPikachuCostume = .rockStar
        }
        await s.hatch(baseID: 172)
        XCTAssertEqual(s.currentSpeciesID, 172)
        XCTAssertNil(s.state.active?.pikachuCostume, "Pichu brings nothing")
        s.applyUsage(s.threshold)
        XCTAssertEqual(s.currentSpeciesID, 25)
        let brought = try XCTUnwrap(s.state.active?.pikachuCostume)
        XCTAssertTrue(missing.contains(brought), "\(brought) was owned already")
        XCTAssertEqual(s.state.pikachuCostumes.count, PikachuCostume.allCases.count - 1)
        XCTAssertEqual(s.currentSpriteForm, brought.form)
        XCTAssertEqual(PikachuCostume.displayForm(speciesID: 25, form: s.currentSpriteForm), brought.form)
        XCTAssertEqual(s.representativeSubject.form, brought.form, "the menu bar shows it in its own costume")
        XCTAssertEqual(PikachuCostume.displayForm(speciesID: 25, form: nil), PikachuCostume.rockStar.form,
                       "every other Pikachu wears the equipped one")
        XCTAssertEqual(s.state.equippedPikachuCostume, .rockStar, "arriving doesn't change the choice")

        s.applyUsage(s.threshold)
        XCTAssertEqual(s.currentSpeciesID, 26)
        XCTAssertEqual(s.currentSpriteForm, s.currentForm, "a Raichu wears no costume")
    }

    /// Once every costume is owned, a Pikachu brings none and wears the equipped one.
    func testWithEveryCostumeOwnedAPikachuWearsTheEquippedOne() async throws {
        let s = try store {
            $0.pikachuCostumes = Set(PikachuCostume.allCases)
            $0.equippedPikachuCostume = .libre
        }
        await s.hatch(baseID: 172)
        s.applyUsage(s.threshold)
        XCTAssertEqual(s.currentSpeciesID, 25)
        XCTAssertNil(s.state.active?.pikachuCostume)
        XCTAssertEqual(PikachuCostume.displayForm(speciesID: 25, form: s.currentSpriteForm), PikachuCostume.libre.form)
    }

    /// Fifteen Pikachu bring the fifteen costumes, never one twice.
    func testFifteenPikachuBringEveryCostumeOnce() throws {
        var owned = Set<PikachuCostume>()
        for k in UInt64(0)..<15 {
            let costume = try XCTUnwrap(PikachuCostume.next(owned: owned, seed: k &* 0x9E37_79B9_7F4A_7C15))
            XCTAssertFalse(owned.contains(costume))
            owned.insert(costume)
        }
        XCTAssertEqual(owned, Set(PikachuCostume.allCases))
        XCTAssertNil(PikachuCostume.next(owned: owned, seed: 1))
    }

    /// Only a costume won can be worn, and None takes it off.
    func testOnlyAWonCostumeCanBeEquipped() throws {
        let s = try store { $0.pikachuCostumes = [.popStar] }
        XCTAssertFalse(s.equipPikachuCostume(.belle))
        XCTAssertNil(s.state.equippedPikachuCostume)
        XCTAssertTrue(s.equipPikachuCostume(.popStar))
        XCTAssertEqual(PikachuCostume.equipped, .popStar)
        XCTAssertTrue(s.equipPikachuCostume(nil))
        XCTAssertNil(PikachuCostume.equipped)
    }

    /// The save keeps the costumes, the equipped one and the one a Pikachu brought; a costume it doesn't know, or an
    /// equipped one not owned, is dropped without losing the rest.
    func testTheSaveKeepsOnlyTheCostumesItKnows() throws {
        var st = CompanionState()
        st.pikachuCostumes = [.belle, .hoennCap]
        st.equippedPikachuCostume = .hoennCap
        st.active = MonState(baseID: 172, pathIDs: [172, 25], stageIndex: 1, usedAtStage: 0, rarity: .common,
                             totalForms: 3)
        st.active?.pikachuCostume = .belle
        let kept = try JSONDecoder().decode(CompanionState.self, from: JSONEncoder().encode(st))
        XCTAssertEqual(kept.pikachuCostumes, [.belle, .hoennCap])
        XCTAssertEqual(kept.equippedPikachuCostume, .hoennCap)
        XCTAssertEqual(kept.active?.pikachuCostume, .belle)

        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(st)) as? [String: Any])
        json["pikachuCostumes"] = ["belle", "party-hat"]
        json["equippedPikachuCostume"] = "unova-cap"
        var active = try XCTUnwrap(json["active"] as? [String: Any])
        active["pikachuCostume"] = "party-hat"
        json["active"] = active
        let read = try JSONDecoder().decode(CompanionState.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertEqual(read.pikachuCostumes, [.belle])
        XCTAssertNil(read.equippedPikachuCostume, "not owned")
        XCTAssertEqual(read.active?.currentID, 25, "the Pikachu stays")
        XCTAssertNil(read.active?.pikachuCostume)
    }

    /// A costume is a look of Pikachu's sprites only: not a form an egg rolls, each its own files.
    func testACostumeOnlyChangesPikachusSprites() {
        PikachuCostume.equipped = .kalosCap
        XCTAssertFalse(PokemonForm.hasForms(speciesID: 25))
        XCTAssertEqual(PikachuCostume.displayForm(speciesID: 25, form: nil), PikachuCostume.kalosCap.form)
        XCTAssertEqual(PikachuCostume.displayForm(speciesID: 25, form: PokemonForm("alola")), PikachuCostume.kalosCap.form,
                       "the line's form is Raichu's, Pikachu keeps its costume")
        XCTAssertEqual(PikachuCostume.displayForm(speciesID: 25, form: PikachuCostume.belle.form), PikachuCostume.belle.form)
        XCTAssertNil(PikachuCostume.displayForm(speciesID: 25, form: PikachuCostume.plain), "None: its own look")
        // [Regression, review of 2026-11-04] A Gigantamax Pikachu (a weekly boss, a form won) showed in the costume.
        let gigantamax = PokemonForm("gmax")
        XCTAssertNotNil(BattleForms.form(speciesID: 25, form: gigantamax))
        XCTAssertEqual(PikachuCostume.displayForm(speciesID: 25, form: gigantamax), gigantamax)
        XCTAssertNil(PikachuCostume.displayForm(speciesID: 26, form: nil), "Raichu wears nothing")
        let rocker = PikachuCostume.rockStar.form
        XCTAssertEqual(SpriteStore.spriteURLs(speciesID: 25, animated: true, shiny: false, form: rocker)
            .first?.path.hasSuffix("other/showdown/10080.gif"), true)
        XCTAssertEqual(SpriteStore.spriteURLs(speciesID: 25, animated: false, shiny: false, form: rocker)
            .first?.lastPathComponent, "10080.png")
        XCTAssertEqual(Set(PikachuCostume.allCases.map(\.pokemonID)).count, PikachuCostume.allCases.count)
    }

    /// All fifteen unlock the Light Ball, which puts 2 Rare Eggs and 5 Rare Candies in the Bag: speeding up Pikachu's
    /// line, as it used to, helped nobody who already held every costume.
    func testEveryCostumeUnlocksTheLightBall() throws {
        let fourteen = try store { $0.pikachuCostumes = Set(PikachuCostume.allCases.dropLast()) }
        XCTAssertFalse(fourteen.isUnlocked(.lightBall))
        XCTAssertFalse(fourteen.claimAchievement(.lightBall))
        let all = try store { $0.pikachuCostumes = Set(PikachuCostume.allCases) }
        XCTAssertTrue(all.isUnlocked(.lightBall))
        XCTAssertTrue(all.claimAchievement(.lightBall))
        XCTAssertEqual(all.itemCount(.lightBall), 0, "not kept in the Bag")
        XCTAssertEqual(all.itemCount(.rareEgg), 2)
        XCTAssertEqual(all.itemCount(.rareCandy), 5)
        XCTAssertTrue(all.isClaimed(.lightBall))
        let pichu = MonState(baseID: 172, pathIDs: [172], stageIndex: 0, usedAtStage: 0, rarity: .common, totalForms: 3)
        XCTAssertEqual(all.growthSpeedMultiplier(for: pichu), 1, accuracy: 0.0001, "no growth bonus any more")
    }

    /// A save holding the old Light Ball trades it once for the same rewards; the achievement stays claimed.
    func testAnOwnedLightBallIsTradedOnceForItsRewards() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("lightball-\(UUID().uuidString).json")
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        var st = CompanionState()
        st.installBaselineSet = true
        st.lastDate = "2026-10-26"
        st.pikachuCostumes = Set(PikachuCostume.allCases)
        st.inventory = [ItemKind.lightBall.rawValue: 1, ItemKind.rareCandy.rawValue: 1]
        try JSONEncoder().encode(st).write(to: url)
        let first = CompanionStore(provider: StubProvider(value: line), clock: { self.now }, fileURL: url, rng: SeededRNG(seed: 3))
        XCTAssertEqual(first.itemCount(.lightBall), 0)
        XCTAssertEqual(first.itemCount(.rareEgg), 2)
        XCTAssertEqual(first.itemCount(.rareCandy), 6)
        XCTAssertTrue(first.isClaimed(.lightBall))
        XCTAssertFalse(first.claimAchievement(.lightBall), "nothing more to claim")
        let again = CompanionStore(provider: StubProvider(value: line), clock: { self.now }, fileURL: url, rng: SeededRNG(seed: 3))
        XCTAssertEqual(again.itemCount(.rareEgg), 2, "once")
        XCTAssertEqual(again.itemCount(.rareCandy), 6)
    }
}
