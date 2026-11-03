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
                     "protect", "authentic", "mirror", "reflectable", "snatch", "gravity", "heal", "slicing", "wind"] {
            XCTAssertTrue(MoveTable.all.values.contains { $0.flags.contains(flag) }, flag)
        }
        XCTAssertTrue(try XCTUnwrap(MoveTable.move("shadow-ball")).isBallistic)
        let outcome = battle([try mon("gengar", 94, moves: ["shadow-ball"])],
                             [try mon("chesnaught", 652, moves: ["growl"], ability: "bulletproof")])
        XCTAssertTrue(has(outcome, .ability(battler: "chesnaught", ability: "bulletproof")))
        XCTAssertFalse(hits(outcome).contains { $0.move == "shadow-ball" })
    }

    // MARK: Weights and Showdown's flags

    /// Low Kick and Grass Knot by the target's weight; Heavy Slam and Heat Crash by how many times their user outweighs
    /// it. PokéAPI gives each variety's weight (in hectograms).
    func testWeightPowers() throws {
        XCTAssertEqual([0.1, 9.9, 10, 24.9, 25, 50, 99.9, 100, 199.9, 200, 999].map { BattleSimulation.weightPower(targetKilograms: $0) },
                       [20, 20, 40, 40, 60, 80, 80, 100, 100, 120, 120])
        XCTAssertEqual([1, 1.99, 2, 3, 4, 4.99, 5, 50].map(BattleSimulation.weightRatioPower), [40, 40, 60, 80, 100, 100, 120, 120])
        XCTAssertEqual(SpeciesBattleTable.data(speciesID: 143)?.weight, 4600, "Snorlax, 460 kg")
        XCTAssertEqual(SpeciesBattleTable.data(speciesID: 25)?.weight, 60, "Pikachu, 6 kg")
        // Heavy Metal doubles a Pikachu's 6 kg past 10: Low Kick goes from 20 to 40.
        let kicker = try mon("lee", 106, moves: ["low-kick"])
        let light = battle([kicker], [try mon("pika", 25, moves: ["splash"], isBoss: true)])
        let heavy = battle([kicker], [try mon("pika", 25, moves: ["splash"], ability: "heavy-metal", isBoss: true)])
        XCTAssertEqual(meanDamage(heavy, "low-kick") / meanDamage(light, "low-kick"), 2, accuracy: 0.25)
        // Snorlax outweighs a Machamp 3.5 times (80), a Light Metal one 7 times (120).
        let slammer = try mon("lax", 143, moves: ["heavy-slam"])
        let champ = battle([slammer], [try mon("champ", 68, moves: ["splash"], isBoss: true)])
        let lighter = battle([slammer], [try mon("champ", 68, moves: ["splash"], ability: "light-metal", isBoss: true)])
        XCTAssertEqual(meanDamage(lighter, "heavy-slam") / meanDamage(champ, "heavy-slam"), 1.5, accuracy: 0.2)
    }

    /// Charge doubles the next Electric move; Wind Rider takes a wind move and raises its Attack; Sharpness lifts a
    /// slicing move by half. The slicing and wind flags come from Showdown's data: PokéAPI has neither.
    func testChargeWindAndSlicing() throws {
        let foe = try mon("lax", 143, moves: ["splash"], isBoss: true)
        let charged = battle([try mon("pika", 25, moves: ["charge", "thunder-shock"])], [foe])
        let plain = battle([try mon("pika", 25, moves: ["growl", "thunder-shock"])], [foe])
        XCTAssertEqual(meanDamage(charged, "thunder-shock") / meanDamage(plain, "thunder-shock"), 2, accuracy: 0.25)

        XCTAssertTrue(try XCTUnwrap(MoveTable.move("air-cutter")).isWind)
        XCTAssertTrue(try XCTUnwrap(MoveTable.move("x-scissor")).isSlicing)
        let rider = battle([try mon("pidgeot", 18, moves: ["air-cutter"])],
                           [try mon("bramble", 947, moves: ["splash"], ability: "wind-rider", isBoss: true)])
        XCTAssertTrue(has(rider, .ability(battler: "bramble", ability: "wind-rider")))
        XCTAssertFalse(hits(rider).contains { $0.move == "air-cutter" })

        let target = try mon("lax", 143, moves: ["splash"], isBoss: true)
        let sharp = battle([try mon("gallade", 475, moves: ["psycho-cut"], ability: "sharpness")], [target])
        let steady = battle([try mon("gallade", 475, moves: ["psycho-cut"], ability: "steadfast")], [target])
        XCTAssertEqual(meanDamage(sharp, "psycho-cut") / meanDamage(steady, "psycho-cut"), 1.5, accuracy: 0.2)
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

    /// U-turn takes its user out after the hit, the best of its bench stepping in at once; it may come back later.
    /// The replay shows it off the field. A foe's U-turn hits and it stays: the foes never leave.
    func testUTurnSwitchesItsUserOut() throws {
        let outcome = battle([try mon("scizor", 212, moves: ["u-turn"]), try mon("lax", 143, level: 20, moves: ["body-slam"])],
                             [try mon("champ", 68, moves: ["rain-dance", "sunny-day"])])
        let turn = try XCTUnwrap(hits(outcome).first { $0.move == "u-turn" })
        XCTAssertTrue(outcome.events.contains { $0.event == .leave(battler: "scizor") && $0.time == turn.time })
        XCTAssertTrue(outcome.events.contains {
            if case .enter(0, 0, "lax") = $0.event { return $0.time == turn.time }
            return false
        })
        let frame = BattleFrame.at(turn.time, setup: outcome.setup, events: outcome.events)
        XCTAssertEqual(frame.units.first { $0.id == "scizor" }?.onField, false)
        let alone = battle([try mon("scizor", 212, moves: ["u-turn"])], [try mon("champ", 68, moves: ["rain-dance", "sunny-day"])])
        XCTAssertFalse(alone.events.contains { $0.event == .leave(battler: "scizor") }, "without a bench it stays")
        let foe = battle([try mon("champ", 68, moves: ["rain-dance", "sunny-day"])],
                         [try mon("scizor", 212, moves: ["u-turn"]), try mon("next", 143, moves: ["body-slam"])])
        XCTAssertTrue(hits(foe).contains { $0.move == "u-turn" })
        XCTAssertFalse(foe.events.contains { $0.event == .leave(battler: "scizor") }, "a foe never leaves")
    }

    /// Baton Pass hands its stages to the one that comes in; Shed Tail leaves it a substitute for half the HP; Parting
    /// Shot lowers the foe's attacks on the way out. The bench members stand low so the movers enter first.
    func testBatonPassShedTailPartingShot() throws {
        let foe = try mon("champ", 68, level: 60, moves: ["rain-dance", "sunny-day"])
        let sturdy = try mon("champ", 68, moves: ["rain-dance", "sunny-day"])
        let baton = battle([try mon("ninjask", 291, moves: ["swords-dance", "baton-pass", "x-scissor"]),
                            try mon("lax", 143, level: 20, moves: ["body-slam"])], [sturdy])
        let passed = try XCTUnwrap(baton.events.firstIndex { $0.event == .leave(battler: "ninjask") })
        XCTAssertTrue(baton.events[passed...].contains {
            if case .stat("lax", .attack, let change) = $0.event { return change >= 2 }
            return false
        })
        // The Attack it got is real: its Body Slams hit about twice as hard as after a passed Agility.
        let control = battle([try mon("ninjask", 291, moves: ["agility", "baton-pass", "x-scissor"]),
                              try mon("lax", 143, level: 20, moves: ["body-slam"])], [sturdy])
        XCTAssertGreaterThan(meanDamage(baton, "body-slam") / meanDamage(control, "body-slam"), 1.6)
        let shed = try mon("cyclizar", 967, moves: ["shed-tail", "dragon-claw"])
        let tail = battle([shed, try mon("lax", 143, level: 20, moves: ["body-slam"])], [foe])
        XCTAssertTrue(has(tail, .hurt(battler: "cyclizar", amount: (shed.stats.hp + 1) / 2, hp: shed.stats.hp - (shed.stats.hp + 1) / 2,
                                      cause: .substitute)))
        XCTAssertTrue(has(tail, .substitute(battler: "lax", hp: shed.stats.hp / 4)), "a quarter of Cyclizar's HP")
        let shot = battle([try mon("panda", 675, moves: ["parting-shot", "crunch"]), try mon("lax", 143, level: 20, moves: ["body-slam"])],
                          [foe])
        XCTAssertTrue(shot.events.contains {
            if case .stat("champ", .specialAttack, -1) = $0.event { return true }
            return false
        })
        XCTAssertTrue(shot.events.contains { $0.event == .leave(battler: "panda") })
        let theirs = battle([foe], [try mon("ninjask", 291, moves: ["swords-dance", "baton-pass", "x-scissor"]),
                                    try mon("lax", 143, moves: ["body-slam"])])
        XCTAssertFalse(theirs.events.contains { $0.event == .leave(battler: "ninjask") }, "a foe never passes")
    }

    /// Roar sends out a Pokémon holding boosts, one of its bench coming in at random; Dragon Tail does it after the
    /// hit. Only ours: the foes never leave the field.
    func testRoarAndDragonTailForceOut() throws {
        let roar = battle([try mon("scizor", 212, level: 60, moves: ["swords-dance", "bullet-punch"]),
                           try mon("next", 130, level: 50, moves: ["splash"])],
                          [try mon("lax", 143, moves: ["roar", "body-slam"])])
        XCTAssertTrue(roar.events.contains { $0.event == .leave(battler: "scizor") })
        XCTAssertTrue(roar.events.contains {
            if case .enter(0, 0, "next") = $0.event { return true }
            return false
        })
        let tail = battle([try mon("lax", 143, moves: ["growl"]), try mon("next", 130, level: 50, moves: ["splash"])],
                          [try mon("chomp", 445, moves: ["dragon-tail"])])
        let hit = try XCTUnwrap(hits(tail).first { $0.move == "dragon-tail" && $0.hp > 0 })
        XCTAssertTrue(tail.events.contains { $0.event == .leave(battler: hit.target) && $0.time == hit.time })
        let foes = battle([try mon("lax", 143, moves: ["roar", "dragon-tail"])],
                          [try mon("scizor", 212, level: 60, moves: ["swords-dance", "bullet-punch"]),
                           try mon("next", 130, level: 50, moves: ["splash"])])
        XCTAssertFalse(foes.events.contains {
            if case .leave = $0.event { return true }
            return false
        }, "no foe is ever sent out")
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

    // MARK: Two turns, locks, streaks

    /// The (start, end) of each cast of `move` by `battler`.
    private func castWindows(_ outcome: BattleOutcome, _ battler: String, _ move: String) -> [(start: Int, end: Int)] {
        outcome.events.compactMap { timed in
            guard case .cast(let who, let m, _, let ends) = timed.event, who == battler, m == move else { return nil }
            return (timed.time, ends)
        }
    }

    /// Digging, a Pokémon is out of reach for its charge, the two seconds (by its speed) before it strikes: Tackle
    /// misses it then and hits it the rest of the time; Earthquake reaches it, at twice the power.
    func testDigIsOutOfReachButForEarthquake() throws {
        // Shuckle digs: its Defense keeps it standing through many hits, its Attack keeps the foe standing.
        let chomp = try mon("chomp", 213, moves: ["dig"])
        let charge = Int(2000.0 * 300 / Double(100 + chomp.stats.speed) / 3)
        func underground(_ outcome: BattleOutcome) -> [(start: Int, end: Int)] {
            castWindows(outcome, "chomp", "dig").map { ($0.end - charge + 1, $0.end) }
        }
        let dug = battle([chomp], [try mon("lax", 143, moves: ["tackle"])])
        let hidden = underground(dug)
        XCTAssertFalse(hits(dug).contains { $0.target == "chomp" && during($0.time, hidden) })
        XCTAssertTrue(dug.events.contains {
            if case .miss("lax", "chomp", "tackle") = $0.event { return during($0.time, hidden) }
            return false
        })
        XCTAssertTrue(hits(dug).contains { $0.target == "chomp" }, "in sight the rest of the cast")
        let quake = battle([chomp], [try mon("rhy", 112, level: 40, moves: ["earthquake"])])
        let below = underground(quake)
        func damages(_ inside: Bool) -> [Int] {
            quake.events.compactMap { timed in
                guard case .hit("rhy", "chomp", "earthquake", let damage, let hp, _, false) = timed.event, hp > 0,
                      during(timed.time, below) == inside else { return nil }
                return damage
            }
        }
        let inside = damages(true), outside = damages(false)
        XCTAssertFalse(inside.isEmpty)
        XCTAssertFalse(outside.isEmpty)
        let ratio = Double(inside.reduce(0, +)) / Double(inside.count) / (Double(outside.reduce(0, +)) / Double(outside.count))
        XCTAssertEqual(ratio, 2, accuracy: 0.3)
    }

    /// Outrage locks its user for two or three casts, then confuses it.
    func testOutrageLocksThenConfuses() throws {
        // Skarmory, a Steel type, resists the Outrages and stands to the end of the lock.
        let outcome = battle([try mon("chomp", 445, moves: ["outrage", "earthquake"])], [try mon("skarm", 227, moves: ["rain-dance", "sunny-day"])])
        let casts = outcome.events.compactMap { timed -> String? in
            if case .cast("chomp", let move, _, _) = timed.event { return move }
            return nil
        }
        let run = casts.prefix { $0 == "outrage" }.count
        XCTAssertTrue((2...3).contains(run), "\(casts.prefix(5))")
        XCTAssertTrue(has(outcome, .status(battler: "chomp", ailment: .confusion)))
    }

    /// Rollout casts five times in a row, each twice as strong; against a boss it stops growing at 120 power.
    func testRolloutDoublesButNotPastABossCap() throws {
        let fillers = ["rain-dance", "sunny-day"]
        let rolls = battle([try mon("golem", 76, level: 20, moves: ["rollout"])], [try mon("bliss", 242, moves: fillers)])
        let damages = hits(rolls).filter { $0.move == "rollout" }.prefix(5).map(\.damage)
        XCTAssertEqual(damages.count, 5)
        XCTAssertGreaterThan(Double(damages[4]) / Double(damages[0]), 8, "\(damages)")
        let boss = battle([try mon("golem", 76, level: 20, moves: ["rollout"])],
                          [try mon("boss", 242, moves: fillers, isBoss: true)])
        let onBoss = hits(boss).filter { $0.move == "rollout" }.prefix(5).map(\.damage)
        XCTAssertEqual(onBoss.count, 5)
        XCTAssertLessThan(Double(onBoss[4]) / Double(onBoss[2]), 1.4, "\(onBoss)")
    }

    /// Fury Cutter doubles with each that landed before it, up to 160 power.
    func testFuryCutterGrows() throws {
        let outcome = battle([try mon("scizor", 212, level: 40, moves: ["fury-cutter"])], [try mon("bliss", 242, moves: ["rain-dance", "sunny-day"])])
        let damages = hits(outcome).filter { $0.move == "fury-cutter" }.prefix(4).map(\.damage)
        XCTAssertEqual(damages.count, 4)
        XCTAssertGreaterThan(Double(damages[2]) / Double(damages[0]), 3, "\(damages)")
        XCTAssertLessThan(Double(damages[3]) / Double(damages[2]), 1.3, "160 at most: \(damages)")
    }

    /// Uproar wakes the sleepers as it starts, and nobody falls asleep while it goes on.
    func testUproarKeepsEveryoneAwake() throws {
        let outcome = battle([try mon("loud", 295, moves: ["uproar"])], [try mon("shroom", 242, moves: ["mach-punch", "spore"])])
        // The lock holds from the first Uproar that landed through the two casts after it.
        let roars = castWindows(outcome, "loud", "uproar")
        let first = try XCTUnwrap(hits(outcome).first { $0.move == "uproar" })
        let after = roars.filter { $0.start >= first.time }.prefix(2)
        XCTAssertEqual(after.count, 2)
        let spans = [(start: first.time, end: after.last!.end)]
        XCTAssertFalse(outcome.events.contains {
            if case .status("loud", .sleep) = $0.event { return during($0.time, spans) }
            return false
        })
    }

    /// Future Sight lands two turns later, through Protect: over a few seeds, one lands while Snorlax's Protect holds.
    func testFutureSightLandsTwoTurnsLater() throws {
        var throughProtect = 0
        for seed: UInt64 in 1...12 {
            let outcome = battle([try mon("zam", 65, moves: ["future-sight", "psychic"])],
                                 [try mon("lax", 143, moves: ["protect", "rain-dance", "sunny-day"])], seed: seed)
            let foreseen = try XCTUnwrap(volatileAt(outcome, "lax", "future-sight"), "seed \(seed)")
            let landed = try XCTUnwrap(hits(outcome).first { $0.move == "future-sight" }, "seed \(seed)")
            XCTAssertEqual(landed.time, foreseen + 2 * BattleRules.turn, "seed \(seed)")
            // A Protect that did not fail holds for 1.5 s from the end of its cast.
            let shields = castWindows(outcome, "lax", "protect").filter { cast in
                !outcome.events.contains { $0.time == cast.end && $0.event == .fail(battler: "lax", move: "protect", reason: .failed) }
            }.map { (start: $0.end - 1, end: $0.end + 1500) }
            if during(landed.time, shields) { throughProtect += 1 }
        }
        XCTAssertGreaterThan(throughProtect, 0)
    }

    /// Skull Bash raises Defense as it starts to charge; Electro Shot skips its charge in the rain.
    func testChargesThatRaiseAndSkip() throws {
        let fillers = ["rain-dance", "sunny-day"]
        let bash = battle([try mon("lax", 143, moves: ["skull-bash"])], [try mon("bliss", 242, moves: fillers)])
        let cast = try XCTUnwrap(castWindows(bash, "lax", "skull-bash").first)
        XCTAssertTrue(bash.events.contains {
            if case .stat("lax", .defense, 1) = $0.event { return $0.time == cast.start }
            return false
        })
        let dry = battle([try mon("zap", 145, moves: ["electro-shot"])], [try mon("bliss", 242, moves: ["growl"])])
        let wet = battle([try mon("zap", 145, moves: ["electro-shot"])], [try mon("bliss", 242, moves: ["growl"], ability: "drizzle")])
        let dryCast = try XCTUnwrap(castWindows(dry, "zap", "electro-shot").first)
        let wetCast = try XCTUnwrap(castWindows(wet, "zap", "electro-shot").first)
        XCTAssertLessThan(wetCast.end - wetCast.start, dryCast.end - dryCast.start)
    }

    // MARK: Powers, accuracies and priorities by the situation

    /// Acrobatics doubles without a berry held; Punishment grows with the target's boosts; Return hits at 102 and
    /// Frustration at 1 for a Pokémon its trainer raised; Crush Grip falls with the target's HP.
    func testPowersByTheSituation() throws {
        let fillers = ["rain-dance", "sunny-day"]
        let bare = battle([try mon("bird", 18, moves: ["acrobatics"])], [try mon("lax", 143, moves: fillers)])
        let holding = battle([try mon("bird", 18, moves: ["acrobatics"])], [try mon("lax", 143, moves: fillers)], berries: [.sitrus: 1])
        XCTAssertEqual(meanDamage(bare, "acrobatics") / meanDamage(holding, "acrobatics"), 2, accuracy: 0.25)
        let punish = battle([try mon("absol", 359, level: 50, moves: ["punishment"])],
                            [try mon("scizor", 212, moves: ["swords-dance", "agility", "rain-dance"])])
        let blows = hits(punish).filter { $0.move == "punishment" && $0.hp > 0 }.map(\.damage)
        XCTAssertGreaterThan(Double(try XCTUnwrap(blows.last)) / Double(try XCTUnwrap(blows.first)), 1.5, "\(blows)")
        let loved = battle([try mon("lax", 143, moves: ["return"])], [try mon("bliss", 242, moves: fillers)])
        let spite = battle([try mon("lax", 143, moves: ["frustration"])], [try mon("bliss", 242, moves: fillers)])
        XCTAssertGreaterThan(meanDamage(loved, "return"), 10 * meanDamage(spite, "frustration"))
        let grip = battle([try mon("champ", 68, level: 50, moves: ["crush-grip"])], [try mon("bliss", 242, moves: fillers)])
        let grips = hits(grip).filter { $0.move == "crush-grip" && $0.hp > 0 }.map(\.damage)
        XCTAssertGreaterThan(Double(try XCTUnwrap(grips.first)) / Double(try XCTUnwrap(grips.last)), 1.5, "\(grips)")
    }

    /// Stockpile stores up to three; Spit Up strikes at 100 a stock, Swallow heals by them; both spend them, and the
    /// Defenses they raised fall back.
    func testStockpileSpitUpSwallow() throws {
        let fillers = ["rain-dance", "sunny-day"]
        let spit = battle([try mon("swalot", 317, moves: ["stockpile", "stockpile", "spit-up"])], [try mon("lax", 143, moves: fillers)])
        XCTAssertEqual(spit.events.filter { $0.event == .volatile(battler: "swalot", effect: "stockpile") }.count >= 2, true)
        XCTAssertTrue(hits(spit).contains { $0.move == "spit-up" })
        XCTAssertTrue(spit.events.contains {
            if case .stat("swalot", .defense, let change) = $0.event { return change <= -2 }
            return false
        })
        let swallow = battle([try mon("swalot", 317, moves: ["stockpile", "swallow"], hp: 100)], [try mon("lax", 143, moves: fillers)])
        XCTAssertTrue(swallow.events.contains {
            if case .heal("swalot", _, _, .move) = $0.event { return true }
            return false
        })
    }

    /// Magnitude rolls its power, Present sometimes heals the target, Beat Up hits once per Pokémon standing on the side.
    func testRolledPowersAndBeatUp() throws {
        let fillers = ["rain-dance", "sunny-day"]
        let quake = battle([try mon("dug", 51, level: 50, moves: ["magnitude"])], [try mon("lax", 143, moves: fillers)])
        XCTAssertGreaterThanOrEqual(Set(hits(quake).filter { $0.move == "magnitude" }.map(\.damage)).count, 4)
        var healed = false
        for seed: UInt64 in 1...4 {
            let gift = battle([try mon("deli", 225, moves: ["present"])], [try mon("lax", 143, moves: fillers, hp: 300)], seed: seed)
            if gift.events.contains(where: {
                if case .heal("lax", _, _, .move) = $0.event { return true }
                return false
            }) { healed = true }
        }
        XCTAssertTrue(healed)
        let beat = battle([try mon("absol", 359, moves: ["beat-up"]), try mon("b1", 143, moves: fillers), try mon("b2", 6, moves: fillers)],
                          [try mon("bliss", 242, moves: fillers)])
        let first = try XCTUnwrap(hits(beat).first { $0.move == "beat-up" })
        XCTAssertEqual(hits(beat).filter { $0.move == "beat-up" && $0.time == first.time }.count, 3)
    }

    /// Fake Out and First Impression work on the first cast only; Sucker Punch only against a foe about to attack;
    /// Focus Punch fails when hit while it gathers; Last Resort waits for every other move to be used.
    func testMovesThatNeedTheirMoment() throws {
        let fillers = ["rain-dance", "sunny-day"]
        let fake = battle([try mon("cat", 53, moves: ["fake-out", "slash"])], [try mon("lax", 143, moves: fillers)])
        XCTAssertEqual(castWindows(fake, "cat", "fake-out").map(\.start), [0])
        let calm = battle([try mon("absol", 359, moves: ["sucker-punch", "night-slash"])], [try mon("lax", 143, moves: fillers)])
        XCTAssertFalse(hits(calm).contains { $0.move == "sucker-punch" }, "Snorlax never attacks")
        let angry = battle([try mon("absol", 359, moves: ["sucker-punch", "night-slash"])], [try mon("lax", 143, moves: ["giga-impact"])])
        XCTAssertTrue(hits(angry).contains { $0.move == "sucker-punch" })
        let focus = battle([try mon("champ", 68, moves: ["focus-punch"])], [try mon("jolt", 135, level: 60, moves: ["quick-attack"])])
        XCTAssertGreaterThan(fails(focus, "champ", "focus-punch"), 0)
        let resort = battle([try mon("eevee", 133, moves: ["last-resort", "tackle", "growl"])], [try mon("bliss", 242, moves: fillers)])
        let first = try XCTUnwrap(castWindows(resort, "eevee", "last-resort").first)
        XCTAssertFalse(castWindows(resort, "eevee", "tackle").isEmpty)
        XCTAssertTrue(castWindows(resort, "eevee", "tackle").contains { $0.start < first.start })
        XCTAssertTrue(castWindows(resort, "eevee", "growl").contains { $0.start < first.start })
    }

    /// Smack Down grounds a flying target: Earthquake reaches it after.
    func testSmackDownGrounds() throws {
        let outcome = battle([try mon("tyranitar", 248, level: 50, moves: ["smack-down", "earthquake"])],
                             [try mon("skarm", 227, moves: ["rain-dance", "sunny-day"])])
        let grounded = try XCTUnwrap(volatileAt(outcome, "skarm", "smack-down"))
        XCTAssertTrue(hits(outcome).contains { $0.move == "earthquake" && $0.time > grounded })
    }

    // MARK: Sacrifices and healing

    /// Memento lowers the foe's attacks by two and knocks its user out; Healing Wish knocks its user out and the next
    /// to step into its place comes in whole.
    func testMementoAndHealingWish() throws {
        let fillers = ["rain-dance", "sunny-day"]
        let memento = battle([try mon("lax", 143, moves: fillers)],
                             [try mon("drif", 426, moves: ["memento"], hp: 50), try mon("next", 130, moves: fillers)])
        XCTAssertTrue(memento.events.contains {
            if case .stat("lax", .attack, -2) = $0.event { return true }
            return false
        })
        XCTAssertTrue(memento.events.contains {
            if case .hurt("drif", _, 0, .recoil) = $0.event { return true }
            return false
        })
        let next = try mon("next", 130, moves: fillers, hp: 40)
        let wish = battle([try mon("lax", 143, moves: fillers)], [try mon("clef", 36, moves: ["healing-wish"], hp: 50), next])
        XCTAssertTrue(has(wish, .volatile(battler: "next", effect: "healing-wish")))
        XCTAssertTrue(has(wish, .heal(battler: "next", amount: next.stats.hp - 40, hp: next.stats.hp, cause: .move)))
    }

    /// Strength Sap heals by the target's Attack and lowers it; Purify cures the target and heals the user; Shore Up
    /// heals two thirds in a sandstorm.
    func testStrengthSapPurifyShoreUp() throws {
        let fillers = ["rain-dance", "sunny-day"]
        let champ = try mon("champ", 68, moves: fillers)
        let sap = battle([try mon("shiinotic", 756, moves: ["strength-sap"], hp: 50)], [champ])
        XCTAssertTrue(sap.events.contains {
            if case .heal("shiinotic", let amount, _, .move) = $0.event { return amount == min(champ.stats.attack, 1000) || amount > 100 }
            return false
        })
        XCTAssertTrue(sap.events.contains {
            if case .stat("champ", .attack, -1) = $0.event { return true }
            return false
        })
        let purify = battle([try mon("pyuku", 771, moves: ["toxic", "purify"], hp: 50)], [try mon("lax", 143, moves: fillers, ability: "thick-fat")])
        XCTAssertTrue(has(purify, .cure(battler: "lax", ailment: .badPoison)))
        let sandy = try mon("palossand", 770, moves: ["shore-up"], hp: 10)
        let shore = battle([sandy], [try mon("ttar", 248, level: 50, moves: fillers, ability: "sand-stream")])
        XCTAssertTrue(has(shore, .heal(battler: "palossand", amount: sandy.stats.hp * 67 / 100, hp: 10 + sandy.stats.hp * 67 / 100,
                                       cause: .move)))
    }

    /// Heal Bell cures the whole side, the bench too; Refresh its user's burn; Jungle Healing heals and cures the side.
    func testHealBellRefreshJungleHealing() throws {
        let burnt = try mon("lax", 143, moves: ["rain-dance", "sunny-day"])
        let bell = battle([try mon("bliss", 242, moves: ["heal-bell", "rain-dance"]), burnt],
                          [try mon("zard", 6, level: 50, moves: ["will-o-wisp", "rain-dance"])])
        XCTAssertTrue(bell.events.contains {
            if case .cure(_, .burn) = $0.event { return true }
            return false
        })
        let refresh = battle([try mon("lax", 143, moves: ["refresh", "body-slam"], ability: "thick-fat")],
                             [try mon("zard", 6, level: 50, moves: ["will-o-wisp", "rain-dance"])])
        XCTAssertTrue(has(refresh, .cure(battler: "lax", ailment: .burn)))
        let jungle = battle([try mon("zarude", 893, moves: ["jungle-healing", "power-whip"], hp: 100)],
                            [try mon("lax", 143, moves: ["rain-dance", "sunny-day"])])
        XCTAssertTrue(jungle.events.contains {
            if case .heal("zarude", _, _, .move) = $0.event { return true }
            return false
        })
    }

    /// Roost heals half and sets the Flying type aside until the next cast ends.
    func testRoostSetsFlyingAside() throws {
        let outcome = battle([try mon("skarm", 227, moves: ["roost", "rain-dance", "sunny-day"], hp: 100)],
                             [try mon("chomp", 445, level: 40, moves: ["rain-dance", "sunny-day"])])
        let aside = try XCTUnwrap(outcome.events.firstIndex { $0.event == .retype(battler: "skarm", types: [.steel]) })
        XCTAssertTrue(outcome.events[aside...].contains { $0.event == .retype(battler: "skarm", types: [.steel, .flying]) },
                      "back after the next cast")
    }

    /// Revival Blessing brings a fainted Pokémon of the side back to half its HP, on the bench: it fights again.
    func testRevivalBlessingBringsOneBack() throws {
        let fallen = try mon("weak", 10, level: 5, moves: ["tackle"])
        let outcome = battle([try mon("lax", 143, moves: ["body-slam"])],
                             [fallen, try mon("paw", 923, moves: ["revival-blessing", "rain-dance", "sunny-day"])])
        XCTAssertTrue(has(outcome, .heal(battler: "weak", amount: fallen.stats.hp / 2, hp: fallen.stats.hp / 2, cause: .move)))
        let enters = outcome.events.filter {
            if case .enter(1, _, "weak") = $0.event { return true }
            return false
        }
        XCTAssertGreaterThanOrEqual(enters.count, 2, "it steps in again")
    }

    // MARK: The newest moves, and the last ones

    /// PokéAPI gives the newest moves a power and nothing else: the table fills their effects in.
    func testTheNewestMovesGetTheirEffects() throws {
        XCTAssertEqual(try XCTUnwrap(MoveTable.move("wave-crash")).drain, -33)
        let arrows = try XCTUnwrap(MoveTable.move("triple-arrows"))
        XCTAssertEqual(arrows.critStage, 1)
        XCTAssertEqual(arrows.flinchChance, 30)
        XCTAssertEqual(arrows.statChanges, [BattleMove.StatChange(stat: .defense, change: -1)])
        XCTAssertEqual(arrows.category, .damageLower)
        XCTAssertEqual(try XCTUnwrap(MoveTable.move("population-bomb")).maxHits, 10)
        XCTAssertEqual(try XCTUnwrap(MoveTable.move("malignant-chain")).ailment, .badPoison)
        XCTAssertEqual(try XCTUnwrap(MoveTable.move("make-it-rain")).category, .damageRaise)
        let fillers = ["rain-dance", "sunny-day"]
        let crash = battle([try mon("basc", 550, moves: ["wave-crash"])], [try mon("lax", 143, moves: fillers)])
        XCTAssertTrue(crash.events.contains {
            if case .hurt("basc", _, _, .recoil) = $0.event { return true }
            return false
        })
        var drawn = Set<BattleAilment>()
        for seed: UInt64 in 1...12 {
            let claw = battle([try mon("sneasler", 903, level: 50, moves: ["dire-claw", "rain-dance"])],
                              [try mon("lax", 143, moves: fillers, ability: "thick-fat")], seed: seed)
            for timed in claw.events {
                if case .status("lax", let ailment) = timed.event { drawn.insert(ailment) }
            }
        }
        XCTAssertGreaterThanOrEqual(drawn.count, 2, "\(drawn)")
    }

    /// Population Bomb rolls each hit after the first and stops on a miss; Triple Kick grows with each hit.
    func testHitsRolledOneByOne() throws {
        let fillers = ["rain-dance", "sunny-day"]
        var counts = Set<Int>()
        for seed: UInt64 in 1...8 {
            let bomb = battle([try mon("maus", 925, level: 30, moves: ["population-bomb"])], [try mon("bliss", 242, moves: fillers)], seed: seed)
            let first = try XCTUnwrap(hits(bomb).first { $0.move == "population-bomb" })
            counts.insert(hits(bomb).filter { $0.move == "population-bomb" && $0.time == first.time }.count)
        }
        XCTAssertGreaterThan(counts.count, 1, "not always ten: \(counts)")
        XCTAssertTrue(counts.allSatisfy { (1...10).contains($0) })
        let kick = battle([try mon("hitmon", 106, level: 40, moves: ["triple-kick"])], [try mon("bliss", 242, moves: fillers)])
        let first = try XCTUnwrap(hits(kick).first { $0.move == "triple-kick" })
        let volley = hits(kick).filter { $0.move == "triple-kick" && $0.time == first.time }.map(\.damage)
        if volley.count == 3 { XCTAssertGreaterThan(volley[2], volley[0], "\(volley)") }
    }

    /// High Jump Kick that does not land costs half the HP; Steel Beam costs it, landed or not; Stone Axe lays
    /// Stealth Rock; Salt Cure takes an eighth a turn, a sixteenth of a boss.
    func testCrashCostsAndLeftovers() throws {
        let fillers = ["rain-dance", "sunny-day"]
        let kicker = try mon("hitmon", 106, moves: ["high-jump-kick"])
        let jump = battle([kicker], [try mon("gengar", 94, moves: fillers)])
        XCTAssertTrue(has(jump, .hurt(battler: "hitmon", amount: kicker.stats.hp / 2, hp: kicker.stats.hp - kicker.stats.hp / 2,
                                      cause: .recoil)), "a Ghost takes no kick")
        let beam = try mon("magne", 462, moves: ["steel-beam"])
        let steel = battle([beam], [try mon("lax", 143, moves: fillers)])
        XCTAssertTrue(has(steel, .hurt(battler: "magne", amount: (beam.stats.hp + 1) / 2, hp: beam.stats.hp - (beam.stats.hp + 1) / 2,
                                       cause: .recoil)))
        let axe = battle([try mon("kleavor", 900, level: 40, moves: ["stone-axe"])], [try mon("lax", 143, moves: fillers)])
        XCTAssertTrue(has(axe, .hazard(side: 1, hazard: "stealth-rock", layers: 1)))
        let lax = try mon("lax", 143, moves: fillers)
        let salt = battle([try mon("garg", 934, level: 30, moves: ["salt-cure", "rain-dance", "sunny-day"])], [lax])
        XCTAssertTrue(salt.events.contains {
            if case .hurt("lax", let amount, _, .curse) = $0.event { return amount == lax.stats.hp / 8 }
            return false
        })
        let boss = try mon("boss", 143, moves: fillers, isBoss: true)
        let onBoss = battle([try mon("garg", 934, level: 30, moves: ["salt-cure", "rain-dance", "sunny-day"])], [boss])
        XCTAssertFalse(onBoss.events.contains {
            if case .hurt("boss", let amount, _, .curse) = $0.event { return amount > boss.stats.hp / 16 }
            return false
        })
    }

    /// Rage Fist grows with each hit its user took; Gigaton Hammer is never used twice in a row; Laser Focus makes the
    /// next hit critical; Splash and its kin do nothing.
    func testRageFistGigatonLaserFocusSplash() throws {
        let fillers = ["rain-dance", "sunny-day"]
        let rage = battle([try mon("anni", 979, level: 50, moves: ["rage-fist"])], [try mon("shuckle", 213, moves: ["peck"])])
        let fists = hits(rage).filter { $0.move == "rage-fist" && $0.hp > 0 }.map(\.damage)
        XCTAssertGreaterThan(Double(try XCTUnwrap(fists.last)) / Double(try XCTUnwrap(fists.first)), 1.5, "\(fists)")
        // Alone in its loop: Struggle between two Hammers.
        let hammer = battle([try mon("tinka", 959, level: 30, moves: ["gigaton-hammer"])], [try mon("bliss", 242, moves: fillers)])
        let casts = hammer.events.compactMap { timed -> String? in
            if case .cast("tinka", let move, _, _) = timed.event { return move }
            return nil
        }
        XCTAssertFalse(zip(casts, casts.dropFirst()).contains { $0 == "gigaton-hammer" && $1 == "gigaton-hammer" }, "\(casts.prefix(6))")
        let laser = battle([try mon("lax", 143, moves: ["laser-focus", "body-slam"])], [try mon("bliss", 242, moves: fillers)])
        let focused = try XCTUnwrap(volatileAt(laser, "lax", "laser-focus"))
        XCTAssertTrue(laser.events.contains {
            if case .hit("lax", _, "body-slam", _, _, _, true) = $0.event { return $0.time > focused }
            return false
        })
        let splash = battle([try mon("karp", 129, moves: ["splash"])], [try mon("lax", 143, moves: fillers)])
        XCTAssertTrue(has(splash, .fail(battler: "karp", move: "splash", reason: .nothing)))
    }

    /// Powder makes the foe's next Fire move burst on it; Psycho Shift hands the user's status to the target; Victory
    /// Dance raises three stats.
    func testPowderPsychoShiftVictoryDance() throws {
        let fillers = ["rain-dance", "sunny-day"]
        let zard = try mon("zard", 6, level: 60, moves: ["flamethrower"])
        let powder = battle([try mon("vivi", 666, moves: ["powder"] + fillers)], [zard])
        XCTAssertTrue(powder.events.contains {
            if case .hurt("zard", let amount, _, .ability) = $0.event { return amount == zard.stats.hp / 4 }
            return false
        })
        let burnt = battle([try mon("lax", 143, moves: ["psycho-shift", "body-slam"], ability: "thick-fat")],
                           [try mon("sable", 302, level: 50, moves: ["will-o-wisp", "rain-dance"])])
        XCTAssertTrue(burnt.events.contains {
            if case .status("sable", .burn) = $0.event { return true }
            return false
        }, "Snorlax's burn moved onto Sableye")
        let dance = battle([try mon("quaq", 914, moves: ["victory-dance", "aqua-step"])], [try mon("lax", 143, moves: fillers)])
        for stat in [BattleStat.attack, .defense, .speed] {
            XCTAssertTrue(dance.events.contains {
                if case .stat("quaq", let s, 1) = $0.event { return s == stat }
                return false
            }, "\(stat)")
        }
    }

    // MARK: Genders, love and the rare moves

    /// A foe's gender follows its species' rate and stays the same for the same Pokémon; a player's is its profile's,
    /// or the one its profile will draw.
    func testGendersInBattle() throws {
        XCTAssertEqual(try mon("ditto", 132).resolvedGender, .genderless)
        XCTAssertEqual(try mon("chansey", 113).resolvedGender, .female, "female only")
        XCTAssertEqual(try mon("tauros", 128).resolvedGender, .male, "male only")
        let rats = (0..<200).compactMap { BattlerSpec.make(id: "foe\($0)-19", speciesID: 19, level: 30 + $0 % 40)?.resolvedGender }
        let females = rats.filter { $0 == .female }.count
        XCTAssertTrue((70...130).contains(females), "about half of Rattata are female: \(females)")
        XCTAssertEqual(try mon("rat", 19, level: 33).resolvedGender, try mon("rat", 19, level: 33).resolvedGender)
        var entry = DexEntry(baseID: 19, finalID: 19, chainOrder: [19], rarity: .common, caughtAt: nil)
        entry.profile = PokemonProfile.generate(seed: 42)
        let drawn = try XCTUnwrap(entry.profile).drawnGender(rate: 4)
        XCTAssertEqual(DungeonTeamBuilder.spec(for: entry)?.gender, drawn, "the profile's draw before it is enriched")
        entry.profile?.gender = drawn == .male ? .female : .male
        XCTAssertEqual(DungeonTeamBuilder.spec(for: entry)?.gender, entry.profile?.gender, "the profile's own once set")
    }

    /// Attract and Cute Charm make a foe of the other gender fall in love: it fails about half its casts while its
    /// love stands; the same gender or a genderless one do not fall. Captivate charms the other gender only.
    func testAttractCuteCharmAndCaptivate() throws {
        let fillers = ["rain-dance", "sunny-day"]
        func gendered(_ id: String, _ species: Int, _ moves: [String], _ gender: PokemonGender, ability: String? = nil) throws -> BattlerSpec {
            var spec = try mon(id, species, moves: moves, ability: ability)
            spec.gender = gender
            return spec
        }
        let love = battle([try gendered("clef", 36, ["attract"] + fillers, .female)], [try gendered("lax", 143, ["body-slam"], .male)])
        XCTAssertTrue(has(love, .volatile(battler: "lax", effect: "attract")))
        let smitten = love.events.filter { $0.event == .fail(battler: "lax", move: "body-slam", reason: .infatuation) }.count
        let slams = love.events.filter {
            if case .cast("lax", "body-slam", _, _) = $0.event { return true }
            return false
        }.count
        XCTAssertGreaterThan(smitten, slams / 4, "\(smitten) of \(slams)")
        let same = battle([try gendered("clef", 36, ["attract"] + fillers, .male)], [try gendered("lax", 143, ["body-slam"], .male)])
        XCTAssertFalse(has(same, .volatile(battler: "lax", effect: "attract")))
        let ditto = battle([try gendered("clef", 36, ["attract"] + fillers, .female)], [try mon("ditto", 132, moves: ["tackle"])])
        XCTAssertFalse(has(ditto, .volatile(battler: "ditto", effect: "attract")))
        let charm = battle([try gendered("clef", 36, fillers, .female, ability: "cute-charm")], [try gendered("lax", 143, ["body-slam"], .male)])
        XCTAssertTrue(has(charm, .volatile(battler: "lax", effect: "attract")))
        let captivate = battle([try gendered("clef", 36, ["captivate"] + fillers, .female)], [try gendered("zard", 6, ["flamethrower"], .female)])
        XCTAssertFalse(captivate.events.contains {
            if case .stat("zard", .specialAttack, _) = $0.event { return true }
            return false
        })
        XCTAssertFalse(captivate.events.contains {
            if case .cast("clef", "captivate", _, _) = $0.event { return true }
            return false
        }, "the same gender: never cast")
    }

    /// The moves whose effect does not come from their user's stats wait for a Technical Capsule, like the strongest
    /// (the owner, 2026-11-03).
    func testRareMovesAreLocked() throws {
        for slug in ["curse", "nightmare", "perish-song", "destiny-bond", "fissure", "super-fang", "endeavor", "counter", "bide"] {
            XCTAssertTrue(try XCTUnwrap(MoveTable.move(slug)).isLocked, slug)
        }
        for slug in ["seismic-toss", "night-shade", "toxic", "leech-seed", "swords-dance", "tackle"] {
            XCTAssertFalse(try XCTUnwrap(MoveTable.move(slug)).isLocked, slug)
        }
    }

    /// Every species loops at least one move: Metapod Harden, Ditto Transform, Wobbuffet Counter, Smeargle Sketch.
    func testEverySpeciesLoopsAMove() throws {
        let empty = SpeciesBattleTable.all.values.filter { $0.loop.isEmpty }.map(\.pokemonID).sorted()
        XCTAssertEqual(empty, [])
        XCTAssertEqual(SpeciesBattleTable.data(speciesID: 132)?.loop, ["transform"])
        XCTAssertTrue(SpeciesBattleTable.data(speciesID: 202)?.loop.contains("counter") ?? false)
        XCTAssertEqual(SpeciesBattleTable.data(speciesID: 235)?.loop, ["sketch"])
    }
}
