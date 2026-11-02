import XCTest
@testable import PokeTokenBar

/// The looped real-time battle engine, one mechanic at a time, then thousands of random battles.
final class BattleEngineTests: XCTestCase {
    private func mon(_ id: String, _ species: Int, level: Int = 100, moves: [String]? = nil, ability: String? = nil,
                     isBoss: Bool = false) throws -> BattlerSpec {
        try XCTUnwrap(BattlerSpec.make(id: id, speciesID: species, level: level, ability: ability, moves: moves,
                                       isBoss: isBoss))
    }

    private func battle(_ mine: [BattlerSpec], _ theirs: [BattlerSpec], active: Int = 1, seed: UInt64 = 1,
                        berries: [BattleBerry: Int] = [:]) -> BattleOutcome {
        BattleEngine.run(BattleSetup(sides: [BattleSideSpec(battlers: mine, active: active, berries: berries),
                                             BattleSideSpec(battlers: theirs, active: active)], seed: seed))
    }

    private func events(_ outcome: BattleOutcome, _ match: (BattleEvent) -> Bool) -> [TimedBattleEvent] {
        outcome.events.filter { match($0.event) }
    }

    // MARK: Data

    func testTheMoveTableReadsPokeAPIsData() throws {
        let earthquake = try XCTUnwrap(MoveTable.move("earthquake"))
        XCTAssertEqual(earthquake.type, .ground)
        XCTAssertEqual(earthquake.moveClass, .physical)
        XCTAssertEqual(earthquake.power, 100)
        XCTAssertTrue(earthquake.hitsAllOpponents)
        XCTAssertGreaterThan(MoveTable.all.count, 900)
        XCTAssertGreaterThan(SpeciesBattleTable.all.count, 1300)
        let garchomp = try XCTUnwrap(SpeciesBattleTable.data(speciesID: 445))
        XCTAssertEqual(garchomp.baseStats, [108, 130, 95, 80, 85, 102])
        XCTAssertEqual(garchomp.types, [.dragon, .ground])
        XCTAssertEqual(SpeciesBattleTable.data(speciesID: 1)?.abilities.last?.slug, "chlorophyll")
        XCTAssertEqual(SpeciesBattleTable.data(speciesID: 1)?.abilities.last?.hidden, true)
    }

    /// R1: a base by the move (priority 0.8 s, status 1.2 s, by power 1.5 to 3.8 s, two more seconds to charge or
    /// recharge); validated 2026-10-30: offensive moves of 100 power or more are locked.
    func testCastBasesAndLocks() throws {
        func base(_ slug: String) throws -> Int { try XCTUnwrap(MoveTable.move(slug)).castBase }
        XCTAssertEqual(try base("quick-attack"), 800)
        XCTAssertEqual(try base("swords-dance"), 1200)
        XCTAssertEqual(try base("tackle"), 1500)
        XCTAssertEqual(try base("dark-pulse"), 2200)
        XCTAssertEqual(try base("earthquake"), 3000)
        XCTAssertEqual(try base("hyper-beam"), 5800)
        XCTAssertEqual(try base("solar-beam"), 5000)
        XCTAssertTrue(try XCTUnwrap(MoveTable.move("earthquake")).isLocked)
        XCTAssertFalse(try XCTUnwrap(MoveTable.move("dark-pulse")).isLocked)
        XCTAssertFalse(try XCTUnwrap(MoveTable.move("swords-dance")).isLocked)
        XCTAssertTrue(try XCTUnwrap(MoveTable.move("swords-dance")).hasEffect)
        XCTAssertFalse(try XCTUnwrap(MoveTable.move("splash")).hasEffect)
    }

    // MARK: The clock

    /// A cast lasts its base × 300 / (100 + Speed), then a third (R1).
    func testACastLastsByItsMoveAndItsCastersSpeed() throws {
        let gengar = try mon("gengar", 94, moves: ["dark-pulse"])
        let outcome = battle([gengar], [try mon("hypno", 97)])
        let first = try XCTUnwrap(outcome.events.first {
            if case .cast(let battler, _, _, _) = $0.event { return battler == "gengar" }
            return false
        })
        guard case .cast(_, let move, _, let ends) = first.event else { return XCTFail() }
        XCTAssertEqual(move, "dark-pulse")
        XCTAssertEqual(ends, Int((2200.0 * 300 / Double(100 + gengar.stats.speed) / 3).rounded()))
    }

    func testTheSameSeedPlaysTheSameBattle() throws {
        let mine = [try mon("a", 445), try mon("b", 248)]
        let theirs = [try mon("c", 149), try mon("d", 130)]
        XCTAssertEqual(battle(mine, theirs, seed: 7), battle(mine, theirs, seed: 7))
        XCTAssertNotEqual(battle(mine, theirs, seed: 7).events, battle(mine, theirs, seed: 8).events)
    }

    // MARK: Hits

