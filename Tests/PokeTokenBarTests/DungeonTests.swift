import XCTest
@testable import PokeTokenBar

/// The dungeons' catalog, team rules and expedition walk.
final class DungeonTests: XCTestCase {
    private let context = ExpeditionContext(tier: .t1, shinyDenominator: 64, now: Date(timeIntervalSince1970: 1_790_000_000))

    private func candidate(_ species: Int, rarity: Rarity = .common, shiny: Bool = false, id: String? = nil) -> DungeonCandidate {
        DungeonCandidate(entryID: id ?? "e\(species)", speciesID: species, baseID: SpeciesInfo.baseID(of: species), form: nil,
                         rarity: rarity, isShiny: shiny)
    }

    private func member(_ species: Int, level: Int = 100) throws -> ExpeditionMember {
        ExpeditionMember(entryID: "m\(species)", spec: try XCTUnwrap(BattlerSpec.make(id: "m\(species)", speciesID: species, level: level)))
    }

    // MARK: Challenge bosses

    /// The daily and weekly bosses (the owner, 2026-11-03): stronger than the same Pokémon anywhere else, the weekly's the
    /// most, and measured against their form's base stats, so that a Gigantamax Pikachu (320) stands about as long as a
    /// Primal Groudon (770). One factor for all left the first a walkover and the second out of reach.
    func testChallengeBossesAreTheStrongestAndEvenedByTheirBaseStats() throws {
        XCTAssertNil(ExpeditionEngine.challengeFactors(.ceruleanCave, baseTotal: 600))
        let daily = try XCTUnwrap(ExpeditionEngine.challengeFactors(.daily, baseTotal: 600))
        let weekly = try XCTUnwrap(ExpeditionEngine.challengeFactors(.weekly, baseTotal: 600))
        XCTAssertGreaterThan(weekly.hp, daily.hp)
        XCTAssertGreaterThan(weekly.stats, daily.stats)
        func spec(_ speciesID: Int, challenge: DungeonID?) throws -> BattlerSpec {
            let form = try XCTUnwrap(BattleForms.weekly.first { $0.speciesID == speciesID })
            var random = BattleRandom(seed: 1)
            return try XCTUnwrap(ExpeditionEngine.bossSpec(ExpeditionBoss(speciesID: speciesID, form: form.form, isShiny: false),
                                                           tier: .t5, challenge: challenge, random: &random))
        }
        let groudon = try spec(383, challenge: .weekly), pikachu = try spec(25, challenge: .weekly)
        let plainGroudon = try spec(383, challenge: nil), plainPikachu = try spec(25, challenge: nil)
        XCTAssertGreaterThan(groudon.stats.hp, plainGroudon.stats.hp, "a challenge's boss outlasts the same one elsewhere")
        XCTAssertGreaterThan(pikachu.stats.attack, plainPikachu.stats.attack)
        // The gap between the weakest and the strongest form narrows: Pikachu's HP against Groudon's.
        XCTAssertGreaterThan(Double(pikachu.stats.hp) / Double(groudon.stats.hp),
                             1.5 * Double(plainPikachu.stats.hp) / Double(plainGroudon.stats.hp))
    }

