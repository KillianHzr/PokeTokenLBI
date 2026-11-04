import Foundation

/// The Luck screen's numbers: every hatch replayed against the Pokédex and draw items of its moment with the roll's own
/// rules (`HatchDraw`), and how lucky its draws were.
struct HatchLuck: Sendable {
    enum Criterion: CaseIterable, Sendable { case uncommon, rare, legendary, shiny, new, ditto }

    /// The odds of what a hatch drew, lowest and highest over the eggs that could have brought it when its egg is unknown.
    struct OddsRange: Equatable, Sendable {
        let low: Double
        let high: Double
    }

    struct Judgement: Equatable, Sendable {
        let odds: Double
        let hit: Bool
    }

    struct Hatch: Sendable {
        /// From 1, in hatch order.
        let number: Int
        let entry: DexEntry
        let isActive: Bool
        let isDitto: Bool
        /// Its line's rarity in the species index.
        let rarity: Rarity
        /// The record's egg, the player's choice, or a Pokémon Egg after a graduation; nil when unknown.
        let egg: HatchEgg?
        let eggChosenByPlayer: Bool
        /// The app's guess, which the player asked for and may still change (`guessedEggs`).
        let eggDeduced: Bool
        /// The player may say its egg (`HatchRecord.isOpenToPlayer`): a hatch after a release the app did not note.
        let asksEgg: Bool
        let possibleEggs: [HatchEgg]
        /// The odds of its line, of a Ditto for one, from each of them.
        let lineOddsByEgg: [HatchEgg: Double]
        /// The odds of the rarity it hatched in, of a Ditto for one.
        let rarityOdds: OddsRange
        /// Whether it brought something new (`HatchDraw.bringsNew`), and the odds of that outcome; nil for a Ditto.
        let bringsNew: Bool
        let newOdds: OddsRange?
        /// Its form is still hidden and decides whether it brings something: not judged on it, then or ever if it is
        /// sent off before a stage shows it.
        let isFormMystery: Bool
        /// The odds of its line, of a Ditto for one, when its egg is known.
        let lineOdds: Double?
        let judged: [Criterion: Judgement]
        /// The Luck score after it, and how much it moved it.
        var score = 50.0
        var effect = 0.0
        /// Each criterion's percentile after it.
        var percentiles: [Criterion: Double] = [:]
    }

    struct CriterionResult: Equatable, Sendable {
        let criterion: Criterion
        let hits: Int
        let expected: Double
        /// The share of players who, with exactly the same odds at each hatch, did worse: ties count half.
        let percentile: Double
        /// Hatches since the last hit; nil before the first.
        let sinceLast: Int?
    }

    let hatches: [Hatch]
    let criteria: [CriterionResult]
    /// Hatches a week, from the first catch to now; nil under two dated catches a day apart.
    let hatchesPerWeek: Double?
    let stock: EggStock
    let itemsSince: [ItemKind: Date]

