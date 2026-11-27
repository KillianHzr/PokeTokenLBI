import XCTest
@testable import PokeTokenBar

private let flabebe = 669, floette = 670, florges = 671, pichu = 172, pikachu = 25, raichu = 26
private let eevee = 133, meowth = 52, duraludon = 884

private func gmax(_ speciesID: Int) throws -> BattleForm {
    try XCTUnwrap(BattleForms.forms(speciesID: speciesID).first { $0.kind == .gigantamax })
}
private func mega(_ speciesID: Int) throws -> BattleForm {
    try XCTUnwrap(BattleForms.forms(speciesID: speciesID).first { $0.kind == .mega })
}

private struct Lines: PokeProviding {
    func line(baseSpeciesID id: Int) async throws -> EvoLine {
        let trees: [Int: EvoNode] = [
            flabebe: EvoNode(speciesID: flabebe, children: [EvoNode(speciesID: floette, children: [EvoNode(speciesID: florges, children: [])])]),
            pichu: EvoNode(speciesID: pichu, children: [EvoNode(speciesID: pikachu, children: [EvoNode(speciesID: raichu, children: [])])]),
            eevee: EvoNode(speciesID: eevee, children: [EvoNode(speciesID: 134, children: [])]),
            meowth: EvoNode(speciesID: meowth, children: [EvoNode(speciesID: 53, children: [])]),
            duraludon: EvoNode(speciesID: duraludon, children: [EvoNode(speciesID: 1018, children: [])]),
        ]
        return EvoLine(baseID: id, tree: trees[id] ?? EvoNode(speciesID: id, children: []), rarity: .common, names: [:])
    }
    func baseSpeciesIndex() async throws -> [BaseSpecies] { [BaseSpecies(id: pichu, captureRate: 190)] }
}