    /// The boss a daily expedition really meets takes the challenge's factors: more than Arceus's ×4.5 HP.
    func testADailyExpeditionMeetsTheChallengeBoss() throws {
        let dungeon = DungeonCatalog.dungeon(.daily)
        let team = try [150, 384, 383, 382, 487, 483].map { try member($0) }
        let mega = try XCTUnwrap(BattleForms.daily.first { $0.speciesID == 6 })
        let context = ExpeditionContext(tier: dungeon.tier, shinyDenominator: 64, now: Date(timeIntervalSince1970: 0))
        for seed in UInt64(1)...20 {
            var e = ExpeditionEngine.start(dungeon: dungeon, team: team, rules: [], teamSize: 6, seed: seed,
                                           cost: dungeon.floors * 1000, berries: [:], revives: [:], context: context,
                                           boss: ExpeditionBoss(speciesID: 6, form: mega.form, isShiny: false))
            while !e.isOver, case .exploring = e.phase {
                ExpeditionEngine.feed(&e, tokens: e.floorCost, context: context)
                if case .awaitingHeal = e.phase { ExpeditionEngine.answerHeal(&e, paid: false, context: context) }
            }
            let bossBattle = e.log.compactMap { entry -> ExpeditionBattle? in
                if case .battle(let battle) = entry.kind, battle.kind == .boss { return battle }
                return nil
            }.last
            guard let boss = bossBattle?.setup.sides[1].battlers.first else { continue }
            let data = try XCTUnwrap(SpeciesBattleTable.data(speciesID: 6, form: mega.form))
            let plain = BattleStats.computed(base: data.baseStats, ivs: Array(repeating: 31, count: 6), level: 100,
                                             nature: nil, speciesID: 6)
            // Its share one against one (2026-11-06) on top of the challenge's factors.
            XCTAssertGreaterThan(Double(boss.stats.hp), 4.6 * ExpeditionEngine.oneOnOneChallenge * Double(plain.hp))
            XCTAssertLessThan(Double(boss.stats.hp), 4.6 * Double(plain.hp), "lowered for one against one")
            return
        }
        XCTFail("no run reached the boss")
    }

    // MARK: Catalog

    func testThirteenDungeonsOverFiveTiers() {
        XCTAssertEqual(DungeonCatalog.all.filter { !$0.id.isChallenge }.count, 13)
        XCTAssertEqual(DungeonTier.allCases.map(\.floors), [5, 8, 10, 12, 15])
        let difficulty = 0.1
        // The daily dungeon at 200M (the owner, 2026-11-02), eight floors; the weekly one a T4's, twelve.
        XCTAssertEqual(DungeonCatalog.dungeon(.daily).cost(difficulty: difficulty), 200_000_000)
        XCTAssertEqual(DungeonCatalog.dungeon(.weekly).cost(difficulty: difficulty), 600_000_000)
        XCTAssertEqual([DungeonCatalog.dungeon(.daily).floors, DungeonCatalog.dungeon(.weekly).floors], [8, 12])
        XCTAssertEqual(DungeonTier.t1.cost(difficulty: difficulty), 75_000_000)
        XCTAssertEqual(DungeonTier.t2.cost(difficulty: difficulty), 187_500_000)
        XCTAssertEqual(DungeonTier.t3.cost(difficulty: difficulty), 300_000_000)
        XCTAssertEqual(DungeonTier.t4.cost(difficulty: difficulty), 600_000_000)
        XCTAssertEqual(DungeonTier.t5.cost(difficulty: difficulty), 900_000_000)
        XCTAssertEqual(DungeonTier.t4.keys, 1)
        XCTAssertEqual(DungeonTier.t5.keys, 1, "one key for the Hall of Origin since 2026-11-09")
    }

    /// Every dungeon has wild Pokémon, none legendary, and bosses the battle table knows; Arceus only at the end of
    /// the Hall of Origin (R13).
    func testWildPokemonAndBosses() {
        for dungeon in DungeonCatalog.all {
            XCTAssertFalse(dungeon.wild.isEmpty, dungeon.id.rawValue)
            XCTAssertFalse(dungeon.wild.contains { SpeciesInfo.all[$0]?.isLegendary == true }, dungeon.id.rawValue)
            // A challenge's boss is drawn among the battle forms the player lacks (`challengeBoss`).
            XCTAssertEqual(dungeon.bosses.isEmpty, dungeon.id.isChallenge, dungeon.id.rawValue)
            XCTAssertTrue(dungeon.bosses.allSatisfy { SpeciesBattleTable.data(speciesID: $0) != nil }, dungeon.id.rawValue)
            if dungeon.id != .hallOfOrigin { XCTAssertFalse(dungeon.bosses.contains(DungeonCatalog.arceusID), dungeon.id.rawValue) }
        }
        XCTAssertEqual(DungeonCatalog.dungeon(.hallOfOrigin).bosses, [DungeonCatalog.arceusID])
        XCTAssertEqual(DungeonCatalog.dungeon(.ceruleanCave).bosses, [150])
        XCTAssertEqual(Set(DungeonCatalog.dungeon(.mtCoronet).bosses), [483, 484, 487])
        XCTAssertTrue(DungeonCatalog.dungeon(.viridianForest).wild.allSatisfy {
            SpeciesBattleTable.data(speciesID: $0)!.types.contains { [.bug, .grass].contains($0) }
        })
    }

