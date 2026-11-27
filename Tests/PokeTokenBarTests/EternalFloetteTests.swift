import XCTest
@testable import PokeTokenBar

private let flabebe = 669, floette = 670, florges = 671
private let eternal = PokemonForm("eternal")

private let flabebeLine = EvoLine(baseID: flabebe,
                                  tree: EvoNode(speciesID: flabebe, children: [EvoNode(speciesID: floette, children: [EvoNode(speciesID: florges, children: [])])]),
                                  rarity: .common, names: [:])

private struct FixedRNG: RandomNumberGenerator {
    let value: UInt64
    mutating func next() -> UInt64 { value }
}

private func entry(_ final: Int, chain: [Int], form: PokemonForm?, shiny: Bool = false) -> DexEntry {
    var e = DexEntry(baseID: chain[0], finalID: final, chainOrder: chain, rarity: .common,
                     caughtAt: Date(timeIntervalSince1970: 0), form: form)
    e.isShiny = shiny
    return e
}

@MainActor
final class EternalFloetteTests: XCTestCase {
    private func store(dex: [DexEntry] = [], rng: any RandomNumberGenerator = SeededRNG(seed: 1)) -> CompanionStore {
        var st = CompanionState()
        st.installBaselineSet = true
        st.dex = dex
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("eternal-\(UUID().uuidString).json")
        try? JSONEncoder().encode(st).write(to: url)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return CompanionStore(provider: StubProvider(value: flabebeLine), fileURL: url, rng: rng, difficulty: 1)
    }

    private let colors = ["red", "yellow", "orange", "blue", "white"]

    // Criterion 1

    func testEternalFlowerIsAFloetteFormWithItsPokeAPISprites() {
        XCTAssertEqual(PokemonForm.forms(speciesID: floette).map(\.rawValue), colors + ["eternal"])
        XCTAssertEqual(PokemonForm.formID(speciesID: floette, form: eternal), 10163)
        XCTAssertEqual(PokemonForm.detailsID(speciesID: floette, form: eternal), 10061)
        XCTAssertEqual(PokemonForm.staticAssetName(speciesID: floette, form: eternal), "10061")
        XCTAssertEqual(PokemonForm.assetName(speciesID: floette, form: eternal), "670-eternal")
        for shiny in [false, true] {
            let still = SpriteStore.spriteURL(speciesID: floette, animated: false, shiny: shiny, form: eternal).absoluteString
            let moving = SpriteStore.spriteURL(speciesID: floette, animated: true, shiny: shiny, form: eternal).absoluteString
            let folder = shiny ? "shiny/" : ""
            XCTAssertTrue(still.hasSuffix("/pokemon/\(folder)10061.png"), still)
            XCTAssertTrue(moving.hasSuffix("/pokemon/other/showdown/\(folder)10061.gif"), moving)
        }
        XCTAssertEqual(PokemonForm.lineForms(baseID: flabebe).map(\.rawValue), colors + ["eternal"])
        XCTAssertEqual(PokemonForm.resolved(speciesID: flabebe, form: eternal)?.rawValue, "red", "only Floette shows it")
        XCTAssertEqual(PokemonForm.resolved(speciesID: florges, form: eternal)?.rawValue, "red")
    }

    func testEternalFlowerHasItsNameInTheEightLanguages() {
        let expected: [AppLanguage: String] = [
            .ko: "영원의 꽃", .en: "Eternal Flower", .ja: "えいえんのはな", .es: "Flor Eterna",
            .fr: "Fleur Éternelle", .pt: "Flor Eterna", .de: "Ewigblütler", .ru: "Вечный цветок",
        ]
        XCTAssertEqual(Set(expected.keys), Set(AppLanguage.allCases))
        for (language, name) in expected {
            XCTAssertEqual(PokemonForm.label(speciesID: floette, form: eternal, language: language), name, "\(language)")
        }
    }

    // Criterion 4

    func testTheFormTotalGoesFrom1482To1483() {
        XCTAssertEqual(CompanionStore.collectableFormCount, 1483)
    }

