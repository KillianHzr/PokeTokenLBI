import SwiftUI

/// The Dungeons tab (Q29, maquette 1): the Legendary Keys, the expedition under way, then every dungeon with its tier,
/// theme (R7), team, rules and length; locked, what is still missing; open, its bosses as met (Q17: a silhouette once
/// reached, whole once beaten, nothing before) and the way to its team screen.
@MainActor
struct DungeonsView: View {
    let store: CompanionStore
    let nav: PopoverNavigation

    var body: some View {
        let l = store.l
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    SectionTitle(text: l.dungeonsTab, systemImage: "map.fill")
                    Spacer(minLength: 4)
                    ItemIconView(kind: .legendaryKey, size: 16)
                    Text("\(l.itemName(.legendaryKey)) ×\(store.itemCount(.legendaryKey))")
                        .font(.caption.weight(.semibold)).monospacedDigit().foregroundStyle(.secondary)
                }
                if let expedition = store.expedition {
                    underway(expedition, l)
                } else {
                    Text(l.dungeonsIntro).font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                // The daily and weekly dungeons first, side by side: what they give changes with the day and the week.
                HStack(alignment: .top, spacing: 8) {
                    ForEach([DungeonID.daily, .weekly], id: \.self) { id in
                        ChallengeCard(store: store, id: id) { nav.dungeonTeam = id }
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
                ForEach(shown, id: \.self) { id in
                    DungeonCard(store: store, id: id) { nav.dungeonTeam = id }
                }
            }
            .reservesScrollerLane()
        }
        .frame(height: 520)
        // The day's and the week's bosses stay as first shown.
        .task { store.settleChallengeBosses() }
    }

    /// The Ruins of Alph show only once a Treasure Map, or a visit, made them known.
    private var shown: [DungeonID] {
        DungeonID.allCases.filter { id in
            !id.isChallenge && (id != .ruinsOfAlph || store.itemCount(.treasureMap) > 0 || store.dungeonProgress.wins(id) > 0)
        }
    }

    private func underway(_ e: Expedition, _ l: L) -> some View {
        HStack(spacing: 8) {
            DungeonIcon(id: e.dungeon, size: 28)
            Text(l.dungeonUnderway(l.dungeonName(e.dungeon), floor: min(e.floor, e.floors), floors: e.floors))
                .font(.caption.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 4)
            Button { nav.tab = .home } label: {
                HStack(spacing: 2) {
                    Text(l.dungeonSee)
                    Image(systemName: "chevron.right").font(.system(size: 8, weight: .bold))
                }
                .font(.caption.weight(.semibold)).foregroundStyle(Design.actionColor)
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .designSurface(cornerRadius: Design.cornerRadius)
    }
}

/// One dungeon's card.
@MainActor
private struct DungeonCard: View {
    let store: CompanionStore
    let id: DungeonID
    let onPrepare: () -> Void

    var body: some View {
        let l = store.l
        let dungeon = DungeonCatalog.dungeon(id)
        let (size, rules) = store.teamRules(id)
        let unmet = store.unmetUnlocks(id)
        let wins = store.dungeonProgress.wins(id)
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 10) {
                DungeonIcon(id: id, size: 32)
                    .grayscale(unmet.isEmpty ? 0 : 1).opacity(unmet.isEmpty ? 1 : 0.5)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Badge("T\(dungeon.tier.rawValue)", tint: .secondary, style: .tinted)
                        Text(l.dungeonName(id)).font(.callout.weight(.semibold))
                        Spacer(minLength: 4)
                        status(unmet: unmet, wins: wins, l)
                    }
                    Text(([l.dungeonTeamSize(size)] + rules.map(l.dungeonRule)
                          + [l.dungeonCost(TokenFormatter.compact(dungeon.tier.cost(difficulty: store.growthDifficulty)))])
                        .joined(separator: " · "))
                        .font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 3) {
                        ForEach(dungeon.themeTypes, id: \.self) { type in
                            Badge(l.typeName(type).uppercased(), tint: .type(type))
                        }
                    }
                }
            }
            if unmet.isEmpty {
                HStack(spacing: 6) {
                    bosses(dungeon, l)
                    Spacer(minLength: 4)
                    entry(l)
                }
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(dungeon.unlocks.enumerated()), id: \.offset) { _, unlock in
                        let met = store.isMet(unlock)
                        Label(l.dungeonUnlock(unlock), systemImage: met ? "checkmark.circle.fill" : "circle")
                            .font(.caption).foregroundStyle(met ? .primary : .secondary)
                    }
                }
            }
        }
        .padding(12)
        .designSurface(cornerRadius: Design.cornerRadius)
    }

    @ViewBuilder
    private func status(unmet: [DungeonUnlock], wins: Int, _ l: L) -> some View {
        if !unmet.isEmpty {
            Label(l.dungeonLocked, systemImage: "lock.fill").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
        } else if wins > 0 {
            Text(l.dungeonWins(wins)).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
        } else {
            Badge(l.dungeonNew.uppercased(), tint: .blue, style: .tinted)
        }
    }

    /// Q17: the bosses beaten whole, those only reached as silhouettes, none before.
    @ViewBuilder
    private func bosses(_ dungeon: Dungeon, _ l: L) -> some View {
        let progress = store.dungeonProgress
        let met = dungeon.bosses.filter { progress.bossesReached.contains(DungeonProgress.bossKey(id, $0)) }
        if met.isEmpty {
            Text(l.dungeonBossUnknown).font(.caption).foregroundStyle(.secondary)
        } else {
            HStack(spacing: 2) {
                ForEach(met, id: \.self) { species in
                    let beaten = progress.bossesBeaten.contains(DungeonProgress.bossKey(id, species))
                    SpriteView(speciesID: species, size: 28, isSilhouette: !beaten, sameScale: true)
                        .speciesNameTooltip(species, language: store.language)
                }
            }
        }
    }

    @ViewBuilder
    private func entry(_ l: L) -> some View {
        let keys = store.keysToEnter(id)
        HStack(spacing: 6) {
            if keys > 0 {
                Text(l.dungeonEntryKeys(keys, key: l.itemName(.legendaryKey))).font(.caption2).foregroundStyle(.secondary)
            } else if id == .ruinsOfAlph {
                Text(l.dungeonEntryMap(l.itemName(.treasureMap))).font(.caption2).foregroundStyle(.secondary)
            }
            Button(store.dungeonProgress.wins(id) > 0 ? l.dungeonGoAgain : l.dungeonPrepare, action: onPrepare)
                .buttonStyle(.pill(prominent: true))
                .disabled(!store.canEnter(id))
                .hoverTip(store.expedition != nil ? l.dungeonOneAtATime : nil)
        }
    }
}

