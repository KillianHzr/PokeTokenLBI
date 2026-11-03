import XCTest
@testable import PokeTokenBar

/// The egg roll's rules by the second their change was published (`HatchRules`), each checked on both sides of it.
final class HatchRulesTests: XCTestCase {
    private typealias Change = HatchRules.Change

    private func before(_ change: Change) -> HatchRules {
        HatchRules(rolledAt: change.publishedAt.addingTimeInterval(-1))
    }

    private func at(_ change: Change) -> HatchRules { HatchRules(rolledAt: change.publishedAt) }

    private func draw(_ rules: HatchRules, _ collection: CompanionState = CompanionState(), items: Set<ItemKind> = []) -> HatchDraw {
        HatchDraw(collection: collection, items: items, rules: rules)
    }

    private func graduated(_ base: Int, _ final: Int, chain: [Int], form: String? = nil) -> CompanionState {
        var c = CompanionState()
        c.dex = [DexEntry(baseID: base, finalID: final, chainOrder: chain, rarity: .common, caughtAt: nil, form: form.map { PokemonForm($0) })]
        c.collectedFinals = ["\(base):\(final)"]
        return c
    }

    private let pidgey = BaseSpecies(id: 16, captureRate: 255)
    private let phione = BaseSpecies(id: 489, captureRate: 30, isLegendary: true)
    private let mew = BaseSpecies(id: 151, captureRate: 45, isUnbreedableLegendary: true)
    private let beldum = BaseSpecies(id: 374, captureRate: 3)
    private let necrozma = BaseSpecies(id: 800, captureRate: 255, isLegendary: true)

    func testChangesAreListedInOrderOfPublication() {
        let dates = Change.allCases.map(\.publishedAt)
        XCTAssertEqual(dates, dates.sorted())
    }

    func testAChangeCountsFromItsSecond() {
        for (i, change) in Change.allCases.enumerated() {
            XCTAssertEqual(before(change).changes, Set(Change.allCases.prefix(i)), change.rawValue)
            XCTAssertEqual(at(change).changes, Set(Change.allCases.prefix(i + 1)), change.rawValue)
        }
        XCTAssertEqual(HatchRules(rolledAt: nil), .current, "a roll of unknown date")
    }

    func testALinesWeightByUpdate() {
        func weights(_ rules: HatchRules) -> [Int] { [mew, phione, pidgey].map(rules.weight) }
        XCTAssertEqual(weights(before(.collectorItems)), [45, 30, 255])
        XCTAssertEqual(weights(at(.collectorItems)), [3, 30, 255])
        XCTAssertEqual(weights(before(.rarityWeights)), [3, 30, 255])
        XCTAssertEqual(weights(at(.rarityWeights)), [3, 3, 212])
    }

    /// A line weighed half from its first final, then once complete, forms registered, then forms graduated.
    func testHalfWeightInThreeEras() {
        let eevee = BaseSpecies(id: 133, captureRate: 255)
        let vaporeon = graduated(133, 134, chain: [133, 134])
        XCTAssertEqual(draw(before(.completeLines), vaporeon).hatchWeight(for: eevee), 127, "one final was enough")
        XCTAssertEqual(draw(at(.completeLines), vaporeon).hatchWeight(for: eevee), 255, "seven finals are missing")

        var released = CompanionState()
        released.dex = [DexEntry(baseID: 19, finalID: 20, chainOrder: [19, 20], rarity: .common, caughtAt: nil, releasedAt: Date(),
                                 form: PokemonForm("alola")),
                        DexEntry(baseID: 19, finalID: 20, chainOrder: [19, 20], rarity: .common, caughtAt: nil, form: PokemonForm("normal"))]
        released.collectedFinals = ["19:20"]
        let rattata = BaseSpecies(id: 19, captureRate: 255)
        XCTAssertEqual(draw(before(.graduatedForms), released).hatchWeight(for: rattata), 106, "a released Alolan form was registered")
        XCTAssertEqual(draw(at(.graduatedForms), released).hatchWeight(for: rattata), 212, "it does not count as graduated")
    }

