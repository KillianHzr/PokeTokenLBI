import Foundation

/// The changes the updates made to the egg roll, each in force from the second it was published: its merge into the
/// fork's `main`, or its release before the fork. Before them all, the rules of v2.5.3. A new change to the roll adds its
/// case here, and its lines with forms to `formArrivals`.
struct HatchRules: Sendable, Equatable {
    enum Change: String, CaseIterable, Sendable {
        /// v2.5.5: Unown hatches in a letter.
        case unownLetters = "2026-09-28T06:03:06Z"
        /// #2: the first lines with forms.
        case firstForms = "2026-10-15T08:11:45Z"
        /// #4: stones' eggs; legendaries no egg hatches in the games weigh like Mewtwo; the Azure Flute, Reveal Glass,
        /// Clear Bell, Griseous Orb and badges.
        case collectorItems = "2026-10-20T14:29:36Z"
        /// #16: generations 6 to 9, and the forms of more lines.
        case laterGenerations = "2026-10-20T16:37:10Z"
        /// #19: a stone's egg goes by the types of the forms it can roll.
        case stoneEggsByFormType = "2026-10-20T20:22:12Z"
        /// #20: the forms of lines where only an evolved species has them.
        case evolvedSpeciesForms = "2026-10-20T20:43:19Z"
        /// #21: the Clear Bell, Griseous Orb and badges stop weighing on the roll; the Reveal Glass takes three Forces
        /// of Nature of four.
        case onlyFluteWeighs = "2026-10-20T22:33:19Z"
        /// #26: the species index cached before generation 6 is fetched again.
        case indexReloaded = "2026-10-21T07:06:41Z"
        /// #28: a line weighs half once complete, its forms included, not from its first final; the Flute only lifts
        /// legendaries; Basculin's, Darumaka's and Poltchageist's forms become one per individual.
        case completeLines = "2026-10-21T08:10:17Z"
        /// #33: Arceus hatches Normal.
        case arceusPlates = "2026-10-21T09:37:49Z"
        /// #34: the Type: Null Egg; Type: Null hatches Normal.
        case silvallyMemories = "2026-10-21T10:09:55Z"
        /// #36: the Oval and Glimmering Charms.
        case charms = "2026-10-21T10:30:08Z"
        /// #39: the Oval Charm only looks at the forms the egg can roll.
        case ovalCharmEggForms = "2026-10-21T13:42:55Z"
        /// #40: the Flute goes from ×4 to ×2.
        case fluteTimesTwo = "2026-10-21T13:53:18Z"
        /// #64: one weight per rarity; eggs admit by rarity; the Flute lifts every legendary; the Legendary Egg; an
        /// achievement counts graduated Pokémon, not registered ones.
        case rarityWeights = "2026-10-26T07:10:49Z"
        /// #67: no Ditto in an egg that keeps a promise.
        case dittoKeepsPromises = "2026-10-26T07:40:01Z"
        /// #68: the Birthday Egg, and the forms of more lines.
        case birthdayEgg = "2026-10-26T10:13:49Z"
        /// #71: a stone's egg lowers a line complete in its type to a quarter; no egg brings the line hatched last.
        case stoneEggDuplicates = "2026-10-26T11:24:04Z"
        /// #73: the event eggs and the Fossil Egg, the only one to bring fossil lines.
        case eventAndFossilEggs = "2026-10-27T13:39:49Z"
        /// #75: a fossil line back in every egg once graduated.
        case graduatedFossilsEverywhere = "2026-10-27T15:59:55Z"
        /// #89: forms count once graduated, not once registered; the Friendship Egg brings a fossil first catch; a
        /// season's Deerling never twice in a row.
        case graduatedForms = "2026-10-28T11:29:16Z"
        /// #93: an event egg with none of its Pokémon in the pool hatches as a plain egg.
        case plainEggWithoutEventPool = "2026-10-29T07:22:40Z"
        /// #97: season's eggs Uncommon or better; Pokémon Day's babies.
        case seasonEggsAndBabies = "2026-10-29T11:25:11Z"

        private static let instants: [Change: Date] = {
            let formatter = ISO8601DateFormatter()
            return Dictionary(uniqueKeysWithValues: allCases.map { ($0, formatter.date(from: $0.rawValue)!) })
        }()

        var publishedAt: Date { Self.instants[self]! }

        /// The update that brought an item that weighs on a draw; nil for the Shiny Charm, sold before the fork.
        static func arrival(of item: ItemKind) -> Change? {
            switch item {
            case .ovalCharm, .glimmeringCharm: return .charms
            case .shinyCharm: return nil
            default: return .collectorItems
            }
        }
    }

    /// The Reveal Glass's goal until `Change.onlyFluteWeighs`.
    static let formerRevealGlassSpecies = [641, 642, 645]

    let changes: Set<Change>
    /// Installed before generation 6: its cached species index holds the pool to the first five until `indexReloaded`.
    let cachedOldIndex: Bool

    static let current = HatchRules(changes: Set(Change.allCases))

    init(changes: Set<Change>, cachedOldIndex: Bool = false) {
        self.changes = changes
        self.cachedOldIndex = cachedOldIndex
    }

