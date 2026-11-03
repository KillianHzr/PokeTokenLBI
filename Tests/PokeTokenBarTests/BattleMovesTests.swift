import XCTest
@testable import PokeTokenBar

/// Every move works in battle as in the games (the owner, 2026-11-03: "il doivent tous fonctionner normalement"), one
/// game turn being four seconds, and no move ever knocks a boss out at once ("on doit jamais pouvoir one shot des
/// boss"). One mechanic per test, the boss's case beside it.
final class BattleMovesTests: XCTestCase {
    private func mon(_ id: String, _ species: Int, level: Int = 100, moves: [String]? = nil, ability: String? = nil,
                     isBoss: Bool = false, hp: Int? = nil) throws -> BattlerSpec {
        var spec = try XCTUnwrap(BattlerSpec.make(id: id, speciesID: species, level: level, ability: ability, moves: moves,
                                                  isBoss: isBoss))
        if let hp { spec.hp = hp }
        return spec
    }

    private func battle(_ mine: [BattlerSpec], _ theirs: [BattlerSpec], active: Int = 1, seed: UInt64 = 1) -> BattleOutcome {
        BattleEngine.run(BattleSetup(sides: [BattleSideSpec(battlers: mine, active: active),
                                             BattleSideSpec(battlers: theirs, active: active)], seed: seed))
    }

    private struct Hit {
        let time: Int, attacker: String, target: String, move: String, damage: Int, hp: Int
    }

    private func hits(_ outcome: BattleOutcome) -> [Hit] {
        outcome.events.compactMap { timed in
            guard case .hit(let attacker, let target, let move, let damage, let hp, _, _) = timed.event else { return nil }
            return Hit(time: timed.time, attacker: attacker, target: target, move: move, damage: damage, hp: hp)
        }
    }

    private func fails(_ outcome: BattleOutcome, _ battler: String, _ move: String) -> Int {
        outcome.events.filter { $0.event == .fail(battler: battler, move: move, reason: .failed) }.count
    }

    /// The target's HP just before a hit: its HP after, plus the damage.
    private func before(_ hit: Hit) -> Int { hit.hp + hit.damage }

    /// Each hit of `move`, with the last hit its user took before it.
    private func answers(_ all: [Hit], _ move: String) -> [(answer: Hit, taken: Hit?)] {
        all.enumerated().filter { $0.element.move == move }.map { i, answer in
            (answer, all[..<i].last { $0.target == answer.attacker })
        }
    }

    // MARK: Damage sent back

    /// Counter sends back twice the last physical hit taken within a turn (four seconds), to the foe that dealt it; it
    /// fails when there is none, as at the very start.
    func testCounterSendsBackTwiceTheLastPhysicalHit() throws {
        let outcome = battle([try mon("wobb", 202, moves: ["counter"])], [try mon("lax", 143, moves: ["body-slam"])])
        let counters = answers(hits(outcome), "counter")
        XCTAssertFalse(counters.isEmpty)
        XCTAssertGreaterThan(fails(outcome, "wobb", "counter"), 0, "the first Counter comes before any hit")
        for (counter, taken) in counters {
            let taken = try XCTUnwrap(taken)
            XCTAssertLessThanOrEqual(counter.time - taken.time, BattleRules.turn)
            XCTAssertEqual(counter.target, "lax")
            XCTAssertEqual(counter.damage, min(2 * taken.damage, before(counter)))
        }
        // Counter casts faster than Body Slam: the next Counter finds the hit answered already and fails.
        let answered = counters.compactMap { $0.taken.map { "\($0.time):\($0.damage)" } }
        XCTAssertEqual(Set(answered).count, answered.count, "each hit is answered once")
    }