    func testTheRuinsOfAlphDrawTheirRules() {
        let first = DungeonCatalog.alphRules(seed: 1)
        XCTAssertEqual(first.teamSize, DungeonCatalog.alphRules(seed: 1).teamSize)
        XCTAssertTrue((3...6).contains(first.teamSize))
        XCTAssertFalse(first.rules.isEmpty)
    }

    // MARK: Team rules

    func testTheRulesOfATeam() {
        let pidgey = candidate(16), clefairy = candidate(35, rarity: .uncommon), mewtwo = candidate(150, rarity: .legendary)
        XCTAssertTrue(DungeonTeamRules.admits(pidgey, rules: [.maxRarity(.common)]))
        XCTAssertFalse(DungeonTeamRules.admits(clefairy, rules: [.maxRarity(.common)]))
        XCTAssertFalse(DungeonTeamRules.admits(mewtwo, rules: [.noLegendary]))
        XCTAssertTrue(DungeonTeamRules.admits(mewtwo, rules: [.onlyLegendaries]))
        XCTAssertTrue(DungeonTeamRules.admits(candidate(6), rules: [.onlyStarters]))
        XCTAssertFalse(DungeonTeamRules.admits(pidgey, rules: [.onlyStarters]))
        XCTAssertFalse(DungeonTeamRules.admits(candidate(9), rules: [.bannedType(.water)]))
        XCTAssertFalse(DungeonTeamRules.admits(pidgey, rules: [.onlyShinies]))
        XCTAssertTrue(DungeonTeamRules.admits(candidate(16, shiny: true), rules: [.onlyShinies]))
        XCTAssertFalse(DungeonTeamRules.holds(.atMostOneLegendary, for: [mewtwo, candidate(144, rarity: .legendary)]))
        XCTAssertTrue(DungeonTeamRules.holds(.sharedType, for: [candidate(6), candidate(4), candidate(37)]))
        XCTAssertFalse(DungeonTeamRules.holds(.sharedType, for: [candidate(6), candidate(9)]))
        XCTAssertTrue(DungeonTeamRules.holds(.oneRegion, for: [candidate(6), candidate(9)]))
        XCTAssertFalse(DungeonTeamRules.holds(.oneRegion, for: [candidate(6), candidate(157)]))
        XCTAssertFalse(DungeonTeamRules.isValid([pidgey, pidgey], size: 2, rules: []), "one species once")
        XCTAssertFalse(DungeonTeamRules.isValid([pidgey], size: 3, rules: []), "the dungeon's size exactly")
        XCTAssertTrue(DungeonTeamRules.isValid([pidgey, candidate(19), candidate(10)], size: 3, rules: [.maxRarity(.common)]))
    }

    /// Q8: the strongest the rules allow; a shared-type rule keeps one type.
    func testComposeForMeKeepsTheRules() throws {
        let species = [6, 9, 3, 25, 130, 149, 248, 143, 65, 94, 68, 59, 135, 26, 125]
        let pool = species.compactMap { id -> (candidate: DungeonCandidate, spec: BattlerSpec)? in
            guard let spec = BattlerSpec.make(id: "e\(id)", speciesID: id, level: 100) else { return nil }
            return (candidate(id, rarity: SpeciesInfo.lineRarity(of: id)), spec)
        }
        let plant = DungeonCatalog.dungeon(.powerPlant)
        let team = DungeonTeamBuilder.compose(pool, dungeon: plant, size: 3, rules: [.sharedType])
        XCTAssertEqual(team.count, 3)
        let picked = pool.filter { team.contains($0.candidate.entryID) }.map(\.candidate)
        XCTAssertTrue(DungeonTeamRules.isValid(picked, size: 3, rules: [.sharedType]))
        let forest = DungeonTeamBuilder.compose(pool, dungeon: DungeonCatalog.dungeon(.viridianForest), size: 3,
                                                rules: [.maxRarity(.common)])
        XCTAssertTrue(pool.filter { forest.contains($0.candidate.entryID) }.allSatisfy { $0.candidate.rarity == .common })
    }