    /// Until #64 a rarity's egg admitted by capture rate, so no Necrozma (255), then by rarity.
    func testShopEggsAdmission() {
        let index = [pidgey, BaseSpecies(id: 102, captureRate: 90), BaseSpecies(id: 1, captureRate: 45), necrozma, phione]
        func pool(_ rules: HatchRules, _ tier: Rarity) -> [Int] { draw(rules).hatchPool(index, egg: .init(tier: tier)).map(\.base.id) }
        XCTAssertEqual(pool(before(.rarityWeights), .uncommon), [102, 1, 489])
        XCTAssertEqual(pool(at(.rarityWeights), .uncommon), [102, 1, 800, 489])
        XCTAssertEqual(pool(before(.rarityWeights), .rare), [1, 489])
        XCTAssertEqual(pool(at(.rarityWeights), .rare), [1, 800, 489])
    }

    /// ×4 on any weight of 3, then on legendaries, ×2 from #40, then on every legendary.
    func testAzureFluteByUpdate() {
        func weights(_ rules: HatchRules) -> [Int] {
            let d = draw(rules, items: [.legendCharm])
            return [mew, phione, beldum].map { d.hatchWeight(for: $0) }
        }
        XCTAssertEqual(weights(at(.collectorItems)), [12, 30, 12])
        XCTAssertEqual(weights(before(.completeLines)), [12, 30, 12])
        XCTAssertEqual(weights(at(.completeLines)), [12, 30, 3])
        XCTAssertEqual(weights(before(.fluteTimesTwo)), [12, 30, 3])
        XCTAssertEqual(weights(at(.fluteTimesTwo)), [6, 30, 3])
        XCTAssertEqual(weights(before(.rarityWeights)), [6, 30, 3])
        XCTAssertEqual(weights(at(.rarityWeights)), [6, 6, 40])
    }

    /// The Clear Bell, Griseous Orb and badges only weighed from #4 to #21.
    func testFormerItemsWeighedForAWhile() {
        let items: Set<ItemKind> = [.clearBell]
        let bulbasaur = BaseSpecies(id: 1, captureRate: 45), gastly = BaseSpecies(id: 92, captureRate: 190), geodude = BaseSpecies(id: 74, captureRate: 255)
        XCTAssertEqual(draw(before(.onlyFluteWeighs), items: items).hatchWeight(for: bulbasaur), 90)
        XCTAssertEqual(draw(before(.onlyFluteWeighs), items: items).hatchWeight(for: mew), 3, "not a legendary's weight")
        XCTAssertEqual(draw(before(.onlyFluteWeighs), items: items).hatchWeight(for: gastly), 190)
        XCTAssertEqual(draw(at(.onlyFluteWeighs), items: items).hatchWeight(for: bulbasaur), 45)

        XCTAssertEqual(draw(before(.onlyFluteWeighs), items: [.griseousOrb]).hatchWeight(for: gastly), 380)
        XCTAssertEqual(draw(before(.onlyFluteWeighs), items: [.griseousOrb]).hatchWeight(for: geodude), 255)
        XCTAssertEqual(draw(at(.onlyFluteWeighs), items: [.griseousOrb]).hatchWeight(for: gastly), 190)

        let badge = PokemonType.water.badgeItem
        XCTAssertEqual(draw(before(.onlyFluteWeighs), items: [badge]).hatchWeight(for: geodude), 306, "weak to water, +20%")
        XCTAssertEqual(draw(before(.onlyFluteWeighs), items: [badge]).hatchWeight(for: gastly), 190)
        XCTAssertEqual(draw(at(.onlyFluteWeighs), items: [badge]).hatchWeight(for: geodude), 255)
    }

