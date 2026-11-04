import XCTest
@testable import PokeTokenBar

private struct SuspenseLineProvider: PokeProviding {
    func line(baseSpeciesID: Int) async throws -> EvoLine {
        func node(_ id: Int) -> EvoNode {
            EvoNode(speciesID: id, children: (PokemonEvolutionData.children[id] ?? []).map(node))
        }
        return EvoLine(baseID: baseSpeciesID, tree: node(baseSpeciesID), rarity: .common,
                       names: [105: ["en": "Marowak"], 503: ["en": "Samurott"]])
    }
    func baseSpeciesIndex() async throws -> [BaseSpecies] {
        [BaseSpecies(id: 16, captureRate: 255), BaseSpecies(id: 104, captureRate: 190)]
    }
    func baseSpecies(id: Int) async throws -> BaseSpecies? { nil }
}

/// A form is rolled at the hatch but stays hidden until a stage shows it: everything said of the Pokémon before then
/// holds for each form it can carry.
@MainActor
final class FormSuspenseTests: XCTestCase {
    private let normal = PokemonForm("normal"), alola = PokemonForm("alola")
    private let hiddenLines = [102, 104, 109, 155, 172, 206, 216, 420, 439, 501, 548, 627, 664, 677, 679, 704, 712, 722, 744,
                               848, 868, 891, 915, 924, 963]