/// The daily or weekly dungeon (2026-11-02), half a row: its boss, the form it gives, then what to do or why not now.
/// Its length, cost, one try and difficulty are on hover.
@MainActor
private struct ChallengeCard: View {
    let store: CompanionStore
    let id: DungeonID
    let onPrepare: () -> Void

    var body: some View {
        let l = store.l
        let dungeon = DungeonCatalog.dungeon(id)
        let unmet = store.unmetUnlocks(id)
        // A run under way keeps its own boss past midnight (or the week's turn): the card shows it, not the next one.
        let running = store.expedition.flatMap { e in
            e.dungeon == id ? BattleForms.form(speciesID: e.boss.speciesID, form: e.boss.form) : nil
        }
        let boss = running ?? store.challengeBoss(id)
        let tried = store.challengeTried(id)
        let details = [l.dungeonFloors(dungeon.floors),
                       l.dungeonCost(TokenFormatter.compact(dungeon.cost(difficulty: store.growthDifficulty))),
                       id == .daily ? l.challengeOneTryADay : l.challengeOneTryAWeek].joined(separator: " · ")
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 6) {
                Group {
                    if let boss {
                        SpriteView(speciesID: boss.speciesID, size: 36, form: boss.form, sameScale: true)
                    } else {
                        Image(systemName: id == .daily ? "sun.max.fill" : "calendar").font(.title3).foregroundStyle(.secondary)
                    }
                }
                .frame(width: 38, height: 38)
                .grayscale(unmet.isEmpty ? 0 : 1).opacity(unmet.isEmpty ? 1 : 0.5)
                VStack(alignment: .leading, spacing: 1) {
                    Text(l.dungeonName(id)).font(.caption.weight(.semibold)).lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    if let boss {
                        BattleFormTitle(form: boss, language: store.language)
                            .font(.caption2).foregroundStyle(.secondary).lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            Spacer(minLength: 0)
            Group {
                if running != nil {
                    Label(l.challengeUnderway, systemImage: "figure.walk")
                } else if let unlock = unmet.first {
                    Label(l.dungeonUnlock(unlock), systemImage: "lock.fill")
                } else if boss == nil {
                    Label(l.challengeAllWonShort, systemImage: "checkmark.seal.fill")
                } else if tried {
                    Label(id == .daily ? l.challengeTriedShortDay : l.challengeTriedShortWeek, systemImage: "hourglass")
                } else {
                    Button(l.dungeonPrepare, action: onPrepare)
                        .buttonStyle(.pill(prominent: true))
                        .disabled(!store.canEnter(id))
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
            .font(.caption2).foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .designSurface(cornerRadius: Design.cornerRadius)
        .hoverTip(boss == nil && unmet.isEmpty ? l.challengeAllWon
                  : tried ? (id == .daily ? l.challengeTriedToday : l.challengeTriedThisWeek)
                  : store.expedition != nil && unmet.isEmpty ? l.dungeonOneAtATime
                  : details + "\n" + l.challengeHard)
    }
}

/// A dungeon's icon (R15): its diorama, drawn in code.
@MainActor
struct DungeonIcon: View {
    let id: DungeonID
    var size: CGFloat = 32

    var body: some View {
        Group {
            if let image = DungeonSprites.image(id) {
                Image(decorative: image, scale: 1).resizable().interpolation(size.truncatingRemainder(dividingBy: 32) == 0 ? .none : .high)
            } else {
                Color.clear
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}