    /// An item that weighed on a draw counts from the update that brought it; the Shiny Charm, from before the fork.
    func testAnItemsArrival() {
        XCTAssertNil(Change.arrival(of: .shinyCharm))
        for item in [ItemKind.legendCharm, .revealGlass, .clearBell, .griseousOrb, PokemonType.fire.badgeItem] {
            XCTAssertEqual(Change.arrival(of: item), .collectorItems, "\(item)")
        }
        XCTAssertEqual(Change.arrival(of: .ovalCharm), .charms)
        XCTAssertEqual(Change.arrival(of: .glimmeringCharm), .charms)
    }

    func testAnEggCountsFromItsPublication() {
        let eggs: [(Change?, HatchEgg)] = [(nil, .tier(nil)), (nil, .tier(.rare)), (.collectorItems, .stone(.fire)), (.silvallyMemories, .typeNull),
                                           (.rarityWeights, .legendary), (.birthdayEgg, .birthday), (.eventAndFossilEggs, .fossil),
                                           (.eventAndFossilEggs, .event(.halloween, key: nil))]
        for (change, egg) in eggs {
            guard let change else {
                XCTAssertTrue(HatchRules(changes: []).allows(egg))
                continue
            }
            XCTAssertFalse(before(change).allows(egg), "\(egg)")
            XCTAssertTrue(at(change).allows(egg), "\(egg)")
        }
    }

    /// Generations 6 to 9 from #16, or from #26 for a player whose cached index stopped at generation 5.
    func testLaterGenerationsAndTheCachedIndex() {
        let index = [pidgey, BaseSpecies(id: 661, captureRate: 255)]
        func pool(_ rules: HatchRules) -> [Int] { draw(rules).hatchPool(index, egg: .init()).map(\.base.id) }
        let new = Change.laterGenerations.publishedAt, reloaded = Change.indexReloaded.publishedAt
        XCTAssertEqual(pool(before(.laterGenerations)), [16])
        XCTAssertEqual(pool(HatchRules(rolledAt: new, firstHatch: new)), [16, 661], "installed from then")
        XCTAssertEqual(pool(HatchRules(rolledAt: new, firstHatch: new.addingTimeInterval(-1))), [16], "installed before")
        XCTAssertEqual(pool(HatchRules(rolledAt: reloaded.addingTimeInterval(-1), firstHatch: new.addingTimeInterval(-1))), [16])
        XCTAssertEqual(pool(HatchRules(rolledAt: reloaded, firstHatch: new.addingTimeInterval(-1))), [16, 661])
        let rattataForms = HatchRules(rolledAt: new, firstHatch: new.addingTimeInterval(-1)).lineForms(baseID: 19)
        XCTAssertFalse(rattataForms.isEmpty, "the forms came with the code, not the index")
    }

    /// A stone's egg went by its species' types, then by those of the forms it can roll: Alolan Vulpix is Ice.
    func testAStonesEggByFormType() {
        let vulpix = BaseSpecies(id: 37, captureRate: 190)
        func pool(_ rules: HatchRules) -> [Int] { draw(rules).hatchPool([vulpix], egg: .init(type: .ice)).map(\.base.id) }
        XCTAssertEqual(pool(before(.stoneEggsByFormType)), [])
        XCTAssertEqual(pool(at(.stoneEggsByFormType)), [37])
        let alola = PokemonForm("alola")
        XCTAssertEqual(draw(before(.stoneEggsByFormType)).lineFormDraw(baseID: 37, types: [.ice]).forms.count, 2, "any form")
        XCTAssertEqual(draw(at(.stoneEggsByFormType)).lineFormDraw(baseID: 37, types: [.ice]).forms, [alola])
    }