    // MARK: The expedition

    private func start(_ id: DungeonID, team: [ExpeditionMember], seed: UInt64 = 1, revives: [String: Int] = [:]) -> Expedition {
        let dungeon = DungeonCatalog.dungeon(id)
        return ExpeditionEngine.start(dungeon: dungeon, team: team, rules: dungeon.rules, teamSize: team.count, seed: seed,
                                      cost: dungeon.floors * 1000, berries: [:], revives: revives,
                                      context: ExpeditionContext(tier: dungeon.tier, shinyDenominator: 64, now: context.now))
    }

    /// Tokens fill floor after floor, each playing its event, a branch every three floors, the boss at the end.
    func testTokensWalkTheTeamToTheBoss() throws {
        var e = start(.viridianForest, team: [try member(6), try member(9), try member(3)])
        let ctx = ExpeditionContext(tier: .t1, shinyDenominator: 64, now: context.now)
        XCTAssertEqual(e.floorCost, 1000)
        ExpeditionEngine.feed(&e, tokens: 999, context: ctx)
        XCTAssertEqual(e.floor, 1)
        XCTAssertTrue(e.log.isEmpty)
        ExpeditionEngine.feed(&e, tokens: 1, context: ctx)
        XCTAssertEqual(e.floor, 2)
        XCTAssertFalse(e.log.isEmpty)
        while !e.isOver, case .exploring = e.phase {
            ExpeditionEngine.feed(&e, tokens: 1000, context: ctx)
            if case .awaitingHeal = e.phase { ExpeditionEngine.answerHeal(&e, paid: false, context: ctx) }
        }
        XCTAssertTrue(e.bossReached)
        XCTAssertTrue(e.log.contains { if case .branch = $0.kind { return true }; return false })
        XCTAssertTrue(e.team.allSatisfy { $0.spec.hp >= 0 && $0.spec.hp <= $0.spec.stats.hp })
        guard case .capture(let left) = e.phase else { return XCTFail("three strong starters beat a forest boss: \(e.phase)") }
        XCTAssertEqual(left, 3)
        XCTAssertTrue(ExpeditionEngine.throwBall(&e, ball: .masterBall, context: ctx))
        XCTAssertEqual(e.phase, .finished(won: true))
        XCTAssertEqual(e.loot.eggs.last?.baseID, SpeciesInfo.baseID(of: e.boss.speciesID))
    }

    func testTheSameSeedWalksTheSameDungeon() throws {
        let team = [try member(6), try member(9), try member(3)]
        let ctx = ExpeditionContext(tier: .t1, shinyDenominator: 64, now: context.now)
        var a = start(.viridianForest, team: team, seed: 9), b = start(.viridianForest, team: team, seed: 9)
        ExpeditionEngine.feed(&a, tokens: 3500, context: ctx)
        for _ in 0..<7 { ExpeditionEngine.feed(&b, tokens: 500, context: ctx) }
        XCTAssertEqual(a, b, "tokens in one go or in pieces walk the same floors")
    }

    /// Three failed throws: the boss stays, the loot is kept (it fell).
    func testThreeMissedThrowsEndTheCapture() throws {
        var e = start(.viridianForest, team: [try member(6)])
        e.phase = .capture(throwsLeft: 3)
        e.boss = ExpeditionBoss(speciesID: 150, form: nil, isShiny: false)
        let ctx = ExpeditionContext(tier: .t1, shinyDenominator: 64, now: context.now)
        var caught = false
        for _ in 0..<3 where !caught { caught = ExpeditionEngine.throwBall(&e, ball: nil, context: ctx) }
        XCTAssertEqual(e.phase, .finished(won: true))
        XCTAssertFalse(ExpeditionEngine.throwBall(&e, ball: .masterBall, context: ctx), "no fourth throw")
    }

