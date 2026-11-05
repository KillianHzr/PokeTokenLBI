import XCTest
@testable import PokeTokenBar

/// The balance simulator (D2): full expeditions in each dungeon with a team "Compose for me" builds, the share that
/// reaches the boss and the share that wins. Balanced on 2026-11-02 against a full Pokédex (491 graduated) so it
/// still has to fight: T1 a warm-up near 100%, T2 85 to 100%, T3 70 to 90%, T4 30 to 50%, the Hall of Origin under 10%.
/// The daily and weekly dungeons, set on 2026-11-03 against 511 graduated: about 50% and 35% (`challengeFactors`); an
/// average Pokédex about 10% and none. `PTB_DUNGEON_BY_BOSS` shows each boss reached and how often it fell.
///
///     PTB_DUNGEON_SIM=1 [PTB_DUNGEON_SAVE=<companion-state.json copy>] [PTB_DUNGEON_ONLY=daily,weekly] \
///         swift test --filter DungeonSimulatorTests
///
/// Without a save, an average player's Pokédex is drawn: sixty graduated Pokémon, mostly Commons, IVs at random.
final class DungeonSimulatorTests: XCTestCase {
    func testWinRates() throws {
        let env = ProcessInfo.processInfo.environment
        guard env["PTB_DUNGEON_SIM"] != nil else { throw XCTSkip("set PTB_DUNGEON_SIM to run the simulator") }
        let runs = Int(env["PTB_DUNGEON_RUNS"] ?? "") ?? 40
        let dex: [DexEntry]
        if let path = env["PTB_DUNGEON_SAVE"] {
            let state = try JSONDecoder().decode(CompanionState.self, from: Data(contentsOf: URL(fileURLWithPath: path)))
            dex = state.dex.filter { !$0.isReleased }
        } else {
            dex = averageDex()
        }
        print("SIM \(dex.count) graduated, \(runs) runs per dungeon")
        // PTB_DUNGEON_ONLY=daily,weekly runs those dungeons alone.
        let only = Set((env["PTB_DUNGEON_ONLY"] ?? "").split(separator: ",").map(String.init))
        for dungeon in DungeonCatalog.all where only.isEmpty || only.contains(dungeon.id.rawValue) {
            let pool = dex.compactMap { entry -> (candidate: DungeonCandidate, spec: BattlerSpec)? in
                DungeonTeamBuilder.spec(for: entry, theme: dungeon.themeTypes).map { (DungeonCandidate(entry), $0) }
            }
            var size = dungeon.teamSize, rules = dungeon.rules
            if dungeon.id == .ruinsOfAlph { (size, rules) = DungeonCatalog.alphRules(seed: 7) }
            let ids = DungeonTeamBuilder.compose(pool, dungeon: dungeon, size: size, rules: rules)
            guard !ids.isEmpty else {
                print("SIM \(dungeon.id.rawValue) T\(dungeon.tier.rawValue): no team fits the rules")
                continue
            }
            let team = ids.compactMap { id in pool.first { $0.candidate.entryID == id } }
                .map { ExpeditionMember(entryID: $0.candidate.entryID, spec: $0.spec) }
            // A challenge's boss is a battle form (a Mega for the daily, a Gigantamax, Primal or legendary Mega for the
            // weekly), drawn per run; without it the engine would stand a wild species in.
            let forms = dungeon.id == .daily ? BattleForms.daily : dungeon.id == .weekly ? BattleForms.weekly : []
            var reached = 0, won = 0, battles = 0
            var byBoss: [String: (runs: Int, won: Int)] = [:]
            let context = ExpeditionContext(tier: dungeon.tier, shinyDenominator: 64, now: Date(timeIntervalSince1970: 0))
            for run in 0..<runs {
                var e = ExpeditionEngine.start(dungeon: dungeon, team: team, rules: rules, teamSize: size,
                                               seed: UInt64(run) &* 104_729 &+ 11, cost: dungeon.floors * 1000,
                                               berries: [:], revives: [:], context: context,
                                               boss: forms.isEmpty ? nil : Optional(forms[run % forms.count]).map {
                                                   ExpeditionBoss(speciesID: $0.speciesID, form: $0.form, isShiny: false)
                                               })
                while !e.isOver, case .exploring = e.phase {
                    ExpeditionEngine.feed(&e, tokens: e.floorCost, context: context)
                    if case .awaitingHeal = e.phase { ExpeditionEngine.answerHeal(&e, paid: false, context: context) }
                }
                battles += e.battles
                if e.bossReached { reached += 1 }
                // The boss fell: a capture to come, or a challenge's form won at once.
                let bossWon: Bool
                if case .capture = e.phase { bossWon = true } else if case .finished(won: true) = e.phase { bossWon = true } else { bossWon = false }
                if bossWon { won += 1 }
                if e.bossReached {
                    let key = "\(e.boss.speciesID)" + (e.boss.form.map { "-\($0.rawValue)" } ?? "")
                    byBoss[key, default: (0, 0)].runs += 1
                    if bossWon { byBoss[key, default: (0, 0)].won += 1 }
                }
            }
            let names = team.map { "\($0.spec.speciesID)" }.joined(separator: ",")
            print(String(format: "SIM %@ T%d reach %3.0f%% win %3.0f%% battles %.1f team [%@]", dungeon.id.rawValue,
                         dungeon.tier.rawValue, 100 * Double(reached) / Double(runs), 100 * Double(won) / Double(runs),
                         Double(battles) / Double(runs), names))
            // PTB_DUNGEON_BY_BOSS: each boss reached, and how often it fell.
            if env["PTB_DUNGEON_BY_BOSS"] != nil {
                for (boss, r) in byBoss.sorted(by: { $0.key < $1.key }) {
                    print("SIM   boss \(boss): \(r.won)/\(r.runs)")
                }
            }
        }
    }

    /// Sixty graduated Pokémon an average player could hold: final stages, mostly Common lines, IVs at random.
    private func averageDex() -> [DexEntry] {
        var random = BattleRandom(seed: 42)
        let finals = SpeciesInfo.all.keys.filter { $0 <= 1025 && SpeciesInfo.isFinal($0) && SpeciesBattleTable.all[$0] != nil }.sorted()
        var entries: [DexEntry] = []
        while entries.count < 60 {
            let id = finals[random.below(finals.count)]
            let rarity = SpeciesInfo.lineRarity(of: id)
            let keep: Int = switch rarity {
            case .common: 100
            case .uncommon: 50
            case .rare: 25
            case .legendary: 5
            }
            guard random.below(100) < keep, !entries.contains(where: { $0.finalID == id }) else { continue }
            var profile = PokemonProfile.generate(seed: random.next())
            profile.level = 100
            var entry = DexEntry(baseID: SpeciesInfo.baseID(of: id), finalID: id, chainOrder: [id], rarity: rarity,
                                 caughtAt: Date(timeIntervalSince1970: 0))
            entry.profile = profile
            entry.isShiny = random.below(64) == 0
            entries.append(entry)
        }
        return entries
    }
}