    /// From #71 a stone's egg lowers a line complete in its type to a quarter, and no egg brings the line hatched last.
    func testStoneEggDuplicatesAndTheLineHatchedLast() {
        let collection = graduated(16, 18, chain: [16, 17, 18])
        let w = BaseSpecies(id: 16, captureRate: 255)
        XCTAssertEqual(draw(before(.stoneEggDuplicates), collection).hatchWeight(for: w, type: .flying), 106)
        XCTAssertEqual(draw(at(.stoneEggDuplicates), collection).hatchWeight(for: w, type: .flying), 53)

        var last = CompanionState()
        last.lastHatchedBaseID = 16
        let index = [pidgey, BaseSpecies(id: 19, captureRate: 255)]
        XCTAssertEqual(draw(before(.stoneEggDuplicates), last).hatchPool(index, egg: .init()).map(\.base.id), [16, 19])
        XCTAssertEqual(draw(at(.stoneEggDuplicates), last).hatchPool(index, egg: .init()).map(\.base.id), [19])

        last.lastHatchedBaseID = 151
        let legends = [mew, BaseSpecies(id: 251, captureRate: 45, isUnbreedableLegendary: true)]
        XCTAssertEqual(draw(before(.stoneEggDuplicates), last).birthdayDraw(legends).lines.map(\.base.id), [151, 251])
        XCTAssertEqual(draw(at(.stoneEggDuplicates), last).birthdayDraw(legends).lines.map(\.base.id), [251])
    }

    /// Fossil lines only from a Fossil Egg from #73, those graduated back in every egg from #75, a first catch in the
    /// Friendship Egg from #89.
    func testFossilLinesInOtherEggs() {
        let aerodactyl = BaseSpecies(id: 142, captureRate: 45)
        let c = graduated(142, 142, chain: [142])
        XCTAssertEqual(draw(before(.eventAndFossilEggs)).hatchPool([aerodactyl], egg: .init()).count, 1)
        XCTAssertEqual(draw(at(.eventAndFossilEggs), c).hatchPool([aerodactyl], egg: .init()).count, 0)
        XCTAssertEqual(draw(before(.graduatedFossilsEverywhere), c).hatchPool([aerodactyl], egg: .init()).count, 0)
        XCTAssertEqual(draw(at(.graduatedFossilsEverywhere), c).hatchPool([aerodactyl], egg: .init()).count, 1)

        var released = c
        released.dex[0].releasedAt = Date()
        released.dex[0].caughtAt = Date()
        released.collectedFinals = []
        let friendship = CompanionStore.EggSpec(event: .companion)
        XCTAssertEqual(draw(before(.graduatedForms), released).hatchPool([aerodactyl], egg: friendship).count, 0)
        XCTAssertEqual(draw(at(.graduatedForms), released).hatchPool([aerodactyl], egg: friendship).count, 1)
    }

    /// An event egg without its Pokémon in the pool was kept until #93, then hatches as a plain egg.
    func testAnEmptyEventPool() {
        let valentine = CompanionStore.EggSpec(event: .valentine)
        XCTAssertEqual(draw(before(.plainEggWithoutEventPool)).hatchPool([pidgey], egg: valentine).count, 0)
        XCTAssertEqual(draw(at(.plainEggWithoutEventPool)).hatchPool([pidgey], egg: valentine).map(\.base.id), [16])
    }

    /// Season's eggs Uncommon or better, and Pokémon Day's babies, from #97.
    func testSeasonEggsAndPokemonDayBabies() {
        let sewaddle = BaseSpecies(id: 540, captureRate: 255)
        let spring = CompanionStore.EggSpec(tier: EventEgg.spring.tier, type: EventEgg.spring.type, event: .spring)
        XCTAssertEqual(draw(before(.seasonEggsAndBabies)).hatchPool([sewaddle], egg: spring).count, 1)
        XCTAssertEqual(draw(at(.seasonEggsAndBabies)).hatchPool([sewaddle], egg: spring).count, 0)
        XCTAssertNil(before(.seasonEggsAndBabies).tier(of: spring))
        XCTAssertEqual(at(.seasonEggsAndBabies).tier(of: spring), .uncommon)
        XCTAssertEqual(before(.seasonEggsAndBabies).tier(of: .init(tier: .rare)), .rare, "a Shop's keeps it")

        let pichu = BaseSpecies(id: 172, captureRate: 190)
        XCTAssertFalse(before(.seasonEggsAndBabies).admits(pichu, event: .pokemonDay, companionLine: nil))
        XCTAssertTrue(at(.seasonEggsAndBabies).admits(pichu, event: .pokemonDay, companionLine: nil))
    }

