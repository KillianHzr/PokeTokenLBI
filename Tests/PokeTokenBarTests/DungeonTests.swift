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
        XCTAssertEqual(DungeonTier.t5.keys, 3)
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

    /// R5: under a quarter of the team's HP, the team waits for the heal once; the tokens go to the reserve and are
    /// played once it is answered.
    func testTheEmergencyHealWaitsWithTheReserve() throws {
        let ctx = ExpeditionContext(tier: .t1, shinyDenominator: 64, now: context.now)
        var waiting: Expedition?
        for seed in UInt64(1)...60 where waiting == nil {
            var e = start(.viridianForest, team: [try member(6), try member(9), try member(3)], seed: seed)
            for i in e.team.indices { e.team[i].spec.hp = max(1, e.team[i].spec.stats.hp / 10) }
            ExpeditionEngine.feed(&e, tokens: 1000, context: ctx)
            if case .awaitingHeal = e.phase { waiting = e }
        }
        var e = try XCTUnwrap(waiting, "some floor leaves the team under a quarter of its HP")
        guard case .awaitingHeal(let price) = e.phase else { return XCTFail() }
        XCTAssertEqual(price, ExpeditionEngine.healPrice(cost: e.cost))
        let floor = e.floor
        ExpeditionEngine.feed(&e, tokens: 500, context: ctx)
        XCTAssertEqual(e.reserve, 500)
        XCTAssertEqual(e.floor, floor, "the team waits")
        ExpeditionEngine.answerHeal(&e, paid: true, context: ctx)
        XCTAssertTrue(e.healUsed)
        XCTAssertEqual(e.reserve, 0)
        XCTAssertEqual(e.floorTokens, 500, "the reserve went into the next floor")
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
}