    /// A weak team falls, and the whole team down ends the expedition lost (Q3).
    func testAWeakTeamLoses() throws {
        var e = start(.ceruleanCave, team: [try member(10, level: 5), try member(13, level: 5)])
        let ctx = ExpeditionContext(tier: .t4, shinyDenominator: 64, now: context.now)
        for _ in 0..<20 where !e.isOver {
            ExpeditionEngine.feed(&e, tokens: e.floorCost, context: ctx)
            if case .awaitingHeal = e.phase { ExpeditionEngine.answerHeal(&e, paid: false, context: ctx) }
        }
        XCTAssertEqual(e.phase, .finished(won: false))
        XCTAssertTrue(e.log.contains { $0.kind == .defeat })
    }

    /// R5: under a quarter of the team's HP, the team waits for the heal once. Since 2026-11-09 it takes no token
    /// while it waits, nor the rest of the feed that offered the heal: they go back to growth (the owner: a day away
    /// from the app was a day of growth lost). A reserve a save from before holds still walks on at the answer.
    func testTheEmergencyHealWaitsAndGivesTheTokensBack() throws {
        let ctx = ExpeditionContext(tier: .t1, shinyDenominator: 64, now: context.now)
        var waiting: Expedition?
        for seed in UInt64(1)...60 where waiting == nil {
            var e = start(.viridianForest, team: [try member(6), try member(9), try member(3)], seed: seed)
            for i in e.team.indices { e.team[i].spec.hp = max(1, e.team[i].spec.stats.hp / 10) }
            // A floor and some (a floor is 1000): the rest after the floor that offers the heal.
            let left = ExpeditionEngine.feed(&e, tokens: 1400, context: ctx)
            if case .awaitingHeal = e.phase {
                waiting = e
                XCTAssertEqual(left, 1400 - e.tokensIn, "the rest of the feed that offered the heal goes back")
                XCTAssertGreaterThan(left, 0)
            }
        }
        var e = try XCTUnwrap(waiting, "some floor leaves the team under a quarter of its HP")
        guard case .awaitingHeal(let price) = e.phase else { return XCTFail() }
        XCTAssertEqual(price, ExpeditionEngine.healPrice(cost: e.cost))
        let floor = e.floor, tokensIn = e.tokensIn
        XCTAssertEqual(ExpeditionEngine.feed(&e, tokens: 500, context: ctx), 500, "the wait's tokens go back")
        XCTAssertEqual(e.reserve, 0)
        XCTAssertEqual(e.tokensIn, tokensIn)
        XCTAssertEqual(e.floor, floor, "the team waits")
        e.reserve = 500  // a save from before 2026-11-09
        ExpeditionEngine.answerHeal(&e, paid: true, context: ctx)
        XCTAssertTrue(e.healUsed)
        XCTAssertEqual(e.reserve, 0)
        XCTAssertEqual(e.floorTokens, 500, "an old reserve went into the next floor")
        XCTAssertTrue(e.team.allSatisfy { $0.spec.hp == $0.spec.stats.hp })
        // Offered once: falling under a quarter again asks nothing.
        for i in e.team.indices { e.team[i].spec.hp = 1 }
        ExpeditionEngine.feed(&e, tokens: 500, context: ctx)
        if case .awaitingHeal = e.phase { XCTFail("the heal is offered once") }
    }

