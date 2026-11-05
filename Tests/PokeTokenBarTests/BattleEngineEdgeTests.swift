import XCTest
@testable import PokeTokenBar

/// The engine's edge cases the review of 2026-11-04 found, each played from the situation that triggers it.
final class BattleEngineEdgeTests: XCTestCase {
    private func mon(_ id: String, _ species: Int, level: Int = 100, moves: [String], ability: String? = nil,
                     isBoss: Bool = false) throws -> BattlerSpec {
        try XCTUnwrap(BattlerSpec.make(id: id, speciesID: species, level: level, ability: ability, moves: moves, isBoss: isBoss))
    }

    private func battle(_ mine: [BattlerSpec], _ theirs: [BattlerSpec], active: Int = 1, theirActive: Int = 1,
                        seed: UInt64 = 1) -> BattleOutcome {
        BattleEngine.run(BattleSetup(sides: [BattleSideSpec(battlers: mine, active: active),
                                             BattleSideSpec(battlers: theirs, active: theirActive)], seed: seed))
    }

    private func times(_ outcome: BattleOutcome, _ match: (BattleEvent) -> Bool) -> [Int] {
        outcome.events.filter { match($0.event) }.map(\.time)
    }

    private func casts(_ outcome: BattleOutcome, _ battler: String, _ move: String? = nil) -> [Int] {
        times(outcome) { if case .cast(battler, let m, _, _) = $0 { return move == nil || m == move } else { return false } }
    }

    private func hitsBy(_ outcome: BattleOutcome, _ attacker: String, _ move: String? = nil) -> [Int] {
        times(outcome) {
            if case .hit(attacker, _, let m, _, _, _, _) = $0 { return move == nil || m == move } else { return false }
        }
    }

    /// Cured of its sleep by an ally's Heal Bell, a Pokémon acts again: it stood idle for the rest of the battle, its
    /// cast cleared by the sleep and never started again.
    func testACuredSleeperActsAgain() throws {
        // Insomnia keeps the healer awake while Spore puts its ally to sleep.
        let outcome = battle([try mon("lax", 143, moves: ["body-slam"]),
                              try mon("chansey", 113, moves: ["heal-bell", "seismic-toss"], ability: "insomnia")],
                             [try mon("loom", 286, moves: ["spore"], isBoss: true)], active: 2)
        // A cure at the very end of an ally's Heal Bell, not a wake.
        let bells = outcome.events.compactMap { timed -> (String, Int)? in
            if case .cast(let who, "heal-bell", _, let ends) = timed.event { return (who, ends) } else { return nil }
        }
        let cure = outcome.events.first { timed in
            guard case .cure(let who, .sleep) = timed.event else { return false }
            return bells.contains { $0.0 != who && $0.1 == timed.time }
        }
        let cured = try XCTUnwrap(cure, "a Heal Bell cures a sleeper")
        guard case .cure(let who, _) = cured.event else { return XCTFail() }
        XCTAssertTrue(casts(outcome, who).contains { $0 >= cured.time }, "\(who) casts again once cured")
    }

    /// Two casts ending at the same moment: the first one's Fake Out flinches the other, which then waits instead of
    /// acting in the same step.
    func testAFlinchInTheSameStepHolds() throws {
        let outcome = battle([try mon("a", 52, moves: ["fake-out", "scratch"])], [try mon("b", 52, moves: ["fake-out", "scratch"])])
        let first = try XCTUnwrap(hitsBy(outcome, "a", "fake-out").first)
        XCTAssertFalse(hitsBy(outcome, "b").contains(first), "the flinched one does not act at the same instant")
    }

    /// Disabled while Outrage locks it, a Pokémon goes on with its loop: it struggled for the rest of the battle.
    func testALockItMayNotKeepEnds() throws {
        let outcome = battle([try mon("dnite", 149, moves: ["outrage", "dragon-claw"])],
                             [try mon("zam", 227, moves: ["disable"], isBoss: true)])
        XCTAssertFalse(casts(outcome, "zam", "disable").isEmpty, "Disable")
        // Its loop goes on with Dragon Claw; a Struggle could only start once the foe is down, with no one to hit.
        XCTAssertTrue(hitsBy(outcome, "dnite", "struggle").isEmpty, "no Struggle while another move is free")
        XCTAssertFalse(hitsBy(outcome, "dnite", "dragon-claw").isEmpty)
    }

    /// Shedinja has 1 HP: Substitute and Belly Drum cost nothing of it, so they fail; Curse costs it its HP.
    func testShedinjaPaysForWhatCostsHP() throws {
        let free = battle([try mon("shed", 292, moves: ["substitute", "belly-drum", "shadow-sneak"])],
                          [try mon("lax", 143, moves: ["splash"], isBoss: true)])
        XCTAssertTrue(times(free) { if case .substitute("shed", _) = $0 { return true } else { return false } }.isEmpty)
        XCTAssertTrue(casts(free, "shed", "substitute").isEmpty && casts(free, "shed", "belly-drum").isEmpty,
                      "not even cast for nothing")
        XCTAssertTrue(times(free) { if case .stat("shed", .attack, let change) = $0 { return change > 0 } else { return false } }.isEmpty)
        let cursed = battle([try mon("shed", 292, moves: ["curse"]), try mon("lax2", 143, moves: ["splash"])],
                            [try mon("lax", 143, moves: ["splash"], isBoss: true)])
        XCTAssertFalse(times(cursed) { $0 == .faint(battler: "shed") }.isEmpty, "Curse takes its only HP")
    }

