import Foundation

extension ItemKind {
    /// The items that change an egg's odds while owned: the shiny odds (Shiny Charm, Reveal Glass, Glimmering Charm),
    /// the lines drawn (Oval Charm) and the legendaries' weight (Azure Flute).
    static let drawItems: [ItemKind] = [.shinyCharm, .ovalCharm, .legendCharm, .revealGlass, .glimmeringCharm]

    /// The items that weighed on the roll until `HatchRules.Change.onlyFluteWeighs`.
    static let formerDrawItems: [ItemKind] = [.clearBell, .griseousOrb] + PokemonType.allCases.map(\.badgeItem)
}

/// The egg roll's rules, as functions of a Pokédex, the draw items owned and the updates' changes, nothing else. The
/// hatch rolls with them (`CompanionStore.chooseBase`, `hatchCore`), and the Luck screen replays every past hatch with
/// them against the Pokédex, items and rules of that hatch, so the two never part.
struct HatchDraw: Sendable {
    typealias EggSpec = CompanionStore.EggSpec

    /// The Pokédex the egg is rolled against (`dex`, `collectedFinals`, the Plates' achievements) and the line hatched
    /// last (`lastHatchedBaseID`).
    let collection: CompanionState
    /// The draw items owned, among `ItemKind.drawItems` and `formerDrawItems`.
    let items: Set<ItemKind>
    let rules: HatchRules
    /// The collection's forms that count, read once for the many lines of a roll.
    private let graduated: GraduatedForms

    init(collection: CompanionState, items: Set<ItemKind>, rules: HatchRules = .current) {
        self.collection = collection
        self.items = items
        self.rules = rules
        graduated = GraduatedForms(collection.dex, includingReleased: !rules.has(.graduatedForms))
    }

    private var ownsOvalCharm: Bool { items.contains(.ovalCharm) }

    /// The shiny odds' denominator: 64, 48 with the Shiny Charm, halved again by the Reveal Glass.
    var shinyDenominator: UInt64 {
        CompanionStore.shinyDenominator(charmOwned: items.contains(.shinyCharm),
                                        revealGlassOwned: items.contains(.revealGlass))
    }

    /// The Glimmering Charm, reward for every form, makes every hatch shiny.
    var alwaysShiny: Bool { items.contains(.glimmeringCharm) }
    var shinyChance: Double { alwaysShiny ? 1 : 1 / Double(shinyDenominator) }

    func rollsShiny(roll: UInt64) -> Bool {
        CompanionStore.rollsShiny(roll: roll, charmOwned: items.contains(.shinyCharm),
                                  revealGlassOwned: items.contains(.revealGlass))
    }

    /// Whether a Ditto may hide in this egg's Pokémon (`CompanionStore.dittoDisguiseHit` then rolls it): never when the
    /// egg promises a type (a stone's), an event's Pokémon, a fossil, or a form still missing (the Oval Charm), which a
    /// Ditto has none of.
    func letsDittoHide(baseID: Int, egg: EggSpec, fromFossilEgg: Bool) -> Bool {
        guard rules.has(.dittoKeepsPromises) else { return true }
        let keepsAPromise = egg.type != nil || egg.event != nil || fromFossilEgg
            || (ownsOvalCharm && lineMissesForms(baseID: baseID, types: egg.formTypes))
        return !keepsAPromise
    }

    /// The Oval Charm's target: this egg can still bring a form of the line that does not count yet.
    private func lineMissesForms(baseID: Int, types: [PokemonType]) -> Bool {
        let forms = CompanionState.eggForms(among: rules.rollableForms(baseID: baseID), baseID: baseID,
                                            types: rules.has(.ovalCharmEggForms) ? types : [])
        return !forms.isEmpty && !Set(forms).isSubset(of: collection.graduatedLineForms(baseID: baseID, graduated: graduated))
    }

    /// Roll weight of one base species: its hatch weight (halved once its line is collected), then the
    /// Azure Flute. Split out of `chooseBase` so the boost can be tested without a roll. The flute reads the
    /// hatch weight, not the capture rate: Mew, Celebi, Rayquaza and Shaymin have a capture rate of 45 but
    /// roll like Mewtwo. It is the only item that reweights the roll; the Oval Charm only narrows it to lines with
    /// a form missing (`hatchPool`), and the others only add growth bonuses.
    /// A stone's egg (`type`) judges a line by what it can hatch (`isLineComplete(baseID:type:)`) and lowers a
    /// collected one to a quarter rather than a half: a stone is spent on that egg.
    func hatchWeight(for e: BaseSpecies, type: PokemonType? = nil) -> Int {
        var w: Int
        let weight = rules.weight(e)
        if let type, rules.has(.stoneEggDuplicates) {
            w = collection.isLineComplete(baseID: e.id, type: type, graduated: graduated) ? max(1, weight / 4) : max(1, weight)
        } else {
            w = CollectionWeight.adjusted(weight, isCollected: isCollected(e.id))
        }
        if items.contains(.legendCharm) { w *= rules.fluteMultiplier(for: e) }
        return rules.has(.onlyFluteWeighs) ? w : withFormerItems(w, for: e)
    }