    /// Revives taken along get the knocked out up after a battle, Max Revives first.
    func testRevivesGetTheFallenUp() throws {
        let ctx = ExpeditionContext(tier: .t2, shinyDenominator: 64, now: context.now)
        var revived = false
        for seed in UInt64(1)...20 where !revived {
            var e = start(.mtEmber, team: [try member(10, level: 5), try member(6)], seed: seed,
                          revives: [ItemKind.maxRevive.rawValue: 5])
            for _ in 0..<7 where !e.isOver {
                ExpeditionEngine.feed(&e, tokens: e.floorCost, context: ctx)
                if case .awaitingHeal = e.phase { ExpeditionEngine.answerHeal(&e, paid: false, context: ctx) }
            }
            revived = e.log.contains { if case .revive("m10", true) = $0.kind { return true }; return false }
            if revived { XCTAssertLessThan(e.revives[ItemKind.maxRevive.rawValue] ?? 0, 5) }
        }
        XCTAssertTrue(revived, "the level 5 Caterpie falls in some battle and gets up")
    }

    /// Q19: a throw's odds by rarity.
    func testCaptureOdds() {
        XCTAssertEqual(ExpeditionEngine.captureOdds(.common), 0.60)
        XCTAssertEqual(ExpeditionEngine.captureOdds(.uncommon), 0.45)
        XCTAssertEqual(ExpeditionEngine.captureOdds(.rare), 0.30)
        XCTAssertEqual(ExpeditionEngine.captureOdds(.legendary), 0.12)
    }

    /// Arceus's own odds, one in three a throw (the owner, 2026-11-09), with the balls' factors and the Master Ball
    /// still sure; the other legendary bosses keep 12%.
    func testArceusIsCaughtOneThrowInThree() {
        let arceus = ExpeditionBoss(speciesID: DungeonCatalog.arceusID, form: nil, isShiny: false)
        XCTAssertEqual(ExpeditionEngine.throwOdds(arceus, ball: nil), 1.0 / 3, accuracy: 1e-9)
        XCTAssertEqual(ExpeditionEngine.throwOdds(arceus, ball: .greatBall), 0.5, accuracy: 1e-9)
        XCTAssertEqual(ExpeditionEngine.throwOdds(arceus, ball: .ultraBall), 2.0 / 3, accuracy: 1e-9)
        XCTAssertEqual(ExpeditionEngine.throwOdds(arceus, ball: .masterBall), 1)
        XCTAssertEqual(1 - pow(1 - ExpeditionEngine.throwOdds(arceus, ball: nil), 3), 0.70, accuracy: 0.01,
                       "about 70% over the three Poké Balls")
        let giratina = ExpeditionBoss(speciesID: 487, form: nil, isShiny: false)
        XCTAssertEqual(ExpeditionEngine.throwOdds(giratina, ball: nil), 0.12, accuracy: 1e-9)
        XCTAssertEqual(ExpeditionEngine.throwOdds(giratina, ball: .masterBall), 1)
        // The throws at the fallen Arceus catch him at that rate.
        var caught = 0
        for seed in 0..<600 {
            var e = Expedition(dungeon: .hallOfOrigin, teamSize: 6, rules: [], startedAt: Date(timeIntervalSince1970: 0),
                               seed: UInt64(seed) &* 7919, cost: 0, team: [], boss: arceus, candiesLeft: 0, berries: [:],
                               revives: [:])
            e.phase = .capture(throwsLeft: 1)
            if ExpeditionEngine.throwBall(&e, ball: nil, context: ExpeditionContext(tier: .t5, shinyDenominator: 64,
                                                                                  now: Date(timeIntervalSince1970: 0))) {
                caught += 1
            }
        }
        XCTAssertEqual(Double(caught) / 600, 1.0 / 3, accuracy: 0.06)
    }

