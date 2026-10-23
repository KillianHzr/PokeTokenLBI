import XCTest
@testable import PokeTokenBar

/// Lines as PokéAPI returns them: every evolution is in the tree, whatever the form of the individual.
private struct FormLineProvider: PokeProviding {
    let entries = [BaseSpecies(id: 52, captureRate: 255), BaseSpecies(id: 83, captureRate: 45),
                   BaseSpecies(id: 550, captureRate: 25)]
    func line(baseSpeciesID: Int) async throws -> EvoLine {
        let children: [Int: [Int]] = [52: [53, 863], 83: [865], 550: [902]]
        let tree = EvoNode(speciesID: baseSpeciesID,
                           children: (children[baseSpeciesID] ?? []).map { EvoNode(speciesID: $0, children: []) })
        return EvoLine(baseID: baseSpeciesID, tree: tree, rarity: .common, names: [:])
    }
    func baseSpeciesIndex() async throws -> [BaseSpecies] { entries }
    func baseSpecies(id: Int) async throws -> BaseSpecies? { entries.first { $0.id == id } }
}

/// Regional evolutions, branching lines and the forms of a line follow the individual's form, as in the
/// games: a Kanto Farfetch'd never becomes Sirfetch'd, a counterfeit Poltchageist becomes an unremarkable
/// Sinistcha, and a line is only halved in the egg roll once every final and form of it is collected.
@MainActor
final class FormAwareLineTests: XCTestCase {
    private let date = Date(timeIntervalSince1970: 1_790_000_000)

    private func store(_ st: CompanionState, seed: UInt64 = 1) throws -> CompanionStore {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("form-lines-\(UUID().uuidString).json")
        try JSONEncoder().encode(st).write(to: url)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return CompanionStore(provider: FormLineProvider(), clock: { self.date }, fileURL: url, rng: SeededRNG(seed: seed))
    }

    private func readyState() -> CompanionState {
        var st = CompanionState()
        st.installBaselineSet = true
        st.lastDate = "2026-10-21"
        return st
    }

    /// Hatches `base`, pre-rolled in `form`.
    private func hatch(_ base: Int, _ form: String, seed: UInt64 = 1,
                       before prepare: (inout CompanionState) -> Void = { _ in }) async throws -> CompanionStore {
        var st = readyState()
        prepare(&st)
        st.pendingHatchID = base
        st.pendingForm = PokemonForm(form)
        let s = try store(st, seed: seed)
        s.setEggUsageForTesting(s.eggHatchThreshold)
        await s.hatchIfNeeded()
        return s
    }

    private func entry(_ base: Int, _ chain: [Int], _ form: String?, released: Bool = false) -> DexEntry {
        DexEntry(baseID: base, finalID: chain.last ?? base, chainOrder: chain, rarity: .common, caughtAt: date,
                 releasedAt: released ? date : nil, form: form.map { PokemonForm($0) })
    }

    // MARK: Regional evolutions (point 2)

    func testRegionalEvolutionsFollowTheIndividualsForm() {
        func kids(_ id: Int, _ form: String) -> [Int] { PokemonEvolutionData.children(of: id, form: PokemonForm(form)) }
        XCTAssertEqual(kids(83, "normal"), [], "a Kanto Farfetch'd is final")
        XCTAssertEqual(kids(83, "galar"), [865])
        XCTAssertEqual(kids(52, "normal"), [53])
        XCTAssertEqual(kids(52, "alola"), [53])
        XCTAssertEqual(kids(52, "galar"), [863], "a Galarian Meowth never becomes Persian")
        XCTAssertEqual(kids(122, "normal"), [])
        XCTAssertEqual(kids(122, "galar"), [866])
        XCTAssertEqual(kids(211, "normal"), [])
        XCTAssertEqual(kids(211, "hisui"), [904])
        XCTAssertEqual(kids(215, "normal"), [461])
        XCTAssertEqual(kids(215, "hisui"), [903])
        XCTAssertEqual(kids(194, "normal"), [195])
        XCTAssertEqual(kids(194, "paldea"), [980])
        XCTAssertEqual(kids(222, "normal"), [])
        XCTAssertEqual(kids(222, "galar"), [864])
        XCTAssertEqual(kids(264, "normal"), [])
        XCTAssertEqual(kids(264, "galar"), [862])
        XCTAssertEqual(kids(550, "red-striped"), [])
        XCTAssertEqual(kids(550, "blue-striped"), [])
        XCTAssertEqual(kids(550, "white-striped-female"), [902])
        XCTAssertEqual(kids(562, "normal"), [563])
        XCTAssertEqual(kids(562, "galar"), [867])
    }

