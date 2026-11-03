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

    // MARK: Moves that use another

    private func calls(_ outcome: BattleOutcome, _ battler: String) -> [(time: Int, move: String)] {
        outcome.events.compactMap { timed in
            guard case .call(let who, let move) = timed.event, who == battler else { return nil }
            return (timed.time, move)
        }
    }

    /// Metronome uses a move at random among those it may call, never a Z or Max Move, a protection or a caller.
    func testMetronomeUsesARandomMove() throws {
        XCTAssertTrue(BattleSimulation.metronomePool.allSatisfy { BattleSimulation.canBeCalled($0) })
        XCTAssertFalse(BattleSimulation.metronomePool.contains { MoveTable.move($0)?.isZOrMax ?? true })
        XCTAssertFalse(BattleSimulation.metronomePool.contains("protect"))
        XCTAssertFalse(BattleSimulation.metronomePool.contains("metronome"))
        XCTAssertGreaterThan(BattleSimulation.metronomePool.count, 700)
        var called = Set<String>()
        for seed: UInt64 in 1...4 {
            let outcome = battle([try mon("clef", 36, moves: ["metronome"])], [try mon("lax", 143, moves: ["growl"])],
                                 seed: seed)
            called.formUnion(calls(outcome, "clef").map(\.move))
            XCTAssertTrue(calls(outcome, "clef").allSatisfy { BattleSimulation.metronomePool.contains($0.move) })
        }
        XCTAssertGreaterThan(called.count, 10)
    }

    /// Assist uses a move of another Pokémon of its side, the bench's too (the foes' side keeps its order: Persian
    /// first, Charizard on the bench).
    func testAssistUsesAMoveOfItsSide() throws {
        let outcome = battle([try mon("lax", 143, moves: ["growl"])],
                             [try mon("cat", 53, moves: ["assist"]), try mon("bench", 6, moves: ["flamethrower"])])
        let used = calls(outcome, "cat")
        XCTAssertFalse(used.isEmpty)
        XCTAssertTrue(used.allSatisfy { $0.move == "flamethrower" })
        XCTAssertTrue(hits(outcome).contains { $0.attacker == "cat" && $0.move == "flamethrower" })
    }

    /// Asleep, a Pokémon with Sleep Talk keeps casting it, each time using one of its other moves; awake, it skips it.
    /// Snore likewise only while asleep.
    func testSleepTalkAndSnoreWorkOnlyAsleep() throws {
        let outcome = battle([try mon("lax", 143, moves: ["sleep-talk", "snore", "body-slam"])],
                             [try mon("shroom", 286, moves: ["spore", "growl"])], seed: 2)
        var asleep = false
        var spoke = 0, snored = 0
        for timed in outcome.events {
            switch timed.event {
            case .status("lax", .sleep): asleep = true
            case .cure("lax", .sleep): asleep = false
            case .cast("lax", let move, _, _):
                if move == "sleep-talk" || move == "snore" { XCTAssertTrue(asleep, "\(move) at \(timed.time)") }
            case .call("lax", let move):
                XCTAssertTrue(asleep)
                XCTAssertTrue(["snore", "body-slam"].contains(move))
                spoke += 1
            case .hit("lax", _, "snore", _, _, _, _):
                snored += 1
            default:
                break
            }
        }
        XCTAssertGreaterThan(spoke, 0)
        XCTAssertGreaterThan(snored, 0)
    }

    /// Copycat uses the last move anyone used; Mirror Move its target's. Copycat is skipped until a move it may use was
    /// used, Growl filling in.
    func testCopycatAndMirrorMoveCopyTheLastMove() throws {
        let copy = battle([try mon("cat", 53, moves: ["copycat", "growl"])],
                          [try mon("zard", 6, level: 50, moves: ["flamethrower"])])
        XCTAssertTrue(calls(copy, "cat").contains { $0.move == "flamethrower" })
        XCTAssertTrue(hits(copy).contains { $0.attacker == "cat" && $0.move == "flamethrower" })
        let mirror = battle([try mon("bird", 18, moves: ["mirror-move", "growl"])],
                            [try mon("zard", 6, level: 50, moves: ["flamethrower"])])
        XCTAssertTrue(calls(mirror, "bird").contains { $0.move == "flamethrower" })
        // Moves of the user's own stats are not moves Mirror Move copies.
        let dance = battle([try mon("bird", 18, moves: ["mirror-move", "growl"])],
                           [try mon("scizor", 212, moves: ["swords-dance", "agility", "calm-mind", "bulk-up"])])
        XCTAssertTrue(calls(dance, "bird").isEmpty)
    }

    /// Me First takes the damaging move its target is casting, at one and a half times its power.
    func testMeFirstTakesTheTargetsMove() throws {
        let outcome = battle([try mon("jolt", 135, moves: ["me-first"])], [try mon("lax", 143, moves: ["hyper-voice"])])
        let used = calls(outcome, "jolt")
        XCTAssertFalse(used.isEmpty)
        XCTAssertTrue(used.allSatisfy { $0.move == "hyper-voice" })
        // A status move is not taken.
        let growl = battle([try mon("jolt", 135, moves: ["me-first", "tackle"])], [try mon("lax", 143, moves: ["growl"])])
        XCTAssertTrue(calls(growl, "jolt").isEmpty)
    }

    /// Nature Power is Tri Attack without a terrain, Thunderbolt on Electric Terrain.
    func testNaturePowerFollowsTheTerrain() throws {
        let plain = battle([try mon("lax", 143, moves: ["nature-power"])], [try mon("lapras", 131, moves: ["growl"])])
        XCTAssertEqual(calls(plain, "lax").first?.move, "tri-attack")
        let electric = battle([try mon("lax", 143, moves: ["nature-power"])],
                              [try mon("koko", 785, moves: ["growl"], ability: "electric-surge")])
        XCTAssertEqual(calls(electric, "lax").first?.move, "thunderbolt")
    }

    /// Transform copies the target's types, stats but HP, ability and loop; a boss's raised stats stay its own, the
    /// copy casting at its species' speed.
    func testTransformCopiesTheTarget() throws {
        let zard = try mon("zard", 6, moves: ["flamethrower", "air-slash"])
        let ditto = try mon("ditto", 132, moves: ["transform"])
        let outcome = battle([ditto], [zard])
        XCTAssertTrue(outcome.events.contains { $0.event == .transform(battler: "ditto", into: "zard") })
        XCTAssertTrue(hits(outcome).contains { $0.attacker == "ditto" && $0.move == "flamethrower" })
        let frame = BattleFrame.at(outcome.duration, setup: outcome.setup, events: outcome.events)
        XCTAssertEqual(frame.units.first { $0.id == "ditto" }?.speciesID, 6, "the replay shows a Charizard")
        // Against a boss whose stats are doubled, the copy's casts last by Charizard's own speed.
        var boss = try XCTUnwrap(BattlerSpec.make(id: "boss", speciesID: 6, level: 100, moves: ["growl"], isBoss: true,
                                                  hpFactor: 4, statFactor: 2))
        boss.hp = boss.stats.hp
        let onBoss = battle([ditto], [boss])
        let species = try XCTUnwrap(SpeciesBattleTable.data(speciesID: 6))
        let speed = BattleStats.computed(base: species.baseStats, ivs: Array(repeating: 31, count: 6), level: 100,
                                         nature: nil, speciesID: 6).speed
        let cast = try XCTUnwrap(onBoss.events.first {
            if case .cast("ditto", "growl", _, _) = $0.event { return true }
            return false
        })
        guard case .cast(_, _, _, let ends) = cast.event else { return XCTFail() }
        XCTAssertEqual(ends - cast.time, Int((1200.0 * 300 / Double(100 + speed) / 3).rounded()))
    }

    /// Imposter transforms its Pokémon into the foe in front as it enters.
    func testImposterTransformsOnEntry() throws {
        let outcome = battle([try mon("ditto", 132, moves: ["transform"], ability: "imposter")],
                             [try mon("zard", 6, moves: ["flamethrower"])])
        let transform = try XCTUnwrap(outcome.events.first { $0.event == .transform(battler: "ditto", into: "zard") })
        XCTAssertEqual(transform.time, 0)
    }

    /// Mimic and Sketch put the target's last move in place of themselves for the rest of the battle.
    func testMimicAndSketchLearnTheTargetsLastMove() throws {
        for copier in ["mimic", "sketch"] {
            let outcome = battle([try mon("smeargle", 235, moves: [copier, "tackle"])],
                                 [try mon("zard", 6, level: 50, moves: ["flamethrower"])])
            XCTAssertTrue(outcome.events.contains { $0.event == .learn(battler: "smeargle", move: "flamethrower") }, copier)
            XCTAssertTrue(hits(outcome).contains { $0.attacker == "smeargle" && $0.move == "flamethrower" }, copier)
        }
    }

    /// Instruct makes the ally beside repeat its last move at once.
    func testInstructMakesTheAllyRepeat() throws {
        let outcome = battle([try mon("oranguru", 765, moves: ["instruct"]), try mon("zard", 6, moves: ["flamethrower"])],
                             [try mon("lax", 143, moves: ["growl"]), try mon("lapras", 131, moves: ["growl"])], active: 2)
        let repeats = calls(outcome, "zard")
        XCTAssertFalse(repeats.isEmpty)
        for repeated in repeats {
            XCTAssertTrue(hits(outcome).contains { $0.attacker == "zard" && $0.time == repeated.time })
        }
    }

    // MARK: Any move

    /// Loops of any moves at random, every move but the Z and Max ones: each battle ends, no HP below zero.
    func testLoopsOfAnyMovesAlwaysEndCleanly() throws {
        var random = BattleRandom(seed: 2027)
        let moves = MoveTable.all.keys.filter { !(MoveTable.move($0)?.isZOrMax ?? true) }.sorted()
        let ids = SpeciesBattleTable.all.keys.filter { $0 <= 1025 }.sorted()
        for round in 0..<400 {
            func team(_ side: String) -> [BattlerSpec] {
                (0..<(1 + random.below(4))).compactMap { i in
                    BattlerSpec.make(id: "\(side)\(i)", speciesID: ids[random.below(ids.count)], level: 50 + random.below(51),
                                     moves: (0..<4).map { _ in moves[random.below(moves.count)] },
                                     isBoss: side == "t" && random.below(4) == 0)
                }
            }
            let mine = team("m"), theirs = team("t")
            let outcome = battle(mine, theirs, active: 1 + random.below(2), seed: UInt64(round))
            XCTAssertLessThanOrEqual(outcome.duration, BattleRules.timeLimit, "round \(round)")
            XCTAssertEqual(outcome.events.map(\.time), outcome.events.map(\.time).sorted(), "round \(round)")
            for spec in mine + theirs {
                XCTAssertTrue((0...spec.stats.hp).contains(try XCTUnwrap(outcome.hpLeft[spec.id])), "round \(round)")
            }
        }
    }

    // MARK: Protections and Substitute

    private func has(_ outcome: BattleOutcome, _ event: BattleEvent) -> Bool {
        outcome.events.contains { $0.event == event }
    }

    /// Substitute costs a quarter of the HP and takes the hits until it breaks; a status move does nothing against it
    /// and is skipped, a sound move goes through.
    func testSubstituteTakesTheHits() throws {
        let lax = try mon("lax", 143, moves: ["substitute", "growl"], ability: "thick-fat")
        let outcome = battle([lax], [try mon("champ", 68, level: 60, moves: ["tackle", "toxic", "growl"])])
        let quarter = lax.stats.hp / 4
        XCTAssertTrue(has(outcome, .hurt(battler: "lax", amount: quarter, hp: lax.stats.hp - quarter, cause: .substitute)))
        XCTAssertTrue(has(outcome, .substitute(battler: "lax", hp: quarter)))
        var standing = false
        var absorbed = 0
        for timed in outcome.events {
            switch timed.event {
            case .substitute("lax", let hp):
                if hp < quarter { absorbed += 1 }
                standing = hp > 0
            case .hit(_, "lax", _, _, _, _, _):
                XCTAssertFalse(standing, "no hit reaches Snorlax behind its substitute (\(timed.time))")
            case .status("lax", _):
                XCTAssertFalse(standing, "Toxic lands nothing behind the substitute (\(timed.time))")
            case .cast("champ", "toxic", _, _):
                XCTAssertFalse(standing, "Toxic is skipped while the substitute stands (\(timed.time))")
            default:
                break
            }
        }
        XCTAssertGreaterThan(absorbed, 0)
        XCTAssertTrue(outcome.events.contains {
            if case .stat("lax", .attack, -1) = $0.event { return true }
            return false
        }, "Growl, a sound move, goes through")
    }

    /// Endure keeps its user at 1 HP for its time; protections in a row succeed a third as often each.
    func testEndureAndProtectionsInARow() throws {
        let outcome = battle([try mon("rat", 19, level: 30, moves: ["endure"])], [try mon("champ", 68, moves: ["cross-chop"])])
        XCTAssertTrue(outcome.events.contains { $0.event == .endured(battler: "rat") })
        XCTAssertGreaterThan(fails(outcome, "rat", "endure"), 0, "Endure after Endure fails two times in three")
        var protects = 0, failed = 0
        for seed: UInt64 in 1...4 {
            let alone = battle([try mon("lax", 143, moves: ["protect"])], [try mon("champ", 68, moves: ["tackle"])], seed: seed)
            failed += fails(alone, "lax", "protect")
            protects += alone.events.filter {
                if case .cast("lax", "protect", _, _) = $0.event { return true }
                return false
            }.count
        }
        XCTAssertGreaterThan(failed, protects / 2, "most Protects in a row fail")
    }

    /// King's Shield stops damage only, and lowers a contact attacker's Attack; Spiky Shield hurts it, Baneful Bunker
    /// poisons it.
    func testShieldsPunishContact() throws {
        let king = battle([try mon("aegis", 681, moves: ["kings-shield"])],
                          [try mon("champ", 68, moves: ["tackle", "leer"])])
        XCTAssertTrue(king.events.contains {
            if case .stat("champ", .attack, -1) = $0.event { return true }
            return false
        })
        XCTAssertTrue(king.events.contains {
            if case .stat("aegis", .defense, -1) = $0.event { return true }
            return false
        }, "Leer, a status move, goes through King's Shield")
        let spiky = battle([try mon("chester", 652, moves: ["spiky-shield"])], [try mon("champ", 68, moves: ["tackle"])])
        XCTAssertTrue(spiky.events.contains {
            if case .hurt("champ", _, _, .protection) = $0.event { return true }
            return false
        })
        let bunker = battle([try mon("pareint", 748, moves: ["baneful-bunker"])], [try mon("champ", 68, moves: ["tackle"])])
        XCTAssertTrue(has(bunker, .status(battler: "champ", ailment: .poison)))
    }

    /// Wide Guard stops spread moves for the side, Quick Guard priority moves, Crafty Shield status moves; Mat Block
    /// works on its user's first cast only.
    func testSideGuards() throws {
        let wide = battle([try mon("hitmon", 107, moves: ["wide-guard"]), try mon("lax", 143, moves: ["growl"])],
                          [try mon("chomp", 445, moves: ["earthquake", "dragon-claw"]), try mon("lapras", 131, moves: ["growl"])],
                          active: 2)
        XCTAssertTrue(has(wide, .fail(battler: "chomp", move: "earthquake", reason: .protected)))
        XCTAssertTrue(hits(wide).contains { $0.move == "dragon-claw" }, "a single-target move goes through")
        let quick = battle([try mon("hitmon", 107, moves: ["quick-guard"])], [try mon("rat", 20, moves: ["quick-attack"])])
        XCTAssertTrue(has(quick, .fail(battler: "rat", move: "quick-attack", reason: .protected)))
        let crafty = battle([try mon("florges", 671, moves: ["crafty-shield", "moonblast"])],
                            [try mon("gengar", 94, moves: ["toxic"])])
        XCTAssertTrue(has(crafty, .fail(battler: "gengar", move: "toxic", reason: .protected)))
        let mat = battle([try mon("greninja", 658, moves: ["mat-block", "water-shuriken"])],
                         [try mon("lax", 143, moves: ["body-slam"])])
        let mats = mat.events.filter {
            if case .cast("greninja", "mat-block", _, _) = $0.event { return true }
            return false
        }
        XCTAssertEqual(mats.map(\.time), [0], "Mat Block on the first cast, then skipped")
    }

    /// Magic Coat and Magic Bounce send a status move back; Snatch takes a move its user aims at itself.
    func testMagicCoatAndSnatch() throws {
        let coat = battle([try mon("xatu", 178, moves: ["magic-coat"])], [try mon("lax", 143, moves: ["toxic"], ability: "thick-fat")])
        XCTAssertTrue(has(coat, .reflect(battler: "xatu", move: "toxic")))
        XCTAssertTrue(has(coat, .status(battler: "lax", ailment: .badPoison)))
        let bounce = battle([try mon("espeon", 196, moves: ["psychic"], ability: "magic-bounce")],
                            [try mon("lax", 143, moves: ["growl"])])
        XCTAssertTrue(bounce.events.contains {
            if case .stat("lax", .attack, -1) = $0.event { return true }
            return false
        })
        XCTAssertFalse(bounce.events.contains {
            if case .stat("espeon", .attack, _) = $0.event { return true }
            return false
        })
        let snatch = battle([try mon("absol", 359, moves: ["snatch", "night-slash"])],
                            [try mon("scizor", 212, moves: ["swords-dance", "bullet-punch"])])
        XCTAssertTrue(has(snatch, .reflect(battler: "absol", move: "swords-dance")))
        XCTAssertTrue(snatch.events.contains {
            if case .stat("absol", .attack, 2) = $0.event { return true }
            return false
        })
    }

    /// Feint goes through Protect and lifts it.
    func testFeintGoesThroughProtect() throws {
        let outcome = battle([try mon("weavile", 461, moves: ["feint"])], [try mon("lax", 143, moves: ["protect"])])
        XCTAssertTrue(hits(outcome).contains { $0.move == "feint" })
        XCTAssertFalse(has(outcome, .fail(battler: "weavile", move: "feint", reason: .protected)))
    }
}
