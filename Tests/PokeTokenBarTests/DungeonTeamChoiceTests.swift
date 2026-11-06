import XCTest
@testable import PokeTokenBar

/// The team screen redone on 2026-11-06: what the types say against a dungeon (#139), "Compose for me" deciding by
/// the simulation, the odds of winning beside those of reaching the boss, and what the dice's two paths hold.
final class DungeonTeamChoiceTests: XCTestCase {
    private func spec(_ species: Int, moves: [String]) throws -> BattlerSpec {
        try XCTUnwrap(BattlerSpec.make(id: "s\(species)", speciesID: species, level: 100, moves: moves))
    }

    private func member(_ species: Int, id: String? = nil) throws -> ExpeditionMember {
        let id = id ?? "m\(species)"
        return ExpeditionMember(entryID: id, spec: try XCTUnwrap(BattlerSpec.make(id: id, speciesID: species, level: 100)))
    }

    /// A move hitting a theme type twice and no theme type hitting back twice: strong; the other way round, or moves
    /// that do little to every type: weak. The summary writes what the team's moves reach and who is weak.
    func testTheTypesTellTheFit() throws {
        let charizard = try spec(6, moves: ["flamethrower", "air-slash"])
        let electivire = try spec(466, moves: ["thunderbolt", "thunder-punch"])
        let snorlax = try spec(143, moves: ["body-slam"])
        let blastoise = try spec(9, moves: ["surf"])
        XCTAssertEqual(TeamMatchup.fit(charizard, against: [.bug, .grass]), .strong)
        XCTAssertEqual(TeamMatchup.fit(electivire, against: [.ground, .rock]), .weak, "immune and hit twice")
        XCTAssertEqual(TeamMatchup.fit(snorlax, against: [.ground, .rock]), .neutral)
        XCTAssertEqual(TeamMatchup.fit(blastoise, against: [.ground, .rock]), .strong)
        XCTAssertEqual(TeamMatchup.fit(charizard, against: []), .neutral, "a challenge without its boss")
        let lines = TeamMatchup.summary(team: [charizard, electivire, blastoise], against: [.ground, .rock])
        XCTAssertEqual(lines.map(\.best), [2, 2], "Surf on both")
        XCTAssertEqual(lines.map(\.weakMembers), [1, 1], "Electivire to Ground, Charizard to Rock")
        XCTAssertEqual(TeamMatchup.multiplierText(0.5), "×½")
        XCTAssertEqual(TeamMatchup.multiplierText(2), "×2")
        XCTAssertEqual(TeamMatchup.multiplierText(0), "×0")
    }

    /// The same runs give both odds: reaching the boss as `reachOdds` counts it, and winning, never more often.
    func testTheOddsOfWinningComeWithThoseOfReaching() throws {
        let dungeon = DungeonCatalog.dungeon(.mtMoon)
        let team = try [143, 6, 9, 3].map { try member($0) }
        let odds = DungeonTeamBuilder.odds(team: team, dungeon: dungeon, runs: 6)
        XCTAssertEqual(odds.reach, DungeonTeamBuilder.reachOdds(team: team, dungeon: dungeon, runs: 6), accuracy: 1e-9)
        XCTAssertLessThanOrEqual(odds.win, odds.reach)
        XCTAssertEqual(odds.win, DungeonTeamBuilder.winOdds(team: team, dungeon: dungeon, runs: 6), accuracy: 1e-9)
        let weak = try [10, 13, 129, 16].map { try member($0) }
        XCTAssertLessThan(DungeonTeamBuilder.odds(team: weak, dungeon: dungeon, runs: 6).win, odds.win,
                          "a Caterpie, a Weedle, a Magikarp and a Pidgey win less")
    }