    /// `entries`: the Pokédex in hatch order, the Pokémon raised last when `includesActive`. `today`: what the save does
    /// not date, the Plates' achievements, taken as they are. `itemsSince`: when the player got each draw item, for
    /// hatches without a record (`CompanionStore.drawItemSince`).
    init(entries: [DexEntry], includesActive: Bool, today: CompanionState, index: [BaseSpecies],
         itemsSince: [ItemKind: Date] = [:], now: Date) {
        let rarities = Dictionary(index.map { ($0.id, $0.rarity) }, uniquingKeysWith: { a, _ in a })
        let moments = Self.moments(entries: entries, today: today, itemsSince: itemsSince)
        let measured = moments.map { moment in
            moment.asksEgg ? Self.possibleEggs(of: moment, index: index) : []
        }
        let slots = zip(moments, measured).map { moment, possible in
            EggStock.Slot(started: moment.previous?.caughtAt, possible: possible.map(\.egg), egg: moment.egg,
                          asked: moment.asksEgg)
        }
        self.itemsSince = itemsSince
        stock = EggStock(today: today, entries: entries)
        let settled = stock.settle(slots)
        var hatches: [Hatch] = []
        for (i, moment) in moments.enumerated() {
            hatches.append(Self.hatch(number: i + 1, entry: moment.entry, isActive: includesActive && i == entries.count - 1,
                                      slot: settled[i], source: moment.entry.hatch?.source,
                                      possible: measured[i].filter { settled[i].possible.contains($0.egg) },
                                      roll: moment.roll, hatch: moment.hatch, index: index, rarities: rarities))
        }
        var runs = Criterion.allCases.map { _ in (odds: [Double](), hits: 0) }
        var distributions = Criterion.allCases.map { _ in [1.0] }
        var lastHit: [Int?] = Criterion.allCases.map { _ in nil }
        var score = 50.0
        for i in hatches.indices {
            for (k, criterion) in Criterion.allCases.enumerated() {
                guard let judgement = hatches[i].judged[criterion] else { continue }
                runs[k].odds.append(judgement.odds)
                distributions[k] = Self.adding(judgement.odds, to: distributions[k])
                if judgement.hit {
                    runs[k].hits += 1
                    lastHit[k] = i
                }
            }
            for (k, criterion) in Criterion.allCases.enumerated() {
                hatches[i].percentiles[criterion] = Self.percentile(distributions[k], hits: runs[k].hits)
            }
            let next = hatches[i].percentiles.values.reduce(0, +) / Double(Criterion.allCases.count) * 100
            hatches[i].effect = next - score
            hatches[i].score = next
            score = next
        }
        self.hatches = hatches
        criteria = Criterion.allCases.enumerated().map { k, criterion in
            CriterionResult(criterion: criterion, hits: runs[k].hits, expected: runs[k].odds.reduce(0, +),
                            percentile: Self.percentile(distributions[k], hits: runs[k].hits),
                            sinceLast: lastHit[k].map { hatches.count - 1 - $0 })
        }
        let dated = entries.compactMap(\.caughtAt).sorted()
        if dated.count >= 2, let first = dated.first, dated.last!.timeIntervalSince(first) >= 86_400 {
            hatchesPerWeek = Double(dated.count) / (now.timeIntervalSince(first) / (7 * 86_400))
        } else {
            hatchesPerWeek = nil
        }
    }

    struct Moment: Sendable {
        let entry: DexEntry
        let previous: DexEntry?
        let roll: HatchDraw
        let hatch: HatchDraw

        /// A hatch after a release the app did not note, whose egg the player may say.
        var asksEgg: Bool { entry.hatch?.isOpenToPlayer ?? (previous?.isReleased == true) }
        /// What its record says, or a Pokémon Egg after a graduation; nil when unknown.
        var egg: HatchEgg? { entry.hatch?.egg ?? (previous?.isReleased == true ? nil : .tier(nil)) }
    }

    /// When a Pokémon hatched, or when the one before it left for a save that kept no hatch.
    static func hatchedAt(of entry: DexEntry, after previous: DexEntry?) -> Date? {
        entry.raising?.hatchedAt ?? previous?.caughtAt ?? entry.caughtAt
    }

    /// Every egg against the Pokédex, draw items and rules of its rolls. Its species and form are rolled as the Pokémon
    /// before it leaves, its shiny and Ditto as it hatches.
    static func moments(entries: [DexEntry], today: CompanionState, itemsSince: [ItemKind: Date]) -> [Moment] {
        var collection = today
        collection.active = nil
        collection.dex = []
        collection.collectedFinals = []
        var moments: [Moment] = []
        let firstHatch = entries.first.flatMap { $0.raising?.hatchedAt ?? $0.caughtAt }
        for (i, entry) in entries.enumerated() {
            let previous = i > 0 ? entries[i - 1] : nil
            collection.lastHatchedBaseID = previous?.hatch?.rolledBaseID ?? previous?.baseID
            let rollItems: Set<ItemKind>, hatchItems: Set<ItemKind>
            if let record = entry.hatch, !record.itemsFromDates {
                (rollItems, hatchItems) = (record.rollItems, record.hatchItems)
            } else {
                let started = previous?.caughtAt
                let owned = Set(itemsSince.filter { since in started.map { since.value < $0 } ?? false }.keys)
                (rollItems, hatchItems) = (owned, owned)
            }
            let hatchedAt = hatchedAt(of: entry, after: previous)
            let rolledAt = previous?.caughtAt ?? hatchedAt
            moments.append(Moment(entry: entry, previous: previous,
                                  roll: HatchDraw(collection: collection, items: rollItems,
                                                  rules: HatchRules(rolledAt: rolledAt, firstHatch: firstHatch)),
                                  hatch: HatchDraw(collection: collection, items: hatchItems,
                                                   rules: HatchRules(rolledAt: hatchedAt, firstHatch: firstHatch))))
            if !entry.isReleased { collection.collectedFinals.insert("\(entry.baseID):\(entry.finalID)") }
            collection.dex.append(entry)
        }
        return moments
    }