    /// A gate naming a form its parent does not have would lock that evolution for everyone.
    func testEveryFormGateNamesAnEvolutionAndFormsOfItsParent() {
        for (child, gate) in PokemonEvolutionData.formGates {
            XCTAssertTrue(PokemonEvolutionData.children[gate.parent]?.contains(child) == true, "#\(child)")
            let parentForms = Set(PokemonForm.forms(speciesID: gate.parent).map(\.rawValue))
            XCTAssertTrue(gate.forms.isSubset(of: parentForms), "#\(child): \(gate.forms) vs \(parentForms)")
        }
    }

    func testHatchPlansOnlyEvolutionsOpenToTheForm() async throws {
        for seed: UInt64 in 1...8 {
            let kantoMeowth = try await hatch(52, "normal", seed: seed)
            XCTAssertEqual(kantoMeowth.state.active?.plannedPathIDs, [52, 53], "seed \(seed)")
            let galarMeowth = try await hatch(52, "galar", seed: seed)
            XCTAssertEqual(galarMeowth.state.active?.plannedPathIDs, [52, 863], "seed \(seed)")
        }
        let whiteBasculin = try await hatch(550, "white-striped-female")
        XCTAssertEqual(whiteBasculin.state.active?.plannedPathIDs, [550, 902])
        let redBasculin = try await hatch(550, "red-striped")
        XCTAssertEqual(redBasculin.state.active?.plannedPathIDs, [550])
    }

    /// An egg hatched without a pre-roll rolls its form after the plan: the plan made for the default form is
    /// redone for the rolled one.
    func testAFormRolledAtHatchGetsAPlanItCanFollow() async throws {
        var rolled = Set<String>()
        for seed: UInt64 in 1...40 {
            let s = try store(readyState(), seed: seed)
            await s.hatch(baseID: 52)
            let form = try XCTUnwrap(s.state.active?.form?.rawValue)
            rolled.insert(form)
            XCTAssertEqual(s.state.active?.plannedPathIDs, form == "galar" ? [52, 863] : [52, 53], "seed \(seed): \(form)")
        }
        XCTAssertTrue(rolled.contains("galar") && rolled.contains("normal"), "\(rolled)")
    }

    func testAKantoFarfetchdIsFinalAndGraduatesAsFarfetchd() async throws {
        let kanto = try await hatch(83, "normal")
        XCTAssertEqual(kanto.state.active?.plannedPathIDs, [83])
        XCTAssertTrue(kanto.isFinalStage)
        kanto.applyUsage(kanto.threshold)
        XCTAssertNil(kanto.state.active)
        XCTAssertEqual(kanto.state.dex.last?.finalID, 83)
        XCTAssertTrue(kanto.state.collectedFinals.contains("83:83"))

        let galar = try await hatch(83, "galar")
        XCTAssertFalse(galar.isFinalStage)
        galar.applyUsage(galar.threshold)
        XCTAssertEqual(galar.currentSpeciesID, 865)
    }

    /// Saves from before the fix hold plans the form cannot take: they are redone when the line loads.
    func testASavedPlanTheFormCannotTakeIsRedoneOnLoad() async throws {
        for (form, saved, expected) in [("galar", [52, 53], [52, 863]), ("normal", [52, 863], [52, 53])] {
            var st = readyState()
            st.active = MonState(baseID: 52, pathIDs: [52], plannedPathIDs: saved, stageIndex: 0, usedAtStage: 0,
                                 rarity: .common, totalForms: 2, form: PokemonForm(form))
            let s = try store(st)
            s.update(todayTokensByProvider: ["test": 0], todayDate: "2026-10-21", monthTotal: 0,
                     burnTier: .idle, limitWarning: false, hasUsageData: true)
            let deadline = Date().addingTimeInterval(2)
            while s.currentLine == nil, Date() < deadline { try await Task.sleep(nanoseconds: 1_000_000) }
            XCTAssertNotNil(s.currentLine)
            XCTAssertEqual(s.state.active?.plannedPathIDs, expected, form)
        }
    }

    func testTheEvolutionStripShowsOnlyEvolutionsOpenToTheForm() async throws {
        func hasBranch(_ s: CompanionStore) -> Bool {
            s.lineNodes.contains { if case .branch = $0.content { return true } else { return false } }
        }
        let kanto = try await hatch(52, "normal")
        XCTAssertFalse(hasBranch(kanto), "no Perrserker silhouette for a Kanto Meowth")
        XCTAssertEqual(kanto.lineNodes.count, 2)
        let galar = try await hatch(52, "galar")
        XCTAssertFalse(hasBranch(galar))
        XCTAssertEqual(galar.lineNodes.count, 2)
    }

    // MARK: Branching lines (point 3)