    func testEternalFloetteCountsInTheSecondStepOfCompletionWhenShiny() {
        let plain = store(dex: [entry(floette, chain: [flabebe, floette], form: eternal)])
        XCTAssertTrue(plain.state.ownsSpecies(floette, form: eternal))
        XCTAssertFalse(plain.state.ownsShinySpecies(floette, form: eternal))
        let shiny = store(dex: [entry(floette, chain: [flabebe, floette], form: eternal, shiny: true)])
        XCTAssertTrue(shiny.state.ownsShinySpecies(floette, form: eternal))
        XCTAssertFalse(shiny.state.ownsShinySpecies(floette, form: PokemonForm("red")))
    }

    // Criterion 2

    func testAnEggOfTheLineWeighsItLikeAColor() {
        let draw = HatchDraw(collection: CompanionState(), items: [], rules: .current)
        let forms = draw.lineFormDraw(baseID: flabebe, types: []).forms
        XCTAssertEqual(forms.last, eternal)
        XCTAssertEqual(PokemonForm.rollWeights(among: forms, collected: []), [Int](repeating: 2, count: 6))
        let held = Set(forms)
        XCTAssertEqual(PokemonForm.rollWeights(among: forms, collected: held), [Int](repeating: 1, count: 6))
    }

    func testItHatchesAloneWhileMissingWithTheOvalCharmOrMissingFormsFirst() {
        var c = CompanionState()
        c.dex = colors.map { entry(florges, chain: [flabebe, floette, florges], form: PokemonForm($0)) }
        let missingFirst = HatchDraw(collection: c, items: [], rules: .current).lineFormDraw(baseID: flabebe, types: [])
        XCTAssertEqual(missingFirst.forms, [eternal])
        XCTAssertEqual(missingFirst.collected.count, 5)
        let oval = HatchDraw(collection: c, items: [.ovalCharm], rules: HatchRules(changes: Set(HatchRules.Change.allCases).subtracting([.missingFormsFirst])))
        XCTAssertEqual(oval.lineFormDraw(baseID: flabebe, types: []).forms, [eternal])
    }

    func testTheEggsOfBeforeReplayWithTheFiveColors() {
        let change = HatchRules.Change.eternalFlower
        func names(_ rules: HatchRules) -> [String] { rules.lineForms(baseID: flabebe).map(\.rawValue) }
        XCTAssertEqual(names(HatchRules(rolledAt: change.publishedAt.addingTimeInterval(-1))), colors)
        XCTAssertEqual(names(HatchRules(rolledAt: change.publishedAt)), colors + ["eternal"])
        XCTAssertEqual(HatchRules(rolledAt: change.publishedAt.addingTimeInterval(-1)).rollableForms(baseID: flabebe).count, 5)

        var before = DexEntry(baseID: flabebe, finalID: florges, chainOrder: [flabebe, floette, florges], rarity: .common,
                              caughtAt: change.publishedAt.addingTimeInterval(-5), form: PokemonForm("red"))
        before.raising = RaisingRecord(hatchedAt: change.publishedAt.addingTimeInterval(-9))
        let moments = HatchLuck.moments(entries: [before], today: CompanionState(), itemsSince: [:])
        XCTAssertEqual(names(moments[0].roll.rules), colors)
        XCTAssertEqual(names(moments[0].hatch.rules), colors)
    }

    func testAnEternalFloetteHatchedAfterTheChangeIsJudgedWithItsFormInTheDraw() {
        let change = HatchRules.Change.eternalFlower
        var red = DexEntry(baseID: flabebe, finalID: florges, chainOrder: [flabebe, floette, florges], rarity: .common,
                           caughtAt: change.publishedAt.addingTimeInterval(2), form: PokemonForm("red"))
        red.raising = RaisingRecord(hatchedAt: change.publishedAt.addingTimeInterval(-30))
        var floetteEntry = DexEntry(baseID: flabebe, finalID: floette, chainOrder: [floette], rarity: .common,
                                    caughtAt: change.publishedAt.addingTimeInterval(5), form: eternal)
        floetteEntry.raising = RaisingRecord(hatchedAt: change.publishedAt.addingTimeInterval(1))

        let moments = HatchLuck.moments(entries: [red, floetteEntry], today: CompanionState(), itemsSince: [:])
        XCTAssertTrue(moments[1].roll.lineFormDraw(baseID: flabebe, types: []).forms.contains(eternal))

        let luck = HatchLuck(entries: [red, floetteEntry], includesActive: false, today: CompanionState(),
                             index: [BaseSpecies(id: flabebe, captureRate: 255)], itemsSince: [:],
                             now: change.publishedAt.addingTimeInterval(86_400))
        XCTAssertTrue(luck.hatches[1].bringsNew)
    }