    /// No Ditto in an egg that keeps a promise, from #67.
    func testADittoKeepsTheEggsPromiseFromItsUpdate() {
        let stone = CompanionStore.EggSpec(type: .fire), oval: Set<ItemKind> = [.ovalCharm]
        XCTAssertTrue(draw(before(.dittoKeepsPromises)).letsDittoHide(baseID: 16, egg: stone, fromFossilEgg: false))
        XCTAssertFalse(draw(at(.dittoKeepsPromises)).letsDittoHide(baseID: 16, egg: stone, fromFossilEgg: false))
        XCTAssertTrue(draw(before(.dittoKeepsPromises), items: oval).letsDittoHide(baseID: 19, egg: .init(), fromFossilEgg: false))
        XCTAssertFalse(draw(at(.dittoKeepsPromises), items: oval).letsDittoHide(baseID: 19, egg: .init(), fromFossilEgg: false))
        XCTAssertTrue(draw(at(.dittoKeepsPromises), items: oval).letsDittoHide(baseID: 16, egg: .init(), fromFossilEgg: false), "no form")
        XCTAssertFalse(draw(.current).letsDittoHide(baseID: 16, egg: .init(event: .halloween), fromFossilEgg: false))
        XCTAssertFalse(draw(.current).letsDittoHide(baseID: 142, egg: .init(), fromFossilEgg: true))
    }

    /// A season's Deerling could come twice in a row, or in a form the Oval Charm no longer wants, until #89.
    func testASeasonsDeerlingByUpdate() {
        var c = CompanionState()
        c.lastHatchedBaseID = EventEgg.deerlingID
        let index = [BaseSpecies(id: EventEgg.deerlingID, captureRate: 190)]
        XCTAssertNotNil(draw(before(.graduatedForms), c).seasonDeerling(index, event: .spring))
        XCTAssertNil(draw(at(.graduatedForms), c).seasonDeerling(index, event: .spring))
        XCTAssertNil(draw(before(.graduatedForms), c).seasonDeerling([], event: .spring))
        XCTAssertNil(draw(before(.graduatedForms), c).seasonDeerling(index, event: .halloween))
    }

    /// The catalogue of each merge, line by line.
    func testTheFormsOfALineByUpdate() {
        func names(_ rules: HatchRules, _ base: Int) -> [String] { rules.lineForms(baseID: base).map(\.rawValue) }
        XCTAssertEqual(before(.unownLetters).lineForms(baseID: 201), [])
        XCTAssertEqual(at(.unownLetters).lineForms(baseID: 201).count, 28)
        XCTAssertEqual(before(.firstForms).lineForms(baseID: 412), [])
        XCTAssertEqual(names(at(.firstForms), 412), ["plant", "sandy", "trash"])
        XCTAssertEqual(before(.laterGenerations).lineForms(baseID: 19), [])
        XCTAssertEqual(names(at(.laterGenerations), 19), ["normal", "alola"])
        XCTAssertEqual(before(.evolvedSpeciesForms).lineForms(baseID: 172), [], "Raichu's forms did not reach Pichu's line")
        XCTAssertEqual(names(at(.evolvedSpeciesForms), 172), ["normal", "alola"])
        XCTAssertEqual(before(.birthdayEgg).lineForms(baseID: 216), [])
        XCTAssertFalse(at(.birthdayEgg).lineForms(baseID: 216).isEmpty)

        XCTAssertEqual(names(at(.firstForms), 550), ["red-striped", "blue-striped"])
        XCTAssertEqual(names(at(.laterGenerations), 550), ["red-striped", "blue-striped", "white-striped"])
        XCTAssertEqual(names(at(.evolvedSpeciesForms), 550), ["red-striped", "blue-striped", "white-striped", "male", "female"])
        XCTAssertEqual(names(at(.completeLines), 550), ["red-striped", "blue-striped", "white-striped-male", "white-striped-female"])
        XCTAssertEqual(names(at(.firstForms), 554), ["standard", "zen"])
        XCTAssertEqual(names(at(.laterGenerations), 554), ["standard", "galar", "zen", "galar-standard", "galar-zen"])
        XCTAssertEqual(names(at(.completeLines), 554), ["standard", "zen", "galar-standard", "galar-zen"])
        XCTAssertEqual(names(at(.laterGenerations), 1012), ["counterfeit", "artisan"])
        XCTAssertEqual(names(at(.evolvedSpeciesForms), 1012), ["counterfeit", "artisan", "unremarkable", "masterpiece"])
        XCTAssertEqual(names(at(.completeLines), 1012), ["counterfeit", "artisan"])
    }

