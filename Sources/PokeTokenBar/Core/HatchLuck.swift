import Foundation

/// The Luck screen's numbers: every hatch replayed against the Pokédex and draw items of its moment with the roll's own
/// rules (`HatchDraw`), the luck journal's draws beside them (`LuckDraw`), and how lucky it all was (`LuckScore`: the
/// share of players with exactly these draws who did worse; the owner's scoping of 2026-11-25).
struct HatchLuck: Sendable {
    typealias Criterion = LuckCriterion

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
        /// Its shiny, something new and Ditto, at the odds they had.
        let judged: [Criterion: Judgement]
        /// Its rarity, each tier "or better" (uncommon, rare, legendary): the counts the rarity shows. The score counts
        /// it once, graded (`LuckCriterion.rarity`).
        let tiers: [Rarity: Judgement]
        /// The six IVs' total the hatch drew, before any Capsule; nil without a profile.
        let ivTotal: Int?
        /// Whether it drew its hidden ability, one time in 128; nil when it had none to draw or is not known yet.
        let hiddenAbility: Bool?
        /// The draws it weighs in the score.
        let events: [LuckEvent]
        /// The Luck score after it, and how much it moved it.
        var score = 50.0
        var effect = 0.0
        /// Each criterion's percentile after it.
        var percentiles: [Criterion: Double] = [:]
    }

    /// A rarity tier "or better" over the hatches judged on it.
    struct TierCount: Equatable, Sendable {
        let rarity: Rarity
        let hits: Int
        let expected: Double
    }

    struct CriterionResult: Equatable, Sendable {
        let criterion: Criterion
        /// Its hits and expected hits: for the rarity, the uncommons or better; for the IVs, the hatches judged.
        let hits: Int
        let expected: Double
        /// The share of players who, with exactly the same draws, got fewer points: ties count half.
        let percentile: Double
        /// Hatches since the last hit; nil before the first, and for what is not a hatch's.
        let sinceLast: Int?
        /// The rarity's tiers, uncommon to legendary.
        var tiers: [TierCount] = []
        /// The IVs' average total, against the 93 expected.
        var averageIVs: Double?
    }

    /// The score over a span: overall, by family, by criterion.
    struct Period: Sendable {
        /// Out of 100.
        let score: Double
        let families: [LuckFamily: Double]
        let criteria: [CriterionResult]
        /// What it holds: the hatches and the days of the luck journal.
        let hatchCount: Int
        let journalDays: Int

        var strongest: CriterionResult? { criteria.max { $0.percentile < $1.percentile } }
        var weakest: CriterionResult? { criteria.min { $0.percentile < $1.percentile } }
    }

    /// A point of the score's curve: after a hatch, or after a day of the luck journal.
    struct Step: Sendable {
        enum Kind: Sendable, Equatable {
            /// `hatches`' index.
            case hatch(Int)
            case journal
        }
        let kind: Kind
        let date: Date?
        var score = 50.0
        var percentiles: [Criterion: Double] = [:]
    }

    /// One of the luckiest draws, a hatch's or the journal's, at the odds it had.
    struct Highlight: Sendable, Equatable {
        let criterion: Criterion
        let odds: Double
        let date: Date?
        /// `hatches`' index, for a hatch's.
        let hatch: Int?
        /// For the journal's.
        let draw: LuckDrawKind?
        /// The tier a rarity hit reached.
        let rarity: Rarity?
    }

    let hatches: [Hatch]
    /// All time.
    let criteria: [CriterionResult]
    let families: [LuckFamily: Double]
    /// The last `recentDays` days; nil when nothing was drawn in them.
    let recent: Period?
    let steps: [Step]
    /// The luckiest draws, the least likely first.
    let highlights: [Highlight]
    /// Expeditions in the history, for the summary's sentence.
    let expeditions: Int
    /// Hatches a week, from the first catch to now; nil under two dated catches a day apart.
    let hatchesPerWeek: Double?
    let stock: EggStock
    let itemsSince: [ItemKind: Date]

    /// The span the recent score covers.
    static let recentDays = 30.0

    /// `entries`: the Pokédex in hatch order, the Pokémon raised last when `includesActive`. `today`: what the save does
    /// not date, the Plates' achievements, taken as they are. `itemsSince`: when the player got each draw item, for
    /// hatches without a record (`CompanionStore.drawItemSince`). `draws`: the luck journal. `hiddenAbilities`: whether
    /// each line has a hidden ability to draw, by its first species, as far as known.
    init(entries: [DexEntry], includesActive: Bool, today: CompanionState, index: [BaseSpecies],
         itemsSince: [ItemKind: Date] = [:], draws: [LuckDraw] = [], expeditions: Int = 0,
         hiddenAbilities: [Int: Bool] = [:], now: Date, players: Int = LuckScore.players) {
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
        self.expeditions = expeditions
        stock = EggStock(today: today, entries: entries)
        let settled = stock.settle(slots)
        var hatches: [Hatch] = []
        for (i, moment) in moments.enumerated() {
            hatches.append(Self.hatch(number: i + 1, entry: moment.entry, isActive: includesActive && i == entries.count - 1,
                                      slot: settled[i], source: moment.entry.hatch?.source,
                                      possible: measured[i].filter { settled[i].possible.contains($0.egg) },
                                      roll: moment.roll, hatch: moment.hatch, index: index, rarities: rarities,
                                      hiddenAbilities: hiddenAbilities))
        }

        // The timeline: each hatch at its moment, each day of the journal after the hatches before its last draw.
        var steps: [Step] = [], events: [[LuckEvent]] = []
        let days = Dictionary(grouping: draws, by: \.day).map { (at: $0.value.map(\.at).max()!, draws: $0.value) }
            .sorted { $0.at < $1.at }
        var nextDay = 0
        func addDays(before date: Date?) {
            while nextDay < days.count, date.map({ days[nextDay].at < $0 }) ?? true {
                steps.append(Step(kind: .journal, date: days[nextDay].at))
                events.append(days[nextDay].draws.sorted { $0.key < $1.key }.map(Self.event))
                nextDay += 1
            }
        }
        var clock = Date.distantPast
        for (i, moment) in moments.enumerated() {
            let date = max(Self.hatchedAt(of: moment.entry, after: moment.previous) ?? clock, clock)
            clock = date
            addDays(before: date)
            steps.append(Step(kind: .hatch(i), date: date == .distantPast ? nil : date))
            events.append(hatches[i].events)
        }
        addDays(before: nil)

        let standings = LuckScore.run(events, players: players)
        var previous = 50.0
        for (s, standing) in standings.enumerated() {
            steps[s].score = standing.overall * 100
            steps[s].percentiles = standing.criteria
            if case .hatch(let i) = steps[s].kind {
                hatches[i].score = steps[s].score
                hatches[i].effect = steps[s].score - previous
                hatches[i].percentiles = standing.criteria
            }
            previous = steps[s].score
        }
        let final = standings.last ?? LuckScore.Standing()
        self.steps = steps
        self.hatches = hatches
        families = final.families
        criteria = Self.results(hatches: hatches, draws: draws, standing: final, sinceLast: true)

        let cutoff = now.addingTimeInterval(-Self.recentDays * 86_400)
        let recentSteps = steps.indices.filter { (steps[$0].date ?? .distantPast) >= cutoff }
        if recentSteps.isEmpty {
            recent = nil
        } else {
            let standing = LuckScore.final(recentSteps.map { events[$0] }, players: players)
            let recentHatches = recentSteps.compactMap { s -> Hatch? in
                if case .hatch(let i) = steps[s].kind { return hatches[i] } else { return nil }
            }
            let recentDraws = draws.filter { $0.at >= cutoff }
            recent = Period(score: standing.overall * 100, families: standing.families,
                            criteria: Self.results(hatches: recentHatches, draws: recentDraws, standing: standing,
                                                   sinceLast: false),
                            hatchCount: recentHatches.count, journalDays: Set(recentDraws.map(\.day)).count)
        }
        highlights = Self.luckiest(hatches: hatches, draws: draws)

        let dated = entries.compactMap(\.caughtAt).sorted()
        if dated.count >= 2, let first = dated.first, dated.last!.timeIntervalSince(first) >= 86_400 {
            hatchesPerWeek = Double(dated.count) / (now.timeIntervalSince(first) / (7 * 86_400))
        } else {
            hatchesPerWeek = nil
        }
    }

    /// Out of 100, all time.
    var score: Double { steps.last?.score ?? 50 }

    /// All time, as a span.
    var period: Period {
        Period(score: score, families: families, criteria: criteria, hatchCount: hatches.count,
               journalDays: steps.filter { $0.kind == .journal }.count)
    }

    var strongest: CriterionResult? { period.strongest }
    var weakest: CriterionResult? { period.weakest }

    /// A day's line of the journal, as the score weighs it.
    private static func event(_ draw: LuckDraw) -> LuckEvent {
        LuckEvent(shape: .draws(draw.kind.criterion, odds: draw.odds, trials: draw.trials, hits: draw.hits), seed: draw.seed)
    }

    /// Each criterion some draw could move, its hits against the expected, at `standing`'s percentile.
    private static func results(hatches: [Hatch], draws: [LuckDraw], standing: LuckScore.Standing,
                                sinceLast: Bool) -> [CriterionResult] {
        Criterion.allCases.compactMap { criterion -> CriterionResult? in
            guard let percentile = standing.criteria[criterion] else { return nil }
            func last(_ hit: (Hatch) -> Bool) -> Int? {
                guard sinceLast, let i = hatches.lastIndex(where: hit) else { return nil }
                return hatches.count - 1 - i
            }
            switch criterion {
            case .rarity:
                let tiers = [Rarity.uncommon, .rare, .legendary].map { rarity in
                    let judged = hatches.compactMap { $0.tiers[rarity] }
                    return TierCount(rarity: rarity, hits: judged.filter(\.hit).count, expected: judged.reduce(0) { $0 + $1.odds })
                }
                return CriterionResult(criterion: criterion, hits: tiers[0].hits, expected: tiers[0].expected,
                                       percentile: percentile, sinceLast: last { $0.tiers[.rare]?.hit == true }, tiers: tiers)
            case .shiny, .new, .ditto:
                let judged = hatches.compactMap { $0.judged[criterion] }
                return CriterionResult(criterion: criterion, hits: judged.filter(\.hit).count,
                                       expected: judged.reduce(0) { $0 + $1.odds }, percentile: percentile,
                                       sinceLast: last { $0.judged[criterion]?.hit == true })
            case .ivs:
                let totals = hatches.compactMap(\.ivTotal)
                return CriterionResult(criterion: criterion, hits: totals.count, expected: Double(totals.count),
                                       percentile: percentile, sinceLast: nil,
                                       averageIVs: totals.isEmpty ? nil : Double(totals.reduce(0, +)) / Double(totals.count))
            case .hiddenAbility:
                let judged = hatches.compactMap(\.hiddenAbility)
                return CriterionResult(criterion: criterion, hits: judged.filter { $0 }.count,
                                       expected: Double(judged.count) / Double(PokemonProfile.hiddenAbilityOneIn),
                                       percentile: percentile, sinceLast: last { $0.hiddenAbility == true })
            case .capture, .dungeonShiny, .find:
                let lines = draws.filter { $0.kind.criterion == criterion }
                return CriterionResult(criterion: criterion, hits: lines.reduce(0) { $0 + $1.hits },
                                       expected: lines.reduce(0) { $0 + Double($1.trials) * $1.odds },
                                       percentile: percentile, sinceLast: nil)
            }
        }
    }

    /// The luckiest draws, five at most, the least likely first: a hatch's shiny, rarity, Ditto, hidden ability or IVs
    /// in the top 1%, and the journal's hits of one in ten or rarer.
    private static func luckiest(hatches: [Hatch], draws: [LuckDraw]) -> [Highlight] {
        var found: [Highlight] = []
        for (i, hatch) in hatches.enumerated() {
            let date = hatch.entry.raising?.hatchedAt ?? hatch.entry.caughtAt
            func add(_ criterion: Criterion, _ odds: Double, rarity: Rarity? = nil) {
                found.append(Highlight(criterion: criterion, odds: odds, date: date, hatch: i, draw: nil, rarity: rarity))
            }
            if let shiny = hatch.judged[.shiny], shiny.hit { add(.shiny, shiny.odds) }
            if let ditto = hatch.judged[.ditto], ditto.hit { add(.ditto, ditto.odds) }
            if let top = [Rarity.legendary, .rare].first(where: { hatch.tiers[$0]?.hit == true }), let tier = hatch.tiers[top] {
                add(.rarity, tier.odds, rarity: top)
            }
            if hatch.hiddenAbility == true { add(.hiddenAbility, 1 / Double(PokemonProfile.hiddenAbilityOneIn)) }
            if let total = hatch.ivTotal {
                let odds = 1 - (total > 0 ? LuckScale.ivTotal.cumulative[total - 1] : 0)
                if odds <= 0.01 { add(.ivs, odds) }
            }
        }
        for draw in draws where draw.hits > 0 && draw.odds <= 0.1 {
            found.append(Highlight(criterion: draw.kind.criterion, odds: draw.odds, date: draw.at, hatch: nil, draw: draw.kind,
                                   rarity: nil))
        }
        return Array(found.sorted { $0.odds < $1.odds }.prefix(5))
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
        /// Of that rarity or better.
        var atLeast: [Rarity: Double] = [:]
        var line = 0.0
        var new = 0.0
        var ditto = 0.0
        var shiny = 0.0
        var total = 0.0
        /// The egg's outcomes as the score draws them, rarity, something new and Ditto together: none counted apart.
        var cells: [Cell: Double] = [:]
    }

    /// One outcome of an egg for the score: a rarity's rank (`Rarity.sortRank`), new or not, a Ditto.
    struct Cell: Hashable, Sendable {
        var rank: Int
        var new: Bool
        var ditto: Bool
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
            for floor in [Rarity.uncommon, .rare, .legendary] where outcome.rarity.sortRank >= floor.sortRank {
                odds.atLeast[floor, default: 0] += w
            }
            if outcome.id == base { odds.line += w }
            let isNew = bringsNew(outcome.id, outcome.form)
            if isNew { odds.new += w }
            odds.shiny += w * (outcome.alwaysShiny ? 1 : shiny)
            let stages = PokemonEvolutionData.stageCount(from: outcome.id)
            var ditto = 0.0
            if outcome.rarity == .common, stages >= 2,
               hatch.letsDittoHide(baseID: outcome.id, egg: spec, fromFossilEgg: egg == .fossil) {
                ditto = w / Double(PokemonOdds.dittoDisguiseDenominator)
                odds.ditto += ditto
                // A Ditto brings what the Pokémon it hides in would: something new or not, as `odds.new` counts it.
                odds.cells[Cell(rank: 0, new: isNew, ditto: true), default: 0] += ditto
            }
            odds.cells[Cell(rank: outcome.rarity.sortRank, new: isNew, ditto: false), default: 0] += w - ditto
        }
        guard odds.total > 0 else { return odds }
        for key in odds.share.keys { odds.share[key]! /= odds.total }
        for key in odds.atLeast.keys { odds.atLeast[key]! /= odds.total }
        for key in odds.cells.keys { odds.cells[key]! /= odds.total }
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
        case .dungeon(let baseID, _, _): return base == baseID
        case .costume(_, let speciesID): return base == SpeciesInfo.baseID(of: speciesID)
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
                              index: [BaseSpecies], rarities: [Int: Rarity], hiddenAbilities: [Int: Bool]) -> Hatch {
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
        var judged: [Criterion: Judgement] = [:], tiers: [Rarity: Judgement] = [:]
        var events: [LuckEvent] = []
        func seed(_ part: String) -> UInt64 {
            var hash: UInt64 = 0xcbf2_9ce4_8422_2325
            for byte in "luck:\(entry.id):\(part)".utf8 { hash = (hash ^ UInt64(byte)) &* 0x100_0000_01b3 }
            return hash
        }
        if known != nil, let o = all.first {
            for floor in [Rarity.uncommon, .rare, .legendary] {
                tiers[floor] = Judgement(odds: o.atLeast[floor] ?? 0, hit: !isDitto && rarity.sortRank >= floor.sortRank)
            }
            judged[.shiny] = Judgement(odds: o.shiny, hit: entry.isShiny)
            let couldShowADitto = isDitto || entry.chainOrder.count >= 2 || !(entry.isReleased || isActive)
            if couldShowADitto { judged[.ditto] = Judgement(odds: o.ditto, hit: isDitto) }
            let newKnown = !isDitto && !isFormMystery
            if newKnown { judged[.new] = Judgement(odds: o.new, hit: new) }
            if let pick = Self.pick(o.cells, observed: Cell(rank: isDitto ? 0 : rarity.sortRank, new: new, ditto: isDitto),
                                    newKnown: newKnown, dittoKnown: couldShowADitto) {
                events.append(LuckEvent(shape: pick, seed: seed("egg")))
            }
        } else {
            judged[.shiny] = Judgement(odds: hatch.shinyChance, hit: entry.isShiny)
        }
        judged = judged.filter { $0.value.odds < 1 }
        tiers = tiers.filter { $0.value.odds < 1 }
        if let shiny = judged[.shiny] {
            events.append(LuckEvent(shape: .draws(.shiny, odds: shiny.odds, trials: 1, hits: shiny.hit ? 1 : 0),
                                    seed: seed("shiny")))
        }
        // The IVs as the hatch drew them (`PokemonProfile.generate`): a Capsule since changes nothing.
        let ivTotal = entry.profile.map { profile -> Int in
            let ivs = PokemonProfile.generate(seed: profile.seed).ivs
            return ivs.hp + ivs.attack + ivs.defense + ivs.specialAttack + ivs.specialDefense + ivs.speed
        }
        if let ivTotal {
            events.append(LuckEvent(shape: .scale(.ivs, LuckScale.ivTotal, observed: ivTotal), seed: seed("ivs")))
        }
        // The hidden ability, once drawn, for a line that has one (as far as its details are known).
        let hiddenAbility: Bool? = entry.profile.flatMap { profile in
            guard profile.abilitySlot != nil, hiddenAbilities[entry.baseID] ?? true else { return nil }
            return profile.abilityIsHidden
        }
        if let hiddenAbility {
            events.append(LuckEvent(shape: .draws(.hiddenAbility, odds: 1 / Double(PokemonProfile.hiddenAbilityOneIn),
                                                  trials: 1, hits: hiddenAbility ? 1 : 0), seed: seed("ability")))
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
                     lineOdds: known == nil ? nil : all.first.map { isDitto ? $0.ditto : $0.line }, judged: judged,
                     tiers: tiers, ivTotal: ivTotal, hiddenAbility: hiddenAbility, events: events)
    }

    /// An egg's outcomes for the score, each worth its points (`LuckScore.points`): the rarity's of doing at least as
    /// well, something new's and Ditto's of their odds. What is not known of the hatch (its form still hidden, a Ditto
    /// it could not show) is merged away, for the player as for the simulated ones. Nil when the replay cannot have
    /// drawn what hatched: no luck to read in a draw the replay misses.
    static func pick(_ cells: [Cell: Double], observed: Cell, newKnown: Bool, dittoKnown: Bool) -> LuckEvent.Shape? {
        func reduced(_ cell: Cell) -> Cell {
            let ditto = dittoKnown && cell.ditto
            return Cell(rank: ditto ? 0 : cell.rank, new: newKnown && cell.new, ditto: ditto)
        }
        var merged: [Cell: Double] = [:]
        for (cell, odds) in cells where odds > 0 { merged[reduced(cell), default: 0] += odds }
        let seen = reduced(observed)
        guard (merged[seen] ?? 0) > 0 else { return nil }
        let atLeast = { (rank: Int) in merged.filter { $0.key.rank >= rank }.values.reduce(0, +) }
        let newOdds = merged.filter(\.key.new).values.reduce(0, +)
        let dittoOdds = merged.filter(\.key.ditto).values.reduce(0, +)
        let order = merged.keys.sorted {
            ($0.rank, $0.new ? 1 : 0, $0.ditto ? 1 : 0) < ($1.rank, $1.new ? 1 : 0, $1.ditto ? 1 : 0)
        }
        let outcomes = order.map { cell -> LuckOutcome in
            var points: [Criterion: Int] = [:]
            if cell.rank > 0 { points[.rarity] = LuckScore.points(atLeast(cell.rank)) }
            if cell.new { points[.new] = LuckScore.points(newOdds) }
            if cell.ditto { points[.ditto] = LuckScore.points(dittoOdds) }
            return LuckOutcome(odds: merged[cell] ?? 0, points: points.filter { $0.value > 0 })
        }
        return .pick(outcomes, observed: order.firstIndex(of: seen)!)
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
}
