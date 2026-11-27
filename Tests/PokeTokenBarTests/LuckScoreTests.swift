import XCTest
@testable import PokeTokenBar

/// The Luck score (`LuckScore`, the owner's scoping of 2026-11-25): players with exactly the same draws, each drawn
/// again at its odds, and the share of them who got fewer points, ties counted half.
final class LuckScoreTests: XCTestCase {
    private func draws(_ criterion: LuckCriterion, _ odds: Double, trials: Int = 1, hits: Int, seed: UInt64 = 1) -> LuckEvent {
        LuckEvent(shape: .draws(criterion, odds: odds, trials: trials, hits: hits), seed: seed)
    }

    /// A rarer outcome is worth more: its surprise, in thousandths of a nat; a sure one nothing.
    func testPointsAreTheSurprise() {
        XCTAssertEqual(LuckScore.points(1), 0)
        XCTAssertEqual(LuckScore.points(0.5), 693)
        XCTAssertEqual(LuckScore.points(1.0 / 64), 4159)
        XCTAssertLessThan(LuckScore.points(1.0 / 48), LuckScore.points(1.0 / 64), "the Shiny Charm's shiny is worth less")
    }

    /// One draw: a hit at 10% beats the nine players in ten who missed and ties with the one who hit.
    func testOneDrawStandsWhereItsOddsPutIt() {
        XCTAssertEqual(LuckScore.final([[draws(.shiny, 0.1, hits: 1)]]).criteria[.shiny] ?? 0, 0.95, accuracy: 0.01)
        XCTAssertEqual(LuckScore.final([[draws(.shiny, 0.1, hits: 0)]]).criteria[.shiny] ?? 0, 0.45, accuracy: 0.01)
        XCTAssertEqual(LuckScore.final([[draws(.shiny, 0.5, trials: 2, hits: 1)]]).criteria[.shiny] ?? 0, 0.5, accuracy: 0.015)
        XCTAssertEqual(LuckScore.final([[draws(.shiny, 0.5, trials: 2, hits: 2)]]).criteria[.shiny] ?? 0, 0.875, accuracy: 0.015)
    }

    /// A sure draw moves nothing, and no criterion shows before a draw that could move it.
    func testASureDrawMovesNothing() {
        let standing = LuckScore.final([[draws(.capture, 1, hits: 1)]])
        XCTAssertTrue(standing.criteria.isEmpty)
        XCTAssertTrue(standing.families.isEmpty)
        XCTAssertEqual(standing.overall, 0.5)
    }

    /// A criterion feeds its family and the overall score, never the other family.
    func testACriterionFeedsItsFamily() {
        let standing = LuckScore.final([[draws(.find, 0.01, hits: 1)]])
        XCTAssertEqual(standing.families[.dungeons] ?? 0, 0.995, accuracy: 0.005)
        XCTAssertNil(standing.families[.hatches])
        XCTAssertEqual(standing.overall, standing.families[.dungeons] ?? 0, accuracy: 1e-12)
    }

    /// One egg's outcomes come together: its rarity and its novelty from one draw, never apart.
    func testAPickIsDrawnInOnePiece() {
        // A legendary that is new, or a common that is not: whoever gets one gets both of its criteria.
        let outcomes = [LuckOutcome(odds: 0.9, points: [:]),
                        LuckOutcome(odds: 0.1, points: [.rarity: LuckScore.points(0.1), .new: LuckScore.points(0.1)])]
        let hit = LuckScore.final([[LuckEvent(shape: .pick(outcomes, observed: 1), seed: 3)]])
        XCTAssertEqual(hit.criteria[.rarity] ?? 0, 0.95, accuracy: 0.01)
        XCTAssertEqual(hit.criteria[.new] ?? 0, 0.95, accuracy: 0.01)
        XCTAssertEqual(hit.overall, 0.95, accuracy: 0.01, "one draw, not two: as rare as itself, no rarer")
    }

    /// The IVs' total: 32⁶ ways from 0 to 186, 93 on average; 0 is worth nothing, 186 the rarest.
    func testTheIVsScale() {
        let scale = LuckScale.ivTotal
        XCTAssertEqual(scale.cumulative.count, 187)
        XCTAssertEqual(scale.cumulative.last ?? 0, 1, accuracy: 1e-12)
        var mean = 0.0, below = 0.0
        for (total, upTo) in scale.cumulative.enumerated() {
            mean += Double(total) * (upTo - below)
            below = upTo
        }
        XCTAssertEqual(mean, 93, accuracy: 1e-6)
        XCTAssertEqual(scale.points[0], 0)
        XCTAssertEqual(scale.points[186], LuckScore.points(pow(1.0 / 32, 6)))
        XCTAssertEqual(scale.outcome(0), 0)
        XCTAssertEqual(scale.outcome(0.999_999_999_999), 186)
        XCTAssertEqual(LuckScore.final([[LuckEvent(shape: .scale(.ivs, scale, observed: 93), seed: 5)]]).criteria[.ivs] ?? 0,
                       0.5, accuracy: 0.02)
    }