    /// A hit older than a turn is not answered: Shuckle's Giga Impact lasts more than four seconds, and while its
    /// partner keeps Snorlax asleep the Counter after it finds only an old hit, and fails (at 26 s with seed 1).
    func testCounterAnswersOnlyAHitOfTheLastTurn() throws {
        let outcome = battle([try mon("shuckle", 213, moves: ["counter", "giga-impact"]),
                              try mon("gyara", 130, level: 20, moves: ["spore", "rain-dance", "sunny-day"])],
                             [try mon("lax", 143, moves: ["quick-attack"])], active: 2)
        let all = hits(outcome)
        let counters = answers(all, "counter")
        XCTAssertFalse(counters.isEmpty)
        for (counter, taken) in counters {
            XCTAssertLessThanOrEqual(counter.time - (try XCTUnwrap(taken)).time, BattleRules.turn)
        }
        let stale = outcome.events.filter { $0.event == .fail(battler: "shuckle", move: "counter", reason: .failed) }
            .filter { failure in
                let last = all.last { $0.target == "shuckle" && $0.time <= failure.time }
                return last.map { failure.time - $0.time > BattleRules.turn } ?? false
            }
        XCTAssertFalse(stale.isEmpty, "the scenario reaches a Counter after an old hit")
    }

    /// Mirror Coat answers special hits only: against a physical attacker it always fails.
    func testMirrorCoatAnswersSpecialHitsOnly() throws {
        let special = battle([try mon("wobb", 202, moves: ["mirror-coat"])], [try mon("lapras", 131, moves: ["ice-beam"])])
        let coats = answers(hits(special), "mirror-coat")
        XCTAssertFalse(coats.isEmpty)
        for (coat, taken) in coats {
            let taken = try XCTUnwrap(taken)
            XCTAssertEqual(coat.damage, min(2 * taken.damage, before(coat)))
        }
        let physical = battle([try mon("wobb", 202, moves: ["mirror-coat"])], [try mon("lax", 143, moves: ["body-slam"])])
        XCTAssertTrue(hits(physical).filter { $0.move == "mirror-coat" }.isEmpty)
        XCTAssertGreaterThan(fails(physical, "wobb", "mirror-coat"), 0)
    }

    /// Metal Burst sends back one and a half times the last hit, physical or special.
    func testMetalBurstSendsBackOneAndAHalfTimes() throws {
        let outcome = battle([try mon("steel", 306, moves: ["metal-burst"])], [try mon("lapras", 131, moves: ["ice-beam"])])
        let bursts = answers(hits(outcome), "metal-burst")
        XCTAssertFalse(bursts.isEmpty)
        for (burst, taken) in bursts {
            let taken = try XCTUnwrap(taken)
            XCTAssertEqual(burst.damage, min(Int(Double(taken.damage) * 1.5), before(burst)))
        }
    }

    /// Bide waits two turns whatever its user's speed, storing the hits it takes, then sends twice that to the foe that
    /// hit last.
    func testBideStoresTwoTurnsAndSendsBackTwice() throws {
        let outcome = battle([try mon("lax", 143, moves: ["bide"])], [try mon("champ", 68, level: 50, moves: ["tackle"])])
        var castAt: Int?
        var stored = 0
        var checked = 0
        for timed in outcome.events {
            switch timed.event {
            case .cast("lax", "bide", _, let ends):
                XCTAssertEqual(ends - timed.time, 2 * BattleRules.turn)
                castAt = timed.time
                stored = 0
            case .hit(_, "lax", _, let damage, _, _, _) where castAt != nil:
                stored += damage
            case .hit("lax", "champ", "bide", let damage, let hp, _, _):
                XCTAssertEqual(damage, min(2 * stored, hp + damage))
                checked += 1
                castAt = nil
            default:
                break
            }
        }
        XCTAssertGreaterThan(checked, 0)
    }

    /// The hits Bide sent back are answered: a Counter right after it fails unless a newer hit came. Jolteon's
    /// Counter is quicker than Blissey's Tackle, so some come with nothing new, and fail.
    func testAfterBideCounterAnswersOnlyNewerHits() throws {
        var bare = 0
        for seed: UInt64 in 1...6 {
            let outcome = battle([try mon("jolt", 135, moves: ["bide", "counter"])],
                                 [try mon("bliss", 242, moves: ["tackle"])], seed: seed)
            let all = hits(outcome)
            var bideAt: Int?
            for (i, hit) in all.enumerated() {
                if hit.move == "bide" { bideAt = i }
                guard hit.move == "counter", let bide = bideAt else { continue }
                let taken = try XCTUnwrap(all[..<i].lastIndex { $0.target == "jolt" })
                XCTAssertGreaterThan(taken, bide, "seed \(seed): the Counter answers a hit after the Bide")
            }
            bare += fails(outcome, "jolt", "counter")
        }
        XCTAssertGreaterThan(bare, 0, "some Counters after a Bide find nothing new")
    }

