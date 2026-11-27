import Foundation

/// The families the Luck screen sorts its criteria in (the owner's scoping of 2026-11-25).
enum LuckFamily: String, CaseIterable, Sendable {
    case hatches, dungeons
}

/// What the Luck screen judges: the hatches' from the Pokédex replayed (`HatchLuck`), the others from the luck journal
/// (`LuckDraw`).
enum LuckCriterion: String, CaseIterable, Sendable, Codable {
    /// One graded note, a legendary above a rare above an uncommon: counted once (it counted three times before).
    case rarity
    case shiny
    /// A species or a form missing from the Pokédex.
    case new
    case ditto
    /// The six IVs' total, as the hatch drew them.
    case ivs
    case hiddenAbility
    /// Each throw at a boss, and at a shiny met on a floor (the owner: one throw at a time, each at its ball's odds).
    case capture
    /// A boss shiny, a shiny met on a floor.
    case dungeonShiny
    /// A secret boss, a secret passage, a chest's egg, a victory's extras, a leader's chest, a Technical Capsule, a
    /// Wishing Piece, the Explorer Kit's treasures and the Shock Drive (the owner, 2026-11-25: "dans Donjons").
    case find

    var family: LuckFamily {
        switch self {
        case .capture, .dungeonShiny, .find: .dungeons
        case .rarity, .shiny, .new, .ditto, .ivs, .hiddenAbility: .hatches
        }
    }
}

/// One way a draw can go, worth points for some criteria: the rarer, the more (`LuckScore.points`).
struct LuckOutcome: Sendable, Equatable {
    var odds: Double
    var points: [LuckCriterion: Int]
}

/// A graded draw's outcomes, worst first, each worth the surprise of doing at least as well: the IVs' total.
struct LuckScale: Sendable, Equatable {
    /// The odds of each outcome or a worse one.
    let cumulative: [Double]
    /// Each outcome's points: `LuckScore.points` of doing at least as well.
    let points: [Int]
    /// The variance of the points one draw gives.
    let variance: Double
    /// For each of `buckets` slices of 0..<1, the first outcome a draw in it can give: a draw then looks a step or two
    /// ahead rather than through every outcome (the IVs are drawn ten thousand times a hatch).
    private let firstInBucket: [Int]
    private static let buckets = 1024

    init(odds: [Double]) {
        let total = odds.reduce(0, +)
        var cumulative: [Double] = [], points: [Int] = []
        var below = 0.0, mean = 0.0, square = 0.0
        for share in odds.map({ total > 0 ? $0 / total : 0 }) {
            let value = LuckScore.points(1 - below)
            points.append(value)
            mean += share * Double(value)
            square += share * Double(value) * Double(value)
            below += share
            cumulative.append(below)
        }
        self.cumulative = cumulative
        self.points = points
        variance = max(0, square - mean * mean)
        var first: [Int] = [], k = 0
        for b in 0..<Self.buckets {
            let start = Double(b) / Double(Self.buckets)
            while k < cumulative.count - 1, cumulative[k] <= start { k += 1 }
            first.append(k)
        }
        firstInBucket = first
    }

    /// The outcome a uniform `u` in 0..<1 draws: the first whose cumulative odds pass it.
    func outcome(_ u: Double) -> Int {
        var k = firstInBucket[min(Self.buckets - 1, max(0, Int(u * Double(Self.buckets))))]
        while k < cumulative.count - 1, u >= cumulative[k] { k += 1 }
        return k
    }

    /// The six IVs' total, 0 to 186, each IV drawn evenly from 0 to 31 (`PokemonProfile.generate`).
    static let ivTotal: LuckScale = {
        var ways = [1.0]
        for _ in 0..<6 {
            var next = [Double](repeating: 0, count: ways.count + 31)
            for (total, count) in ways.enumerated() {
                for iv in 0...31 { next[total + iv] += count }
            }
            ways = next
        }
        return LuckScale(odds: ways)
    }()
}

/// One draw the Luck screen weighs, or several alike, with the seed its simulated players draw it with.
struct LuckEvent: Sendable {
    enum Shape: Sendable {
        /// One draw among its outcomes: an egg's rarity, something new and Ditto come together, never counted apart.
        case pick([LuckOutcome], observed: Int)
        /// `trials` draws of `odds` each, `hits` of them hit, each hit worth `LuckScore.points(odds)`.
        case draws(LuckCriterion, odds: Double, trials: Int, hits: Int)
        /// A graded draw (`LuckScale`), `observed` its outcome.
        case scale(LuckCriterion, LuckScale, observed: Int)
    }