    private static let bagEggs: [HatchEgg] = {
        var seen = Set<HatchEgg>()
        return ItemKind.allCases.compactMap(HatchEgg.init(item:)).filter { seen.insert($0).inserted }
    }()

    struct EggOdds {
        var share: [Rarity: Double] = [:]
        var line = 0.0
        var new = 0.0
        var ditto = 0.0
        var shiny = 0.0
        var total = 0.0
    }

    private static func odds(of egg: HatchEgg, base: Int, roll: HatchDraw, hatch: HatchDraw, index: [BaseSpecies],
                             bringsNew: (Int, PokemonForm?) -> Bool) -> EggOdds {
        var odds = EggOdds()
        let spec = egg.spec ?? EggSpec()
        let shiny = hatch.shinyChance
        for outcome in roll.outcomes(egg, index: index) {
            let w = outcome.weight
            odds.total += w
            odds.share[outcome.rarity, default: 0] += w
            if outcome.id == base { odds.line += w }
            if bringsNew(outcome.id, outcome.form) { odds.new += w }
            odds.shiny += w * (outcome.alwaysShiny ? 1 : shiny)
            let stages = PokemonEvolutionData.stageCount(from: outcome.id)
            if outcome.rarity == .common, stages >= 2,
               hatch.letsDittoHide(baseID: outcome.id, egg: spec, fromFossilEgg: egg == .fossil) {
                odds.ditto += w / Double(PokemonOdds.dittoDisguiseDenominator)
            }
        }
        guard odds.total > 0 else { return odds }
        for key in odds.share.keys { odds.share[key]! /= odds.total }
        odds.line /= odds.total
        odds.new /= odds.total
        odds.ditto /= odds.total
        odds.shiny /= odds.total
        // A Ditto hides in a common.
        odds.share[.common, default: 0] -= odds.ditto
        return odds
    }

    typealias EggSpec = CompanionStore.EggSpec

    private static func mayHold(_ egg: HatchEgg, base: Int, roll: HatchDraw, index: [BaseSpecies]) -> Bool {
        switch egg {
        case .typeNull: return base == PokemonForm.typeNullSpeciesID
        case .fossil: return roll.fossilDraw(index).contains { $0.id == base }
        case .birthday: return roll.birthdayDraw(index).lines.contains { $0.base.id == base }
        case .tier, .stone, .legendary, .event:
            guard let spec = egg.spec, let species = index.first(where: { $0.id == base }) else { return false }
            // A season's Deerling, first rolled apart from the pool.
            if base == EventEgg.deerlingID, spec.event?.seasonForm != nil { return true }
            return roll.guaranteeCheck(spec)(species)
        }
    }

    /// The eggs there were that day whose pool holds its line, a Ditto only from an egg it can hide in.
    static func possibleEggs(of moment: Moment, index: [BaseSpecies]) -> [(egg: HatchEgg, odds: EggOdds)] {
        let entry = moment.entry, roll = moment.roll
        let isDitto = entry.baseID == PokemonOdds.dittoSpeciesID
        let bringsNew = roll.bringsNew()
        return bagEggs.filter { candidate in
            roll.rules.allows(candidate) && (isDitto || mayHold(candidate, base: entry.baseID, roll: roll, index: index))
        }.map { candidate in
            (candidate, odds(of: candidate, base: entry.baseID, roll: roll, hatch: moment.hatch, index: index,
                             bringsNew: bringsNew))
        }.filter { isDitto ? $0.1.ditto > 0 : $0.1.line > 0 }
    }