    private func isCollected(_ baseID: Int) -> Bool {
        guard rules.has(.completeLines) else { return collection.hasCollectedFinal(forBaseID: baseID) }
        return collection.isLineComplete(baseID: baseID, forms: rules.rollableForms(baseID: baseID), graduated: graduated)
    }

    /// The Clear Bell doubled the capture rates up to 45 but the legendaries', the Griseous Orb Ghost and Dragon lines,
    /// and each badge a line was weak to added 20%.
    private func withFormerItems(_ weight: Int, for e: BaseSpecies) -> Int {
        var w = weight
        let lifted = rules.weight(e)
        if items.contains(.clearBell), lifted <= 45, lifted > PokemonOdds.hatchWeight(.legendary) { w *= 2 }
        if items.contains(.griseousOrb), PokemonTypeData.types(forSpeciesID: e.id).contains(where: { $0 == .ghost || $0 == .dragon }) {
            w *= 2
        }
        let badges = PokemonType.allCases.filter {
            items.contains($0.badgeItem) && PokemonTypeData.isWeak(to: $0, speciesID: e.id, form: nil)
        }.count
        return badges > 0 ? max(1, Int((Double(w) * (1 + 0.2 * Double(badges))).rounded())) : w
    }

    /// The species an egg draws from, each with its weight: what `chooseBase` rolls and what an egg card shows
    /// (`hatchOdds`), from one function so the odds shown are the roll's. Empty when no species keeps the egg's
    /// guarantees. Not the Birthday, Fossil and season's Deerling rolls, which have their own.
    func hatchPool(_ full: [BaseSpecies], egg: EggSpec, logging: Bool = false) -> [(base: BaseSpecies, weight: Int)] {
        // 등급 보증 알은 후보를 먼저 좁힌다 — capture_rate 상한이 곧 등급 하한이고, 전설은 플래그로
        // 늘 들어간다(`Rarity.admits`: capture_rate 255 인 Necrozma·Eternatus·Terapagos 도 "희귀 이상").
        // 좁힌 결과가 비면 보증을 못 지키므로 전체 풀로 폴백하지 말고 알을 유지한다(다음 틱 재시도).
        // A fossil line hatches from Fossil Eggs only until it graduates (`FossilDig`), then from any egg like
        // every other species: shiny, twice, with another nature.
        let guarantees = guaranteeCheck(egg)
        var index = full.filter(guarantees)
        if !rules.poolHasLaterGenerations { index = index.filter { $0.id <= PokemonTypeData.generations[4].upperBound } }
        // An event egg hatches the event's Pokémon (`EventEgg.admits`). None of them in the pool (a first catch
        // the index leaves out), it hatches as a plain egg would rather than wait forever: no other egg can be
        // used while it incubates.
        if let event = egg.event {
            let companionLine = collection.companionLineID
            let eventIndex = index.filter { rules.admits($0, event: event, companionLine: companionLine) }
            if eventIndex.isEmpty {
                guard rules.has(.plainEggWithoutEventPool) else { return [] }
                if logging { AppLog.write("hatch: no \(event.rawValue) Pokémon in the pool, hatched as a plain egg") }
            } else {
                index = eventIndex
            }
        }
        guard !index.isEmpty else { return [] }
        // The Oval Charm, reward for every species: eggs only bring lines with a form still missing, while
        // some are left within the egg's guarantees.
        if ownsOvalCharm {
            let missing = index.filter { lineMissesForms(baseID: $0.id, types: egg.formTypes) }
            if !missing.isEmpty { index = missing }
        }
        if rules.has(.stoneEggDuplicates) { index = CompanionStore.withoutLastHatched(index, last: collection.lastHatchedBaseID) }
        return index.map { ($0, hatchWeight(for: $0, type: egg.type)) }
    }

