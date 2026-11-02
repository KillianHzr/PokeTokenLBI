import Foundation

extension ItemKind {
    /// The items that change an egg's odds while owned: the shiny odds (Shiny Charm, Reveal Glass, Glimmering Charm),
    /// the lines drawn (Oval Charm) and the legendaries' weight (Azure Flute).
    static let drawItems: [ItemKind] = [.shinyCharm, .ovalCharm, .legendCharm, .revealGlass, .glimmeringCharm]
}

/// The egg roll's rules, as functions of a Pokédex and the draw items owned, nothing else. The hatch rolls with them
/// (`CompanionStore.chooseBase`, `hatchCore`), and the Luck screen replays every past hatch with them against the
/// Pokédex and items of that hatch, so the two never part.
struct HatchDraw: Sendable {
    typealias EggSpec = CompanionStore.EggSpec

    /// The Pokédex the egg is rolled against (`dex`, `collectedFinals`, the Plates' achievements) and the line hatched
    /// last (`lastHatchedBaseID`).
    let collection: CompanionState
    /// The draw items owned, among `ItemKind.drawItems`.
    let items: Set<ItemKind>

    private var ownsOvalCharm: Bool { items.contains(.ovalCharm) }

    /// The shiny odds' denominator: 64, 48 with the Shiny Charm, halved again by the Reveal Glass.
    var shinyDenominator: UInt64 {
        CompanionStore.shinyDenominator(charmOwned: items.contains(.shinyCharm),
                                        revealGlassOwned: items.contains(.revealGlass))
    }

    /// The Glimmering Charm, reward for every form, makes every hatch shiny.
    var alwaysShiny: Bool { items.contains(.glimmeringCharm) }

    func rollsShiny(roll: UInt64) -> Bool {
        CompanionStore.rollsShiny(roll: roll, charmOwned: items.contains(.shinyCharm),
                                  revealGlassOwned: items.contains(.revealGlass))
    }

    /// Whether a Ditto may hide in this egg's Pokémon (`CompanionStore.dittoDisguiseHit` then rolls it): never when the
    /// egg promises a type (a stone's), an event's Pokémon, a fossil, or a form still missing (the Oval Charm), which a
    /// Ditto has none of.
    func letsDittoHide(baseID: Int, egg: EggSpec, fromFossilEgg: Bool) -> Bool {
        let keepsAPromise = egg.type != nil || egg.event != nil || fromFossilEgg
            || (ownsOvalCharm && collection.lineMissesForms(baseID: baseID, types: egg.formTypes))
        return !keepsAPromise
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
        if let type {
            w = collection.isLineComplete(baseID: e.id, type: type) ? max(1, e.hatchWeight / 4) : max(1, e.hatchWeight)
        } else {
            w = CollectionWeight.adjusted(e.hatchWeight, isCollected: collection.isLineComplete(baseID: e.id))
        }
        // The legendary rarity: every legendary and mythical, never Beldum (capture rate 3).
        if items.contains(.legendCharm) && e.rarity == .legendary {
            w *= LegendCharm.weightMultiplier
        }
        return w
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
        let graduated = collection.graduatedSpeciesIDs
        // The Friendship Egg keeps its promise even then: the line is the player's own first Pokémon.
        let friendship = egg.event == .companion ? collection.companionLineID : nil
        let admitted = full.filter { !FossilDig.isFossilLine($0.id) || graduated.contains($0.id) || $0.id == friendship }
        var index = egg.tier.map { t in admitted.filter(t.admits) } ?? admitted
        // A Legendary Egg hatches a legendary or mythical Pokémon, any of them.
        if egg.legendaryEgg { index = index.filter(\.isLegendary) }
        if let targetType = egg.type {
            index = index.filter { PokemonTypeData.canHatch(baseID: $0.id, as: targetType) }
        }
        // An event egg hatches the event's Pokémon (`EventEgg.admits`). None of them in the pool (a first catch
        // the index leaves out), it hatches as a plain egg would rather than wait forever: no other egg can be
        // used while it incubates.
        if let event = egg.event {
            let companionLine = collection.companionLineID
            let eventIndex = index.filter { event.admits($0, companionLine: companionLine) }
            if eventIndex.isEmpty {
                if logging { AppLog.write("hatch: no \(event.rawValue) Pokémon in the pool, hatched as a plain egg") }
            } else {
                index = eventIndex
            }
        }
        guard !index.isEmpty else { return [] }
        // The Oval Charm, reward for every species: eggs only bring lines with a form still missing, while
        // some are left within the egg's guarantees.
        if ownsOvalCharm {
            let missing = index.filter { collection.lineMissesForms(baseID: $0.id, types: egg.formTypes) }
            if !missing.isEmpty { index = missing }
        }
        index = CompanionStore.withoutLastHatched(index, last: collection.lastHatchedBaseID)
        return index.map { ($0, hatchWeight(for: $0, type: egg.type)) }
    }

    /// The forms an egg of this line rolls among, and those the line graduated in (`PokemonForm.roll`). No forms for a
    /// line without any.
    func lineFormDraw(baseID: Int, types: [PokemonType]) -> (forms: [PokemonForm], collected: Set<PokemonForm>) {
        // The same forms the Oval Charm's species filter reads (`CompanionState.lineMissesForms`).
        var forms = CompanionState.eggForms(baseID: baseID, types: types)
        guard !forms.isEmpty else { return ([], []) }
        let collected = collection.graduatedLineForms(baseID: baseID)
        // The Oval Charm hatches a form still missing when the line has one.
        if ownsOvalCharm {
            let missing = forms.filter { !collected.contains($0) }
            if !missing.isEmpty { forms = missing }
        }
        return (forms, collected)
    }

    /// The fossil lines a Fossil Egg can hatch: those not graduated yet, every one once all are.
    var fossilCandidates: Set<Int> {
        let graduated = collection.graduatedSpeciesIDs
        let missing = FossilDig.lines.filter { !graduated.contains($0) }
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
        guard let seasonForm = event?.seasonForm, index.contains(where: { $0.id == EventEgg.deerlingID }),
              collection.lastHatchedBaseID != EventEgg.deerlingID,
              !ownsOvalCharm || !collection.graduatedLineForms(baseID: EventEgg.deerlingID).contains(seasonForm)
        else { return nil }
        return seasonForm
    }

    /// The lines a Birthday Egg draws from (`BirthdayGift.pool`), not the line hatched last while another is left, each
    /// with its weight: a mythical line not graduated yet, else a legendary one, each as likely; once every one
    /// graduated, any of them by its hatch weight, shiny.
    func birthdayDraw(_ index: [BaseSpecies]) -> (lines: [(base: BaseSpecies, weight: Int)], shiny: Bool) {
        let (pool, byWeight) = BirthdayGift.pool(index, graduated: collection.graduatedSpeciesIDs)
        let lines = CompanionStore.withoutLastHatched(pool, last: collection.lastHatchedBaseID)
        return (lines.map { ($0, byWeight ? hatchWeight(for: $0) : 1) }, byWeight)
    }
}