    var shape: Shape
    /// Its own: the players draw it the same way whatever comes before or after, so the score only moves with a draw.
    var seed: UInt64

    /// The criteria it can give points to.
    var criteria: Set<LuckCriterion> {
        switch shape {
        case .pick(let outcomes, _): Set(outcomes.flatMap { $0.points.filter { $0.value > 0 }.keys })
        case .draws(let criterion, let odds, let trials, _): trials > 0 && LuckScore.points(odds) > 0 ? [criterion] : []
        case .scale(let criterion, let scale, _): scale.points.contains { $0 > 0 } ? [criterion] : []
        }
    }

    /// The variance of the points it gives each criterion it can move, at its own odds.
    var variances: [LuckCriterion: Double] {
        switch shape {
        case .pick(let outcomes, _):
            let total = outcomes.reduce(0) { $0 + max(0, $1.odds) }
            guard total > 0 else { return [:] }
            var result: [LuckCriterion: Double] = [:]
            for criterion in criteria {
                var mean = 0.0, square = 0.0
                for outcome in outcomes {
                    let share = max(0, outcome.odds) / total, value = Double(outcome.points[criterion] ?? 0)
                    mean += share * value
                    square += share * value * value
                }
                result[criterion] = max(0, square - mean * mean)
            }
            return result
        case .draws(let criterion, let odds, let trials, _):
            let value = Double(LuckScore.points(odds))
            return [criterion: Double(trials) * odds * (1 - odds) * value * value]
        case .scale(let criterion, let scale, _):
            return [criterion: scale.variance]
        }
    }

    /// The points it gave.
    var observedPoints: [LuckCriterion: Int] {
        switch shape {
        case .pick(let outcomes, let observed): outcomes.indices.contains(observed) ? outcomes[observed].points : [:]
        case .draws(let criterion, let odds, _, let hits): [criterion: hits * LuckScore.points(odds)]
        case .scale(let criterion, let scale, let observed): [criterion: scale.points[min(max(0, observed), scale.points.count - 1)]]
        }
    }
}

/// The score: as many players as `players` make exactly the player's draws, each drawn again at its own odds, and the
/// score is the share of them who did worse, ties counted half. Seventy-two means luckier than 72% of players with
/// those very draws. Within a criterion a draw is worth its surprise (`points`), the rarer the more. A family and the
/// overall score weigh their criteria alike, each by the spread its draws can give (measured on the owner's save of
/// 2026-11-27: by points alone, a hatch's IVs outweighed everything else, the dungeons next to nothing).
enum LuckScore {
    static let players = 10_000

    /// The points of an outcome of `odds`: its surprise, in thousandths of a nat. A sure one is worth nothing.
    static func points(_ odds: Double) -> Int {
        guard odds < 1 else { return 0 }
        return Int((-log(max(odds, 1e-12)) * 1000).rounded())
    }

    /// Where the player stands, out of 1: overall, by family and by criterion, only those some draw could move.
    struct Standing: Sendable, Equatable {
        var overall = 0.5
        var families: [LuckFamily: Double] = [:]
        var criteria: [LuckCriterion: Double] = [:]
    }

    /// Each criterion's weight in its family and overall: one over the spread of its points over all `events`, so
    /// that each weighs alike; none for a criterion no draw can move.
    static func weights(_ events: [LuckEvent]) -> [LuckCriterion: Double] {
        var variance: [LuckCriterion: Double] = [:]
        for event in events {
            for (criterion, v) in event.variances { variance[criterion, default: 0] += v }
        }
        return variance.compactMapValues { $0 > 0 ? 1 / $0.squareRoot() : nil }
    }

    /// The standing after each step (a hatch, a day of dungeons), its events drawn for every player. The overall score
    /// is measured after every step (each hatch's effect on it); the criteria and families every `steps / detail`
    /// steps and at the last, enough for their curves.
    static func run(_ steps: [[LuckEvent]], players: Int = players, detail: Int = 300) -> [Standing] {
        var simulation = Simulation(players: players, weights: weights(steps.flatMap { $0 }))
        var standing = Standing()
        var pending = Set<LuckCriterion>()
        let every = max(1, steps.count / max(1, detail))
        return steps.enumerated().map { s, events in
            var touched = false
            for event in events {
                let moved = simulation.add(event)
                pending.formUnion(moved)
                touched = touched || !moved.isEmpty
            }
            if touched { standing.overall = simulation.percentile(.overall) }
            if !pending.isEmpty, s % every == 0 || s == steps.count - 1 {
                for criterion in pending { standing.criteria[criterion] = simulation.percentile(.criterion(criterion)) }
                for family in Set(pending.map(\.family)) { standing.families[family] = simulation.percentile(.family(family)) }
                pending = []
            }
            return standing
        }
    }