    /// "Compose for me" keeps, among its candidate teams, the one the runs say wins most, not the first by theme
    /// score (the owner's Mt. Moon of 2026-11-05: 85% where another region won 98%).
    func testComposeKeepsTheTeamThatWinsMost() throws {
        let dungeon = DungeonCatalog.dungeon(.mtMoon)
        let weak = try [10, 13, 129, 16].map { try member($0) }
        let strong = try [150, 94, 3, 248].map { try member($0) }
        let choice = DungeonTeamBuilder.ComposeChoice(teams: [weak, strong], dungeon: dungeon, boss: nil)
        XCTAssertEqual(choice.run(runs: 6), strong.map(\.entryID))
        XCTAssertEqual(DungeonTeamBuilder.ComposeChoice(teams: [weak], dungeon: dungeon, boss: nil).run(), weak.map(\.entryID),
                       "one team: no run")
        XCTAssertEqual(DungeonTeamBuilder.ComposeChoice(teams: [], dungeon: dungeon, boss: nil).run(), [])
    }

    /// The candidate teams: the theme's best first (what `compose` keeps), one per region a one-region dungeon asks
    /// at most, each valid under the rules.
    func testTheCandidateTeamsKeepTheRules() throws {
        let species = [6, 9, 3, 25, 130, 149, 143, 65, 94, 157, 160, 154, 196, 197, 248, 254, 257, 260, 282, 289]
        let pool = species.compactMap { id -> (candidate: DungeonCandidate, spec: BattlerSpec)? in
            guard let spec = BattlerSpec.make(id: "e\(id)", speciesID: id, level: 100) else { return nil }
            return (DungeonCandidate(entryID: "e\(id)", speciesID: id, baseID: SpeciesInfo.baseID(of: id), form: nil,
                                     rarity: SpeciesInfo.lineRarity(of: id), isShiny: false), spec)
        }
        let moon = DungeonCatalog.dungeon(.mtMoon)
        let teams = DungeonTeamBuilder.candidateTeams(pool, dungeon: moon, size: 4, rules: moon.rules)
        XCTAssertGreaterThan(teams.count, 1, "Kanto's, Johto's and Hoenn's")
        XCTAssertEqual(teams.first, DungeonTeamBuilder.compose(pool, dungeon: moon, size: 4, rules: moon.rules))
        for team in teams {
            let picked = pool.filter { team.contains($0.candidate.entryID) }.map(\.candidate)
            XCTAssertTrue(DungeonTeamRules.isValid(picked, size: 4, rules: moon.rules), "\(team)")
        }
        XCTAssertEqual(Set(teams.map { Set($0) }).count, teams.count, "no team twice")
        // A dungeon without a team-wide rule has one group: its bosses rarely change who is best, and the same team
        // must not be run twice.
        let forest = DungeonCatalog.dungeon(.viridianForest)
        let one = DungeonTeamBuilder.candidateTeams(pool, dungeon: forest, size: 3, rules: [])
        XCTAssertEqual(Set(one.map { Set($0) }).count, one.count, "no team twice")
        XCTAssertLessThanOrEqual(one.count, 2)
    }

    /// The dice's two paths as the dungeon's page shows them: the draw's own weights, in percent; the risky path more
    /// battles and traps, as many chests' weight; the shiny meeting from T3.
    func testThePathsOddsAreTheDraws() {
        for tier in DungeonTier.allCases {
            let safe = ExpeditionEngine.eventOdds(tier: tier, risky: false)
            let risky = ExpeditionEngine.eventOdds(tier: tier, risky: true)
            XCTAssertEqual(safe.map(\.percent).reduce(0, +), 100, accuracy: 1e-9)
            XCTAssertEqual(risky.map(\.percent).reduce(0, +), 100, accuracy: 1e-9)
            XCTAssertEqual(safe.map(\.kind), risky.map(\.kind))
            XCTAssertEqual(safe.first?.kind == .shiny, tier >= .t3)
            func share(_ odds: [(kind: ExpeditionEventKind, percent: Double)], _ kinds: Set<ExpeditionEventKind>) -> Double {
                odds.filter { kinds.contains($0.kind) }.map(\.percent).reduce(0, +)
            }
            XCTAssertGreaterThan(share(risky, [.wild, .horde, .trainer]), share(safe, [.wild, .horde, .trainer]), "\(tier)")
            XCTAssertGreaterThan(share(risky, [.trap]), share(safe, [.trap]))
            let weights = ExpeditionEngine.eventWeights(tier: tier, risky: true)
            XCTAssertEqual(weights.first { $0.0 == .chest }?.1, ExpeditionEngine.eventWeights(tier: tier, risky: false).first { $0.0 == .chest }?.1)
        }
    }

