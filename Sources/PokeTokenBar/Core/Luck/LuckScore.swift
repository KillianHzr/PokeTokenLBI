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

    init(odds: [Double]) {
        let total = odds.reduce(0, +)
        var cumulative: [Double] = [], points: [Int] = []
        var below = 0.0
        for share in odds.map({ total > 0 ? $0 / total : 0 }) {
            points.append(LuckScore.points(1 - below))
            below += share
            cumulative.append(below)
        }
        self.cumulative = cumulative
        self.points = points
    }

    /// The outcome a uniform `u` in 0..<1 draws.
    func outcome(_ u: Double) -> Int {
        var low = 0, high = cumulative.count - 1
        while low < high {
            let middle = (low + high) / 2
            if u < cumulative[middle] { high = middle } else { low = middle + 1 }
        }
        return low
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
/// score is the share of them who got fewer points, ties counted half. Seventy-two means luckier than 72% of players
/// with those very draws; the criteria and families are scored the same way on their own draws.
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

    /// The standing after each step (a hatch, a day of dungeons), its events drawn for every player.
    static func run(_ steps: [[LuckEvent]], players: Int = players) -> [Standing] {
        var simulation = Simulation(players: players)
        var standing = Standing()
        return steps.map { events in
            var touched = Set<LuckCriterion>()
            for event in events {
                touched.formUnion(simulation.add(event))
            }
            for criterion in touched { standing.criteria[criterion] = simulation.percentile(.criterion(criterion)) }
            for family in Set(touched.map(\.family)) { standing.families[family] = simulation.percentile(.family(family)) }
            if !touched.isEmpty { standing.overall = simulation.percentile(.overall) }
            return standing
        }
    }

    /// The standing once every step is drawn.
    static func final(_ steps: [[LuckEvent]], players: Int = players) -> Standing {
        run([steps.flatMap { $0 }], players: players).last ?? Standing()
    }

    /// Every player's points so far, by criterion, family and overall, and the player's own.
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
        var totals: [Int]
        var mine = [Int](repeating: 0, count: Slot.count)

        init(players: Int) {
            self.players = max(1, players)
            totals = [Int](repeating: 0, count: Slot.count * self.players)
        }

        /// The slots `points` of a criterion feed: its own, its family's, the overall.
        private static func slots(_ criterion: LuckCriterion) -> [Int] {
            [Slot.criterion(criterion).index, Slot.family(criterion.family).index, Slot.overall.index]
        }

        /// Draws `event` for every player and adds the player's own points; the criteria it may have moved.
        mutating func add(_ event: LuckEvent) -> Set<LuckCriterion> {
            let criteria = event.criteria
            guard !criteria.isEmpty else { return [] }
            for (criterion, points) in event.observedPoints where points != 0 {
                for slot in Self.slots(criterion) { mine[slot] += points }
            }
            var random = BattleRandom(seed: event.seed)
            let n = players
            switch event.shape {
            case .pick(let outcomes, _):
                // Each outcome's points by slot, and the cumulative odds to draw it from.
                let total = outcomes.reduce(0) { $0 + max(0, $1.odds) }
                guard total > 0 else { return criteria }
                var cumulative: [Double] = [], gains: [[(slot: Int, points: Int)]] = []
                var running = 0.0
                for outcome in outcomes {
                    running += max(0, outcome.odds) / total
                    cumulative.append(running)
                    gains.append(outcome.points.filter { $0.value != 0 }.flatMap { criterion, points in
                        Self.slots(criterion).map { (slot: $0, points: points) }
                    })
                }
                totals.withUnsafeMutableBufferPointer { totals in
                    for player in 0..<n {
                        let u = Self.unit(&random)
                        var k = 0
                        while k < cumulative.count - 1, u >= cumulative[k] { k += 1 }
                        for gain in gains[k] { totals[gain.slot * n + player] += gain.points }
                    }
                }
            case .draws(let criterion, let odds, let trials, _):
                let points = LuckScore.points(odds)
                let slots = Self.slots(criterion)
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
                        for slot in slots { totals[slot * n + player] += hits * points }
                    }
                }
            case .scale(let criterion, let scale, _):
                let slots = Self.slots(criterion)
                totals.withUnsafeMutableBufferPointer { totals in
                    for player in 0..<n {
                        let points = scale.points[scale.outcome(Self.unit(&random))]
                        guard points != 0 else { continue }
                        for slot in slots { totals[slot * n + player] += points }
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