    /// The standing once every step is drawn.
    static func final(_ steps: [[LuckEvent]], players: Int = players) -> Standing {
        run([steps.flatMap { $0 }], players: players).last ?? Standing()
    }

    /// Every player's points so far, by criterion, and by family and overall at the criteria's weights, and the
    /// player's own.
    private struct Simulation {
        enum Slot {
            case criterion(LuckCriterion), family(LuckFamily), overall

            var index: Int {
                switch self {
                case .criterion(let c): LuckCriterion.allCases.firstIndex(of: c)!
                case .family(let f): LuckCriterion.allCases.count + LuckFamily.allCases.firstIndex(of: f)!
                case .overall: LuckCriterion.allCases.count + LuckFamily.allCases.count
                }
            }
            static let count = LuckCriterion.allCases.count + LuckFamily.allCases.count + 1
        }

        let players: Int
        /// Each criterion's weight, a whole number so that a family's sum ties exactly where its points do.
        let weights: [Int]
        var totals: [Int]
        var mine = [Int](repeating: 0, count: Slot.count)

        init(players: Int, weights: [LuckCriterion: Double]) {
            self.players = max(1, players)
            self.weights = LuckCriterion.allCases.map { weights[$0].map { max(1, Int(($0 * 1_000_000).rounded())) } ?? 0 }
            totals = [Int](repeating: 0, count: Slot.count * self.players)
        }

        /// Where `points` of `criterion` go: its own slot plainly, its family's and the overall at its weight.
        private func gains(_ criterion: LuckCriterion, _ points: Int) -> [(slot: Int, points: Int)] {
            let c = Slot.criterion(criterion).index, weighted = points * weights[c]
            return [(c, points), (Slot.family(criterion.family).index, weighted), (Slot.overall.index, weighted)]
        }