    private static func hatch(number: Int, entry: DexEntry, isActive: Bool, slot: EggStock.Slot, source: HatchRecord.Source?,
                              possible: [(egg: HatchEgg, odds: EggOdds)], roll: HatchDraw, hatch: HatchDraw,
                              index: [BaseSpecies], rarities: [Int: Rarity]) -> Hatch {
        let isDitto = entry.baseID == PokemonOdds.dittoSpeciesID
        let rarity = rarities[entry.baseID] ?? entry.rarity
        let bringsNew = roll.bringsNew()
        let new = !isDitto && bringsNew(entry.baseID, entry.form)
        let isFormMystery = PokemonForm.isFormHidden(baseID: entry.baseID, reached: entry.chainOrder)
            && Set(roll.lineFormDraw(baseID: entry.baseID, types: []).forms.map { bringsNew(entry.baseID, $0) }).count > 1
        func measure(_ candidate: HatchEgg) -> EggOdds {
            odds(of: candidate, base: entry.baseID, roll: roll, hatch: hatch, index: index, bringsNew: bringsNew)
        }
        let known = slot.egg
        let all = known.map { egg in [possible.first { $0.egg == egg }?.odds ?? measure(egg)] } ?? possible.map(\.odds)
        func range(_ value: (EggOdds) -> Double) -> OddsRange {
            let values = all.map(value)
            return OddsRange(low: values.min() ?? 0, high: values.max() ?? 0)
        }
        let rarityOdds = range { isDitto ? $0.ditto : $0.share[rarity] ?? 0 }
        var judged: [Criterion: Judgement] = [:]
        if known != nil, let o = all.first {
            for (criterion, r) in [(Criterion.uncommon, Rarity.uncommon), (.rare, .rare), (.legendary, .legendary)] {
                judged[criterion] = Judgement(odds: o.share[r] ?? 0, hit: !isDitto && rarity == r)
            }
            judged[.shiny] = Judgement(odds: o.shiny, hit: entry.isShiny)
            judged[.ditto] = Judgement(odds: o.ditto, hit: isDitto)
            if !isDitto, !isFormMystery { judged[.new] = Judgement(odds: o.new, hit: new) }
        } else {
            judged[.shiny] = Judgement(odds: hatch.shinyChance, hit: entry.isShiny)
        }
        return Hatch(number: number, entry: entry, isActive: isActive, isDitto: isDitto, rarity: rarity, egg: known,
                     eggChosenByPlayer: source == .player && known != nil && !slot.isSure,
                     eggDeduced: source == .deduced && known != nil && !slot.isSure,
                     asksEgg: slot.asked && !slot.isSure, possibleEggs: possible.map(\.egg),
                     lineOddsByEgg: Dictionary(possible.map { ($0.egg, isDitto ? $0.odds.ditto : $0.odds.line) },
                                               uniquingKeysWith: { a, _ in a }),
                     rarityOdds: rarityOdds,
                     bringsNew: new,
                     newOdds: isDitto || isFormMystery ? nil : range { new ? $0.new : 1 - $0.new },
                     isFormMystery: isFormMystery,
                     lineOdds: known == nil ? nil : all.first.map { isDitto ? $0.ditto : $0.line }, judged: judged)
    }