    func testBranchingFinalsComeFromTheEvolutionData() {
        // The former hand-written list (Gen 1 to 4 and Sylveon) is unchanged.
        let former: [Int: [Int]] = [
            43: [45, 182], 44: [45, 182], 60: [62, 186], 61: [62, 186], 79: [80, 199],
            133: [134, 135, 136, 196, 197, 470, 471, 700], 236: [106, 107, 237], 265: [267, 269],
            266: [267], 268: [269], 280: [282, 475], 281: [282, 475], 290: [291, 292], 361: [362, 478],
            366: [367, 368], 412: [413, 414],
        ]
        for (id, finals) in former {
            XCTAssertEqual(CompanionStore.branchingFinals(for: id), finals, "#\(id)")
        }
        // The eight lines it missed.
        XCTAssertEqual(CompanionStore.branchingFinals(for: 840), [841, 842, 1019])
        XCTAssertEqual(CompanionStore.branchingFinals(for: 1011), [1019])
        XCTAssertEqual(CompanionStore.branchingFinals(for: 123), [212, 900])
        XCTAssertEqual(CompanionStore.branchingFinals(for: 935), [936, 937])
        XCTAssertEqual(CompanionStore.branchingFinals(for: 789), [791, 792])
        XCTAssertEqual(CompanionStore.branchingFinals(for: 52), [53, 863])
        XCTAssertEqual(CompanionStore.branchingFinals(for: 194), [195, 980])
        XCTAssertEqual(CompanionStore.branchingFinals(for: 215), [461, 903])
        XCTAssertEqual(CompanionStore.branchingFinals(for: 562), [563, 867])
        // For one individual, only the finals its form reaches.
        XCTAssertEqual(CompanionStore.branchingFinals(for: 52, form: PokemonForm("normal")), [53])
        XCTAssertEqual(CompanionStore.branchingFinals(for: 52, form: PokemonForm("galar")), [863])
        XCTAssertNil(CompanionStore.branchingFinals(for: 83, form: PokemonForm("normal")))
        // Finals and single-final lines.
        XCTAssertNil(CompanionStore.branchingFinals(for: 134))
        XCTAssertNil(CompanionStore.branchingFinals(for: 25))
        XCTAssertNil(CompanionStore.branchingFinals(for: 1))
    }

    /// A released Applin is not a duplicate while Appletun and Hydrapple are still missing.
    func testAReleasedApplinIsNotADuplicateWhileOtherFinalsAreMissing() throws {
        var st = readyState()
        let flapple = entry(840, [840, 841], nil)
        let released = entry(840, [840], nil, released: true)
        st.dex = [flapple, released]
        st.collectedFinals = ["840:841"]
        let s = try store(st)
        XCTAssertFalse(s.duplicateCatchEntryIDs.contains(released.id))

        var complete = st
        let appletun = entry(840, [840, 842], nil)
        let hydrapple = entry(840, [840, 1011, 1019], nil)
        let laterRelease = DexEntry(baseID: 840, finalID: 840, chainOrder: [840], rarity: .common,
                                    caughtAt: date.addingTimeInterval(60), releasedAt: date, form: nil)
        complete.dex = [flapple, appletun, hydrapple, laterRelease]
        let full = try store(complete)
        XCTAssertTrue(full.duplicateCatchEntryIDs.contains(laterRelease.id))
    }

    /// While a Galarian Meowth is raised, a released Kanto Meowth is a duplicate once Persian is collected:
    /// Perrserker, missing, is not open to it.
    func testAReleasedKantoMeowthIgnoresPerrserkerWhileAGalarianOneIsRaised() async throws {
        let persian = entry(52, [52, 53], "normal")
        let released = DexEntry(baseID: 52, finalID: 52, chainOrder: [52], rarity: .common,
                                caughtAt: date.addingTimeInterval(60), releasedAt: date, form: PokemonForm("normal"))
        let s = try await hatch(52, "galar") { st in
            st.dex = [persian, released]
            st.collectedFinals = ["52:53"]
        }
        XCTAssertNotNil(s.currentLine)
        XCTAssertTrue(s.duplicateCatchEntryIDs.contains(released.id))
    }

    // MARK: Forms named differently along a line (point 4)