    /// The chests' eggs grow with the tier (the owner, 2026-11-04): none in T1, which draws nothing for them so its
    /// walks stay what they were; an Uncommon Egg one chest in 8 in T2; a Rare Egg one in 10 in T3; a Legendary Egg one
    /// in 50 in T4 (else a Rare Egg 3 in 20); one in 15 in T5 (else a Rare Egg one in 5).
    func testTheChestsEggsGrowWithTheTier() {
        let draws = 30_000
        var found: [DungeonTier: [ItemKind: Int]] = [:]
        for tier in DungeonTier.allCases {
            var random = BattleRandom(seed: 7)
            for _ in 0..<draws {
                if let egg = ExpeditionEngine.chestEgg(tier, random: &random) { found[tier, default: [:]][egg, default: 0] += 1 }
            }
        }
        XCTAssertNil(found[.t1], "no egg in T1")
        var t1 = BattleRandom(seed: 7), untouched = BattleRandom(seed: 7)
        _ = ExpeditionEngine.chestEgg(.t1, random: &t1)
        XCTAssertEqual(t1.below(1_000_000), untouched.below(1_000_000), "T1 draws nothing")
        func share(_ tier: DungeonTier, _ egg: ItemKind) -> Double { Double(found[tier]?[egg] ?? 0) / Double(draws) }
        XCTAssertEqual(Set(found[.t2]?.keys ?? [:].keys), [.uncommonEgg])
        XCTAssertEqual(share(.t2, .uncommonEgg), 1 / 8, accuracy: 0.01)
        XCTAssertEqual(Set(found[.t3]?.keys ?? [:].keys), [.rareEgg])
        XCTAssertEqual(share(.t3, .rareEgg), 1 / 10, accuracy: 0.01)
        XCTAssertEqual(Set(found[.t4]?.keys ?? [:].keys), [.rareEgg, .legendaryEgg])
        XCTAssertEqual(share(.t4, .legendaryEgg), 1 / 50, accuracy: 0.004)
        XCTAssertEqual(share(.t4, .rareEgg), 0.15, accuracy: 0.01)
        XCTAssertEqual(Set(found[.t5]?.keys ?? [:].keys), [.rareEgg, .legendaryEgg])
        XCTAssertEqual(share(.t5, .legendaryEgg), 1 / 15, accuracy: 0.008)
        XCTAssertEqual(share(.t5, .rareEgg), 0.2, accuracy: 0.01)
        XCTAssertTrue(ExpeditionEngine.isRare({ var l = ExpeditionLoot(); l.add(.rareEgg); return l }()))
        XCTAssertTrue(ExpeditionEngine.isRare({ var l = ExpeditionLoot(); l.add(.legendaryEgg); return l }()))
        XCTAssertFalse(ExpeditionEngine.isRare({ var l = ExpeditionLoot(); l.add(.uncommonEgg); return l }()))
    }

    /// A boss already caught gives an egg of its tier's rarity, a legendary had shiny a Legendary Egg (the owner,
    /// 2026-11-04).
    func testABossCaughtAgainGivesItsTiersEgg() {
        XCTAssertEqual(DungeonTier.allCases.map(ExpeditionEngine.tierEgg),
                       [.pokemonEgg, .uncommonEgg, .rareEgg, .rareEgg, .legendaryEgg])
        XCTAssertEqual(ExpeditionEngine.eggInPlace(.tierEgg, tier: .t3), .rareEgg)
        XCTAssertEqual(ExpeditionEngine.eggInPlace(.legendaryEgg, tier: .t3), .legendaryEgg)
        XCTAssertNil(ExpeditionEngine.eggInPlace(.ownEgg, tier: .t3))
        XCTAssertNil(ExpeditionEngine.eggInPlace(nil, tier: .t3))
    }

    /// A legendary whose egg was won once falls with no throw: the expedition ends, won, its loot only.
    func testABossGivingTheLootOnlyEndsAsItFalls() throws {
        var e = start(.viridianForest, team: [try member(6), try member(9), try member(3)])
        e.bossReward = .lootOnly
        let ctx = ExpeditionContext(tier: .t1, shinyDenominator: 64, now: context.now)
        while !e.isOver, case .exploring = e.phase {
            ExpeditionEngine.feed(&e, tokens: 1000, context: ctx)
            if case .awaitingHeal = e.phase { ExpeditionEngine.answerHeal(&e, paid: false, context: ctx) }
        }
        XCTAssertEqual(e.phase, .finished(won: true))
        XCTAssertTrue(e.log.contains { if case .victory = $0.kind { return true }; return false })
        XCTAssertFalse(e.log.contains { if case .capture = $0.kind { return true }; return false })
        XCTAssertTrue(e.loot.eggs.isEmpty)
    }
}