    /// Arceus from #33 and Type: Null from #34 hatch in their default form; their forms come from items.
    func testFormsFromItemsStopRolling() {
        XCTAssertEqual(before(.arceusPlates).rollableForms(baseID: 493).count, 18)
        XCTAssertEqual(at(.arceusPlates).rollableForms(baseID: 493).map(\.rawValue), ["normal"])
        XCTAssertEqual(before(.silvallyMemories).rollableForms(baseID: 772).count, 18)
        XCTAssertEqual(at(.silvallyMemories).rollableForms(baseID: 772).map(\.rawValue), ["normal"])
    }

    /// Today's rules roll the catalogue as it is: a new line with forms must say when it came.
    func testEveryLineWithFormsHasItsArrival() {
        for baseID in Set(PokemonForm.catalog.keys.map(PokemonForm.lineBase(of:))) {
            XCTAssertEqual(HatchRules.current.rollableForms(baseID: baseID), PokemonForm.rollableLineForms(baseID: baseID), "\(baseID)")
            XCTAssertEqual(HatchRules(changes: []).lineForms(baseID: baseID), [], "\(baseID) has no arrival")
        }
    }

    /// The roll, the half weight, the Oval Charm and a stone's egg read the forms of their time, not today's.
    func testTheDrawReadsTheFormsOfItsTime() {
        XCTAssertEqual(draw(before(.laterGenerations)).lineFormDraw(baseID: 19, types: []).forms, [])
        XCTAssertEqual(draw(at(.laterGenerations)).lineFormDraw(baseID: 19, types: []).forms.count, 2)

        let teddiursa = BaseSpecies(id: 216, captureRate: 120)
        let ursaluna = graduated(216, 901, chain: [216, 217, 901])
        XCTAssertEqual(draw(before(.birthdayEgg), ursaluna).hatchWeight(for: teddiursa), 45, "complete: no form yet")
        XCTAssertEqual(draw(at(.birthdayEgg), ursaluna).hatchWeight(for: teddiursa), 90, "its Bloodmoon form is missing")

        let index = [pidgey, teddiursa]
        func ovalPool(_ rules: HatchRules) -> [Int] { draw(rules, items: [.ovalCharm]).hatchPool(index, egg: .init()).map(\.base.id) }
        XCTAssertEqual(ovalPool(before(.birthdayEgg)), [16, 216], "no line misses a form")
        XCTAssertEqual(ovalPool(at(.birthdayEgg)), [216])

        let arceus = BaseSpecies(id: 493, captureRate: 3, isUnbreedableLegendary: true)
        func firePool(_ rules: HatchRules) -> [Int] { draw(rules).hatchPool([arceus], egg: .init(type: .fire)).map(\.base.id) }
        XCTAssertEqual(firePool(before(.arceusPlates)), [493], "it rolled its Fire form")
        XCTAssertEqual(firePool(at(.arceusPlates)), [], "Normal only")
    }

