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

    /// The day's team, at its hour: one day in three, never while an expedition runs, another ambush waits or a hideout
    /// keeps something, nor before a first dungeon is won with a team to defend. Settled once a day.
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
        guard let target = VillainRules.target(bag, random: &random) else {
            persist()
            return
        }
        let ambush = VillainAmbush(team: draw.team, item: target.kind.rawValue, count: target.count, at: currentDate,
                                   seed: random.next(), grunts: VillainRules.grunts(draw.team, random: &random))
        changeDungeons { $0.ambush = ambush }
        notifyCompanionEvent(l.villainAmbushTitle(draw.team), l.villainAmbushLine(draw.team, item: l.itemName(target.kind)))
        AppLog.write("villains: \(draw.team.rawValue) ambush for \(target.count) \(target.kind.rawValue)")
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

    /// The defense, one against one as in the dungeons: won, the team flies off; lost, the item goes to its hideout.
    /// Nil when there is nothing to defend now (none waiting, already fought, a team away exploring).
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
        if !won {
            let taken = min(ambush.count, itemCount(kind))
            ambush.count = taken
            if taken > 0 {
                changeBag(kind, by: -taken)
                if kind.isPassive, kind.isAchievement { markAchievementClaimed(kind) }
                let team = ambush.team, tier = ambush.tier
                changeDungeons { progress in
                    var stash = progress.stash ?? VillainStash(team: team, items: [:], tier: tier)
                    stash.items[kind.rawValue, default: 0] += taken
                    stash.tier = max(stash.tier, tier)
                    progress.stash = stash
                }
            }
        }
        let settled = ambush
        changeDungeons { $0.ambush = settled }
        AppLog.write("villains: \(ambush.team.rawValue) ambush \(won ? "beaten" : "won, \(ambush.count) \(kind.rawValue) taken")")
        persist()
        return won
    }

    /// The ambush card goes once its fight is seen.
    func dismissVillainAmbush() {
        guard state.dungeons.ambush?.won != nil else { return }
        changeDungeons { $0.ambush = nil }
        persist()
    }
}