        /// Draws `event` for every player and adds the player's own points; the criteria it may have moved.
        mutating func add(_ event: LuckEvent) -> Set<LuckCriterion> {
            let criteria = event.criteria
            guard !criteria.isEmpty else { return [] }
            for (criterion, points) in event.observedPoints where points != 0 {
                for gain in gains(criterion, points) { mine[gain.slot] += gain.points }
            }
            var random = BattleRandom(seed: event.seed)
            let n = players
            switch event.shape {
            case .pick(let outcomes, _):
                // Each outcome's gains, one flat list cut by outcome (an array of arrays costs a retain a player),
                // and the cumulative odds to draw it from.
                let total = outcomes.reduce(0) { $0 + max(0, $1.odds) }
                guard total > 0 else { return criteria }
                var slots: [Int] = [], points: [Int] = [], starts = [0]
                var cumulative: [Double] = [], running = 0.0
                for outcome in outcomes {
                    running += max(0, outcome.odds) / total
                    cumulative.append(running)
                    for (criterion, value) in outcome.points where value != 0 {
                        for gain in gains(criterion, value) {
                            slots.append(gain.slot)
                            points.append(gain.points)
                        }
                    }
                    starts.append(slots.count)
                }
                // Most eggs give most players nothing: those who get something are reached by their gaps.
                let worth = outcomes.indices.filter { starts[$0 + 1] > starts[$0] }
                let worthOdds = worth.reduce(0) { $0 + max(0, outcomes[$1].odds) } / total
                var within: [Double] = [], inner = 0.0
                for k in worth {
                    inner += max(0, outcomes[k].odds) / total / max(worthOdds, 1e-300)
                    within.append(inner)
                }
                totals.withUnsafeMutableBufferPointer { totals in
                    slots.withUnsafeBufferPointer { slots in
                        points.withUnsafeBufferPointer { points in
                            func give(_ k: Int, _ player: Int) {
                                for g in starts[k]..<starts[k + 1] { totals[slots[g] * n + player] += points[g] }
                            }
                            if worthOdds < 0.3 {
                                Self.forEachHit(of: worthOdds, among: n, &random) { player, random in
                                    let u = Self.unit(&random)
                                    var k = 0
                                    while k < within.count - 1, u >= within[k] { k += 1 }
                                    give(worth[k], player)
                                }
                            } else {
                                for player in 0..<n {
                                    let u = Self.unit(&random)
                                    var k = 0
                                    while k < cumulative.count - 1, u >= cumulative[k] { k += 1 }
                                    give(k, player)
                                }
                            }
                        }
                    }
                }
            case .draws(let criterion, let odds, let trials, _) where trials == 1 && odds < 0.3:
                // One rare draw (a shiny, a hidden ability): only the players who hit it, reached by their gaps.
                let slots = gains(criterion, LuckScore.points(odds))
                totals.withUnsafeMutableBufferPointer { totals in
                    Self.forEachHit(of: odds, among: n, &random) { player, _ in
                        for gain in slots { totals[gain.slot * n + player] += gain.points }
                    }
                }
            case .draws(let criterion, let odds, let trials, _):
                let slots = gains(criterion, LuckScore.points(odds))
                let table = Self.binomial(trials: trials, odds: odds)
                totals.withUnsafeMutableBufferPointer { totals in
                    for player in 0..<n {
                        let hits: Int
                        if let table {
                            let u = Self.unit(&random)
                            var k = 0
                            while k < table.count - 1, u >= table[k] { k += 1 }
                            hits = k
                        } else {
                            hits = (0..<trials).reduce(0) { count, _ in count + (Self.unit(&random) < odds ? 1 : 0) }
                        }
                        guard hits > 0 else { continue }
                        for gain in slots { totals[gain.slot * n + player] += hits * gain.points }
                    }
                }
            case .scale(let criterion, let scale, _):
                let c = Slot.criterion(criterion).index, weight = weights[c]
                let family = Slot.family(criterion.family).index, overall = Slot.overall.index
                totals.withUnsafeMutableBufferPointer { totals in
                    for player in 0..<n {
                        let points = scale.points[scale.outcome(Self.unit(&random))]
                        guard points != 0 else { continue }
                        totals[c * n + player] += points
                        totals[family * n + player] += points * weight
                        totals[overall * n + player] += points * weight
                    }
                }
            }
            return criteria
        }

        /// The share of players below the player in `slot`, ties counted half.
        func percentile(_ slot: Slot) -> Double {
            let index = slot.index, own = mine[index], n = players
            var below = 0, equal = 0
            totals.withUnsafeBufferPointer { totals in
                for player in 0..<n {
                    let total = totals[index * n + player]
                    if total < own { below += 1 } else if total == own { equal += 1 }
                }
            }
            return (Double(below) + Double(equal) / 2) / Double(n)
        }

        /// Each of `n` players who hits a draw of `odds`, in order: the gap to the next one drawn from its geometric law,
        /// as likely as drawing every player in turn.
        private static func forEachHit(of odds: Double, among n: Int, _ random: inout BattleRandom,
                                       _ hit: (Int, inout BattleRandom) -> Void) {
            guard odds > 0 else { return }
            let miss = log(1 - min(odds, 1 - 1e-12))
            var player = -1
            while true {
                let gap = Int((log(1 - unit(&random)) / miss).rounded(.down))
                guard gap < n - player - 1 else { return }
                player += gap + 1
                hit(player, &random)
            }
        }

        /// A uniform number in 0..<1.
        private static func unit(_ random: inout BattleRandom) -> Double {
            Double(random.next() >> 11) * 0x1p-53
        }

        /// The cumulative odds of 0, 1, 2… hits in `trials` draws of `odds`, cut where what is left is negligible; nil
        /// when the first term underflows, the draws then made one by one.
        private static func binomial(trials: Int, odds: Double) -> [Double]? {
            // No hit possible; a sure draw is worth no points and never comes here (`LuckEvent.criteria`).
            guard trials > 0, odds > 0, odds < 1 else { return [1] }
            var term = pow(1 - odds, Double(trials))
            guard term > 1e-300 else { return nil }
            var cumulative = [term]
            let ratio = odds / (1 - odds)
            var k = 0
            while k < trials, cumulative[k] < 1 - 1e-12 {
                term *= Double(trials - k) / Double(k + 1) * ratio
                k += 1
                cumulative.append(cumulative[k - 1] + term)
            }
            cumulative[cumulative.count - 1] = 1
            return cumulative
        }
    }
}