    /// The journal's fork says its path, until which floor, and what it changes.
    func testTheForkSaysWhatItChanges() {
        for language in AppLanguage.allCases {
            let l = L(language)
            XCTAssertTrue(l.dungeonLogBranch(roll: 5, risky: true, until: 6).contains("6"), "\(language)")
            XCTAssertNotEqual(l.dungeonLogBranch(roll: 5, risky: true, until: 6), l.dungeonLogBranch(roll: 2, risky: false, until: 6))
            XCTAssertFalse(l.dungeonPathRule.contains("—") || l.dungeonPathRule.contains("–"), "\(language)")
        }
    }
}

/// #141 (DyRize's idea, the owner's rule of 2026-11-06): from T2, a floor's secret passage one time in 25, half
/// skipping the next floor unpaid, half a hidden room's chest; never in T1, a challenge, nor past the boss's floor or
/// the Pokémon Center's.
final class SecretPassageTests: XCTestCase {
    private func member(_ species: Int, _ i: Int) throws -> ExpeditionMember {
        ExpeditionMember(entryID: "m\(species)-\(i)", spec: try XCTUnwrap(BattlerSpec.make(id: "m\(species)-\(i)", speciesID: species, level: 100)))
    }

    private func walk(_ id: DungeonID, seeds: Range<UInt64>) throws -> [Expedition] {
        let dungeon = DungeonCatalog.dungeon(id)
        let team = try [150, 248, 149, 6, 9, 3].prefix(dungeon.teamSize).enumerated().map { try member($0.element, $0.offset) }
        let context = ExpeditionContext(tier: dungeon.tier, shinyDenominator: 64, now: Date(timeIntervalSince1970: 0))
        return seeds.map { seed in
            var e = ExpeditionEngine.start(dungeon: dungeon, team: Array(team), rules: [], teamSize: team.count, seed: seed,
                                           cost: dungeon.floors * 1000, berries: [:], revives: [:], context: context)
            for _ in 0...(dungeon.floors * 4) {
                if case .capture = e.phase { break }
                if e.isOver { break }
                ExpeditionEngine.feed(&e, tokens: e.floorCost, context: context)
                if case .awaitingHeal = e.phase { ExpeditionEngine.answerHeal(&e, paid: false, context: context) }
            }
            return e
        }
    }

    private func passages(_ runs: [Expedition]) -> [(floor: Int, skipped: Bool, floors: Int, log: [ExpeditionLogEntry])] {
        runs.flatMap { e in
            e.log.compactMap { entry -> (Int, Bool, Int, [ExpeditionLogEntry])? in
                guard case .secretPassage(let skipped, _) = entry.kind else { return nil }
                XCTAssertTrue(entry.isRare, "in gold")
                return (entry.floor, skipped, e.floors, e.log)
            }
        }
    }

    func testSecretPassagesComeFromT2() throws {
        XCTAssertTrue(passages(try walk(.viridianForest, seeds: 0..<150)).isEmpty, "none in T1")
        let found = passages(try walk(.mtMoon, seeds: 0..<200))
        let floorsWalked = 200 * DungeonCatalog.dungeon(.mtMoon).floors
        XCTAssertGreaterThan(found.count, floorsWalked / 100, "about one floor in 25")
        XCTAssertLessThan(found.count, floorsWalked / 12)
        XCTAssertTrue(found.contains { $0.skipped } && found.contains { !$0.skipped }, "both kinds")
        for passage in found where passage.skipped {
            XCTAssertLessThan(passage.floor + 1, passage.floors, "never the boss's floor")
            XCTAssertFalse(passage.log.contains { $0.floor == passage.floor + 1 && $0.kind != .bossReached(speciesID: 0, isShiny: false)
                && { if case .branch = $0.kind { return false }; return true }($0) },
                           "nothing happens on the floor skipped")
        }
    }