    /// Whether a species keeps an egg's guarantees: its rarity or better, its type, a legendary, and a fossil line only
    /// once graduated. What `hatchPool` narrows to before an event's Pokémon, the Oval Charm and the line hatched last.
    func guaranteeCheck(_ egg: EggSpec) -> (BaseSpecies) -> Bool {
        let graduatedSpecies = collection.graduatedSpeciesIDs
        // The Friendship Egg keeps its promise even then: the line is the player's own first Pokémon.
        let friendship = rules.has(.graduatedForms) && egg.event == .companion ? collection.companionLineID : nil
        let tier = rules.tier(of: egg)
        return { base in
            (!rules.has(.eventAndFossilEggs) || !FossilDig.isFossilLine(base.id)
                || (rules.has(.graduatedFossilsEverywhere) && graduatedSpecies.contains(base.id))
                || base.id == friendship)
                && (tier.map { rules.admits(base, tier: $0) } ?? true)
                // A Legendary Egg hatches a legendary or mythical Pokémon, any of them.
                && (!egg.legendaryEgg || base.isLegendary)
                && (egg.type.map { canHatch(base.id, as: $0) } ?? true)
        }
    }

    private func canHatch(_ baseID: Int, as type: PokemonType) -> Bool {
        guard rules.has(.stoneEggsByFormType) else { return PokemonTypeData.species(for: type).contains(baseID) }
        return PokemonTypeData.canHatch(baseID: baseID, as: type, among: rules.rollableForms(baseID: baseID))
    }

    /// The forms an egg of this line rolls among, and those the line graduated in (`PokemonForm.roll`). No forms for a
    /// line without any.
    func lineFormDraw(baseID: Int, types: [PokemonType]) -> (forms: [PokemonForm], collected: Set<PokemonForm>) {
        // The same forms the Oval Charm's species filter reads (`CompanionState.lineMissesForms`).
        var forms = CompanionState.eggForms(among: rules.rollableForms(baseID: baseID), baseID: baseID,
                                            types: rules.has(.stoneEggsByFormType) ? types : [])
        guard !forms.isEmpty else { return ([], []) }
        let collected = collection.graduatedLineForms(baseID: baseID, graduated: graduated)
        // The Oval Charm hatches a form still missing when the line has one.
        if ownsOvalCharm {
            let missing = forms.filter { !collected.contains($0) }
            if !missing.isEmpty { forms = missing }
        }
        return (forms, collected)
    }

    /// The fossil lines a Fossil Egg can hatch: those not graduated yet, every one once all are.
    var fossilCandidates: Set<Int> {
        let graduatedSpecies = collection.graduatedSpeciesIDs
        let missing = FossilDig.lines.filter { !graduatedSpecies.contains($0) }
        return Set(missing.isEmpty ? FossilDig.lines : missing)
    }

    /// The lines a Fossil Egg draws from, each as likely: its candidates, not the line hatched last while another is left.
    func fossilDraw(_ index: [BaseSpecies]) -> [BaseSpecies] {
        let candidates = fossilCandidates
        return CompanionStore.withoutLastHatched(index.filter { candidates.contains($0.id) },
                                                 last: collection.lastHatchedBaseID)
    }

    /// The season's form a season's egg first rolls Deerling in, one time in `EventEgg.deerlingOdds`, under the rules
    /// every egg keeps: not the line hatched last, and with the Oval Charm, not a form already collected. Nil when it
    /// cannot.
    func seasonDeerling(_ index: [BaseSpecies], event: EventEgg?) -> PokemonForm? {
        guard let seasonForm = event?.seasonForm, index.contains(where: { $0.id == EventEgg.deerlingID }) else { return nil }
        guard rules.has(.graduatedForms) else { return seasonForm }
        guard collection.lastHatchedBaseID != EventEgg.deerlingID,
              !ownsOvalCharm || !collection.graduatedLineForms(baseID: EventEgg.deerlingID, graduated: graduated).contains(seasonForm)
        else { return nil }
        return seasonForm
    }

    /// The lines a Birthday Egg draws from (`BirthdayGift.pool`), not the line hatched last while another is left, each
    /// with its weight: a mythical line not graduated yet, else a legendary one, each as likely; once every one
    /// graduated, any of them by its hatch weight, shiny.
    func birthdayDraw(_ index: [BaseSpecies]) -> (lines: [(base: BaseSpecies, weight: Int)], shiny: Bool) {
        let (pool, byWeight) = BirthdayGift.pool(index, graduated: collection.graduatedSpeciesIDs)
        let lines = rules.has(.stoneEggDuplicates) ? CompanionStore.withoutLastHatched(pool, last: collection.lastHatchedBaseID) : pool
        return (lines.map { ($0, byWeight ? hatchWeight(for: $0) : 1) }, byWeight)
    }