    private func store(_ path: [Int], stage: Int = 0, form: PokemonForm?, dex: [DexEntry] = [],
                       rollItems: Set<ItemKind>? = nil, inventory: [String: Int] = [:], shiny: Bool = false,
                       boost: Bool = false, newForm: Bool = false, used: Int = 0) async throws -> CompanionStore {
        let suite = "Suspense-\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        addTeardownBlock { defaults.removePersistentDomain(forName: suite) }
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("\(suite).json")
        addTeardownBlock { try? FileManager.default.removeItem(at: file) }
        var state = CompanionState()
        state.language = .en
        state.installBaselineSet = true
        var mon = MonState(baseID: path[0], pathIDs: Array(path.prefix(stage + 1)), plannedPathIDs: path, stageIndex: stage,
                           usedAtStage: used, rarity: .common, totalForms: path.count, isShiny: shiny, nature: .hardy,
                           hasGrowthBoost: boost, form: form)
        mon.hasNewForm = newForm
        if let rollItems { mon.hatch = HatchRecord(egg: .tier(nil), rollItems: rollItems) }
        state.active = mon
        state.dex = dex
        state.inventory = inventory
        try JSONEncoder().encode(state).write(to: file)
        let store = CompanionStore(provider: SuspenseLineProvider(), fileURL: file, defaults: defaults)
        store.update(todayTokensByProvider: [:], todayDate: "2026-10-22", monthTotal: 0, burnTier: .idle,
                     limitWarning: false, hasUsageData: true)
        for _ in 0..<300 where store.currentLine == nil { try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertNotNil(store.currentLine)
        return store
    }

    private func graduated(_ chain: [Int], form: PokemonForm?, shiny: Bool = false, released: Bool = false) -> DexEntry {
        let date = Date(timeIntervalSince1970: 1_790_000_000)
        return DexEntry(baseID: chain[0], finalID: chain.last!, chainOrder: chain, rarity: .common, caughtAt: date,
                        isShiny: shiny, releasedAt: released ? date : nil, form: form)
    }

    private func kantoCubone(form: PokemonForm? = nil, stage: Int = 0, boost: Bool = true, newForm: Bool = false,
                             inventory: [String: Int] = [:], used: Int = 0) async throws -> CompanionStore {
        try await store([104, 105], stage: stage, form: form ?? normal, dex: [graduated([104, 105], form: normal)],
                        inventory: inventory, boost: boost, newForm: newForm, used: used)
    }

    // MARK: Which lines

    func testTheLinesWhoseFormIsHiddenAtTheirFirstStage() {
        let lines = Set((1...1025).filter { base in
            PokemonForm.isFormHidden(baseID: base, reached: [base])
                && PokemonForm.rollableLineForms(baseID: base).count > 1
        })
        XCTAssertEqual(lines, Set(hiddenLines))
    }

    /// Why `formSuspense` reads no egg type: the type an egg asks of a form is its first stage's, the same in each.
    func testAnEggsTypeNeverNarrowsAHiddenForm() {
        for base in hiddenLines {
            let forms = PokemonForm.rollableLineForms(baseID: base)
            for type in PokemonType.allCases {
                XCTAssertEqual(CompanionState.eggForms(baseID: base, type: type), forms, "\(base) \(type)")
            }
        }
    }

    func testAFormShowsAtTheFirstStageThatHasForms() async throws {
        let samurott = [501, 502, 503]
        for stage in 0...1 {
            let s = try await store(samurott, stage: stage, form: PokemonForm("hisui"))
            XCTAssertEqual(s.formSuspense?.revealSpeciesID, 503, "\(stage)")
        }
        let revealed = try await store(samurott, stage: 2, form: PokemonForm("hisui"))
        XCTAssertNil(revealed.formSuspense)
    }

    func testAFormAlreadyShownIsNoMystery() async throws {
        let meowth = try await store([52], form: PokemonForm("galar"), dex: [graduated([52, 53], form: PokemonForm("kanto"))])
        XCTAssertNil(meowth.formSuspense)
    }

    func testALineWithoutFormsHasNoSuspense() async throws {
        let charmander = try await store([4, 5, 6], form: nil)
        XCTAssertNil(charmander.formSuspense)
    }

    // MARK: The forms it can carry

    func testEveryFormOfItsLineWithoutANote() async throws {
        let s = try await kantoCubone()
        XCTAssertEqual(s.formSuspense?.outcomes.map(\.form), [normal, alola])
        XCTAssertEqual(s.formSuspense?.outcomes.map(\.weight), [1, 2])
    }

    func testTheOvalCharmNotedAtItsRollLeavesTheMissingForms() async throws {
        let leftOne = try await store([104, 105], form: alola, dex: [graduated([104, 105], form: normal)], rollItems: [.ovalCharm])
        XCTAssertNil(leftOne.formSuspense, "only one form it could be")
        let rockruff = [744, 745]
        let midday = PokemonForm("midday")
        let leftTwo = try await store(rockruff, form: PokemonForm("dusk"), dex: [graduated(rockruff, form: midday)], rollItems: [.ovalCharm])
        XCTAssertEqual(leftTwo.formSuspense?.outcomes.map(\.form).contains(midday), false)
        XCTAssertEqual(leftTwo.formSuspense?.outcomes.count, 2)
    }

    /// [Regression] A form the egg left no doubt about: the track shows it, as Home judges it.
    func testOneFormLeftKeepsTheTrackOfThatForm() async throws {
        let s = try await store([104, 105], form: alola, dex: [graduated([104, 105], form: normal)], rollItems: [.ovalCharm], newForm: true)
        XCTAssertEqual(s.evolutionTrack, [.reached(104, isCurrent: true), .coming(105, isCaught: false), .graduation])
        XCTAssertEqual(s.evolutionTrackForm, alola)
        XCTAssertEqual(s.activeVerdict, .newForm(speciesID: 105))
    }

    func testAnOvalCharmBoughtAfterTheRollChangesNothing() async throws {
        let s = try await store([104, 105], form: alola, dex: [graduated([104, 105], form: normal)], rollItems: [],
                                inventory: [ItemKind.ovalCharm.rawValue: 1])
        XCTAssertEqual(s.formSuspense?.outcomes.count, 2)
    }

    func testCollectedFinalFormsAnswerAsOneFormAtATime() {
        var state = CompanionState()
        let forms = PokemonForm.lineForms(baseID: 744)
        func check(_ label: String) {
            let all = state.collectedFinalForms(forBaseID: 744)
            for form in forms {
                XCTAssertEqual(all.contains(form), state.hasCollectedFinal(forBaseID: 744, form: form), "\(label) \(form)")
            }
        }
        check("nothing")
        state.collectedFinals = ["744:745"]
        check("no record kept")
        state.dex = [graduated([744, 745], form: forms[1])]
        check("one form")
        state.dex.append(graduated([744, 745], form: forms[0], released: true))
        check("one sent off")
    }

    /// The suspense is made once per state: every badge and line of a render asks it, for up to 63 forms. The stage
    /// that shows the form must not find it still there.
    func testAnEvolutionEndsACachedSuspense() async throws {
        let s = try await kantoCubone()
        XCTAssertNotNil(s.formSuspense)
        s.applyUsage(s.threshold)
        XCTAssertEqual(s.state.active?.currentID, 105)
        XCTAssertNil(s.formSuspense)
    }

    /// [Regression] Sixty-three forms asked the goals sixty-three times: seconds a render on a full Pokédex.
    func testGoalsHoldForEveryFormOfALongLine() async throws {
        let forms = PokemonForm.lineForms(baseID: 868)
        let s = try await store([868, 869], form: forms[40], newForm: true)
        XCTAssertEqual(s.formSuspense?.outcomes.count, forms.count)
        XCTAssertFalse(s.activeGoals.isEmpty)
        XCTAssertEqual(s.activeGoals.first?.gain, 2)
    }

    // MARK: Status

    func testOneFormGraduatedOfTwoIsAMystery() async throws {
        for form in [normal, alola] {
            let s = try await kantoCubone(form: form, boost: form == normal, newForm: form == alola)
            XCTAssertEqual(s.activeNews?.mystery, FormMystery(chances: 2, outOf: 3, revealSpeciesID: 105))
            XCTAssertEqual(s.activeNews?.isDuplicate, false)
            XCTAssertFalse(s.activeIsRepeat)
            XCTAssertTrue(s.hidesGrowthAmounts)
            XCTAssertEqual(s.activeVerdict, .formMystery(FormMystery(chances: 2, outOf: 3, revealSpeciesID: 105)))
        }
    }

    func testOddsAreInLowestTerms() async throws {
        let rockruff = [744, 745]
        let s = try await store(rockruff, form: PokemonForm("midday"), dex: [
            graduated(rockruff, form: PokemonForm("midday")), graduated(rockruff, form: PokemonForm("midnight")),
        ])
        XCTAssertEqual(s.activeNews?.mystery?.chances, 1)
        XCTAssertEqual(s.activeNews?.mystery?.outOf, 2)
    }

    func testAFirstShinyWhicheverTheFormMakesTheOddsCertain() async throws {
        let s = try await store([104, 105], form: normal, dex: [graduated([104, 105], form: normal)], shiny: true, boost: true)
        XCTAssertEqual(s.activeNews?.mystery, FormMystery(chances: 1, outOf: 1, revealSpeciesID: 105))
        XCTAssertTrue(try XCTUnwrap(s.activeNews?.mystery).isCertain)
    }

    func testAFirstShinyOnlyOneFormBringsIsAMystery() async throws {
        let s = try await store([104, 105], form: normal, dex: [graduated([104, 105], form: normal, shiny: true),
                                                                graduated([104, 105], form: alola)], shiny: true, boost: true)
        let news = try XCTUnwrap(s.activeNews)
        XCTAssertEqual(news.mystery, FormMystery(chances: 1, outOf: 2, revealSpeciesID: 105))
        XCTAssertFalse(news.firstShiny, "only one of its forms would bring it")
        XCTAssertFalse(news.isDuplicate)
    }

    func testACostumeWhicheverTheFormMakesTheOddsCertain() async throws {
        let s = try await store([172, 25, 26], form: normal, dex: [graduated([172, 25, 26], form: normal)], boost: true)
        XCTAssertEqual(s.activeNews?.mystery, FormMystery(chances: 1, outOf: 1, revealSpeciesID: 26))
    }

    func testNamesLeaveOutAFormStillHidden() async throws {
        let hidden = try await store([104, 105], form: alola, newForm: true)
        XCTAssertEqual(hidden.activeSpeciesName(105), "Marowak")
        let shown = try await store([104, 105], stage: 1, form: alola, newForm: true)
        XCTAssertEqual(shown.activeNewsNames.last, shown.formDisplayName("Marowak", speciesID: 105, form: alola))
        XCTAssertNotEqual(shown.activeNewsNames.last, "Marowak")
    }

    func testTheHintKeepsAStageNeverSeenUnnamed() async throws {
        let s = try await store([104, 105], form: alola, newForm: true)
        XCTAssertEqual(s.activeNewsNames, ["#104", "???"])
        XCTAssertEqual(s.activeNewsHint, s.l.activeNewHint(["#104", "???"], certain: true))
        let reached = try await store([104, 105], stage: 1, form: alola, newForm: true)
        XCTAssertFalse(reached.activeNewsNames.contains("???"))
        let shiny = try await store([104, 105], form: alola, shiny: true, newForm: true)
        XCTAssertEqual(shiny.activeNewsNames, ["#104", "???", shiny.l.activeFirstShiny])
    }

    func testTheHintNamesASpeciesGraduatedInAnotherForm() async throws {
        let s = try await store([104, 105], form: alola, dex: [graduated([104, 105], form: normal)],
                                rollItems: [.ovalCharm], newForm: true)
        XCTAssertEqual(s.activeNewsNames, [s.formDisplayName("Marowak", speciesID: 105, form: alola)])
    }

    func testTheHintOfAMysteryNamesTheStageThatShowsIt() async throws {
        let s = try await kantoCubone(form: normal)
        XCTAssertEqual(s.activeNewsHint, s.l.formMysteryHint("Marowak", FormMystery(chances: 2, outOf: 3, revealSpeciesID: 105)))
    }

    func testNoFormGraduatedStaysUsualWithoutItsForm() async throws {
        let s = try await store([963, 964], form: PokemonForm("hero"), newForm: true)
        XCTAssertNotNil(s.formSuspense)
        XCTAssertNil(s.activeNews?.mystery)
        XCTAssertFalse(s.hidesGrowthAmounts)
        XCTAssertEqual(s.activeNews?.newSpecies, [963, 964])
        XCTAssertEqual(s.activeVerdict, .lineToComplete(newSpecies: 2...2))
        XCTAssertEqual(s.activeSpeciesName(964), "#964", "named without its form")
    }

    func testEveryFormGraduatedIsADuplicate() async throws {
        let s = try await store([104, 105], form: alola, dex: [graduated([104, 105], form: normal), graduated([104, 105], form: alola)], boost: true)
        XCTAssertNotNil(s.formSuspense)
        XCTAssertNil(s.activeNews?.mystery)
        XCTAssertEqual(s.activeNews?.isDuplicate, true)
        XCTAssertTrue(s.activeIsRepeat)
        XCTAssertEqual(s.activeVerdict, .spare)
    }

    func testTheStageThatShowsTheFormGivesTheUsualVerdict() async throws {
        let s = try await kantoCubone(form: alola, stage: 1, boost: false, newForm: true)
        XCTAssertNil(s.formSuspense)
        XCTAssertNil(s.activeNews?.mystery)
        XCTAssertEqual(s.activeVerdict, .newForm(speciesID: 105))
        XCTAssertEqual(s.activeNews?.newSpecies, [105])
    }

    func testARevealedDittoHasNoMystery() async throws {
        let s = try await store([132], form: nil)
        XCTAssertNil(s.formSuspense)
    }

    // MARK: Ways

    func testWaysHoldForEveryFormItCanCarry() async throws {
        let mimeJr = try await store([439, 122], form: PokemonForm("kanto"))
        XCTAssertEqual(Set(mimeJr.activeWays), [[439, 122], [439, 122, 866]])
        XCTAssertEqual(mimeJr.activeVerdict, .lineToComplete(newSpecies: 2...3))
    }

    // MARK: Growth

    func testAMysteryShowsOnlyTheBonusesOfEveryForm() async throws {
        for form in [normal, alola] {
            let s = try await kantoCubone(form: form, boost: form == normal, newForm: form == alola, inventory: [
                ItemKind.magmaStone.rawValue: 1, ItemKind.libertyPass.rawValue: 1, ItemKind.prisonBottle.rawValue: 1,
                ItemKind.silverWing.rawValue: 1,
            ])
            XCTAssertEqual(s.currentGrowthFactors.map(\.source), [.item(.silverWing), .item(.gracidea)].filter {
                s.currentGrowthFactors.map(\.source).contains($0)
            })
            XCTAssertFalse(s.currentGrowthFactors.contains { $0.source == .repeatBoost }, "\(form)")
            XCTAssertTrue(s.currentGrowthFactors.contains { $0.source == .item(.silverWing) }, "\(form)")
            for hidden in [ItemKind.magmaStone, .libertyPass, .prisonBottle] {
                XCTAssertFalse(s.currentGrowthFactors.contains { $0.source == .item(hidden) }, "\(form) \(hidden)")
            }
        }
    }

    func testAMysteryStillGrowsAtItsRealSpeed() async throws {
        let repeatForm = try await kantoCubone(form: normal, boost: true)
        let newForm = try await kantoCubone(form: alola, boost: false, newForm: true)
        XCTAssertLessThan(repeatForm.threshold, newForm.threshold)
    }

    func testAKnownStatusKeepsItsWholeGrowth() async throws {
        let s = try await store([104, 105], form: alola, dex: [graduated([104, 105], form: normal), graduated([104, 105], form: alola)],
                                inventory: [ItemKind.magmaStone.rawValue: 1], boost: true)
        XCTAssertTrue(s.currentGrowthFactors.contains { $0.source == .repeatBoost })
        XCTAssertTrue(s.currentGrowthFactors.contains { $0.source == .item(.magmaStone) })
    }

    // MARK: Goals

    func testAGoalNeedsEveryFormItCanCarry() async throws {
        let cubone = try await kantoCubone(form: alola, boost: false, newForm: true)
        XCTAssertEqual(cubone.activeGoals, [], "a possible duplicate advances nothing")
    }

    func testAKnownNewLineKeepsItsGoalsAtTheLeastGain() async throws {
        let forms = try await store([963, 964], form: PokemonForm("hero"), newForm: true)
        XCTAssertFalse(forms.activeGoals.isEmpty)
        let zero = try await store([963, 964], form: PokemonForm("zero"), newForm: true)
        XCTAssertEqual(forms.activeGoals, zero.activeGoals, "the same whichever form it rolled")
    }

    func testABranchingGoalCountsTheLeastAnyFormAdds() async throws {
        let kanto = try await store([439, 122], form: PokemonForm("kanto"))
        let galar = try await store([439, 122], form: PokemonForm("galar"))
        XCTAssertEqual(kanto.activeGoals, galar.activeGoals)
        let galarGain = galar.activeGoals.first { $0.generation == 8 }
        XCTAssertEqual(galarGain?.gain ?? 0, 0, "Mr. Rime is out of reach of a Kanto form")
    }

    // MARK: Track

    func testTheStageThatShowsTheFormStandsForEachForm() async throws {
        let s = try await kantoCubone(form: normal)
        XCTAssertEqual(s.evolutionTrack, [.reached(104, isCurrent: true), .branch([
            [BranchEvolutionItem(speciesID: 105, isCollected: true, form: normal)],
            [BranchEvolutionItem(speciesID: 105, isCollected: false, form: alola)],
        ])])
        let alolan = try await kantoCubone(form: alola, boost: false, newForm: true)
        XCTAssertEqual(alolan.evolutionTrack, s.evolutionTrack, "nothing tells them apart")
    }

    func testAMiddleStageComesBeforeTheFormsAtTheStageThatShowsThem() async throws {
        let hisui = PokemonForm("hisui"), first = PokemonForm.forms(speciesID: 503)[0]
        let oshawott = try await store([501, 502, 503], form: hisui)
        XCTAssertEqual(oshawott.evolutionTrack, [.reached(501, isCurrent: true), .coming(502, isCaught: false), .branch([
            [BranchEvolutionItem(speciesID: 503, isCollected: false, form: first)],
            [BranchEvolutionItem(speciesID: 503, isCollected: false, form: hisui)],
        ])])
        let dewott = try await store([501, 502, 503], stage: 1, form: hisui)
        XCTAssertEqual(dewott.evolutionTrack.count, 3)
        XCTAssertEqual(dewott.evolutionTrack[1], .reached(502, isCurrent: true))
    }

    func testAWayOnlyOneFormTakesShowsWithThatForm() async throws {
        let s = try await store([439, 122], form: PokemonForm("kanto"))
        guard case .branch(let paths)? = s.evolutionTrack.last else { return XCTFail("\(s.evolutionTrack)") }
        XCTAssertEqual(paths.map { $0.map(\.speciesID) }, [[122], [122, 866]])
        XCTAssertEqual(paths[1].map(\.form), [PokemonForm("galar"), PokemonForm("galar")])
    }

    func testTheCaptionKeepsOnlyThePercentage() {
        let track: [CompanionStore.EvolutionTrackStop] = [.reached(104, isCurrent: true), .branch([])]
        XCTAssertEqual(CompanionHeader.trackCaption(track, amount: nil, percent: "24%", names: [:], l: L(.en), eta: "about 9 h"), "24%")
        XCTAssertEqual(CompanionHeader.trackCaption(track, amount: "9M", percent: "24%", names: [:], l: L(.en)), L(.en).toNextEvolution("9M") + " · 24%")
    }

    func testBranchItemsOfOneSpeciesAreDistinct() {
        let a = BranchEvolutionItem(speciesID: 105, isCollected: true, form: normal)
        let b = BranchEvolutionItem(speciesID: 105, isCollected: false, form: alola)
        XCTAssertNotEqual(a.id, b.id)
    }

    // MARK: Oak

    func testOakNeverSendsOffNorFeedsAMystery() async throws {
        let s = try await kantoCubone(form: normal, inventory: [ItemKind.rareCandy.rawValue: 5])
        await s.loadHatchIndex()
        XCTAssertNil(s.oakRelease)
        XCTAssertFalse(s.oakSteps.contains { if case .candies = $0 { return true } else { return false } })
        XCTAssertTrue(s.oakSteps.contains(.raise))
    }

    func testOakNamesTheStageThatShowsTheForm() {
        let mystery = FormMystery(chances: 2, outOf: 3, revealSpeciesID: 503)
        XCTAssertEqual(L(.fr).oakBubble(.formMystery(mystery), name: "Mateloutre", newFormName: "", revealName: "Clamiral"),
                       "2 chances sur 3 d'apporter du nouveau, attends qu'il devienne Clamiral !")
        XCTAssertEqual(L(.fr).oakVerdictLabel(.formMystery(mystery)), "Forme mystère")
    }

    // MARK: Words

    func testTheHintTellsTheStageAndTheRealOdds() {
        let mystery = FormMystery(chances: 2, outOf: 3, revealSpeciesID: 503)
        XCTAssertEqual(L(.fr).formMysteryHint("Clamiral", mystery), "Elle se révèle quand il devient Clamiral. 2 chances sur 3 d'apporter du nouveau.")
        XCTAssertEqual(L(.fr).formMysteryOdds(FormMystery(chances: 1, outOf: 2, revealSpeciesID: 503)), "1 chance sur 2 d'apporter du nouveau")
        XCTAssertEqual(L(.fr).formMysteryOdds(FormMystery(chances: 1, outOf: 1, revealSpeciesID: 503)), "Du nouveau quelle que soit sa forme")
    }

    func testRussianOddsDecline() {
        func odds(_ c: Int, _ n: Int) -> String { L(.ru).formMysteryOdds(FormMystery(chances: c, outOf: n, revealSpeciesID: 503)) }
        XCTAssertTrue(odds(1, 2).hasPrefix("1 шанс из 2"))
        XCTAssertTrue(odds(2, 3).hasPrefix("2 шанса из 3"))
        XCTAssertTrue(odds(5, 7).hasPrefix("5 шансов из 7"))
        XCTAssertTrue(odds(11, 31).hasPrefix("11 шансов из 31"))
        XCTAssertTrue(odds(12, 31).hasPrefix("12 шансов из 31"))
        XCTAssertTrue(odds(21, 31).hasPrefix("21 шанс из 31"))
        XCTAssertTrue(odds(22, 31).hasPrefix("22 шанса из 31"))
    }

    // MARK: Reveal

    func testTheRevealSaysWhatTheFormBrings() async throws {
        let alolan = try await kantoCubone(form: alola, stage: 1, boost: false, newForm: true)
        XCTAssertEqual(alolan.evolutionBody("X", wasMystery: true), L(.en).notifEvolveBody("X") + " " + L(.en).formRevealBringsNew)
        let kanto = try await kantoCubone(form: normal, stage: 1)
        XCTAssertEqual(kanto.evolutionBody("X", wasMystery: true), L(.en).notifEvolveBody("X") + " " + L(.en).formRevealNothingNew)
    }

    func testAnEvolutionThatRevealsNoMysteryStaysPlain() async throws {
        let notMystery = try await kantoCubone(form: alola, stage: 1, boost: false, newForm: true)
        XCTAssertEqual(notMystery.evolutionBody("X", wasMystery: false), L(.en).notifEvolveBody("X"))
        let stillHidden = try await store([501, 502, 503], stage: 1, form: PokemonForm("hisui"),
                                          dex: [graduated([501, 502, 503], form: PokemonForm.forms(speciesID: 503)[0])])
        XCTAssertEqual(stillHidden.evolutionBody("X", wasMystery: true), L(.en).notifEvolveBody("X"), "a middle stage shows no form")
    }

    // MARK: Journal

    func testTheJournalKeepsQuietAboutAMystery() async throws {
        let s = try await kantoCubone(form: normal)
        let entry = try XCTUnwrap(s.dexEntries.first { s.isActiveDexEntry($0) })
        XCTAssertTrue(s.hidesFormNews(entry))
        XCTAssertFalse(s.duplicateCatchEntryIDs.contains(entry.id))
    }

    func testTheJournalKeepsTheUsualBadgesOfAKnownStatus() async throws {
        let s = try await store([104, 105], form: alola, dex: [graduated([104, 105], form: normal), graduated([104, 105], form: alola)], boost: true)
        let entry = try XCTUnwrap(s.dexEntries.first { s.isActiveDexEntry($0) })
        XCTAssertFalse(s.hidesFormNews(entry))
        XCTAssertTrue(s.duplicateCatchEntryIDs.contains(entry.id))
    }

    func testOneSentOffBeforeItsFormShowedIsNeverKnown() async throws {
        let sentOff = graduated([104], form: alola, released: true)
        let shown = graduated([104, 105], form: alola, released: true)
        let raised = graduated([104, 105], form: normal)
        let s = try await store([4, 5, 6], form: nil, dex: [raised, sentOff, shown])
        XCTAssertTrue(s.hidesFormNews(sentOff))
        XCTAssertFalse(s.hidesFormNews(shown))
        XCTAssertFalse(s.hidesFormNews(raised))
        XCTAssertFalse(s.duplicateCatchEntryIDs.contains(sentOff.id))
    }

    // MARK: Luck

    private let luckIndex = [BaseSpecies(id: 16, captureRate: 255), BaseSpecies(id: 104, captureRate: 190)]

    private func hatch(_ chain: [Int], form: PokemonForm?, day: Double, released: Bool = false) -> DexEntry {
        let date = Date(timeIntervalSince1970: 1_793_600_000 + day * 86_400)
        var entry = DexEntry(baseID: chain[0], finalID: chain.last!, chainOrder: chain, rarity: .common, caughtAt: date,
                             releasedAt: released ? date : nil, form: form)
        entry.hatch = HatchRecord(egg: .tier(nil))
        return entry
    }

    private func luck(_ entries: [DexEntry], active: Bool = false) -> HatchLuck {
        HatchLuck(entries: entries, includesActive: active, today: CompanionState(), index: luckIndex,
                  now: Date(timeIntervalSince1970: 1_793_600_000 + 30 * 86_400))
    }

    func testAMysteryIsNotJudgedOnNew() throws {
        let l = luck([hatch([104, 105], form: normal, day: 1), hatch([104], form: alola, day: 2)], active: true)
        XCTAssertTrue(l.hatches[1].isFormMystery)
        XCTAssertNil(l.hatches[1].judged[.new])
        XCTAssertNil(l.hatches[1].newOdds)
        XCTAssertNotNil(l.hatches[1].judged[.shiny])
    }

    func testTheRevealBringsItIntoTheCounts() throws {
        let l = luck([hatch([104, 105], form: normal, day: 1), hatch([104, 105], form: alola, day: 2)])
        XCTAssertFalse(l.hatches[1].isFormMystery)
        XCTAssertEqual(l.hatches[1].judged[.new]?.hit, true)
        XCTAssertNotNil(l.hatches[1].newOdds)
    }

    func testOneSentOffBeforeItShowedStaysOutOfTheCounts() throws {
        let l = luck([hatch([104, 105], form: normal, day: 1), hatch([104], form: alola, day: 2, released: true)])
        XCTAssertTrue(l.hatches[1].isFormMystery)
        XCTAssertNil(l.hatches[1].judged[.new])
    }

    func testAHiddenFormWithAKnownStatusIsStillJudged() throws {
        let l = luck([hatch([104], form: alola, day: 1)], active: true)
        XCTAssertFalse(l.hatches[0].isFormMystery)
        XCTAssertEqual(l.hatches[0].judged[.new]?.hit, true)
    }
}