@MainActor
final class WearerEggTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_790_000_000)

    private func graduated(_ chain: [Int], form: PokemonForm? = nil, released: Bool = false) -> DexEntry {
        var entry = DexEntry(baseID: chain[0], finalID: chain.last ?? chain[0], chainOrder: chain, rarity: .common,
                             caughtAt: now, form: form)
        if released { entry.releasedAt = now }
        return entry
    }

    private func url() -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("wearer-egg-\(UUID().uuidString).json")
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }

    private func state(dex: [DexEntry] = [], won: [BattleForm] = [], given: Bool = false,
                       prepare: (inout CompanionState) -> Void = { _ in }) -> CompanionState {
        var st = CompanionState()
        st.installBaselineSet = true
        st.lastDate = "2026-12-05"
        st.claimedTodayTokensByProvider = ["test": 0]
        st.wishingPiecesGiven = true
        st.wearerEggsGiven = given
        st.dex = dex
        st.dungeons.battleForms = Set(won.map(\.key))
        st.active = MonState(baseID: 16, pathIDs: [16], stageIndex: 0, usedAtStage: 0, rarity: .common, totalForms: 3)
        prepare(&st)
        return st
    }

    private func open(_ url: URL, _ st: CompanionState? = nil) throws -> CompanionStore {
        if let st { try JSONEncoder().encode(st).write(to: url) }
        return CompanionStore(provider: Lines(), clock: { self.now }, fileURL: url, rng: SeededRNG(seed: 5), difficulty: 0.1)
    }

    private func store(dex: [DexEntry] = [], won: [BattleForm] = [], given: Bool = false,
                       prepare: (inout CompanionState) -> Void = { _ in }) throws -> CompanionStore {
        try open(url(), state(dex: dex, won: won, given: given, prepare: prepare))
    }

    private func growToTheEnd(_ s: CompanionStore) {
        for _ in 0..<6 {
            guard let mon = s.state.active else { return }
            s.applyUsage(s.stageThreshold(for: mon))
        }
    }

    // MARK: Criterion 2, who receives one

    func testMegaFloetteWonWithOnlyFlorgesGivesAFloetteEggAndOnePiece() throws {
        let form = try mega(floette)
        XCTAssertTrue(BattleForms.daily.contains(form))
        let s = try store(dex: [graduated([flabebe, floette, florges], form: PokemonForm("red"))], won: [form])
        XCTAssertEqual(s.state.wearerEggs.map(\.formKey), [form.key])
        XCTAssertEqual(s.itemCount(.wishingPiece), 1)
        XCTAssertTrue(s.state.wearerEggsGiven)
    }

    func testAWeeklyGigantamaxWithoutWearerGivesAPikachuEggAndThreePieces() throws {
        let form = try gmax(pikachu)
        XCTAssertTrue(BattleForms.weekly.contains(form))
        let s = try store(dex: [graduated([pichu, pikachu, raichu])], won: [form])
        XCTAssertEqual(s.state.wearerEggs.map(\.formKey), [form.key])
        XCTAssertEqual(s.itemCount(.wishingPiece), 3)
    }

    func testAReleasedWearerDoesNotCount() throws {
        let form = try gmax(pikachu)
        let s = try store(dex: [graduated([pikachu], released: true)], won: [form])
        XCTAssertEqual(s.state.wearerEggs.count, 1)
    }

    func testOneEggAndItsPiecesPerFormWithoutWearer() throws {
        let forms = [try mega(floette), try gmax(pikachu), try gmax(duraludon)]
        let s = try store(won: forms)
        XCTAssertEqual(Set(s.state.wearerEggs.map(\.formKey)), Set(forms.map(\.key)))
        XCTAssertEqual(s.state.wearerEggs.count, 3)
        XCTAssertEqual(s.itemCount(.wishingPiece), 1 + 3 + 3)
    }

    func testAFormThatHasAWearerGivesNothing() throws {
        let form = try gmax(pikachu)
        let s = try store(dex: [graduated([pichu, pikachu])], won: [form])
        XCTAssertTrue(s.state.wearerEggs.isEmpty)
        XCTAssertEqual(s.itemCount(.wishingPiece), 0)
        XCTAssertTrue(s.state.wearerEggsGiven, "the flag goes up all the same")
    }

    func testASecondLaunchGivesNothing() throws {
        let file = url()
        let first = try open(file, state(dex: [graduated([pichu, pikachu, raichu])], won: [try gmax(pikachu)]))
        XCTAssertEqual(first.state.wearerEggs.count, 1)
        first.persist()
        let second = try open(file)
        XCTAssertEqual(second.state.wearerEggs.count, 1)
        XCTAssertEqual(second.itemCount(.wishingPiece), 3)
        var raw = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(second.state)) as? [String: Any])
        raw["wearerEggs"] = []
        try JSONSerialization.data(withJSONObject: raw).write(to: file)
        XCTAssertTrue(try open(file).state.wearerEggs.isEmpty, "used, never given again")
    }

    func testANewPlayerGetsNothingAndTouchesNoFile() throws {
        let file = url()
        let s = try open(file)
        XCTAssertTrue(s.state.wearerEggs.isEmpty)
        XCTAssertTrue(s.state.wearerEggsGiven)
        XCTAssertFalse(FileManager.default.fileExists(atPath: file.path))
    }

    func testASaveFromBeforeTheFlagReadsItAsNotGiven() throws {
        var raw = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(CompanionState())) as? [String: Any])
        raw["wearerEggsGiven"] = nil
        raw["wearerEggs"] = nil
        let old = try JSONDecoder().decode(CompanionState.self, from: JSONSerialization.data(withJSONObject: raw))
        XCTAssertFalse(old.wearerEggsGiven)
        XCTAssertTrue(old.wearerEggs.isEmpty)
    }

    func testAnImportOfAnOldExportGivesNothing() throws {
        var imported = state(won: [try gmax(pikachu)])
        imported.wearerEggsGiven = false
        var current = imported
        current.wearerEggsGiven = true
        let merged = SaveTransfer.rebasedForThisDevice(imported, current: current, todayTokensByProvider: [:],
                                                       todayDate: "d", hasUsageData: false)
        XCTAssertTrue(merged.wearerEggsGiven)
        let other = SaveTransfer.rebasedForThisDevice(current, current: imported, todayTokensByProvider: [:],
                                                      todayDate: "d", hasUsageData: false)
        XCTAssertTrue(other.wearerEggsGiven, "either side had it")
        let file = url()
        try JSONEncoder().encode(merged).write(to: file)
        XCTAssertTrue(try open(file).state.wearerEggs.isEmpty)
    }

    // MARK: What an egg holds

    func testItsContentComesFromTheForm() throws {
        let cases: [(BattleForm, species: Int, base: Int, form: PokemonForm?, factor: Bool)] = [
            (try mega(floette), floette, flabebe, PokemonForm("eternal"), false),
            (try gmax(pikachu), pikachu, pichu, nil, true),
            (try gmax(eevee), eevee, eevee, nil, true),
            (try gmax(meowth), meowth, meowth, PokemonForm.resolved(baseID: meowth, form: nil), true),
            (try gmax(duraludon), duraludon, duraludon, nil, true),
        ]
        for (form, species, base, wears, factor) in cases {
            let egg = WearerEgg(formKey: form.key)
            XCTAssertEqual(egg.speciesID, species, form.key)
            XCTAssertEqual(egg.baseID, base, form.key)
            XCTAssertEqual(egg.hatchForm, PokemonForm.resolved(baseID: base, form: wears), form.key)
            XCTAssertEqual(egg.hasGigantamaxFactor, factor, form.key)
        }
        let kanto = WearerEgg(formKey: try gmax(meowth).key)
        XCTAssertTrue(PokemonForm.isDefault(kanto.hatchForm, speciesID: meowth), "a Kantonian Meowth")
    }

    // MARK: Criterion 3, the hatch

    func testItHatchesTheWearerStraightAtItsStage() async throws {
        let cases: [(form: BattleForm, base: Int, wearsFactor: Bool)] = [
            (try mega(floette), flabebe, false), (try gmax(pikachu), pichu, true), (try gmax(eevee), eevee, true),
            (try gmax(meowth), meowth, true), (try gmax(duraludon), duraludon, true),
        ]
        for (form, base, factor) in cases {
            let egg = WearerEgg(formKey: form.key)
            let s = try store(won: [form], given: true) { $0.wearerEggs = [egg] }
            XCTAssertTrue(s.canUseWearerEgg(egg.id), form.key)
            XCTAssertTrue(s.useWearerEgg(egg.id), form.key)
            XCTAssertTrue(s.state.wearerEggs.isEmpty, "used up")
            XCTAssertNil(s.state.active)
            s.setEggUsageForTesting(s.eggHatchThreshold)
            await s.hatchIfNeeded()
            let mon = try XCTUnwrap(s.state.active, form.key)
            XCTAssertEqual(mon.baseID, base, form.key)
            XCTAssertEqual(mon.pathIDs, [form.speciesID], form.key)
            XCTAssertEqual(mon.plannedPathIDs, [form.speciesID], form.key)
            XCTAssertEqual(mon.rolledGigantamaxFactor, factor, form.key)
            XCTAssertEqual(mon.form, egg.hatchForm, form.key)
            XCTAssertNil(s.state.eggFromWearer)
            growToTheEnd(s)
            XCTAssertNil(s.state.active, "graduates at its stage")
            let entry = try XCTUnwrap(s.state.dex.last { !$0.isReleased && $0.finalID == form.speciesID }, form.key)
            XCTAssertEqual(entry.chainOrder, [form.speciesID])
            XCTAssertTrue(form.isWorn(by: entry), "\(form.key) has its wearer")
        }
    }

    func testARestartKeepsAWearerPikachuAsAPikachu() async throws {
        let file = url()
        var st = state(given: true)
        st.active = MonState(baseID: pichu, pathIDs: [pikachu], plannedPathIDs: [pikachu], stageIndex: 0, usedAtStage: 0,
                             rarity: .common, totalForms: 1)
        st.active?.rolledGigantamaxFactor = true
        let s = try open(file, st)
        s.update(todayTokensByProvider: ["test": 0], todayDate: "2026-12-05", monthTotal: 0, burnTier: .idle,
                 limitWarning: false, hasUsageData: true)
        for _ in 0..<50 where s.currentLine == nil { await Task.yield() }
        XCTAssertNotNil(s.currentLine)
        XCTAssertEqual(s.state.active?.pathIDs, [pikachu])
        XCTAssertEqual(s.state.active?.plannedPathIDs, [pikachu])
    }

    func testItIsUsedLikeAnyEggOfTheBag() throws {
        let egg = WearerEgg(formKey: try gmax(pikachu).key)
        let idle = try store(given: true) { $0.wearerEggs = [egg]; $0.active = nil }
        XCTAssertFalse(idle.canUseWearerEgg(egg.id), "a Pokémon to send off")
        let s = try store(given: true) { $0.wearerEggs = [egg] }
        XCTAssertFalse(s.canUseWearerEgg("other"))
        XCTAssertTrue(s.useWearerEgg(egg.id))
        XCTAssertNotNil(s.state.eggFromWearer)
        XCTAssertTrue(s.state.dex.contains { $0.isReleased }, "the Pokémon raised is sent off")
    }

    func testTheEggInIncubationIsNamedAndDrawnAsAWearerEgg() throws {
        let egg = WearerEgg(formKey: try gmax(pikachu).key)
        let s = try store(given: true) { $0.wearerEggs = [egg] }
        XCTAssertTrue(s.useWearerEgg(egg.id))
        XCTAssertEqual(s.incubatingEggName, s.l.wearerEggName)
        XCTAssertEqual(s.eggKind, .dungeon(pikachu))
    }

    // MARK: The hatch record

    func testAWearerEeveeHatchedFromTheEggMarksNoBossCaught() async throws {
        let form = try gmax(eevee)
        let egg = WearerEgg(formKey: form.key)
        let s = try store(won: [form], given: true) { $0.wearerEggs = [egg] }
        XCTAssertTrue(s.useWearerEgg(egg.id))
        s.setEggUsageForTesting(s.eggHatchThreshold)
        await s.hatchIfNeeded()
        let hatched = try XCTUnwrap(s.state.active)
        XCTAssertEqual(hatched.hatch?.egg, .wearer(formKey: form.key))
        growToTheEnd(s)
        var withEgg = CompanionState()
        withEgg.dex = [try XCTUnwrap(s.state.dex.last { !$0.isReleased })]
        var asDungeonEgg = withEgg
        let boss = try XCTUnwrap(DungeonCatalog.all.first { !$0.id.isChallenge && !$0.id.isHideout && $0.id != .ruinsOfAlph }?.bosses.first)
        asDungeonEgg.dex[0].hatch = HatchRecord(egg: .dungeon(baseID: SpeciesInfo.baseID(of: boss), form: nil, shiny: false))
        withEgg.dex[0].hatch = HatchRecord(egg: .wearer(formKey: "\(boss)-gmax"))
        XCTAssertFalse(asDungeonEgg.bossesCaughtBefore.isEmpty, "the check can fail")
        XCTAssertTrue(withEgg.bossesCaughtBefore.isEmpty)
    }

    func testTheLuckScreenNamesTheWearerEggAndItsDrawIsTheOneWearer() throws {
        let form = try gmax(pikachu)
        let egg = HatchEgg.wearer(formKey: form.key)
        for language in AppLanguage.allCases { XCTAssertEqual(L(language).hatchEggName(egg), L(language).wearerEggName, "\(language)") }
        XCTAssertNil(egg.spec)
        let draw = HatchDraw(collection: CompanionState(), items: [], rules: .current)
        let outcomes = draw.outcomes(egg, index: [])
        XCTAssertEqual(outcomes.map(\.id), [pikachu])
        XCTAssertEqual(outcomes.map(\.form), [PokemonForm.resolved(baseID: pichu, form: nil)])
        let record = try JSONDecoder().decode(HatchRecord.self, from: JSONEncoder().encode(HatchRecord(egg: egg)))
        XCTAssertEqual(record.egg, egg)
    }

    // MARK: Criterion 1, the texts

    func testItsNameInTheEightLanguages() {
        let names: [AppLanguage: String] = [
            .ko: "폼 알", .en: "Wearer Egg", .ja: "すがたのタマゴ", .es: "Huevo Portador", .fr: "Œuf Porteur",
            .pt: "Ovo Portador", .de: "Träger-Ei", .ru: "Яйцо носителя",
        ]
        XCTAssertEqual(Set(names.keys), Set(AppLanguage.allCases))
        for (language, name) in names { XCTAssertEqual(L(language).wearerEggName, name, "\(language)") }
    }

    func testItsCardNamesThePokemonItHolds() throws {
        let floetteForm = try mega(floette), pikachuForm = try gmax(pikachu)
        XCTAssertEqual(L(.fr).wearerEggContent(floetteForm, species: "Floette"), "Floette Fleur Éternelle")
        XCTAssertEqual(L(.en).wearerEggContent(floetteForm, species: "Floette"), "Eternal Flower Floette")
        XCTAssertEqual(L(.fr).wearerEggContent(pikachuForm, species: "Pikachu"), "un Pikachu avec le Facteur Gigamax")
        XCTAssertEqual(L(.en).wearerEggContent(pikachuForm, species: "Pikachu"), "a Pikachu with the Gigantamax Factor")
        for language in AppLanguage.allCases {
            let l = L(language)
            for form in [floetteForm, pikachuForm] {
                let line = try XCTUnwrap(l.battleFormWearer(form, species: "X"))
                XCTAssertTrue(line.hasSuffix(l.wearerEggContent(form, species: "X")), "\(language) reuses the Wearer line")
            }
        }
    }

    func testAFormWithoutARequirementIsNamedByItsSpecies() throws {
        XCTAssertEqual(L(.en).wearerEggContent(try mega(3), species: "Venusaur"), "Venusaur")
    }
}
