import Foundation

/// The dungeons' draws read back from what a save kept, for a save from before the luck journal (the owner,
/// 2026-11-25: "le Groudon en boss secret et tout" must count): a run's journal gives its throws, shinies, secret
/// passages and chests' eggs, every run's line its secret boss. A victory's extras were never written down: they count
/// from the journal on.
enum DungeonLuck {
    /// When the secret bosses came to every player (#186 merged into `main`): no run before had one to draw.
    static let secretBossesSince = Date(timeIntervalSince1970: 1_794_327_362) // 2026-11-10T16:16:02Z

    /// The draws a run's journal shows, the shinies at the odds of `shinyDenominator` (the Shiny Charm's and the Reveal
    /// Glass's of that day).
    static func draws(dungeon id: DungeonID, log: [ExpeditionLogEntry], at date: Date, shinyDenominator: Int) -> [LuckDraw] {
        let tier = DungeonCatalog.dungeon(id).tier
        var draws: [LuckDraw] = []
        func note(_ kind: LuckDrawKind, _ odds: Double, _ hit: Bool) {
            draws.merge([LuckDraw(at: date, kind: kind, odds: odds, hits: hit ? 1 : 0)])
        }
        func chestEggs(_ loot: ExpeditionLoot) {
            for (egg, perMille) in ExpeditionEngine.chestEggOdds(tier) {
                note(.chestEgg, Double(perMille) / 1000, (loot.items[egg.rawValue] ?? 0) > 0)
            }
        }
        var boss: ExpeditionBoss?
        // Floors whose event was drawn (the shiny meeting's roll), and those checked for a secret passage after it.
        var eventFloors = Set<Int>(), checkedFloors = Set<Int>()
        var meetings = 0, passages = 0
        for entry in log {
            switch entry.kind {
            case .bossReached(let species, let shiny, let form, let secret):
                boss = ExpeditionBoss(speciesID: species, form: form, isShiny: shiny)
                // The departure's roll: a dungeon's own boss, no challenge's, hideout's or the Ruins'; a legendary may
                // have come shiny for its shiny egg, no roll then.
                if secret != true, !id.isChallenge, !id.isHideout, id != .ruinsOfAlph,
                   !(shiny && SpeciesInfo.lineRarity(of: species) == .legendary) {
                    note(.bossShiny, 1 / Double(max(1, shinyDenominator)), shiny)
                }
            case .capture(_, let ball, let caught):
                guard let boss else { break }
                let odds = ExpeditionEngine.throwOdds(boss, ball: ball.flatMap(ItemKind.init(rawValue:)))
                note(.bossThrow, ExpeditionEngine.perMilleOdds(odds), caught)
            case .battle(let battle):
                guard battle.kind != .boss else { break }
                eventFloors.insert(entry.floor)
                checkedFloors.insert(entry.floor)
            case .chest(let loot):
                eventFloors.insert(entry.floor)
                checkedFloors.insert(entry.floor)
                chestEggs(loot)
            case .trap, .spring, .lost:
                eventFloors.insert(entry.floor)
                checkedFloors.insert(entry.floor)
            case .shiny(let species, let caught):
                eventFloors.insert(entry.floor)
                checkedFloors.insert(entry.floor)
                meetings += 1
                let odds = ExpeditionEngine.captureOdds(SpeciesInfo.lineRarity(of: species))
                note(.shinyCatch, ExpeditionEngine.perMilleOdds(odds), caught)
            case .center:
                checkedFloors.insert(entry.floor)
            case .secretPassage(_, let loot):
                passages += 1
                if let loot { chestEggs(loot) }
            case .branch, .revive, .emergencyHeal, .victory, .defeat, .abandon:
                break
            }
        }
        if tier >= .t3, !eventFloors.isEmpty {
            let odds = Double(ExpeditionEngine.shinyEncounterPerTenThousand(shinyDenominator: shinyDenominator)) / 10_000
            draws.merge([LuckDraw(at: date, kind: .shinyMeeting, odds: odds, trials: eventFloors.count,
                                  hits: min(meetings, eventFloors.count))])
        }
        if tier >= .t2, !id.isChallenge, !checkedFloors.isEmpty {
            draws.merge([LuckDraw(at: date, kind: .secretPassage, odds: Double(ExpeditionEngine.secretPassagePercent) / 100,
                                  trials: checkedFloors.count, hits: min(passages, checkedFloors.count))])
        }
        return draws
    }

    /// The journal a save from before would have had, from its runs, the latest last: each journal's draws, and every
    /// run's secret boss while one was left in its dungeon (`SecretBosses.left`).
    static func backfill(_ history: [DungeonRunRecord], shinyDenominator: (Date) -> Int) -> [LuckDraw] {
        var draws: [LuckDraw] = []
        var caught = Set<String>()
        for run in history {
            if let log = run.log {
                draws.merge(Self.draws(dungeon: run.dungeon, log: log, at: run.endedAt,
                                       shinyDenominator: shinyDenominator(run.endedAt)))
            }
            guard !run.dungeon.isChallenge, !run.dungeon.isHideout, run.endedAt >= secretBossesSince else { continue }
            let left = SecretBosses.left(run.dungeon, caught: caught)
            guard !left.isEmpty else { continue }
            // Its journal says it; a line alone shows a boss none of the dungeon's own.
            let met: ExpeditionBoss?
            if let log = run.log {
                met = log.lazy.compactMap { entry -> ExpeditionBoss? in
                    guard case .bossReached(let species, let shiny, let form, true?) = entry.kind else { return nil }
                    return ExpeditionBoss(speciesID: species, form: form, isShiny: shiny)
                }.first
            } else if !DungeonCatalog.dungeon(run.dungeon).bosses.contains(run.bossSpeciesID) {
                met = left.first { $0.speciesID == run.bossSpeciesID }
            } else {
                met = nil
            }
            draws.merge([LuckDraw(at: run.endedAt, kind: .secretBoss, odds: 1 / Double(SecretBosses.odds),
                                  hits: met == nil ? 0 : 1)])
            if let met, run.caught, let candidate = left.first(where: { $0.speciesID == met.speciesID && $0.form == met.form }) {
                caught.insert(SecretBosses.key(run.dungeon, candidate))
            }
        }
        return draws
    }
}
