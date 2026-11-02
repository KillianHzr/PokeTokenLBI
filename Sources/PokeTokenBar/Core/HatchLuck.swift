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

    /// A criterion's verdict on one hatch: the odds it had, and whether it came.
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
        /// The record's egg, the player's choice, or a Pokémon Egg after a graduation; nil when unknown.
        let egg: HatchEgg?
        let eggChosenByPlayer: Bool
        /// The eggs that could have brought it, for a hatch whose egg the record does not name after a release.
        let possibleEggs: [HatchEgg]
        /// The odds of the rarity it hatched in, of a Ditto for one.
        let rarityOdds: OddsRange
        /// Whether it brought something new (`HatchDraw.bringsNew`), and the odds of that outcome; nil for a Ditto.
        let bringsNew: Bool
        let newOdds: OddsRange?
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

    /// `entries`: the Pokédex in hatch order, the Pokémon raised last when `includesActive`. `today`: what the save does
    /// not date, the Plates' achievements, taken as they are. `itemsSince`: when the player says they got each draw
    /// item, for hatches without a record.
    init(entries: [DexEntry], includesActive: Bool, today: CompanionState, index: [BaseSpecies],
         itemsSince: [ItemKind: Date] = [:], now: Date) {
        let rarities = Dictionary(index.map { ($0.id, $0.rarity) }, uniquingKeysWith: { a, _ in a })
        var collection = today
        collection.active = nil
        collection.dex = []
        collection.collectedFinals = []
        var hatches: [Hatch] = []
        for (i, entry) in entries.enumerated() {
            let previous = i > 0 ? entries[i - 1] : nil
            // A history from before the app kept a line from hatching twice in a row.
            collection.lastHatchedBaseID = previous.map(\.baseID) == entry.baseID ? nil : previous?.baseID
            let record = entry.hatch
            let egg = record?.egg ?? (previous?.isReleased == true ? nil : .tier(nil))
            let rollItems: Set<ItemKind>, hatchItems: Set<ItemKind>
            if let record, !record.chosenByPlayer {
                (rollItems, hatchItems) = (record.rollItems, record.hatchItems)
            } else {
                let started = previous?.caughtAt
                let owned = Set(itemsSince.filter { since in started.map { since.value <= $0 } ?? false }.keys)
                (rollItems, hatchItems) = (owned, owned)
            }
            let previousEgg = hatches.last?.egg
            hatches.append(Self.hatch(number: i + 1, entry: entry, isActive: includesActive && i == entries.count - 1,
                                      egg: egg, chosen: record?.chosenByPlayer ?? false,
                                      roll: HatchDraw(collection: collection, items: rollItems),
                                      hatch: HatchDraw(collection: collection, items: hatchItems),
                                      afterFossilEgg: previousEgg == .fossil, index: index, rarities: rarities))
            if !entry.isReleased { collection.collectedFinals.insert("\(entry.baseID):\(entry.finalID)") }
            collection.dex.append(entry)
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

    /// Every egg the Bag can hold, which a hatch whose egg is unknown may have come from.
    private static let bagEggs: [HatchEgg] = {
        var seen = Set<HatchEgg>()
        return ItemKind.allCases.compactMap(HatchEgg.init(item:)).filter { seen.insert($0).inserted }
    }()

    /// What one egg's draw gave each outcome a hatch is judged on.
    private struct EggOdds {
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
        let shiny = hatch.alwaysShiny ? 1 : 1 / Double(hatch.shinyDenominator)
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

    /// Whether `egg`'s draw can hold `base`, before its odds are worked out.
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
                && (spec.event?.admits(species, companionLine: roll.collection.companionLineID) ?? true)
        }
    }

    private static func hatch(number: Int, entry: DexEntry, isActive: Bool, egg: HatchEgg?, chosen: Bool,
                              roll: HatchDraw, hatch: HatchDraw, afterFossilEgg: Bool, index: [BaseSpecies],
                              rarities: [Int: Rarity]) -> Hatch {
        let isDitto = entry.baseID == PokemonOdds.dittoSpeciesID
        let rarity = rarities[entry.baseID] ?? entry.rarity
        let bringsNew = roll.bringsNew()
        let new = !isDitto && bringsNew(entry.baseID, entry.form)
        // An unknown egg: those whose pool holds the line, a Ditto only from an egg it can hide in.
        let candidates = egg.map { [$0] } ?? bagEggs.filter { candidate in
            !(afterFossilEgg && candidate == .fossil) && (isDitto || mayHold(candidate, base: entry.baseID, roll: roll, index: index))
        }
        let measured = candidates.map {
            ($0, odds(of: $0, base: entry.baseID, roll: roll, hatch: hatch, index: index, bringsNew: bringsNew))
        }.filter { egg != nil || (isDitto ? $0.1.ditto > 0 : $0.1.line > 0) }
        let eggs = measured.map(\.0)
        let all = measured.map(\.1)
        func range(_ value: (EggOdds) -> Double) -> OddsRange {
            let values = all.map(value)
            return OddsRange(low: values.min() ?? 0, high: values.max() ?? 0)
        }
        let rarityOdds = range { isDitto ? $0.ditto : $0.share[rarity] ?? 0 }
        var judged: [Criterion: Judgement] = [:]
        let shiny = hatch.alwaysShiny ? 1 : 1 / Double(hatch.shinyDenominator)
        if egg != nil, let o = all.first {
            for (criterion, r) in [(Criterion.uncommon, Rarity.uncommon), (.rare, .rare), (.legendary, .legendary)] {
                judged[criterion] = Judgement(odds: o.share[r] ?? 0, hit: !isDitto && rarity == r)
            }
            judged[.shiny] = Judgement(odds: o.shiny, hit: entry.isShiny)
            judged[.ditto] = Judgement(odds: o.ditto, hit: isDitto)
            if !isDitto { judged[.new] = Judgement(odds: o.new, hit: new) }
        } else {
            judged[.shiny] = Judgement(odds: shiny, hit: entry.isShiny)
        }
        return Hatch(number: number, entry: entry, isActive: isActive, isDitto: isDitto, egg: egg, eggChosenByPlayer: chosen,
                     possibleEggs: egg == nil ? eggs : [], rarityOdds: rarityOdds, bringsNew: new,
                     newOdds: isDitto ? nil : range { new ? $0.new : 1 - $0.new },
                     lineOdds: egg == nil ? nil : all.first.map { isDitto ? $0.ditto : $0.line }, judged: judged)
    }

    /// The three draws least likely, from eggs known.
    var improbable: [Hatch] {
        Array(hatches.filter { ($0.lineOdds ?? 0) > 0 }.sorted { $0.lineOdds! < $1.lineOdds! }.prefix(3))
    }

    /// The Luck score: the criteria's mean percentile, out of 100.
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