    /// One way an egg can hatch: a line in a form, weighed among the egg's other draws.
    struct Outcome: Equatable, Sendable {
        let id: Int
        let form: PokemonForm?
        let weight: Double
        let rarity: Rarity
        /// It hatches shiny every time (`chooseBase`).
        var alwaysShiny = false
    }

    /// The draws each egg makes (`chooseBase`): the Type: Null Egg's one line, the Fossil and Birthday Eggs' own, the
    /// others' pool. Most event eggs, and a Birthday Egg once every legendary is graduated, hatch shiny every time.
    func outcomes(_ egg: HatchEgg, index: [BaseSpecies]) -> [Outcome] {
        switch egg {
        case .typeNull:
            let id = PokemonForm.typeNullSpeciesID
            return [Outcome(id: id, form: PokemonForm.resolved(baseID: id, form: nil), weight: 1,
                            rarity: index.first { $0.id == id }?.rarity ?? .legendary)]
        case .fossil:
            return outcomes(fossilDraw(index).map { ($0, 1) }, types: [], event: nil, alwaysShiny: false)
        case .birthday:
            let draw = birthdayDraw(index)
            return outcomes(draw.lines, types: [], event: nil, alwaysShiny: draw.shiny)
        case .tier, .stone, .legendary, .event:
            return egg.spec.map { outcomes($0, index: index) } ?? []
        }
    }

    /// A pool's draws, a season's Deerling first one time in `EventEgg.deerlingOdds`: whole weights, so that odds
    /// without forms come out exact.
    func outcomes(_ egg: EggSpec, index: [BaseSpecies]) -> [Outcome] {
        let shines = egg.event?.alwaysShiny ?? false
        let pool = outcomes(hatchPool(index, egg: egg), types: egg.formTypes, event: egg.event, alwaysShiny: shines)
        guard let season = seasonDeerling(index, event: egg.event),
              let base = index.first(where: { $0.id == EventEgg.deerlingID }) else { return pool }
        let others = Double(EventEgg.deerlingOdds - 1)
        let deerling = Outcome(id: base.id, form: PokemonForm.resolved(baseID: base.id, form: season),
                               weight: pool.reduce(0) { $0 + $1.weight }, rarity: base.rarity, alwaysShiny: shines)
        return pool.map {
            Outcome(id: $0.id, form: $0.form, weight: $0.weight * others, rarity: $0.rarity, alwaysShiny: shines)
        } + [deerling]
    }

    /// Lines drawn by weight, each rolling its form as `rollLineForm` does, or taking its event's.
    private func outcomes(_ lines: [(base: BaseSpecies, weight: Int)], types: [PokemonType], event: EventEgg?,
                          alwaysShiny: Bool) -> [Outcome] {
        lines.flatMap { line -> [Outcome] in
            let id = line.base.id
            let weight = Double(line.weight)
            let rarity = line.base.rarity
            if let form = Self.eventForm(baseID: id, event: event) {
                return [Outcome(id: id, form: form, weight: weight, rarity: rarity, alwaysShiny: alwaysShiny)]
            }
            let draw = lineFormDraw(baseID: id, types: types)
            guard !draw.forms.isEmpty else {
                return [Outcome(id: id, form: nil, weight: weight, rarity: rarity, alwaysShiny: alwaysShiny)]
            }
            let weights = PokemonForm.rollWeights(among: draw.forms, collected: draw.collected)
            let total = Double(weights.reduce(0, +))
            return zip(draw.forms, weights).map {
                Outcome(id: id, form: $0, weight: weight * Double($1) / total, rarity: rarity, alwaysShiny: alwaysShiny)
            }
        }
    }

    /// The form an event egg fixes: Deerling in its season's.
    static func eventForm(baseID: Int, event: EventEgg?) -> PokemonForm? {
        guard baseID == EventEgg.deerlingID, let form = event?.seasonForm else { return nil }
        return PokemonForm.resolved(baseID: baseID, form: form)
    }

    /// Whether a Pokémon hatched from `baseID` in `form` brings something new: a species of its line, on any branch, not
    /// graduated in that form yet. Its shine aside. Made once for the many lines of an egg.
    func bringsNew() -> (_ baseID: Int, _ form: PokemonForm?) -> Bool {
        let held = Set(collection.dex.filter { !$0.isReleased }.flatMap { e in
            e.chainOrder.map { CompanionStore.DexSpeciesKey(speciesID: $0, form: e.form) }
        })
        return { baseID, form in
            CompanionStore.lineAhead([baseID], from: baseID, form: form).contains {
                !held.contains(CompanionStore.DexSpeciesKey(speciesID: $0, form: form))
            }
        }
    }
}