    /// The rules of an egg rolled at `date`, today's for a roll of unknown date. `firstHatch`: the player's first.
    init(rolledAt date: Date?, firstHatch: Date? = nil) {
        guard let date else {
            self = .current
            return
        }
        changes = Set(Change.allCases.filter { $0.publishedAt <= date })
        cachedOldIndex = firstHatch.map { $0 < Change.laterGenerations.publishedAt } ?? false
    }

    func has(_ change: Change) -> Bool { changes.contains(change) }

    var poolHasLaterGenerations: Bool {
        has(.laterGenerations) && (!cachedOldIndex || has(.indexReloaded))
    }

    /// Whether the egg was there. The Shop's always were.
    func allows(_ egg: HatchEgg) -> Bool {
        switch egg {
        case .tier: return true
        case .stone: return has(.collectorItems)
        case .typeNull: return has(.silvallyMemories)
        case .legendary: return has(.rarityWeights)
        case .birthday: return has(.birthdayEgg)
        case .fossil, .event: return has(.eventAndFossilEggs)
        }
    }

    /// A line's weight in the roll, before its collection lowers it.
    func weight(_ e: BaseSpecies) -> Int {
        if has(.rarityWeights) { return e.hatchWeight }
        if has(.collectorItems) && e.isUnbreedableLegendary { return PokemonOdds.hatchWeight(.legendary) }
        return e.captureRate
    }

    /// What the Azure Flute multiplies a line's weight by.
    func fluteMultiplier(for e: BaseSpecies) -> Int {
        let lifted = has(.rarityWeights) ? e.rarity == .legendary
            : weight(e) <= PokemonOdds.hatchWeight(.legendary) && (!has(.completeLines) || e.isLegendary)
        guard lifted else { return 1 }
        return has(.fluteTimesTwo) ? LegendCharm.weightMultiplier : 4
    }

    /// Whether a rarity's egg admits a line.
    func admits(_ e: BaseSpecies, tier: Rarity) -> Bool {
        has(.rarityWeights) ? tier.admits(e) : tier.includes(captureRate: e.captureRate)
    }

    /// The rarity an egg promises.
    func tier(of egg: CompanionStore.EggSpec) -> Rarity? {
        egg.event?.isSeason == true && !has(.seasonEggsAndBabies) ? nil : egg.tier
    }

    /// Whether an event's egg brings a line.
    func admits(_ e: BaseSpecies, event: EventEgg, companionLine: Int?) -> Bool {
        if event == .pokemonDay && !has(.seasonEggsAndBabies) { return e.id <= 151 }
        return event.admits(e, companionLine: companionLine)
    }

    /// When each line got its forms, from the catalogue of each merge. A form the catalogue gains later needs a change.
    private static let formArrivals: [Int: Change] = {
        let arrivals: [(Change, [Int])] = [
            (.unownLetters, [201]),
            (.firstForms, [351, 386, 412, 420, 422, 479, 487, 492, 493, 550, 554, 585, 641, 642, 645, 646, 647, 648, 649]),
            (.laterGenerations, [19, 27, 37, 50, 52, 58, 74, 77, 79, 83, 88, 100, 128, 144, 145, 146, 194, 211, 215, 222,
                                 263, 562, 570, 618, 669, 676, 710, 718, 741, 746, 774, 778, 800, 801, 845, 875, 877, 888,
                                 889, 893, 898, 905, 931, 978, 999, 1012, 1017, 1024]),
            (.evolvedSpeciesForms, [102, 104, 109, 155, 172, 206, 439, 501, 548, 627, 664, 677, 679, 704, 712, 722, 744,
                                    772, 848, 891, 963]),
            (.birthdayEgg, [133, 216, 483, 484, 720, 868, 876, 915, 924]),
        ]
        return Dictionary(uniqueKeysWithValues: arrivals.flatMap { change, lines in lines.map { ($0, change) } })
    }()

    /// The forms of the lines whose list changed after they came, each until a change.
    private static let formerForms: [Int: [(until: Change, forms: [String])]] = [
        550: [(.laterGenerations, ["red-striped", "blue-striped"]),
              (.evolvedSpeciesForms, ["red-striped", "blue-striped", "white-striped"]),
              (.completeLines, ["red-striped", "blue-striped", "white-striped", "male", "female"])],
        554: [(.laterGenerations, ["standard", "zen"]),
              (.completeLines, ["standard", "galar", "zen", "galar-standard", "galar-zen"])],
        1012: [(.evolvedSpeciesForms, ["counterfeit", "artisan"]),
               (.completeLines, ["counterfeit", "artisan", "unremarkable", "masterpiece"])],
    ]

    /// Everything an individual of this line could carry then.
    func lineForms(baseID: Int) -> [PokemonForm] {
        if let arrival = Self.formArrivals[baseID], !has(arrival) { return [] }
        if let former = Self.formerForms[baseID]?.first(where: { !has($0.until) }) { return former.forms.map { PokemonForm($0) } }
        return PokemonForm.lineForms(baseID: baseID)
    }

    /// The forms an egg of this line rolled then: only the default once its forms came from items.
    func rollableForms(baseID: Int) -> [PokemonForm] {
        let forms = lineForms(baseID: baseID)
        let fromItems = baseID == 493 ? has(.arceusPlates) : baseID == PokemonForm.typeNullSpeciesID && has(.silvallyMemories)
        return fromItems ? Array(forms.prefix(1)) : forms
    }
}