    /// The skipped floor costs no tokens: an expedition with one reaches its boss for a floor's tokens less.
    func testASkippedFloorIsNotPaid() throws {
        let runs = try walk(.mtMoon, seeds: 0..<200)
        func hasSkip(_ e: Expedition) -> Bool { e.log.contains { if case .secretPassage(true, _) = $0.kind { return true }; return false } }
        func atBoss(_ e: Expedition) -> Bool { e.log.contains { if case .bossReached = $0.kind { return true }; return false } }
        let skipped = try XCTUnwrap(runs.first { hasSkip($0) && atBoss($0) })
        let plain = try XCTUnwrap(runs.first { !hasSkip($0) && atBoss($0) })
        XCTAssertEqual(plain.tokensIn - skipped.tokensIn, plain.floorCost, "one floor's tokens")
    }
}

/// Every battle one against one (the owner, 2026-11-06: "tous 1 par 1 chacun leur tour"), the boss's included, its HP
/// and stats lowered alike to keep the dungeons' odds (`ExpeditionEngine.oneOnOneBoss` and the others).
final class OneAgainstOneTests: XCTestCase {
    func testEveryBattleIsOneAgainstOne() throws {
        let dungeon = DungeonCatalog.dungeon(.mtMoon)
        let team = try [150, 248, 149, 6].enumerated().map { i, s in
            ExpeditionMember(entryID: "m\(i)", spec: try XCTUnwrap(BattlerSpec.make(id: "m\(i)", speciesID: s, level: 100)))
        }
        let context = ExpeditionContext(tier: dungeon.tier, shinyDenominator: 64, now: Date(timeIntervalSince1970: 0))
        var sawGroup = false, sawBoss = false
        for seed in UInt64(1)...12 {
            var e = ExpeditionEngine.start(dungeon: dungeon, team: team, rules: [], teamSize: 4, seed: seed,
                                           cost: dungeon.floors * 1000, berries: [:], revives: [:], context: context)
            for _ in 0...(dungeon.floors * 4) {
                if case .capture = e.phase { break }
                if e.isOver { break }
                ExpeditionEngine.feed(&e, tokens: e.floorCost, context: context)
                if case .awaitingHeal = e.phase { ExpeditionEngine.answerHeal(&e, paid: false, context: context) }
            }
            for entry in e.log {
                guard case .battle(let battle) = entry.kind else { continue }
                XCTAssertEqual(battle.setup.sides.map(\.active), [1, 1], "\(battle.kind)")
                if battle.foes.count > 1 { sawGroup = true }
                if battle.kind == .boss { sawBoss = true }
            }
        }
        XCTAssertTrue(sawGroup, "a horde or a group of wild Pokémon, one at a time")
        XCTAssertTrue(sawBoss)
    }

    /// The boss's HP and stats share one factor: lowered alike, never its HP alone.
    func testTheBossIsLoweredInProportion() throws {
        var random = BattleRandom(seed: 1)
        let boss = try XCTUnwrap(ExpeditionEngine.bossSpec(ExpeditionBoss(speciesID: 149, form: nil, isShiny: false), tier: .t3,
                                                            random: &random))
        var again = BattleRandom(seed: 1)
        let ivs = (0..<6).map { _ in 20 + again.below(12) }
        let full = try XCTUnwrap(BattlerSpec.make(id: "x", speciesID: 149, level: 100, ivs: ivs, isBoss: true, hpFactor: 4, statFactor: 1.25))
        let share = ExpeditionEngine.oneOnOneBoss
        XCTAssertEqual(Double(boss.stats.hp), Double(full.stats.hp) * share, accuracy: Double(full.stats.hp) * 0.02)
        XCTAssertEqual(Double(boss.stats.attack), Double(full.stats.attack) * share, accuracy: Double(full.stats.attack) * 0.03)
        XCTAssertLessThan(ExpeditionEngine.oneOnOneBoss, ExpeditionEngine.oneOnOneBossEarly, "T1 and T2 lowered less")
    }
}