    /// The proposal's reference: the owner's Careful Gengar (Sp. Atk 246) casts Hex at a level 90 Hypno with IVs of
    /// 15 (Sp. Def 225): power 65, STAB, Ghost on Psychic, 152 to 182 without a critical hit. The proposal said 154:
    /// it rounded once at the end, the games round each step (61 × 0.85 = 51, × 1.5 = 76, × 2 = 152).
    func testTheReferenceHexOnHypno() throws {
        let gengar = try XCTUnwrap(BattlerSpec.make(id: "gengar", speciesID: 94, level: 100, ivs: [29, 20, 20, 9, 28, 17],
                                                    nature: .careful, moves: ["hex"]))
        XCTAssertEqual(gengar.stats.specialAttack, 246)
        XCTAssertEqual(gengar.stats.speed, 242)
        let hypno = try XCTUnwrap(BattlerSpec.make(id: "hypno", speciesID: 97, level: 90, ivs: Array(repeating: 15, count: 6),
                                                   moves: ["growl"]))
        XCTAssertEqual(hypno.stats.specialDefense, 225)
        for seed in UInt64(1)...20 {
            let outcome = battle([gengar], [hypno], seed: seed)
            let first = outcome.events.first { if case .hit("gengar", "hypno", "hex", _, _, _, _) = $0.event { return true }; return false }
            guard case .hit(_, _, _, let damage, _, _, false)? = first?.event else { continue }
            XCTAssertTrue((152...182).contains(damage), "\(damage)")
        }
    }

    func testAGroundMoveDoesNothingToAFlyingFoe() throws {
        let outcome = battle([try mon("chomp", 445, moves: ["earthquake"])], [try mon("pidgeot", 18, moves: ["growl"])])
        XCTAssertTrue(events(outcome) { if case .hit(let a, _, _, _, _, _, _) = $0 { return a == "chomp" }; return false }.isEmpty)
        XCTAssertFalse(events(outcome) { if case .noEffect = $0 { return true }; return false }.isEmpty)
    }

    /// R3: a spread move hits every foe at 75%, never an ally.
    func testASpreadMoveHitsEveryFoeAtThreeQuarters() throws {
        let chomp = try mon("chomp", 445, moves: ["earthquake"])
        let ally = try mon("ally", 248, moves: ["growl"])
        let foes = [try mon("f1", 76, moves: ["growl"]), try mon("f2", 95, moves: ["growl"])]
        let outcome = battle([chomp, ally], foes, active: 2)
        let first = events(outcome) { if case .hit(let a, _, "earthquake", _, _, _, _) = $0 { return a == "chomp" }; return false }
        let targets = Set(first.prefix(2).compactMap { e -> String? in
            if case .hit(_, let target, _, _, _, _, _) = e.event { return target }
            return nil
        })
        XCTAssertEqual(targets, ["f1", "f2"])
        XCTAssertEqual(first[0].time, first[1].time)
        XCTAssertTrue(events(outcome) { if case .hit("chomp", "ally", _, _, _, _, _) = $0 { return true }; return false }.isEmpty)
    }

    func testABossNeverFallsToAOneHitKnockOut() throws {
        let outcome = battle([try mon("dug", 51, moves: ["fissure"])], [try mon("boss", 6, moves: ["growl"], isBoss: true)])
        XCTAssertTrue(events(outcome) { if case .hit(_, "boss", "fissure", _, _, _, _) = $0 { return true }; return false }.isEmpty)
    }

    // MARK: Status

    /// Burn halves physical damage and hurts a sixteenth every four seconds.
    func testABurnHurtsEveryFourSeconds() throws {
        let outcome = battle([try mon("zard", 6, moves: ["will-o-wisp"])], [try mon("snorlax", 143, moves: ["growl"])],
                             seed: 3)
        let burns = events(outcome) { if case .hurt("snorlax", _, _, .burn) = $0 { return true }; return false }
        XCTAssertFalse(burns.isEmpty)
        let snorlax = try mon("snorlax", 143)
        for burn in burns {
            XCTAssertEqual(burn.time % BattleRules.residualTick, 0)
            if case .hurt(_, let amount, _, _) = burn.event { XCTAssertEqual(amount, snorlax.stats.hp / 16) }
        }
    }

    /// Asleep, a Pokémon starts no cast until it wakes.
    func testASleepingPokemonCastsNothing() throws {
        let outcome = battle([try mon("breloom", 286, moves: ["spore"])], [try mon("snorlax", 143, moves: ["body-slam"])],
                             seed: 5)
        let slept = try XCTUnwrap(events(outcome) { if case .status("snorlax", .sleep) = $0 { return true }; return false }.first)
        let woke = events(outcome) { if case .cure("snorlax", .sleep) = $0 { return true }; return false }.first?.time ?? outcome.duration
        let casts = events(outcome) { if case .cast("snorlax", _, _, _) = $0 { return true }; return false }
        XCTAssertFalse(casts.contains { $0.time > slept.time && $0.time < woke })
    }