    /// Before #39 the Oval Charm looked at every form: a Fire Stone's egg still chased Vulpix's Alolan form.
    func testOvalCharmEggForms() {
        let vulpix = BaseSpecies(id: 37, captureRate: 190), growlithe = BaseSpecies(id: 58, captureRate: 190), charmander = BaseSpecies(id: 4, captureRate: 45)
        var c = graduated(37, 38, chain: [37, 38], form: "normal")
        c.dex.append(DexEntry(baseID: 58, finalID: 59, chainOrder: [58, 59], rarity: .common, caughtAt: nil, form: PokemonForm("normal")))
        c.dex.append(DexEntry(baseID: 58, finalID: 59, chainOrder: [58, 59], rarity: .common, caughtAt: nil, form: PokemonForm("hisui")))
        let index = [vulpix, growlithe, charmander]
        func pool(_ rules: HatchRules) -> [Int] {
            draw(rules, c, items: [.ovalCharm]).hatchPool(index, egg: .init(type: .fire)).map(\.base.id)
        }
        XCTAssertEqual(pool(before(.ovalCharmEggForms)), [37], "its Alolan form, Ice, was missing")
        XCTAssertEqual(pool(at(.ovalCharmEggForms)), [37, 58, 4], "no form this egg can roll is missing")
    }

    /// The replay rolls an egg with the rules of the second the Pokémon before it left, the first from its hatch, and
    /// hatches it with those of its hatch. A first hatch before generation 6 means an index cached without it.
    func testTheReplayReadsTheRulesOfEachRoll() {
        let edge = Change.laterGenerations.publishedAt
        func entry(_ base: Int, left: Date, hatchedAt: Date) -> DexEntry {
            var e = DexEntry(baseID: base, finalID: base, chainOrder: [base], rarity: .common, caughtAt: left)
            e.raising = RaisingRecord(hatchedAt: hatchedAt)
            return e
        }
        func moments(_ entries: [DexEntry]) -> [HatchLuck.Moment] {
            HatchLuck.moments(entries: entries, today: CompanionState(), itemsSince: [:])
        }
        let installedBefore = moments([entry(16, left: edge.addingTimeInterval(-1), hatchedAt: edge.addingTimeInterval(-9)),
                                       entry(19, left: edge.addingTimeInterval(5), hatchedAt: edge),
                                       entry(16, left: edge.addingTimeInterval(9), hatchedAt: edge.addingTimeInterval(6))])
        XCTAssertFalse(installedBefore[1].roll.rules.has(.laterGenerations), "rolled a second before")
        XCTAssertTrue(installedBefore[1].hatch.rules.has(.laterGenerations), "hatched at the second")
        XCTAssertTrue(installedBefore[2].roll.rules.has(.laterGenerations))
        XCTAssertFalse(installedBefore[2].roll.rules.poolHasLaterGenerations, "its cached index stops at generation 5")
        XCTAssertFalse(installedBefore[2].hatch.rules.poolHasLaterGenerations)

        let firstLeftAfter = moments([entry(16, left: edge.addingTimeInterval(5), hatchedAt: edge.addingTimeInterval(-9)),
                                      entry(19, left: edge.addingTimeInterval(9), hatchedAt: edge.addingTimeInterval(6))])
        XCTAssertFalse(firstLeftAfter[0].roll.rules.has(.laterGenerations), "the first egg, from its hatch")
        XCTAssertFalse(firstLeftAfter[1].roll.rules.poolHasLaterGenerations, "installed before, though it left after")

        let installedThen = moments([entry(16, left: edge.addingTimeInterval(5), hatchedAt: edge),
                                     entry(19, left: edge.addingTimeInterval(9), hatchedAt: edge.addingTimeInterval(6))])
        XCTAssertTrue(installedThen[1].roll.rules.poolHasLaterGenerations)
    }

