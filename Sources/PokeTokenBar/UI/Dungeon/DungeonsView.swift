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
                    Button { nav.showingMyTeam = true } label: { Image(systemName: "person.3.fill") }
                        .buttonStyle(.borderless).hoverTip(l.myTeamTitle)
                    Button { nav.showingTypeChart = true } label: { Image(systemName: "tablecells") }
                        .buttonStyle(.borderless).hoverTip(l.typeChartTitle)
                    Button { nav.showingRunHistory = true } label: { Image(systemName: "clock.arrow.circlepath") }
                        .buttonStyle(.borderless).hoverTip(l.runHistoryTitle)
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
                    DungeonCard(store: store, id: id, onPrepare: { nav.dungeonTeam = id }, onDetails: { nav.dungeonDetail = id })
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
            DungeonIcon(id: e.dungeon, size: 28, boss: e.boss)
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
struct DungeonCard: View {
    let store: CompanionStore
    let id: DungeonID
    let onPrepare: () -> Void
    /// Opens the dungeon's page (`DungeonDetailScreen`); nil hides the button.
    var onDetails: (() -> Void)? = nil
    /// The bosses a card shows, the latest met; the others make a count.
    static let bossesShown = 4

    var body: some View {
        let l = store.l
        let dungeon = DungeonCatalog.dungeon(id)
        let (size, rules) = store.teamRules(id)
        // A dungeon won before a rule changed stays open (`isDungeonOpen`).
        let unmet = store.isDungeonOpen(id) ? [] : store.unmetUnlocks(id)
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
                        if let onDetails {
                            Button(action: onDetails) { Image(systemName: "info.circle") }
                                .buttonStyle(.borderless).font(.caption)
                                .hoverTip(l.dungeonDetailsButton)
                                .accessibilityLabel(l.dungeonDetailsButton)
                        }
                    }
                    Text(([l.dungeonTeamSize(size)] + rules.map(l.dungeonRule)
                          + [l.dungeonCost(TokenFormatter.compact(store.dungeonCost(id)))])
                        .joined(separator: " · "))
                        .font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    // Never broken in two: Mt. Coronet's four in Russian leave 3 points (`DungeonLayoutTests`).
                    HStack(spacing: 3) {
                        ForEach(dungeon.themeTypes, id: \.self) { type in
                            Badge(l.typeName(type).uppercased(), tint: .type(type)).fixedSize()
                        }
                    }
                }
            }
            if unmet.isEmpty {
                // The entry goes under the bosses when both do not fit on one line (a long entry text, a German button).
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 6) {
                        bosses(dungeon, l)
                        Spacer(minLength: 4)
                        entry(l)
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        bosses(dungeon, l)
                        HStack { Spacer(minLength: 0); entry(l) }
                    }
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

    /// Q17: the bosses beaten whole, those only reached as silhouettes, a "?" for each one not met yet (#137): how many
    /// wait there, never who.
    private func bosses(_ dungeon: Dungeon, _ l: L) -> some View {
        let slots = BossSlots(store: store, id: id, dungeon: dungeon, size: 28, shownAtMost: Self.bossesShown)
        return HStack(spacing: 2) {
            ForEach(Array(slots.slots.enumerated()), id: \.offset) { _, slot in slot.view(size: 28, language: store.language) }
            if slots.hidden > 0 {
                Text("+\(slots.hidden)").font(.caption.weight(.semibold)).foregroundStyle(.secondary).fixedSize()
            }
        }
    }

    @ViewBuilder
    private func entry(_ l: L) -> some View {
        let keys = store.keysToEnter(id)
        HStack(spacing: 6) {
            if keys > 0 {
                // Never broken in two: the row puts the entry under the bosses instead.
                Text(l.dungeonEntryKeys(keys, key: l.itemName(.legendaryKey))).font(.caption2).foregroundStyle(.secondary)
                    .fixedSize()
            } else if id == .ruinsOfAlph {
                Text(l.dungeonEntryMap(l.itemName(.treasureMap))).font(.caption2).foregroundStyle(.secondary).fixedSize()
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
                       l.dungeonCost(TokenFormatter.compact(store.dungeonCost(id))),
                       id == .daily ? l.challengeOneTryADay : l.challengeOneTryAWeek].joined(separator: " · ")
        VStack(alignment: .leading, spacing: 6) {
            Text(l.dungeonName(id)).font(.caption.weight(.semibold)).lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            // The boss large and centred, its name under it (the owner, 2026-11-09: at 36 points beside the title it was
            // hard to make out). It fills its box: at one scale with the others, a small form stayed small.
            Group {
                if let boss {
                    SpriteView(speciesID: boss.speciesID, size: 84, form: boss.form)
                } else {
                    Image(systemName: id == .daily ? "sun.max.fill" : "calendar").font(.largeTitle).foregroundStyle(.secondary)
                }
            }
            .frame(width: 86, height: 86)
            .frame(maxWidth: .infinity)
            .grayscale(unmet.isEmpty ? 0 : 1).opacity(unmet.isEmpty ? 1 : 0.5)
            if let boss {
                VStack(spacing: 2) {
                    BattleFormTitle(form: boss, language: store.language)
                        .font(.caption.weight(.medium)).lineLimit(2).multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    // Only when the form is the player's already (the owner, 2026-11-09: a form not won says nothing);
                    // a run's boss won meanwhile says it too.
                    if store.dungeonProgress.battleForms.contains(boss.key) {
                        Label(l.challengeFormOwned, systemImage: "checkmark.circle")
                            .font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity)
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

/// A dungeon's icon (R15): its diorama, drawn in code; a daily or weekly dungeon's boss instead, known from the start
/// (the owner, 2026-11-03: "on doit voir le boss pas un décor").
@MainActor
struct DungeonIcon: View {
    let id: DungeonID
    var size: CGFloat = 32
    var boss: ExpeditionBoss?

    var body: some View {
        Group {
            if id.isChallenge, let boss {
                SpriteView(speciesID: boss.speciesID, size: size, form: boss.form, sameScale: true)
            } else if let image = DungeonSprites.image(id) {
                Image(decorative: image, scale: 1).resizable().interpolation(size.truncatingRemainder(dividingBy: 32) == 0 ? .none : .high)
            } else {
                Color.clear
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// A dungeon's bosses as a player knows them (Q17, #137): beaten whole, reached as a silhouette, a "?" when not met.
/// The Ruins of Alph, whose boss is any final species, show those met and one "?" for the rest.
@MainActor
struct BossSlots {
    @MainActor
    enum Slot {
        case met(speciesID: Int, beaten: Bool)
        case unknown

        @ViewBuilder
        func view(size: CGFloat, language: AppLanguage) -> some View {
            switch self {
            case .met(let species, let beaten):
                SpriteView(speciesID: species, size: size, isSilhouette: !beaten, sameScale: true)
                    .speciesNameTooltip(species, language: language)
            case .unknown:
                Text("?").font(.system(size: size * 0.45, weight: .bold, design: .rounded)).foregroundStyle(.secondary)
                    .frame(width: size, height: size)
                    .background(RoundedRectangle(cornerRadius: size / 4).strokeBorder(.secondary.opacity(0.45),
                                                                                    style: StrokeStyle(lineWidth: 1, dash: [3])))
            }
        }
    }

    /// Up to `shownAtMost` slots, the latest met last; `hidden` more met past them.
    let slots: [Slot]
    let hidden: Int
    let met: Int

    init(store: CompanionStore, id: DungeonID, dungeon: Dungeon, size: CGFloat, shownAtMost: Int) {
        let progress = store.dungeonProgress
        let reached = dungeon.bosses.filter { progress.bossesReached.contains(DungeonProgress.bossKey(id, $0)) }
        func slot(_ species: Int) -> Slot {
            .met(speciesID: species, beaten: progress.bossesBeaten.contains(DungeonProgress.bossKey(id, species)))
        }
        met = reached.count
        if dungeon.bosses.count <= shownAtMost {
            // Every boss has its place, in the catalog's order: its "?" until it is met.
            slots = dungeon.bosses.map { reached.contains($0) ? slot($0) : .unknown }
            hidden = 0
        } else {
            let shown = Array(reached.suffix(shownAtMost - 1))
            slots = shown.map(slot) + [.unknown]
            hidden = reached.count - shown.count
        }
    }
}
