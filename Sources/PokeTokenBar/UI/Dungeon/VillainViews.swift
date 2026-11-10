import SwiftUI

extension VillainTeam {
    var color: Color { Color(.sRGB, red: rgb.red, green: rgb.green, blue: rgb.blue) }
}

/// A villains' team on Home (issue #180), laid out as Prof. Oak's card: the grunt's bust, their words in a bubble,
/// what they are after and their three Pokémon; then the fight, won or lost, and the way to the hideout.
@MainActor
struct VillainAmbushCard: View {
    let store: CompanionStore
    let nav: PopoverNavigation

    private static let bustWidth: CGFloat = 84
    private static let bustHeight: CGFloat = 96
    private static let tail: CGFloat = 6

    var body: some View {
        if let ambush = store.villainAmbush, let kind = ambush.kind {
            let l = store.l
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 5) {
                    Image(systemName: ambush.won == nil ? "exclamationmark.triangle.fill" : ambush.won == true
                          ? "checkmark.seal.fill" : "xmark.seal.fill")
                    Text(l.villainAmbushTitle(ambush.team).uppercased()).kerning(0.6)
                }
                .font(.system(size: 11, weight: .heavy))
                .foregroundStyle(ambush.team.color)
                bubble(ambush, kind, l)
                    .frame(minHeight: Self.bustHeight, alignment: .top)
                    .padding(.leading, Self.bustWidth + 4)
                    .background(alignment: .topLeading) {
                        PortraitBust(name: ambush.team.gruntPortrait, width: Self.bustWidth, symbol: "exclamationmark.triangle")
                            .frame(width: Self.bustWidth).frame(minHeight: 0, maxHeight: .infinity, alignment: .top)
                            .clipped()
                    }
                actions(ambush, l)
            }
            .heroCard(colors: [ambush.won == true ? .gray : ambush.team.color])
        }
    }

    private func bubble(_ ambush: VillainAmbush, _ kind: ItemKind, _ l: L) -> some View {
        let item = l.itemName(kind) + (ambush.count > 1 ? " ×\(ambush.count)" : "")
        return VStack(alignment: .leading, spacing: 6) {
            switch ambush.won {
            case true?: Text(l.villainBeaten(ambush.team, item: item)).font(.callout.weight(.semibold))
            case false?: Text(l.villainGotAway(ambush.team, item: item)).font(.callout.weight(.semibold))
            case nil: Text(l.villainAmbushBubble).font(.callout)
            }
            HStack(spacing: 6) {
                ItemIconView(kind: kind, size: 22)
                Text(item).font(.caption.weight(.semibold))
                Spacer(minLength: 4)
                HStack(spacing: 0) {
                    ForEach(Array(ambush.grunts.enumerated()), id: \.offset) { _, id in
                        SpriteView(speciesID: id, size: 30, sameScale: true).frame(width: 30, height: 30)
                    }
                }
                .hoverTip(l.villainTheirPokemon)
            }
            .grayscale(ambush.won == true ? 0.6 : 0)
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(.vertical, 8).padding(.trailing, 10).padding(.leading, 10 + Self.tail)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SpeechBubble(tail: Self.tail).fill(Color(nsColor: .textBackgroundColor).opacity(0.85)))
    }

    @ViewBuilder
    private func actions(_ ambush: VillainAmbush, _ l: L) -> some View {
        if ambush.won == nil {
            HStack(alignment: .center, spacing: 8) {
                Text(l.villainDefendWith).font(.caption2).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 4)
                // Not now: the item waits at their hideout.
                Button(l.villainLater) { store.dismissVillainAmbush() }
                    .buttonStyle(.borderless).controlSize(.small).font(.caption).foregroundStyle(.secondary)
                Button(l.villainDefend) {
                    store.defendAgainstAmbush()
                    nav.replayBattle = store.villainAmbush?.battle
                    nav.replayStart = 0
                }
                .buttonStyle(.pill(prominent: true))
                .disabled(store.expedition != nil)
                .hoverTip(store.expedition != nil ? l.dungeonOneAtATime : nil)
            }
        } else {
            HStack(spacing: 8) {
                if let battle = ambush.battle {
                    Button(l.villainSeeFight) {
                        nav.replayBattle = battle
                        nav.replayStart = 0
                    }
                    .buttonStyle(.borderless).controlSize(.small).font(.caption.weight(.semibold))
                }
                Spacer(minLength: 4)
                if ambush.won == false {
                    Button(l.villainToHideout) {
                        store.dismissVillainAmbush()
                        nav.tab = .dungeons
                    }
                    .buttonStyle(.pill())
                }
                Button(l.close) { store.dismissVillainAmbush() }.buttonStyle(.pill(prominent: true))
            }
        }
    }
}

/// The hideout in the Dungeons tab (issue #180), on top while its team keeps something: the leader's bust, what they
/// keep, who waits at the end, the way to its team screen. A hero card in the team's color, as the dungeons'.
@MainActor
struct HideoutCard: View {
    let store: CompanionStore
    let onPrepare: () -> Void

    var body: some View {
        if let stash = store.villainStash {
            let l = store.l
            HStack(alignment: .top, spacing: 12) {
                // Its diorama, as every dungeon card's; the leader's bust stands at its foot.
                DungeonIcon(id: .hideout, size: 96, villain: stash.team)
                    .shadow(color: stash.team.color.opacity(0.6), radius: 10)
                    .overlay(alignment: .bottomTrailing) {
                        PortraitBust(name: stash.team.leaderPortrait, width: 46, symbol: "person.fill")
                            .frame(width: 46, height: 60, alignment: .top).clipped()
                            .offset(x: 6, y: 52)
                    }
                    .padding(.bottom, 52)
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 5) {
                        Badge("T\(stash.tier.rawValue)", tint: .secondary, style: .solid, size: 10)
                        Text(l.villainTeamName(stash.team).uppercased()).font(.system(size: 10, weight: .heavy)).kerning(0.6)
                            .foregroundStyle(stash.team.color)
                    }
                    Text(l.villainHideoutName(stash.team)).font(.system(size: 19, weight: .bold, design: .rounded))
                        .fixedSize(horizontal: false, vertical: true)
                    Text(l.villainKeeps).font(.caption2.weight(.bold)).foregroundStyle(.secondary)
                    WrappingHStack(spacing: 6, lineSpacing: 4) {
                        ForEach(stash.items.sorted { $0.key < $1.key }, id: \.key) { key, count in
                            if let kind = ItemKind(rawValue: key) {
                                HStack(spacing: 3) {
                                    ItemIconView(kind: kind, size: 20)
                                    Text(count > 1 ? "\(l.itemName(kind)) ×\(count)" : l.itemName(kind))
                                        .font(.caption.weight(.semibold))
                                }
                            }
                        }
                    }
                    HStack(spacing: 0) {
                        ForEach(Array(stash.team.leaderTeam.enumerated()), id: \.offset) { _, id in
                            SpriteView(speciesID: id, size: 30, sameScale: true).frame(width: 30, height: 30)
                        }
                    }
                    .hoverTip(l.villainWaitsAtTheEnd(stash.team))
                    Text(l.villainWaitsAtTheEnd(stash.team)).font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack {
                        Spacer(minLength: 0)
                        Text(TokenFormatter.compact(store.dungeonCost(.hideout))).font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Button(l.dungeonPrepare, action: onPrepare)
                            .buttonStyle(.pill(prominent: true))
                            .disabled(!store.canEnter(.hideout))
                            .hoverTip(store.expedition != nil ? l.dungeonOneAtATime : nil)
                    }
                }
            }
            .heroCard(colors: [stash.team.color])
        }
    }
}