    func testSwordsDanceRaisesAttackTwoStages() throws {
        let outcome = battle([try mon("scizor", 212, moves: ["swords-dance", "bullet-punch"])],
                             [try mon("snorlax", 143, moves: ["growl"])])
        XCTAssertTrue(events(outcome) { if case .stat("scizor", .attack, 2) = $0 { return true }; return false }.count >= 1)
    }

    // MARK: The bench

    /// The foes keep their order: the first falls, the second steps in a second later.
    func testTheNextPokemonStepsInOneSecondAfterAKnockOut() throws {
        let outcome = battle([try mon("foe", 248, moves: ["stone-edge"])],
                             [try mon("weak", 10, level: 5, moves: ["tackle"]), try mon("next", 445, moves: ["dragon-claw"])])
        let faint = try XCTUnwrap(events(outcome) { if case .faint("weak") = $0 { return true }; return false }.first)
        let enter = try XCTUnwrap(events(outcome) { if case .enter(1, 0, "next") = $0 { return true }; return false }.first)
        XCTAssertEqual(enter.time, faint.time + BattleRules.benchDelay)
    }

    /// Q13: the app sends its best against the foe in front: water against fire.
    func testTheBenchSendsTheBestAgainstTheFoe() throws {
        let outcome = battle([try mon("leaf", 3, moves: ["energy-ball"]), try mon("wave", 9, moves: ["surf"])],
                             [try mon("fire", 6, moves: ["flamethrower"])])
        let first = try XCTUnwrap(events(outcome) { if case .enter(0, _, _) = $0 { return true }; return false }.first)
        XCTAssertEqual(first.event, .enter(side: 0, slot: 0, battler: "wave"))
    }

    func testIntimidateLowersTheFoesAttackOnEntry() throws {
        let outcome = battle([try mon("gyara", 130, ability: "intimidate")], [try mon("chomp", 445)])
        XCTAssertTrue(events(outcome) { if case .stat("chomp", .attack, -1) = $0 { return true }; return false }.count >= 1)
    }

    func testABerryIsEatenWhenHPFallUnderHalf() throws {
        let outcome = battle([try mon("lapras", 131, moves: ["tail-whip"]), try mon("snorlax", 143, moves: ["tail-whip"])],
                             [try mon("machamp", 68, moves: ["karate-chop"])], berries: [.oran: 1])
        let berries = events(outcome) { if case .berry(_, .oran) = $0 { return true }; return false }
        XCTAssertEqual(berries.count, 1, "one Oran for the side")
        XCTAssertEqual(outcome.berriesLeft[0][.oran], 0)
    }

    // MARK: Random battles

    /// Thousands of battles at random: each ends, no HP ever below zero, events in time order, the limit kept.
    func testRandomBattlesAlwaysEndCleanly() throws {
        var random = BattleRandom(seed: 2026)
        let ids = SpeciesBattleTable.all.keys.filter { $0 <= 1025 }.sorted()
        for round in 0..<600 {
            func team(_ side: String) -> [BattlerSpec] {
                (0..<(1 + random.below(6))).compactMap { i in
                    BattlerSpec.make(id: "\(side)\(i)", speciesID: ids[random.below(ids.count)],
                                     level: 40 + random.below(61), ivs: (0..<6).map { _ in random.below(32) })
                }
            }
            let mine = team("m"), theirs = team("t")
            guard !mine.isEmpty, !theirs.isEmpty else { continue }
            let active = 1 + random.below(min(3, max(mine.count, theirs.count)))
            let outcome = battle(mine, theirs, active: active, seed: UInt64(round))
            XCTAssertTrue([0, 1].contains(outcome.winner))
            XCTAssertLessThanOrEqual(outcome.duration, BattleRules.timeLimit)
            XCTAssertEqual(outcome.events.map(\.time), outcome.events.map(\.time).sorted(), "round \(round)")
            for event in outcome.events {
                switch event.event {
                case .hit(_, _, _, let damage, let hp, _, _): XCTAssertGreaterThanOrEqual(hp, 0); XCTAssertGreaterThanOrEqual(damage, 0)
                case .hurt(_, _, let hp, _), .heal(_, _, let hp, _): XCTAssertGreaterThanOrEqual(hp, 0)
                default: break
                }
            }
            for spec in mine + theirs {
                let left = try XCTUnwrap(outcome.hpLeft[spec.id])
                XCTAssertTrue((0...spec.stats.hp).contains(left))
            }
            let losers = (outcome.winner == 0 ? theirs : mine)
            if outcome.duration < BattleRules.timeLimit {
                XCTAssertTrue(losers.allSatisfy { outcome.hpLeft[$0.id] == 0 }, "round \(round)")
            }
        }
    }
}