    /// A boss takes at most a quarter of its HP from one answered hit, however hard it hit.
    func testABossTakesAtMostAQuarterFromAnAnsweredHit() throws {
        let boss = try mon("boss", 68, moves: ["cross-chop"], isBoss: true)
        let outcome = battle([try mon("wobb", 202, moves: ["counter"])], [boss])
        let counters = hits(outcome).filter { $0.move == "counter" }
        XCTAssertFalse(counters.isEmpty)
        XCTAssertTrue(counters.allSatisfy { $0.damage <= boss.stats.hp / 4 })
        XCTAssertTrue(counters.contains { $0.damage == boss.stats.hp / 4 }, "a Cross Chop doubled is more than a quarter")
    }

    // MARK: HP set by the user's

    /// Endeavor brings the target's HP down to the user's; it fails when the user has as many; a boss loses at most an
    /// eighth.
    func testEndeavorBringsTheTargetToTheUsersHP() throws {
        let lax = try mon("lax", 143, moves: ["growl"])
        let outcome = battle([try mon("rat", 20, moves: ["endeavor"], hp: 1)], [lax])
        let first = try XCTUnwrap(hits(outcome).first { $0.move == "endeavor" })
        XCTAssertEqual(first.hp, 1)
        XCTAssertGreaterThan(fails(outcome, "rat", "endeavor"), 0, "then both stand at 1 HP")
        let boss = try mon("boss", 143, moves: ["growl"], isBoss: true)
        let onBoss = try XCTUnwrap(hits(battle([try mon("rat", 20, moves: ["endeavor"], hp: 1)], [boss]))
            .first { $0.move == "endeavor" })
        XCTAssertEqual(onBoss.damage, boss.stats.hp / 8)
    }

    /// Final Gambit deals the user's HP and knocks the user out; a boss takes at most a quarter.
    func testFinalGambitKnocksItsUserOut() throws {
        let gambler = try mon("gambler", 113, moves: ["final-gambit"])
        let outcome = battle([gambler, try mon("next", 143, moves: ["growl"])], [try mon("lax", 143, moves: ["growl"])])
        let gambit = try XCTUnwrap(hits(outcome).first { $0.move == "final-gambit" })
        XCTAssertEqual(gambit.damage, min(gambler.stats.hp, before(gambit)))
        XCTAssertTrue(outcome.events.contains { $0.event == .faint(battler: "gambler") && $0.time == gambit.time })
        let boss = try mon("boss", 143, moves: ["growl"], isBoss: true)
        let onBoss = try XCTUnwrap(hits(battle([gambler, try mon("next", 143, moves: ["growl"])], [boss]))
            .first { $0.move == "final-gambit" })
        XCTAssertEqual(onBoss.damage, boss.stats.hp / 4)
    }

    /// Pain Split shares the HP evenly; a boss loses at most an eighth of its HP to it, the user still gets the average.
    func testPainSplitSharesTheHP() throws {
        let lax = try mon("lax", 143, moves: ["growl"])
        let outcome = battle([try mon("bliss", 242, moves: ["pain-split"], hp: 10)], [lax])
        let average = (10 + lax.stats.hp) / 2
        XCTAssertTrue(outcome.events.contains {
            $0.event == .hurt(battler: "lax", amount: lax.stats.hp - average, hp: average, cause: .painSplit)
        })
        XCTAssertTrue(outcome.events.contains {
            $0.event == .heal(battler: "bliss", amount: average - 10, hp: average, cause: .painSplit)
        })
        let boss = try mon("boss", 143, moves: ["growl"], isBoss: true)
        let onBoss = battle([try mon("bliss", 242, moves: ["pain-split"], hp: 10)], [boss])
        XCTAssertTrue(onBoss.events.contains {
            $0.event == .hurt(battler: "boss", amount: boss.stats.hp / 8, hp: boss.stats.hp - boss.stats.hp / 8,
                              cause: .painSplit)
        })
        XCTAssertTrue(onBoss.events.contains {
            guard case .heal("bliss", let amount, _, .painSplit) = $0.event else { return false }
            return amount == (10 + boss.stats.hp) / 2 - 10
        })
    }
}