    /// Under Trick Room a slow Pokémon's Dig still leaves it in reach for part of its cast: it hid for all of it.
    func testDigStaysInReachUnderTrickRoom() throws {
        // Shuckle is slower than Slowpoke, so it sets Trick Room; Slowpoke's Dig then lasts as a fast one's.
        let outcome = battle([try mon("shuckle", 79, moves: ["dig"])],
                             [try mon("zam", 213, moves: ["trick-room", "psychic"], isBoss: true)])
        let room = try XCTUnwrap(times(outcome) { $0 == .fieldCondition(condition: "trick-room", active: true) }.first)
        let over = times(outcome) { $0 == .fieldCondition(condition: "trick-room", active: false) }.first { $0 > room } ?? Int.max
        // The Digs cast under Trick Room: a Psychic lands during one of them.
        let digs = outcome.events.compactMap { timed -> (start: Int, ends: Int)? in
            guard case .cast("shuckle", "dig", _, let ends) = timed.event, timed.time >= room, ends < over else { return nil }
            return (timed.time, ends)
        }
        XCTAssertFalse(digs.isEmpty)
        XCTAssertTrue(hitsBy(outcome, "zam", "psychic").contains { hit in digs.contains { hit > $0.start && hit < $0.ends } },
                      "Psychic lands on a Dig under way")
    }

    /// Revival Blessing brings back the first to fall while the one that took its place, fallen too, still holds it:
    /// the revived one waited on the bench for good.
    func testRevivalBlessingFillsAPlaceHeldByTheFallen() throws {
        var played = false
        for seed in UInt64(1)...60 {
            // a enters first (level 5), c takes its place once it falls.
            // Shuckle's long Dig keeps it busy: its Revival Blessing comes once the place held by the fallen got no one.
            let outcome = battle([try mon("shuckle", 213, moves: ["dig", "revival-blessing"]), try mon("a", 16, level: 5, moves: ["tackle"]),
                                  try mon("c", 19, level: 2, moves: ["tackle"])],
                                 [try mon("jolt", 135, moves: ["discharge"], isBoss: true)], active: 2, seed: seed)
            func first(_ match: (BattleEvent) -> Bool) -> Int? { times(outcome, match).first }
            guard let aFell = first({ $0 == .faint(battler: "a") }), let cFell = first({ $0 == .faint(battler: "c") }),
                  let cEntry = outcome.events.last(where: { if case .enter(0, _, "c") = $0.event { return true } else { return false } }),
                  case .enter(_, let place, _) = cEntry.event, case let cCame = cEntry.time,
                  aFell < cCame, cCame <= cFell,
                  let revived = first({ if case .heal("a", _, _, .move) = $0 { return true } else { return false } }),
                  revived > cFell + BattleRules.benchDelay
            else { continue }
            played = true
            // It takes the place c held, not one freed later by another fall.
            XCTAssertTrue(times(outcome) { $0 == .enter(side: 0, slot: place, battler: "a") }.contains { $0 > revived },
                          "seed \(seed): the revived one comes into the place c held")
            break
        }
        XCTAssertTrue(played, "no battle revived the first to fall while the second held its place")
    }

    /// Falling asleep by a Rest it stole with Snatch while casting Tackle, a Pokémon's Tackle does not land: it struck in
    /// its sleep.
    func testRestStolenBySnatchStopsTheCast() throws {
        var played = false
        for seed in UInt64(1)...80 {
            let outcome = battle([try mon("thief", 359, moves: ["snatch", "tackle", "tackle"])],
                                 [try mon("lax", 143, moves: ["rest", "body-slam"], isBoss: true)], seed: seed)
            guard let slept = times(outcome, { $0 == .status(battler: "thief", ailment: .sleep) }).first else { continue }
            let ongoing = outcome.events.last { timed in
                if case .cast("thief", _, _, _) = timed.event { return timed.time < slept } else { return false }
            }
            guard case .cast(_, "tackle", _, let ends)? = ongoing?.event, ends > slept else { continue }
            played = true
            let woke = times(outcome) { $0 == .cure(battler: "thief", ailment: .sleep) }.first { $0 > slept } ?? Int.max
            XCTAssertFalse(hitsBy(outcome, "thief").contains { $0 > slept && $0 < woke }, "seed \(seed): nothing while asleep")
            break
        }
        XCTAssertTrue(played, "no battle had the thief steal Rest mid-Tackle")
    }
}
