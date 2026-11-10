import Foundation

/// The villains' teams in the game (issue #180): the day's ambush, the defense, the theft and the hideout.
extension CompanionStore {
    /// The dungeon as walked: a hideout's from what its team keeps, else the catalog's.
    func dungeonInfo(_ id: DungeonID) -> Dungeon {
        if id.isHideout, let stash = state.dungeons.stash { return VillainRules.hideout(stash) }
        return DungeonCatalog.dungeon(id)
    }

    var villainAmbush: VillainAmbush? { state.dungeons.ambush }
    var villainStash: VillainStash? { state.dungeons.stash }

    /// The day's thieves, at their hour: one day in three, never while an expedition runs, another theft waits or a
    /// hideout keeps something, nor before a first dungeon is won with a team to give chase. Settled once a day. They take
    /// the item as they come (the owner, 2026-11-10: else no one would fight them): it waits at their hideout, unless the
    /// team catches them on Home.
    func settleVillainAmbush() {
        let day = challengePeriod(.daily)
        guard state.dungeons.villainDay != day else { return }
        let draw = VillainRules.day(day)
        if draw.comes, Calendar.current.component(.hour, from: currentDate) < draw.hour { return }
        changeDungeons { $0.villainDay = day }
        let wonOne = DungeonCatalog.all.contains { !$0.id.isChallenge && !$0.id.isHideout && state.dungeons.wins($0.id) > 0 }
        guard draw.comes, wonOne, expedition == nil, state.dungeons.ambush == nil, state.dungeons.stash == nil,
              dungeonCandidates.count >= 3 else {
            persist()
            return
        }
        var random = VillainRules.random(day + ":target")
        let bag = Dictionary(uniqueKeysWithValues: ItemKind.allCases.map { ($0, itemCount($0)) })
        guard let target = VillainRules.target(bag, random: &random),
              let tier = VillainRules.tier(of: target.kind) else {
            persist()
            return
        }
        let team = VillainTeam.team(for: tier)
        let taken = min(target.count, itemCount(target.kind))
        changeBag(target.kind, by: -taken)
        if target.kind.isPassive, target.kind.isAchievement { markAchievementClaimed(target.kind) }
        let ambush = VillainAmbush(team: team, item: target.kind.rawValue, count: taken, at: currentDate,
                                   seed: random.next(), grunts: VillainRules.grunts(team, random: &random))
        changeDungeons {
            $0.ambush = ambush
            $0.stash = VillainStash(team: team, items: [target.kind.rawValue: taken], tier: tier)
        }
        notifyCompanionEvent(l.villainAmbushTitle(team), l.villainStoleLine(team, item: l.itemName(target.kind)))
        AppLog.write("villains: \(team.rawValue) took \(taken) \(target.kind.rawValue)")
        persist()
    }

    /// Who defends: Mon équipe, else the six strongest graduated Pokémon.
    var ambushDefenders: [DexEntry] {
        let candidates = dungeonCandidates
        let saved = state.dungeons.savedTeam.compactMap { id in candidates.first { $0.id == id } }
        if !saved.isEmpty { return saved }
        func total(_ entry: DexEntry) -> Int {
            SpeciesBattleTable.data(speciesID: entry.finalID, form: entry.form)?.baseStats.reduce(0, +) ?? 0
        }
        return Array(candidates.sorted { total($0) > total($1) }.prefix(6))
    }

    /// The chase, one against one as in the dungeons: won, the item comes back and the team flies off; lost, it stays at
    /// their hideout. Nil when there is nothing to chase now (none waiting, already fought, a team away exploring).
    @discardableResult
    func defendAgainstAmbush() -> Bool? {
        guard var ambush = state.dungeons.ambush, ambush.won == nil, expedition == nil, let kind = ambush.kind else { return nil }
        let targets = (theme: ambush.team.themeTypes, bosses: ambush.grunts.map { PokemonTypeData.types(forSpeciesID: $0) })
        let mine = ambushDefenders.compactMap { dungeonSpec($0, for: nil, targets: targets) }
        let foes = VillainRules.gruntSpecs(ambush.grunts, tier: ambush.tier, seed: ambush.seed)
        guard !mine.isEmpty, !foes.isEmpty else { return nil }
        let setup = BattleSetup(sides: [BattleSideSpec(battlers: mine, active: 1), BattleSideSpec(battlers: foes, active: 1)],
                                seed: ambush.seed &+ 1)
        let outcome = BattleEngine.run(setup)
        let won = outcome.winner == 0
        ambush.won = won
        ambush.battle = ExpeditionBattle(kind: .trainer, setup: setup, won: won, duration: outcome.duration, foes: ambush.grunts)
        if won, let held = state.dungeons.stash?.items[kind.rawValue], held > 0 {
            let back = min(held, ambush.count)
            changeBag(kind, by: back)
            changeDungeons { progress in
                progress.stash?.items[kind.rawValue] = held - back > 0 ? held - back : nil
                if progress.stash?.items.isEmpty == true { progress.stash = nil }
            }
        }
        let settled = ambush
        changeDungeons { $0.ambush = settled }
        AppLog.write("villains: \(ambush.team.rawValue) chase \(won ? "won, \(ambush.count) \(kind.rawValue) back" : "lost")")
        persist()
        return won
    }

    /// The card goes: after the chase, or before it (the item then waits at the hideout).
    func dismissVillainAmbush() {
        guard state.dungeons.ambush != nil else { return }
        changeDungeons { $0.ambush = nil }
        persist()
    }
}