    /// The egg each hatch still unknown most likely came from, for a player who does not remember. Each counted egg left
    /// goes where it makes the Pokémon hatched the likeliest against the Shop's egg it would have had otherwise, the
    /// oldest hatch on a tie. The others take that Shop's egg, the rarest their line allows.
    func guessedEggs() -> [String: HatchEgg] {
        var left = stock.left
        for hatch in hatches where hatch.entry.hatch?.isOpenToPlayer != false {
            if let egg = hatch.egg?.withoutKey, let count = left[egg] { left[egg] = max(0, count - 1) }
        }
        let shopEggs = hatches.filter { $0.egg == nil }.compactMap { hatch -> (hatch: Hatch, egg: HatchEgg)? in
            let egg = ([.tier(.rare), .tier(.uncommon), .tier(nil)] as [HatchEgg]).first(where: hatch.possibleEggs.contains)
            return egg.map { (hatch, $0) }
        }
        var places: [(gain: Double, number: Int, order: Int, id: String, egg: HatchEgg)] = []
        for (hatch, shopEgg) in shopEggs {
            for (order, egg) in hatch.possibleEggs.enumerated() where (left[egg] ?? 0) > 0 {
                let gain = (hatch.lineOddsByEgg[egg] ?? 0) / (hatch.lineOddsByEgg[shopEgg] ?? 1)
                places.append((gain, hatch.number, order, hatch.entry.id, egg))
            }
        }
        places.sort { ($1.gain, $0.number, $0.order) < ($0.gain, $1.number, $1.order) }
        var guesses: [String: HatchEgg] = [:]
        for place in places where guesses[place.id] == nil && (left[place.egg] ?? 0) > 0 {
            guesses[place.id] = place.egg
            left[place.egg, default: 0] -= 1
        }
        for (hatch, shopEgg) in shopEggs where guesses[hatch.entry.id] == nil { guesses[hatch.entry.id] = shopEgg }
        return guesses
    }

    var improbable: [Hatch] {
        Array(hatches.filter { ($0.lineOdds ?? 0) > 0 }.sorted { $0.lineOdds! < $1.lineOdds! }.prefix(3))
    }

    var strongest: CriterionResult? { criteria.max { $0.percentile < $1.percentile } }
    var weakest: CriterionResult? { criteria.min { $0.percentile < $1.percentile } }

    /// +1 when a hatch raised the score by half a point or more, as shown to a tenth; -1 when it lowered it as much.
    static func effectDirection(_ effect: Double) -> Int {
        let shown = (effect * 10).rounded() / 10
        return shown >= 0.5 ? 1 : shown <= -0.5 ? -1 : 0
    }

    struct Wait: Equatable, Sendable {
        enum Unit: Sendable { case day, week, month, year }
        let count: Int
        let unit: Unit
    }

    /// How long drawing something of `odds` takes on average at `perWeek` hatches a week: in days under two weeks,
    /// weeks under three months, months under two years.
    static func averageWait(odds: Double, perWeek: Double) -> Wait {
        let day = 86_400.0, week = 7 * day, year = 365.25 * day, month = year / 12
        let time = 1 / odds / perWeek * week
        let (unit, size): (Wait.Unit, Double) = (time / day).rounded() < 14 ? (.day, day)
            : time < 3 * month ? (.week, week)
            : (time / month).rounded() < 24 ? (.month, month) : (.year, year)
        return Wait(count: max(1, Int((time / size).rounded())), unit: unit)
    }

    var score: Double { criteria.isEmpty ? 50 : criteria.reduce(0) { $0 + $1.percentile } / Double(criteria.count) * 100 }

    /// The share of equally placed players who did worse with `odds` and `hits` hits: ties count half.
    static func percentile(odds: [Double], hits: Int) -> Double {
        percentile(odds.reduce([1.0]) { adding($1, to: $0) }, hits: hits)
    }

    /// The exact count distribution of independent draws (Poisson binomial), one more draw of odds `p`.
    private static func adding(_ p: Double, to distribution: [Double]) -> [Double] {
        var next = [Double](repeating: 0, count: distribution.count + 1)
        for (k, q) in distribution.enumerated() {
            next[k] += q * (1 - p)
            next[k + 1] += q * p
        }
        return next
    }

    private static func percentile(_ distribution: [Double], hits: Int) -> Double {
        let below = distribution.prefix(max(0, hits)).reduce(0, +)
        let tie = hits < distribution.count ? distribution[hits] : 0
        return below + tie / 2
    }
}