    /// The same draws give the same score, and a later draw never changes the standing before it.
    func testTheScoreIsStable() {
        let steps = [[draws(.shiny, 0.02, hits: 1, seed: 11)], [draws(.capture, 0.3, trials: 4, hits: 1, seed: 12)]]
        XCTAssertEqual(LuckScore.run(steps), LuckScore.run(steps))
        let longer = LuckScore.run(steps + [[draws(.find, 0.04, trials: 10, hits: 2, seed: 13)]])
        XCTAssertEqual(Array(longer.prefix(2)), LuckScore.run(steps))
    }

    /// The proof the score is a true percentile: players who draw at the very odds get scores spread evenly, a tenth
    /// of them under 10 and a tenth over 90, overall and by criterion.
    func testTheScoreIsCalibrated() {
        var rng = SeededRNG(seed: 2026)
        func unit() -> Double { Double.random(in: 0..<1, using: &rng) }
        let players = 300
        var overall: [Double] = [], byCriterion: [LuckCriterion: [Double]] = [:]
        for _ in 0..<players {
            var steps: [[LuckEvent]] = []
            for s in 0..<12 {
                // An egg: common, uncommon, rare, legendary, some of them new.
                let shares = [0.7, 0.18, 0.1, 0.02]
                let atLeast = (0..<4).map { r in shares[r...].reduce(0, +) }
                let outcomes = (0..<4).flatMap { r in
                    [false, true].map { new -> LuckOutcome in
                        var points: [LuckCriterion: Int] = [:]
                        if r > 0 { points[.rarity] = LuckScore.points(atLeast[r]) }
                        if new { points[.new] = LuckScore.points(0.3) }
                        return LuckOutcome(odds: shares[r] * (new ? 0.3 : 0.7), points: points)
                    }
                }
                var u = unit(), observed = 0
                for (k, outcome) in outcomes.enumerated() {
                    u -= outcome.odds
                    if u < 0 { observed = k; break }
                    observed = k
                }
                let base = UInt64(s * 10)
                let ivs = LuckScale.ivTotal.outcome(unit())
                let throwsHit = (0..<3).filter { _ in unit() < 0.45 }.count
                let meetings = (0..<20).filter { _ in unit() < 0.01 }.count
                steps.append([
                    LuckEvent(shape: .pick(outcomes, observed: observed), seed: base + 1),
                    LuckEvent(shape: .draws(.shiny, odds: 1.0 / 64, trials: 1, hits: unit() < 1.0 / 64 ? 1 : 0), seed: base + 2),
                    LuckEvent(shape: .scale(.ivs, LuckScale.ivTotal, observed: ivs), seed: base + 3),
                    LuckEvent(shape: .draws(.capture, odds: 0.45, trials: 3, hits: throwsHit), seed: base + 4),
                    LuckEvent(shape: .draws(.dungeonShiny, odds: 0.01, trials: 20, hits: meetings), seed: base + 5),
                ])
            }
            let standing = LuckScore.final(steps, players: 2_000)
            overall.append(standing.overall)
            for (criterion, share) in standing.criteria { byCriterion[criterion, default: []].append(share) }
        }
        func check(_ shares: [Double], _ label: String, tails: Double? = nil) {
            let n = Double(shares.count)
            XCTAssertEqual(shares.reduce(0, +) / n, 0.5, accuracy: 0.05, label)
            guard let tails else { return }
            XCTAssertEqual(Double(shares.filter { $0 < 0.1 }.count) / n, 0.1, accuracy: tails, "\(label) under 10")
            XCTAssertEqual(Double(shares.filter { $0 > 0.9 }.count) / n, 0.1, accuracy: tails, "\(label) over 90")
        }
        // The overall score, of sixty draws, nearly continuous: its tails are tenths.
        check(overall, "overall", tails: 0.05)
        // A criterion's few outcomes tie (three throws hit 0 to 3 times): its share centres on a half, its tails fall
        // in steps that cannot be tenths (measured 2026-11-27: three throws, one in five players "under 10").
        for criterion in [LuckCriterion.rarity, .ivs, .capture, .shiny, .dungeonShiny] {
            check(byCriterion[criterion] ?? [], "\(criterion)")
        }
    }
}