    // Criterion 3

    func testItHatchesStraightAsAFloetteAndNeverEvolves() async throws {
        let s = store(rng: FixedRNG(value: 10))
        await s.hatch(baseID: flabebe)
        let active = try XCTUnwrap(s.state.active)
        XCTAssertEqual(active.form, eternal)
        XCTAssertEqual(active.baseID, flabebe)
        XCTAssertEqual(active.pathIDs, [floette])
        XCTAssertEqual(active.plannedPathIDs, [floette])
        XCTAssertEqual(active.totalForms, 1)
    }

    func testARestartKeepsAnEternalFloetteAsAFloette() async throws {
        var st = CompanionState()
        st.installBaselineSet = true
        st.active = MonState(baseID: flabebe, pathIDs: [floette], plannedPathIDs: [floette], stageIndex: 0, usedAtStage: 0,
                             rarity: .common, totalForms: 1, form: eternal)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("eternal-\(UUID().uuidString).json")
        try JSONEncoder().encode(st).write(to: url)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        let s = CompanionStore(provider: StubProvider(value: flabebeLine), fileURL: url, rng: SeededRNG(seed: 1), difficulty: 1)
        s.update(todayTokensByProvider: ["test": 0], todayDate: "d1", monthTotal: 0, burnTier: .idle, limitWarning: false, hasUsageData: true)
        for _ in 0..<50 where s.currentLine == nil { await Task.yield() }
        XCTAssertNotNil(s.currentLine)
        XCTAssertEqual(s.state.active?.pathIDs, [floette])
        XCTAssertEqual(s.state.active?.plannedPathIDs, [floette])
        XCTAssertEqual(s.state.active?.currentID, floette)
    }

    func testAColorHatchesAFlabebeThatGrowsToFlorges() async throws {
        let s = store(rng: FixedRNG(value: 0))
        await s.hatch(baseID: flabebe)
        let active = try XCTUnwrap(s.state.active)
        XCTAssertEqual(active.form?.rawValue, "red")
        XCTAssertEqual(active.pathIDs, [flabebe])
        XCTAssertEqual(active.plannedPathIDs, [flabebe, floette, florges])
    }

    func testFloetteEvolvesToFlorgesInEveryColorButEternal() {
        for color in colors { XCTAssertTrue(PokemonEvolutionData.allows(florges, from: floette, form: PokemonForm(color)), color) }
        XCTAssertFalse(PokemonEvolutionData.allows(florges, from: floette, form: eternal))
        XCTAssertEqual(PokemonEvolutionData.children(of: floette, form: eternal), [])
    }

    // Criterion 5

    func testOnlyAnEternalFloetteWearsMegaFloette() throws {
        let mega = try XCTUnwrap(BattleForms.daily.first { $0.speciesID == floette })
        let eternalFloette = entry(floette, chain: [flabebe, floette], form: eternal)
        XCTAssertTrue(mega.isWorn(by: eternalFloette))
        for color in colors {
            XCTAssertFalse(mega.isWorn(by: entry(floette, chain: [flabebe, floette], form: PokemonForm(color))), color)
        }
        XCTAssertFalse(mega.isWorn(by: entry(floette, chain: [flabebe, floette], form: nil)))
        XCTAssertFalse(mega.isWorn(by: entry(florges, chain: [flabebe, floette, florges], form: eternal)))
        var released = eternalFloette
        released.releasedAt = Date(timeIntervalSince1970: 1)
        XCTAssertFalse(mega.isWorn(by: released))
    }
}