    func testOneLineFormSetsEachSpeciesOwnForm() {
        XCTAssertEqual(PokemonForm.lineForms(baseID: 550).map(\.rawValue),
                       ["red-striped", "blue-striped", "white-striped-male", "white-striped-female"])
        XCTAssertEqual(PokemonForm.lineForms(baseID: 1012).map(\.rawValue), ["counterfeit", "artisan"])
        func shown(_ id: Int, _ form: String) -> String? { PokemonForm.resolved(speciesID: id, form: PokemonForm(form))?.rawValue }
        XCTAssertEqual(shown(550, "white-striped-female"), "white-striped")
        XCTAssertEqual(shown(902, "white-striped-female"), "female")
        XCTAssertEqual(shown(902, "white-striped-male"), "male")
        XCTAssertEqual(shown(1012, "artisan"), "artisan")
        XCTAssertEqual(shown(1013, "artisan"), "masterpiece")
        XCTAssertEqual(shown(1013, "counterfeit"), "unremarkable")
        XCTAssertEqual(shown(554, "galar-zen"), "galar")
        XCTAssertEqual(shown(555, "galar-zen"), "galar-zen")
        XCTAssertEqual(shown(554, "zen"), "standard")
        XCTAssertEqual(shown(555, "zen"), "zen")
    }

    /// Every form of every species can be shown by some form of its line.
    func testEveryCataloguedFormIsReachableFromItsLine() {
        for speciesID in PokemonForm.catalog.keys {
            let lineForms = PokemonForm.lineForms(baseID: PokemonForm.lineBase(of: speciesID))
            let shown = Set(lineForms.compactMap { PokemonForm.ownForm(speciesID: speciesID, lineForm: $0) })
            XCTAssertEqual(shown, Set(PokemonForm.forms(speciesID: speciesID)), "#\(speciesID)")
        }
    }

    /// Saves stored one species' form for these lines: each moves to the line form that shows it.
    func testSavedSpeciesFormsMoveToTheirLineForm() throws {
        func stored(_ base: Int, _ form: String) -> String? { PokemonForm.resolved(baseID: base, form: PokemonForm(form))?.rawValue }
        XCTAssertEqual(stored(550, "white-striped"), "white-striped-male")
        XCTAssertEqual(stored(550, "male"), "white-striped-male")
        XCTAssertEqual(stored(550, "female"), "white-striped-female")
        XCTAssertEqual(stored(550, "blue-striped"), "blue-striped")
        XCTAssertEqual(stored(554, "galar"), "galar-standard")
        XCTAssertEqual(stored(1012, "unremarkable"), "counterfeit")
        XCTAssertEqual(stored(1012, "masterpiece"), "artisan")
        XCTAssertEqual(stored(550, "future-form"), "red-striped")

        let json = String(decoding: try JSONEncoder().encode(entry(554, [554], "galar-standard")), as: UTF8.self)
        let legacy = json.replacingOccurrences(of: "\"galar-standard\"", with: "\"galar\"")
        XCTAssertNotEqual(legacy, json)
        let decoded = try JSONDecoder().decode(DexEntry.self, from: Data(legacy.utf8))
        XCTAssertEqual(decoded.form?.rawValue, "galar-standard", "a saved Galarian Darumaka stays Galarian")
    }

    // MARK: Egg roll halving (point 1)

    func testALineIsHalvedOnlyOnceEveryFinalAndFormIsCollected() throws {
        var st = readyState()
        st.collectedFinals = ["133:134"]
        XCTAssertFalse(st.isLineComplete(baseID: 133), "Eevee after Vaporeon still has seven evolutions to find")
        st.collectedFinals = Set([134, 135, 136, 196, 197, 470, 471, 700].map { "133:\($0)" })
        XCTAssertTrue(st.isLineComplete(baseID: 133))

        st.collectedFinals = ["123:212"]
        XCTAssertFalse(st.isLineComplete(baseID: 123), "Kleavor came with Gen 8")

        st.collectedFinals = ["19:20"]
        st.dex = [entry(19, [19, 20], "normal")]
        XCTAssertFalse(st.isLineComplete(baseID: 19), "Alolan Raticate is still missing")
        st.dex.append(entry(19, [19, 20], "alola"))
        XCTAssertTrue(st.isLineComplete(baseID: 19))

        st.collectedFinals = ["83:83"]
        st.dex = [entry(83, [83], "normal")]
        XCTAssertFalse(st.isLineComplete(baseID: 83), "Sirfetch'd is still missing")
        st.collectedFinals.insert("83:865")
        st.dex.append(entry(83, [83, 865], "galar"))
        XCTAssertTrue(st.isLineComplete(baseID: 83))

        let eevee = BaseSpecies(id: 133, captureRate: 45)
        var oneFinal = readyState()
        oneFinal.collectedFinals = ["133:134"]
        XCTAssertEqual(try store(oneFinal).hatchWeight(for: eevee), PokemonOdds.hatchWeight(.rare))
        var allFinals = readyState()
        allFinals.collectedFinals = Set([134, 135, 136, 196, 197, 470, 471, 700].map { "133:\($0)" })
        XCTAssertEqual(try store(allFinals).hatchWeight(for: eevee), PokemonOdds.hatchWeight(.rare) / 2)
    }
}
