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

    private func battle(_ mine: [BattlerSpec], _ theirs: [BattlerSpec], active: Int = 1, seed: UInt64 = 1,
                        berries: [BattleBerry: Int] = [:], theirBerries: [BattleBerry: Int] = [:]) -> BattleOutcome {
        BattleEngine.run(BattleSetup(sides: [BattleSideSpec(battlers: mine, active: active, berries: berries),
                                             BattleSideSpec(battlers: theirs, active: active, berries: theirBerries)],
                                     seed: seed))
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

    // MARK: Sides and field

    /// When `condition` held, from its events: (start, end) pairs, the end at the battle's if it never ended.
    private func windows(_ outcome: BattleOutcome, side: Int? = nil, _ condition: String) -> [(start: Int, end: Int)] {
        var result: [(start: Int, end: Int)] = []
        var start: Int?
        for timed in outcome.events {
            let active: Bool
            switch timed.event {
            case .sideCondition(let s, let c, let on) where c == condition && (side == nil || s == side): active = on
            case .fieldCondition(let c, let on) where c == condition: active = on
            default: continue
            }
            if active, start == nil { start = timed.time }
            if !active, let begun = start {
                result.append((begun, timed.time))
                start = nil
            }
        }
        if let start { result.append((start, outcome.duration)) }
        return result
    }

    private func during(_ time: Int, _ windows: [(start: Int, end: Int)]) -> Bool {
        windows.contains { time > $0.start && time < $0.end }
    }

    /// The mean damage of `move`'s hits that were not critical nor a knock-out (that one shows the HP it took),
    /// during `windows` (or at any time).
    private func meanDamage(_ outcome: BattleOutcome, _ move: String, in windows: [(start: Int, end: Int)]? = nil) -> Double {
        let damages = outcome.events.compactMap { timed -> Int? in
            guard case .hit(_, _, let m, let damage, let hp, _, false) = timed.event, m == move, hp > 0 else { return nil }
            if let windows, !during(timed.time, windows) { return nil }
            return damage
        }
        return damages.isEmpty ? 0 : Double(damages.reduce(0, +)) / Double(damages.count)
    }

    /// Reflect halves physical damage for five turns, Light Screen special damage; Brick Break shatters them first.
    func testScreensHalveTheirDamage() throws {
        let fillers = ["rain-dance", "sunny-day"]
        for (screen, attack) in [("reflect", "strength"), ("light-screen", "hyper-voice")] {
            let foe = try mon("champ", attack == "strength" ? 68 : 131, moves: [attack])
            let shielded = battle([try mon("lax", 143, moves: [screen] + fillers)], [foe])
            let bare = battle([try mon("lax", 143, moves: fillers)], [foe])
            let held = windows(shielded, side: 0, screen)
            XCTAssertFalse(held.isEmpty, screen)
            XCTAssertTrue(held.allSatisfy { $0.end - $0.start <= 5 * BattleRules.turn }, screen)
            let ratio = meanDamage(shielded, attack, in: held) / meanDamage(bare, attack)
            XCTAssertEqual(ratio, 0.5, accuracy: 0.06, "\(screen): \(ratio)")
        }
        let broken = battle([try mon("lax", 143, moves: ["reflect"] + fillers)], [try mon("champ", 68, moves: ["brick-break"])])
        let shattered = try XCTUnwrap(broken.events.first { $0.event == .sideCondition(side: 0, condition: "reflect", active: false) })
        XCTAssertTrue(hits(broken).contains { $0.move == "brick-break" && $0.time == shattered.time })
    }

    /// Safeguard keeps statuses off the side, Mist its stats; the foes' status moves against them are skipped
    /// meanwhile, a damaging move's stat drop does not land. Toxic and Icy Wind come after the side's move.
    func testSafeguardAndMist() throws {
        let fillers = ["rain-dance", "sunny-day"]
        let safe = battle([try mon("lax", 143, moves: ["safeguard"] + fillers, ability: "thick-fat")],
                          [try mon("gengar", 94, level: 50, moves: ["shadow-ball", "toxic"])])
        let guarded = windows(safe, side: 0, "safeguard")
        XCTAssertFalse(guarded.isEmpty)
        for timed in safe.events {
            if case .status("lax", _) = timed.event { XCTAssertFalse(during(timed.time, guarded), "\(timed.time)") }
        }
        let misty = battle([try mon("lax", 143, moves: ["mist"] + fillers)], [try mon("lapras", 131, level: 50, moves: ["icy-wind"])])
        let held = windows(misty, side: 0, "mist")
        XCTAssertFalse(held.isEmpty)
        var hitDuring = false
        for timed in misty.events {
            if case .stat("lax", _, let change) = timed.event, change < 0 { XCTAssertFalse(during(timed.time, held)) }
            if case .hit(_, "lax", "icy-wind", _, _, _, _) = timed.event, during(timed.time, held) { hitDuring = true }
        }
        XCTAssertTrue(hitDuring)
        var poisonedOutside = false
        for timed in safe.events {
            if case .cast("gengar", "toxic", _, _) = timed.event, !during(timed.time, guarded) { poisonedOutside = true }
        }
        XCTAssertTrue(poisonedOutside || !guarded.isEmpty)
    }

    /// Tailwind doubles the side's speed for four turns; Lucky Chant keeps critical hits off for five. Rain Dance
    /// and Sunny Day, always one of them to cast, fill the loops: the battles go on.
    func testTailwindAndLuckyChant() throws {
        let fillers = ["rain-dance", "sunny-day"]
        let lax = try mon("lax", 143, moves: ["tailwind"] + fillers)
        let windy = battle([lax], [try mon("champ", 68, moves: fillers)])
        let blown = windows(windy, side: 0, "tailwind")
        XCTAssertEqual(blown.first.map { $0.end - $0.start }, 4 * BattleRules.turn)
        let cast = try XCTUnwrap(windy.events.first {
            if case .cast("lax", let move, _, _) = $0.event { return move != "tailwind" && during($0.time, blown) }
            return false
        })
        guard case .cast(_, _, _, let ends) = cast.event else { return XCTFail() }
        XCTAssertEqual(ends - cast.time, Int((1200.0 * 300 / Double(100 + 2 * lax.stats.speed) / 3).rounded()))
        let chant = battle([try mon("lax", 143, moves: ["lucky-chant", "rain-dance", "sunny-day"])],
                           [try mon("champ", 68, level: 30, moves: ["storm-throw"])])
        let chanted = windows(chant, side: 0, "lucky-chant")
        XCTAssertFalse(chanted.isEmpty)
        var chantedHits = 0
        for timed in chant.events {
            if case .hit(_, "lax", "storm-throw", _, _, _, let critical) = timed.event, during(timed.time, chanted) {
                XCTAssertFalse(critical)
                chantedHits += 1
            }
        }
        XCTAssertGreaterThan(chantedHits, 3, "Storm Throw, always critical elsewhere")
    }

    /// Entry hazards hurt, poison or slow the Pokémon sent in after a knock-out; a Poison type clears Toxic Spikes.
    func testEntryHazards() throws {
        let setter = try mon("setter", 227, moves: ["spikes", "stealth-rock", "sticky-web", "toxic-spikes", "toxic-spikes",
                                                     "spikes", "spikes", "brave-bird"])
        let zard = try mon("zard", 6, moves: ["growl"], ability: "blaze")
        let outcome = battle([setter], [try mon("first", 129, level: 70, moves: ["splash"]), zard, try mon("grimer", 88, moves: ["growl"])])
        XCTAssertTrue(has(outcome, .hazard(side: 1, hazard: "spikes", layers: 3)))
        XCTAssertTrue(has(outcome, .hazard(side: 1, hazard: "toxic-spikes", layers: 2)))
        // Charizard flies over Spikes and Toxic Spikes, not over Stealth Rock: four times weak, half its HP.
        XCTAssertTrue(has(outcome, .hurt(battler: "zard", amount: zard.stats.hp / 2, hp: zard.stats.hp - zard.stats.hp / 2,
                                         cause: .hazard)))
        XCTAssertFalse(has(outcome, .status(battler: "zard", ailment: .badPoison)))
        XCTAssertTrue(has(outcome, .hazard(side: 1, hazard: "toxic-spikes", layers: 0)), "Grimer clears them")
        XCTAssertFalse(has(outcome, .status(battler: "grimer", ailment: .badPoison)))
    }

    /// Trick Room turns speeds around for five turns: the slower cast quicker.
    func testTrickRoomTurnsSpeedsAround() throws {
        let fillers = ["rain-dance", "sunny-day"]
        let lax = try mon("lax", 143, moves: ["trick-room"] + fillers)
        let outcome = battle([lax], [try mon("jolt", 135, moves: fillers)])
        let room = windows(outcome, "trick-room")
        XCTAssertEqual(room.first.map { $0.end - $0.start }, 5 * BattleRules.turn)
        let cast = try XCTUnwrap(outcome.events.first {
            if case .cast("lax", let move, _, _) = $0.event { return move != "trick-room" && during($0.time, room) }
            return false
        })
        guard case .cast(_, _, _, let ends) = cast.event else { return XCTFail() }
        XCTAssertEqual(ends - cast.time, Int((1200.0 * 300 / Double(100 + 400 - lax.stats.speed) / 3).rounded()))
        let fast = battle([try mon("jolt", 135, moves: ["trick-room", "thunderbolt"])], [try mon("lax", 143, moves: ["growl"])])
        XCTAssertTrue(windows(fast, "trick-room").isEmpty, "a side faster than the foes never sets it")
    }

    /// Gravity grounds everyone and keeps the airborne moves from use; Wonder Room swaps Defense and Special Defense;
    /// Magic Room keeps berries uneaten; Haze clears the stat stages.
    func testGravityRoomsAndHaze() throws {
        let heavy = battle([try mon("chomp", 445, moves: ["gravity", "earthquake"])], [try mon("bird", 18, moves: ["bounce", "growl"])])
        let pulled = windows(heavy, "gravity")
        XCTAssertFalse(pulled.isEmpty)
        XCTAssertTrue(heavy.events.contains {
            if case .hit("chomp", "bird", "earthquake", _, _, _, _) = $0.event { return during($0.time, pulled) }
            return false
        })
        XCTAssertFalse(heavy.events.contains {
            if case .cast("bird", "bounce", _, _) = $0.event { return during($0.time, pulled) }
            return false
        })
        let fillers = ["rain-dance", "sunny-day"]
        let wonder = battle([try mon("bliss", 242, moves: ["wonder-room"] + fillers)], [try mon("champ", 68, moves: ["strength"])])
        let bare = battle([try mon("bliss", 242, moves: fillers)], [try mon("champ", 68, moves: ["strength"])])
        let swapped = windows(wonder, "wonder-room")
        XCTAssertLessThan(meanDamage(wonder, "strength", in: swapped) / meanDamage(bare, "strength"), 0.3,
                          "Blissey's Special Defense takes the physical hits")
        // Magic Room keeps the foes' berries uneaten: Snorlax sets it against Machamp's Sitrus Berries.
        let champ = try mon("champ", 68, moves: fillers)
        let magic = battle([champ], [try mon("lax", 143, moves: ["magic-room", "body-slam"])], berries: [.sitrus: 2])
        let room = windows(magic, "magic-room")
        var halfDuring = false
        for timed in magic.events {
            if case .berry = timed.event { XCTAssertFalse(during(timed.time, room), "\(timed.time)") }
            if case .hit(_, "champ", _, _, let hp, _, _) = timed.event, hp > 0, hp * 2 < champ.stats.hp,
               during(timed.time, room) { halfDuring = true }
        }
        XCTAssertTrue(halfDuring, "Machamp falls under half its HP inside the room")
        let hazy = battle([try mon("weezing", 110, moves: ["haze", "sludge-bomb"])],
                          [try mon("scizor", 212, moves: ["swords-dance", "bullet-punch"])])
        XCTAssertTrue(hazy.events.contains {
            if case .stat("scizor", .attack, let change) = $0.event { return change < 0 }
            return false
        })
    }

    /// Mud Sport divides Electric moves by three; Ion Deluge turns Normal moves Electric for a turn.
    func testSportsAndIonDeluge() throws {
        let fillers = ["rain-dance", "sunny-day"]
        let muddy = battle([try mon("lax", 143, moves: ["mud-sport"] + fillers)], [try mon("jolt", 135, moves: ["thunderbolt"])])
        let bare = battle([try mon("lax", 143, moves: fillers)], [try mon("jolt", 135, moves: ["thunderbolt"])])
        let sport = windows(muddy, "mud-sport")
        // The power falls to a third; the damage a bit less, the formula's last +2 staying whole.
        let ratio = meanDamage(muddy, "thunderbolt", in: sport) / meanDamage(bare, "thunderbolt")
        XCTAssertTrue((0.3...0.42).contains(ratio), "\(ratio)")
        let ion = battle([try mon("chomp", 445, moves: ["ion-deluge", "dragon-claw"])], [try mon("lax", 143, moves: ["tackle"])])
        let deluge = windows(ion, "ion-deluge")
        XCTAssertFalse(deluge.isEmpty)
        XCTAssertTrue(ion.events.contains {
            if case .noEffect("lax", "chomp", "tackle") = $0.event { return during($0.time, deluge) }
            return false
        }, "an Electric Tackle does nothing to Garchomp")
    }

    /// Court Change swaps the sides' hazards; Defog clears them; Rapid Spin clears its own side's.
    func testHazardsMoveAndClear() throws {
        let court = battle([try mon("cinder", 815, moves: ["court-change", "pyro-ball"]), try mon("bench", 6, moves: ["growl"])],
                           [try mon("setter", 227, moves: ["stealth-rock", "brave-bird"]), try mon("next", 130, moves: ["growl"])])
        XCTAssertTrue(has(court, .hazard(side: 0, hazard: "stealth-rock", layers: 1)))
        let swapped = court.events.firstIndex { $0.event == .hazard(side: 1, hazard: "stealth-rock", layers: 1)
            && court.events.contains { $0.event == .hazard(side: 0, hazard: "stealth-rock", layers: 1) } }
        XCTAssertNotNil(swapped)
        let fog = battle([try mon("bird", 18, moves: ["defog", "brave-bird"]), try mon("bench", 6, moves: ["growl"])],
                         [try mon("setter", 227, moves: ["stealth-rock", "drill-peck"])])
        XCTAssertTrue(has(fog, .hazard(side: 0, hazard: "stealth-rock", layers: 0)))
        let spin = battle([try mon("star", 121, moves: ["rapid-spin", "surf"]), try mon("bench", 6, moves: ["growl"])],
                          [try mon("setter", 227, moves: ["stealth-rock", "drill-peck"])])
        XCTAssertTrue(has(spin, .hazard(side: 0, hazard: "stealth-rock", layers: 0)))
    }

    /// Fairy Lock keeps Pokémon from leaving, which none does here: it plays, and nothing happens.
    func testFairyLockDoesNothingHere() throws {
        let outcome = battle([try mon("clef", 36, moves: ["fairy-lock", "moonblast"])], [try mon("lax", 143, moves: ["growl"])])
        XCTAssertTrue(has(outcome, .fail(battler: "clef", move: "fairy-lock", reason: .nothing)))
    }

    // MARK: Data the engine reads

    /// [Regression] Bulletproof never stopped a ball: the flag was read as "ballistic" where PokéAPI writes
    /// "ballistics", and the check also asked for Soundproof. Every flag the engine reads must exist in the data,
    /// "slicing" aside (PokéAPI has none yet).
    func testEveryFlagTheEngineReadsExists() throws {
        for flag in ["contact", "charge", "recharge", "sound", "punch", "bite", "pulse", "ballistics", "powder",
                     "protect", "authentic", "mirror", "reflectable", "snatch", "gravity", "heal"] {
            XCTAssertTrue(MoveTable.all.values.contains { $0.flags.contains(flag) }, flag)
        }
        XCTAssertTrue(try XCTUnwrap(MoveTable.move("shadow-ball")).isBallistic)
        let outcome = battle([try mon("gengar", 94, moves: ["shadow-ball"])],
                             [try mon("chesnaught", 652, moves: ["growl"], ability: "bulletproof")])
        XCTAssertTrue(has(outcome, .ability(battler: "chesnaught", ability: "bulletproof")))
        XCTAssertFalse(hits(outcome).contains { $0.move == "shadow-ball" })
    }

    // MARK: Restraints

    /// When `effect` first landed on `battler`.
    private func volatileAt(_ outcome: BattleOutcome, _ battler: String, _ effect: String) -> Int? {
        outcome.events.first { $0.event == .volatile(battler: battler, effect: effect) }?.time
    }

    /// The moves `battler` started casting between `start` and `end`.
    private func casts(_ outcome: BattleOutcome, _ battler: String, from start: Int, to end: Int) -> [String] {
        outcome.events.compactMap { timed in
            guard case .cast(let who, let move, _, _) = timed.event, who == battler, timed.time > start, timed.time < end
            else { return nil }
            return move
        }
    }

    /// Taunt keeps status moves off for three turns; Encore holds the target to its last move for three; Disable
    /// takes that move for four; Torment forbids the same move twice in a row.
    func testTauntEncoreDisableTorment() throws {
        let turn = BattleRules.turn
        let foe = try mon("scizor", 212, level: 60, moves: ["swords-dance", "bullet-punch", "agility"])
        let taunt = battle([try mon("lax", 143, moves: ["taunt", "rain-dance", "sunny-day"])], [foe])
        let taunted = try XCTUnwrap(volatileAt(taunt, "scizor", "taunt"))
        // Struggle only once Snorlax is down and nothing is left to aim at.
        XCTAssertEqual(Set(casts(taunt, "scizor", from: taunted, to: taunted + 3 * turn)).subtracting(["struggle"]),
                       ["bullet-punch"])
        let encore = battle([try mon("lax", 143, moves: ["encore", "rain-dance", "sunny-day"])],
                            [try mon("scizor", 212, level: 60, moves: ["bullet-punch", "x-scissor"])])
        let encored = try XCTUnwrap(volatileAt(encore, "scizor", "encore"))
        XCTAssertEqual(Set(casts(encore, "scizor", from: encored, to: encored + 3 * turn)).count, 1)
        let disable = battle([try mon("lax", 143, moves: ["disable", "rain-dance", "sunny-day"])],
                             [try mon("scizor", 212, level: 60, moves: ["bullet-punch", "x-scissor"])])
        let disabledAt = try XCTUnwrap(volatileAt(disable, "scizor", "disable"))
        let move = try XCTUnwrap(hits(disable).last { $0.attacker == "scizor" && $0.time <= disabledAt }).move
        XCTAssertFalse(casts(disable, "scizor", from: disabledAt, to: disabledAt + 4 * turn).contains(move))
        let torment = battle([try mon("lax", 143, moves: ["torment", "rain-dance", "sunny-day"])],
                             [try mon("scizor", 212, level: 60, moves: ["bullet-punch"])])
        let tormented = try XCTUnwrap(volatileAt(torment, "scizor", "torment"))
        let after = casts(torment, "scizor", from: tormented, to: tormented + 10 * turn)
        XCTAssertTrue(zip(after, after.dropFirst()).allSatisfy { $0 != $1 || $0 == "struggle" }, "\(after)")
    }

    /// Imprison keeps the foes from the moves its user knows; Heal Block keeps them from healing; Embargo from their
    /// berries.
    func testImprisonHealBlockEmbargo() throws {
        let fillers = ["rain-dance", "sunny-day"]
        let prison = battle([try mon("lax", 143, moves: ["imprison", "tackle"] + fillers)],
                            [try mon("rat", 20, moves: ["tackle", "quick-attack"])])
        let jailed = try XCTUnwrap(volatileAt(prison, "lax", "imprison"))
        XCTAssertFalse(casts(prison, "rat", from: jailed, to: prison.duration).contains("tackle"))
        // Blissey heals by Soft-Boiled and by Leech Seed: neither while blocked, and Soft-Boiled is not even cast.
        let block = battle([try mon("lax", 143, moves: ["heal-block", "rain-dance", "sunny-day"])],
                           [try mon("bliss", 242, moves: ["leech-seed", "soft-boiled", "seismic-toss"], hp: 300)])
        let blocked = try XCTUnwrap(volatileAt(block, "bliss", "heal-block"))
        let until = blocked + 5 * BattleRules.turn
        for timed in block.events where timed.time > blocked && timed.time < until {
            if case .heal("bliss", _, _, _) = timed.event { XCTFail("Blissey heals at \(timed.time)") }
        }
        XCTAssertFalse(casts(block, "bliss", from: blocked, to: until).contains("soft-boiled"))
        XCTAssertTrue(block.events.contains {
            if case .hurt("lax", _, _, .leechSeed) = $0.event { return $0.time > blocked && $0.time < until }
            return false
        }, "the seed drains on, its heal kept off")
        let champ = try mon("champ", 68, moves: fillers)
        let embargo = battle([champ], [try mon("absol", 359, moves: ["embargo", "night-slash"])], berries: [.sitrus: 1])
        let held = try XCTUnwrap(volatileAt(embargo, "champ", "embargo"))
        XCTAssertFalse(embargo.events.contains {
            if case .berry("champ", _) = $0.event { return $0.time > held && $0.time < held + 5 * BattleRules.turn }
            return false
        })
    }

    /// Perish Song knocks out everyone on the field three turns later, never a boss (the owner, 2026-11-03).
    func testPerishSongSparesABoss() throws {
        let side = [try mon("lapras", 131, moves: ["perish-song", "rain-dance", "sunny-day"]), try mon("bench", 6, moves: ["growl"])]
        let outcome = battle(side, [try mon("lax", 143, moves: ["rain-dance", "sunny-day"])])
        let sung = try XCTUnwrap(volatileAt(outcome, "lax", "perish-song"))
        XCTAssertTrue(outcome.events.contains {
            if case .hurt("lax", _, 0, .perishSong) = $0.event { return $0.time == sung + 3 * BattleRules.turn }
            return false
        })
        XCTAssertTrue(outcome.events.contains {
            if case .hurt("lapras", _, 0, .perishSong) = $0.event { return true }
            return false
        }, "its user falls too")
        let boss = battle(side, [try mon("boss", 143, moves: ["rain-dance", "sunny-day"], isBoss: true)])
        XCTAssertNil(volatileAt(boss, "boss", "perish-song"))
        XCTAssertFalse(boss.events.contains {
            if case .hurt("boss", _, _, .perishSong) = $0.event { return true }
            return false
        })
    }

    /// Curse from a Ghost costs half its HP and takes a quarter of the target's each turn, a sixteenth of a boss's;
    /// Nightmare likewise while the target sleeps. Not a Ghost, Curse trades Speed for Attack and Defense.
    func testCurseAndNightmare() throws {
        let gengar = try mon("gengar", 94, moves: ["curse", "rain-dance", "sunny-day"])
        let lax = try mon("lax", 143, moves: ["rain-dance", "sunny-day"])
        let cursed = battle([gengar], [lax])
        XCTAssertTrue(has(cursed, .hurt(battler: "gengar", amount: gengar.stats.hp / 2, hp: gengar.stats.hp - gengar.stats.hp / 2,
                                        cause: .curse)))
        XCTAssertTrue(cursed.events.contains {
            if case .hurt("lax", let amount, _, .curse) = $0.event { return amount == lax.stats.hp / 4 }
            return false
        })
        let boss = try mon("boss", 143, moves: ["rain-dance", "sunny-day"], isBoss: true)
        let onBoss = battle([gengar], [boss])
        XCTAssertTrue(onBoss.events.contains {
            if case .hurt("boss", let amount, _, .curse) = $0.event { return amount == boss.stats.hp / 16 }
            return false
        })
        XCTAssertFalse(onBoss.events.contains {
            if case .hurt("boss", let amount, _, .curse) = $0.event { return amount > boss.stats.hp / 16 }
            return false
        })
        let plain = battle([try mon("lax", 143, moves: ["curse", "body-slam"])], [try mon("champ", 68, moves: ["growl"])])
        XCTAssertTrue(plain.events.contains {
            if case .stat("lax", .defense, 1) = $0.event { return true }
            return false
        })
        let dream = battle([try mon("gengar", 94, moves: ["hypnosis", "nightmare", "rain-dance", "sunny-day"])], [lax], seed: 3)
        XCTAssertTrue(dream.events.contains {
            if case .hurt("lax", let amount, _, .nightmare) = $0.event { return amount == lax.stats.hp / 4 }
            return false
        })
    }

    /// Ingrain and Aqua Ring heal a sixteenth each turn, Ingrain grounding its user; Magnet Rise lifts it off for five
    /// turns.
    func testIngrainAquaRingMagnetRise() throws {
        let lax = try mon("lax", 143, moves: ["aqua-ring", "ingrain", "rain-dance", "sunny-day"], hp: 100)
        let outcome = battle([lax], [try mon("champ", 68, moves: ["rain-dance", "sunny-day"])])
        for cause in [BattleHealCause.ingrain, .aquaRing] {
            XCTAssertTrue(outcome.events.contains {
                if case .heal("lax", let amount, _, let c) = $0.event { return c == cause && amount == lax.stats.hp / 16 }
                return false
            }, "\(cause)")
        }
        let rooted = battle([try mon("bird", 18, moves: ["ingrain", "rain-dance", "sunny-day"])],
                            [try mon("chomp", 445, level: 40, moves: ["earthquake"])])
        let at = try XCTUnwrap(volatileAt(rooted, "bird", "ingrain"))
        XCTAssertTrue(hits(rooted).contains { $0.move == "earthquake" && $0.time > at }, "rooted, Pidgeot is on the ground")
        let risen = battle([try mon("magne", 462, moves: ["magnet-rise", "thunderbolt"])],
                           [try mon("chomp", 445, level: 60, moves: ["earthquake"])])
        let lifted = try XCTUnwrap(volatileAt(risen, "magne", "magnet-rise"))
        XCTAssertFalse(hits(risen).contains {
            $0.move == "earthquake" && $0.time > lifted && $0.time < lifted + 5 * BattleRules.turn
        })
    }

    /// Foresight lets Normal moves hit a Ghost, Miracle Eye Psychic moves a Dark type; Lock-On makes the next move
    /// sure; Tar Shot doubles Fire on its target; Octolock lowers both defenses each turn.
    func testForesightLockOnTarShotOctolock() throws {
        let fore = battle([try mon("lax", 143, moves: ["foresight", "body-slam"])], [try mon("gengar", 94, level: 50, moves: ["growl"])])
        XCTAssertNotNil(volatileAt(fore, "gengar", "foresight"))
        XCTAssertTrue(hits(fore).contains { $0.move == "body-slam" })
        let eye = battle([try mon("alakazam", 65, moves: ["miracle-eye", "psychic"])], [try mon("umbreon", 197, moves: ["growl"])])
        XCTAssertTrue(hits(eye).contains { $0.move == "psychic" })
        var sure = 0, zaps = 0
        for seed: UInt64 in 1...6 {
            let lock = battle([try mon("magne", 462, moves: ["lock-on", "zap-cannon"])], [try mon("lax", 143, moves: ["growl"])],
                              seed: seed)
            var locked = false
            for timed in lock.events {
                switch timed.event {
                case .volatile("magne", "lock-on"): locked = true
                case .hit("magne", _, "zap-cannon", _, _, _, _): if locked { sure += 1; locked = false }; zaps += 1
                case .miss("magne", _, "zap-cannon"): XCTAssertFalse(locked, "a locked Zap Cannon never misses"); locked = false
                default: break
                }
            }
        }
        XCTAssertGreaterThan(sure, 3)
        let tar = battle([try mon("coal", 839, moves: ["tar-shot", "flamethrower"])], [try mon("lax", 143, moves: ["growl"])])
        XCTAssertTrue(tar.events.contains {
            if case .hit("coal", "lax", "flamethrower", _, _, 2.0, _) = $0.event { return true }
            return false
        })
        let octo = battle([try mon("grapploct", 853, moves: ["octolock", "brutal-swing"])],
                          [try mon("lax", 143, moves: ["rain-dance", "sunny-day"])])
        XCTAssertTrue(octo.events.contains {
            if case .stat("lax", .specialDefense, -1) = $0.event { return true }
            return false
        })
    }

    /// Grudge: the move that knocks its user out is lost to the attacker for the battle. Spite, Block, Mean Look and
    /// Spider Web have nothing to take or hold here: nothing happens.
    func testGrudgeAndTheMovesWithNothingToHold() throws {
        var triggered = 0
        for seed: UInt64 in 1...8 {
            // The foes keep their order: Rattata first, Snorlax after it.
            let outcome = battle([try mon("champ", 68, level: 30, moves: ["karate-chop", "tackle"])],
                                 [try mon("rat", 19, level: 30, moves: ["grudge", "rain-dance", "sunny-day"]),
                                  try mon("bench", 143, moves: ["growl"])], seed: seed)
            guard has(outcome, .volatile(battler: "champ", effect: "grudge")),
                  let ko = outcome.events.first(where: { $0.event == .faint(battler: "rat") }) else { continue }
            triggered += 1
            let killer = try XCTUnwrap(hits(outcome).last { $0.target == "rat" && $0.time <= ko.time })
            XCTAssertFalse(casts(outcome, "champ", from: ko.time + 1, to: outcome.duration).contains(killer.move), "seed \(seed)")
        }
        XCTAssertGreaterThan(triggered, 0)
        for slug in ["spite", "block", "mean-look", "spider-web"] {
            let none = battle([try mon("lax", 143, moves: [slug, "body-slam"])], [try mon("champ", 68, moves: ["growl"])])
            XCTAssertTrue(has(none, .fail(battler: "lax", move: slug, reason: .nothing)), slug)
        }
    }

    // MARK: Swaps

    /// Psych Up copies the target's stages, Topsy-Turvy turns them around, Heart Swap trades them; Speed Swap trades
    /// the Speed stats; Power Trick swaps its user's Attack and Defense.
    func testStageAndStatSwaps() throws {
        let fillers = ["rain-dance", "sunny-day"]
        let scizor = try mon("scizor", 212, level: 60, moves: ["swords-dance", "bullet-punch"])
        let psych = battle([try mon("lax", 143, moves: ["psych-up"] + fillers)], [scizor])
        XCTAssertTrue(psych.events.contains {
            if case .stat("lax", .attack, let change) = $0.event { return change >= 2 }
            return false
        })
        let topsy = battle([try mon("lax", 143, moves: ["topsy-turvy"] + fillers)], [scizor])
        XCTAssertTrue(topsy.events.contains {
            if case .stat("scizor", .attack, let change) = $0.event { return change <= -4 }
            return false
        })
        let heart = battle([try mon("lax", 143, moves: ["heart-swap"] + fillers)], [scizor])
        XCTAssertTrue(heart.events.contains {
            if case .stat("lax", .attack, let change) = $0.event { return change >= 2 }
            return false
        })
        let lax = try mon("lax", 143, moves: ["speed-swap"] + fillers)
        let jolt = try mon("jolt", 135, moves: fillers)
        let speed = battle([lax], [jolt])
        let swapped = try XCTUnwrap(volatileAt(speed, "jolt", "speed-swap"))
        let cast = try XCTUnwrap(speed.events.first {
            if case .cast("lax", let move, _, _) = $0.event { return move != "speed-swap" && $0.time >= swapped }
            return false
        })
        guard case .cast(_, _, _, let ends) = cast.event else { return XCTFail() }
        XCTAssertEqual(ends - cast.time, Int((1200.0 * 300 / Double(100 + jolt.stats.speed) / 3).rounded()))
        // Shuckle's Defense of 230 becomes its Attack: its Tackle hits far harder after the trick.
        let tricked = battle([try mon("shuckle", 213, moves: ["power-trick", "tackle"])], [try mon("lax", 143, moves: fillers)])
        let plain = battle([try mon("shuckle", 213, moves: ["tackle"])], [try mon("lax", 143, moves: fillers)])
        XCTAssertGreaterThan(meanDamage(tricked, "tackle") / meanDamage(plain, "tackle"), 3)
    }

    /// Soak makes the target pure Water, Forest's Curse adds Grass, Reflect Type copies, Conversion takes its first
    /// move's type, Camouflage the terrain's; Electrify makes the target's next move Electric.
    func testTypeChanges() throws {
        let fillers = ["rain-dance", "sunny-day"]
        let soak = battle([try mon("jolt", 135, moves: ["soak", "thunderbolt"])], [try mon("lax", 143, moves: fillers)])
        XCTAssertTrue(has(soak, .retype(battler: "lax", types: [.water])))
        XCTAssertTrue(soak.events.contains {
            if case .hit("jolt", "lax", "thunderbolt", _, _, 2.0, _) = $0.event { return true }
            return false
        })
        let curse = battle([try mon("zard", 6, moves: ["forests-curse", "flamethrower"])], [try mon("lax", 143, moves: fillers)])
        XCTAssertTrue(has(curse, .retype(battler: "lax", types: [.normal, .grass])))
        let reflect = battle([try mon("lax", 143, moves: ["reflect-type"] + fillers)], [try mon("zard", 6, moves: fillers)])
        XCTAssertTrue(has(reflect, .retype(battler: "lax", types: [.fire, .flying])))
        let conversion = battle([try mon("porygon", 137, moves: ["thunderbolt", "conversion"])], [try mon("lax", 143, moves: fillers)])
        XCTAssertTrue(has(conversion, .retype(battler: "porygon", types: [.electric])), "its first move is Thunderbolt")
        let camo = battle([try mon("kecleon", 352, moves: ["camouflage"] + fillers)],
                          [try mon("koko", 785, moves: fillers, ability: "electric-surge")])
        XCTAssertTrue(has(camo, .retype(battler: "kecleon", types: [.electric])))
        let electrify = battle([try mon("chomp", 445, moves: ["electrify"] + fillers)], [try mon("lax", 143, level: 50, moves: ["body-slam"])])
        XCTAssertNotNil(volatileAt(electrify, "lax", "electrify"))
        XCTAssertTrue(electrify.events.contains {
            if case .noEffect("lax", "chomp", "body-slam") = $0.event { return true }
            return false
        }, "an Electric Body Slam does nothing to Garchomp")
    }

    /// Worry Seed gives Insomnia (no more sleep), Gastro Acid takes the ability (Levitate: on the ground), Skill Swap
    /// trades them, Simple Beam gives Simple.
    func testAbilityChanges() throws {
        let fillers = ["rain-dance", "sunny-day"]
        let worry = battle([try mon("shroom", 286, moves: ["worry-seed", "spore", "mach-punch"])], [try mon("lax", 143, moves: fillers)])
        let seeded = try XCTUnwrap(worry.events.first { $0.event == .abilityChange(battler: "lax", ability: "insomnia") })
        XCTAssertFalse(worry.events.contains {
            if case .status("lax", .sleep) = $0.event { return $0.time > seeded.time }
            return false
        })
        let gastro = battle([try mon("chomp", 445, moves: ["gastro-acid", "earthquake"])],
                            [try mon("gengar", 94, level: 60, moves: fillers, ability: "levitate")])
        XCTAssertTrue(has(gastro, .abilityChange(battler: "gengar", ability: "")))
        XCTAssertTrue(hits(gastro).contains { $0.move == "earthquake" })
        let skill = battle([try mon("lax", 143, moves: ["skill-swap"] + fillers, ability: "thick-fat")],
                           [try mon("gyara", 130, moves: fillers, ability: "intimidate")])
        XCTAssertTrue(has(skill, .abilityChange(battler: "lax", ability: "intimidate")))
        XCTAssertTrue(has(skill, .abilityChange(battler: "gyara", ability: "thick-fat")))
        let simple = battle([try mon("lax", 143, moves: ["simple-beam"] + fillers)],
                            [try mon("scizor", 212, level: 60, moves: ["swords-dance", "bullet-punch"])])
        let beamed = try XCTUnwrap(simple.events.first { $0.event == .abilityChange(battler: "scizor", ability: "simple") })
        XCTAssertTrue(simple.events.contains {
            if case .stat("scizor", .attack, 4) = $0.event { return $0.time > beamed.time }
            return false
        }, "Swords Dance raises Attack by four")
    }

    // MARK: Switching

    /// U-turn takes its user out after the hit, the next of its bench stepping in at once; it may come back later.
    /// The replay shows it off the field. (The users stand on the foes' side, which keeps its order.)
    func testUTurnSwitchesItsUserOut() throws {
        let outcome = battle([try mon("champ", 68, moves: ["rain-dance", "sunny-day"])],
                             [try mon("scizor", 212, moves: ["u-turn"]), try mon("lax", 143, moves: ["body-slam"])])
        let turn = try XCTUnwrap(hits(outcome).first { $0.move == "u-turn" })
        XCTAssertTrue(outcome.events.contains { $0.event == .leave(battler: "scizor") && $0.time == turn.time })
        XCTAssertTrue(outcome.events.contains {
            if case .enter(1, 0, "lax") = $0.event { return $0.time == turn.time }
            return false
        })
        let frame = BattleFrame.at(turn.time, setup: outcome.setup, events: outcome.events)
        XCTAssertEqual(frame.units.first { $0.id == "scizor" }?.onField, false)
        let alone = battle([try mon("champ", 68, moves: ["rain-dance", "sunny-day"])], [try mon("scizor", 212, moves: ["u-turn"])])
        XCTAssertFalse(alone.events.contains { $0.event == .leave(battler: "scizor") }, "without a bench it stays")
    }

    /// Baton Pass hands its stages to the one that comes in; Shed Tail leaves it a substitute for half the HP; Parting
    /// Shot lowers the foe's attacks on the way out.
    func testBatonPassShedTailPartingShot() throws {
        let foe = try mon("champ", 68, level: 60, moves: ["rain-dance", "sunny-day"])
        let sturdy = try mon("champ", 68, moves: ["rain-dance", "sunny-day"])
        let baton = battle([sturdy], [try mon("ninjask", 291, moves: ["swords-dance", "baton-pass"]), try mon("lax", 143, moves: ["body-slam"])])
        let passed = try XCTUnwrap(baton.events.firstIndex { $0.event == .leave(battler: "ninjask") })
        XCTAssertTrue(baton.events[passed...].contains {
            if case .stat("lax", .attack, let change) = $0.event { return change >= 2 }
            return false
        })
        // The Attack it got is real: its Body Slams hit about twice as hard as after a passed Agility.
        let control = battle([sturdy], [try mon("ninjask", 291, moves: ["agility", "baton-pass"]), try mon("lax", 143, moves: ["body-slam"])])
        XCTAssertGreaterThan(meanDamage(baton, "body-slam") / meanDamage(control, "body-slam"), 1.6)
        let shed = try mon("cyclizar", 967, moves: ["shed-tail"])
        let tail = battle([foe], [shed, try mon("lax", 143, moves: ["body-slam"])])
        XCTAssertTrue(has(tail, .hurt(battler: "cyclizar", amount: (shed.stats.hp + 1) / 2, hp: shed.stats.hp - (shed.stats.hp + 1) / 2,
                                      cause: .substitute)))
        XCTAssertTrue(has(tail, .substitute(battler: "lax", hp: shed.stats.hp / 4)), "a quarter of Cyclizar's HP")
        let shot = battle([foe], [try mon("panda", 675, moves: ["parting-shot"]), try mon("lax", 143, moves: ["body-slam"])])
        XCTAssertTrue(shot.events.contains {
            if case .stat("champ", .specialAttack, -1) = $0.event { return true }
            return false
        })
        XCTAssertTrue(shot.events.contains { $0.event == .leave(battler: "panda") })
    }

    /// Roar sends out a foe holding boosts, one of its bench coming in at random; Dragon Tail does it after the hit.
    func testRoarAndDragonTailForceTheFoeOut() throws {
        let roar = battle([try mon("lax", 143, moves: ["roar", "body-slam"])],
                          [try mon("scizor", 212, level: 60, moves: ["swords-dance", "bullet-punch"]), try mon("next", 130, level: 50, moves: ["splash"])])
        XCTAssertTrue(roar.events.contains { $0.event == .leave(battler: "scizor") })
        XCTAssertTrue(roar.events.contains {
            if case .enter(1, 0, "next") = $0.event { return true }
            return false
        })
        let tail = battle([try mon("chomp", 445, moves: ["dragon-tail"])],
                          [try mon("lax", 143, moves: ["growl"]), try mon("next", 130, level: 50, moves: ["splash"])])
        let hit = try XCTUnwrap(hits(tail).first { $0.move == "dragon-tail" && $0.hp > 0 })
        XCTAssertTrue(tail.events.contains { $0.event == .leave(battler: hit.target) && $0.time == hit.time })
    }

    /// Follow Me draws the foes' single-target moves; Helping Hand gives the ally's next move 1.5x; After You makes the
    /// ally act at once.
    func testFollowMeHelpingHandAfterYou() throws {
        let follow = battle([try mon("clef", 36, moves: ["follow-me", "moonblast"]), try mon("zard", 6, moves: ["flamethrower"])],
                            [try mon("champ", 68, level: 60, moves: ["karate-chop"]), try mon("lapras", 131, level: 60, moves: ["ice-shard"])],
                            active: 2)
        let drawn = try XCTUnwrap(volatileAt(follow, "clef", "follow-me"))
        let during = hits(follow).filter { $0.attacker != "clef" && $0.attacker != "zard" && $0.time > drawn && $0.time < drawn + 1500 }
        XCTAssertFalse(during.isEmpty)
        XCTAssertTrue(during.allSatisfy { $0.target == "clef" }, "\(during.map(\.target))")
        let fillers = ["rain-dance", "sunny-day"]
        let foes = [try mon("lax", 143, moves: fillers), try mon("bliss", 242, moves: fillers)]
        let helped = battle([try mon("helper", 35, moves: ["helping-hand"]), try mon("champ", 68, moves: ["strength"])], foes, active: 2)
        let alone = battle([try mon("helper", 35, moves: fillers), try mon("champ", 68, moves: ["strength"])], foes, active: 2)
        var boosted: [Int] = []
        var pending = false
        for timed in helped.events {
            if case .volatile("champ", "helping-hand") = timed.event { pending = true }
            if case .hit("champ", "lax", "strength", let damage, let hp, _, false) = timed.event, hp > 0 {
                if pending { boosted.append(damage) }
                pending = false
            }
        }
        XCTAssertFalse(boosted.isEmpty)
        let plain = alone.events.compactMap { timed -> Int? in
            if case .hit("champ", "lax", "strength", let damage, let hp, _, false) = timed.event, hp > 0 { return damage }
            return nil
        }
        let ratio = Double(boosted.reduce(0, +)) / Double(boosted.count) / (Double(plain.reduce(0, +)) / Double(max(1, plain.count)))
        XCTAssertEqual(ratio, 1.5, accuracy: 0.15)
        let after = battle([try mon("clef", 36, moves: ["after-you"]), try mon("snorlax", 143, moves: ["giga-impact"])], foes, active: 2)
        let at = try XCTUnwrap(volatileAt(after, "snorlax", "after-you"))
        XCTAssertTrue(hits(after).contains { $0.attacker == "snorlax" && $0.time == at }, "Snorlax's long cast lands at once")
    }

    // MARK: Berries held

    /// Knock Off hits 1.5x as hard on a Pokémon holding a berry and knocks it off: never eaten after.
    func testKnockOffKnocksTheBerryOff() throws {
        let fillers = ["rain-dance", "sunny-day"]
        let outcome = battle([try mon("lax", 143, moves: fillers)], [try mon("absol", 359, level: 60, moves: ["knock-off"])],
                             berries: [.sitrus: 1])
        let knocked = try XCTUnwrap(outcome.events.first {
            if case .berryTaken("lax", .sitrus, nil) = $0.event { return true }
            return false
        })
        XCTAssertFalse(outcome.events.contains {
            if case .berry("lax", _) = $0.event { return $0.time > knocked.time }
            return false
        })
        let all = hits(outcome).filter { $0.move == "knock-off" && $0.hp > 0 }
        let first = try XCTUnwrap(all.first), rest = all.dropFirst()
        XCTAssertFalse(rest.isEmpty)
        let mean = Double(rest.map(\.damage).reduce(0, +)) / Double(rest.count)
        XCTAssertEqual(Double(first.damage) / mean, 1.5, accuracy: 0.2)
    }

    /// Thief steals the berry for a user holding none; Pluck eats it; Incinerate burns it; Trick takes it.
    func testMovesThatTakeTheBerry() throws {
        let fillers = ["rain-dance", "sunny-day"]
        func run(_ slug: String) throws -> BattleOutcome {
            battle([try mon("lax", 143, moves: fillers)], [try mon("user", 359, level: 50, moves: [slug] + fillers)],
                   berries: [.sitrus: 1])
        }
        let thief = try run("thief")
        XCTAssertTrue(has(thief, .berryTaken(battler: "lax", berry: .sitrus, by: "user")))
        XCTAssertTrue(has(thief, .berryGiven(battler: "user", berry: .sitrus)))
        let pluck = try run("pluck")
        XCTAssertTrue(has(pluck, .berryTaken(battler: "lax", berry: .sitrus, by: "user")))
        XCTAssertTrue(has(pluck, .berry(battler: "user", berry: .sitrus)))
        let burnt = try run("incinerate")
        XCTAssertTrue(has(burnt, .berryTaken(battler: "lax", berry: .sitrus, by: nil)))
        let trick = try run("trick")
        XCTAssertTrue(has(trick, .berryGiven(battler: "user", berry: .sitrus)))
    }

    /// Recycle gives back the berry eaten; Belch needs one eaten first; Natural Gift throws the held one (Psychic for
    /// a Sitrus); Stuff Cheeks eats it and raises Defense; Corrosive Gas takes the foes'.
    func testMovesThatUseTheBerry() throws {
        let fillers = ["rain-dance", "sunny-day"]
        let recycle = battle([try mon("lax", 143, moves: ["recycle", "rain-dance", "sunny-day"])],
                             [try mon("champ", 68, level: 60, moves: ["cross-chop"])],
                             berries: [.sitrus: 1])
        let eaten = recycle.events.filter {
            if case .berry("lax", _) = $0.event { return true }
            return false
        }
        XCTAssertTrue(has(recycle, .berryGiven(battler: "lax", berry: .sitrus)))
        XCTAssertGreaterThanOrEqual(eaten.count, 2, "eaten, recycled, eaten again")
        let belch = battle([try mon("swalot", 317, moves: ["belch", "sludge-bomb"])], [try mon("lax", 143, moves: fillers)])
        XCTAssertFalse(belch.events.contains {
            if case .cast("swalot", "belch", _, _) = $0.event { return true }
            return false
        }, "no berry eaten, no Belch")
        let gift = battle([try mon("lax", 143, moves: ["natural-gift"] + fillers)], [try mon("champ", 68, moves: fillers)],
                          berries: [.sitrus: 1])
        XCTAssertTrue(gift.events.contains {
            if case .hit("lax", "champ", "natural-gift", _, _, 2.0, _) = $0.event { return true }
            return false
        }, "a Psychic Natural Gift on Machamp")
        XCTAssertTrue(has(gift, .berryTaken(battler: "lax", berry: .sitrus, by: nil)))
        let cheeks = battle([try mon("greedent", 820, moves: ["stuff-cheeks", "body-slam"])], [try mon("champ", 68, moves: fillers)],
                            berries: [.oran: 1])
        XCTAssertTrue(has(cheeks, .berry(battler: "greedent", berry: .oran)))
        XCTAssertTrue(cheeks.events.contains {
            if case .stat("greedent", .defense, 2) = $0.event { return true }
            return false
        })
        let gas = battle([try mon("lax", 143, moves: fillers)], [try mon("weezing", 110, moves: ["corrosive-gas", "sludge-bomb"])],
                         berries: [.sitrus: 1])
        XCTAssertTrue(has(gas, .berryTaken(battler: "lax", berry: .sitrus, by: nil)))
    }
}