    /// The line hatched last is the one the egg rolled: a Ditto hid in it.
    func testTheLineHatchedLastAfterADitto() {
        var ditto = DexEntry(baseID: 132, finalID: 132, chainOrder: [132], rarity: .rare, caughtAt: Date())
        ditto.hatch = HatchRecord(egg: .tier(nil), rolledBaseID: 19)
        let next = DexEntry(baseID: 16, finalID: 16, chainOrder: [16], rarity: .common, caughtAt: Date())
        let moments = HatchLuck.moments(entries: [ditto, next, next], today: CompanionState(), itemsSince: [:])
        XCTAssertEqual(moments[1].roll.collection.lastHatchedBaseID, 19)
        XCTAssertEqual(moments[2].roll.collection.lastHatchedBaseID, 16)
    }

    /// A saved record keeps the line its egg rolled.
    func testARecordKeepsItsRolledLine() throws {
        let record = HatchRecord(egg: .tier(nil), rolledBaseID: 19)
        XCTAssertEqual(try JSONDecoder().decode(HatchRecord.self, from: JSONEncoder().encode(record)).rolledBaseID, 19)
        XCTAssertNil(try JSONDecoder().decode(HatchRecord.self, from: JSONEncoder().encode(HatchRecord(egg: .tier(nil)))).rolledBaseID)
    }

    /// Pichu only came to the Pokémon Day egg with #97: the menu of an earlier hatch does not offer it.
    func testTheEggMenuReadsTheRulesOfTheEvent() throws {
        func possibleEggs(rolled date: Date) -> [HatchEgg] {
            let index = [BaseSpecies(id: 16, captureRate: 255), BaseSpecies(id: 172, captureRate: 190)]
            let entries = [DexEntry(baseID: 16, finalID: 16, chainOrder: [16], rarity: .common, caughtAt: date, releasedAt: date),
                           DexEntry(baseID: 172, finalID: 172, chainOrder: [172], rarity: .common, caughtAt: date.addingTimeInterval(60))]
            let moment = HatchLuck.moments(entries: entries, today: CompanionState(), itemsSince: [:])[1]
            return HatchLuck.possibleEggs(of: moment, index: index).map(\.egg)
        }
        let edge = Change.seasonEggsAndBabies.publishedAt
        let pokemonDay = HatchEgg.event(.pokemonDay, key: nil)
        XCTAssertFalse(possibleEggs(rolled: edge.addingTimeInterval(-1)).contains(pokemonDay))
        XCTAssertTrue(possibleEggs(rolled: edge).contains(pokemonDay))
    }

    /// The egg menu of a hatch only offers the eggs there were when it was rolled: no Fossil Egg before the dig.
    func testAnEggThatDidNotExistYetIsNotOffered() throws {
        func at(_ day: String) -> Date { ISO8601DateFormatter().date(from: day + "T12:00:00Z")! }
        let index = [BaseSpecies(id: 16, captureRate: 255), BaseSpecies(id: 140, captureRate: 45)]
        let entries = [DexEntry(baseID: 16, finalID: 16, chainOrder: [16], rarity: .common, caughtAt: at("2026-10-21"),
                                releasedAt: at("2026-10-21")),
                       DexEntry(baseID: 140, finalID: 140, chainOrder: [140], rarity: .rare, caughtAt: at("2026-10-22"))]
        let kabuto = try XCTUnwrap(HatchLuck(entries: entries, includesActive: false, today: CompanionState(), index: index,
                                             now: at("2026-10-23")).hatches.last)
        XCTAssertTrue(kabuto.asksEgg)
        XCTAssertTrue(kabuto.possibleEggs.contains(.tier(nil)))
        XCTAssertFalse(kabuto.possibleEggs.contains(.fossil))
    }
}
