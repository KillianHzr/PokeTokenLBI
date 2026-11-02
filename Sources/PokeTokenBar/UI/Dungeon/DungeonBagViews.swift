import SwiftUI

/// A dungeon's egg in the Bag (Q20 B): named by the Pokémon it hatches, shiny when it was, used as the Shop's eggs are.
@MainActor
struct DungeonEggCard: View {
    let store: CompanionStore
    let nav: PopoverNavigation
    let egg: DungeonEgg

    var body: some View {
        let l = store.l
        let name = DungeonEggTitle.text(egg.baseID, l: l, language: store.language)
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 10) {
                SpriteView(speciesID: nil, size: 30, egg: .dungeon(egg.sourceSpeciesID))
                VStack(alignment: .leading, spacing: 3) {
                    DungeonEggTitle(speciesID: egg.baseID, l: l, language: store.language)
                        .font(.callout.weight(.semibold)).lineLimit(1)
                    if egg.isShiny { Badge("✦ " + l.dungeonEggShiny.uppercased(), tint: .orange, style: .tinted) }
                    if store.hasActive {
                        Text(l.eggReleaseNote).font(.caption2).foregroundStyle(.tertiary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 0)
            }
            ReleaseForEggControls(store: store, nav: nav, detail: "", actionTitle: l.useItem,
                                  isAvailable: store.canUseDungeonEgg(egg.id), unavailableText: l.useNeedsPokemon,
                                  confirmText: l.stoneConfirm(store.displayName, name),
                                  lockedHint: store.isRaisingFossilEggPokemon ? l.fossilEggInProgress : nil) {
                store.useDungeonEgg(egg.id)
            }
        }
        .padding(12)
        .designSurface(cornerRadius: Design.cornerRadius)
    }
}

/// "Mewtwo Egg" in the player's language: the Pokémon's name loaded as `PokemonNameLabel` loads it, "…" until then.
@MainActor
struct DungeonEggTitle: View {
    let speciesID: Int
    let l: L
    let language: AppLanguage
    var displayStore = PokemonNameDisplayStore.shared

    static func text(_ speciesID: Int, l: L, language: AppLanguage,
                     names: PokemonNameDisplayStore.Names = PokemonNameDisplayStore.shared.names) -> String {
        let item = PokemonNameItem(resource: PokemonNameResource(kind: .pokemonSpecies, name: String(speciesID)))
        return l.eggOf(PokemonNameText(items: [item], language: language, names: names).text)
    }

    var body: some View {
        let resource = PokemonNameResource(kind: .pokemonSpecies, name: String(speciesID))
        Text(Self.text(speciesID, l: l, language: language, names: displayStore.names))
            .task(id: resource) {
                if displayStore.names[resource] == nil { _ = await displayStore.load(resource, provider: PokemonNameClient.shared) }
            }
    }
}

/// Under a dungeon item in the Bag: a Capsule opens its screen, a chest opens, the rest waits for the dungeons.
@MainActor
struct DungeonItemControls: View {
    let store: CompanionStore
    let nav: PopoverNavigation
    let kind: ItemKind
    let openChest: () -> Void

    var body: some View {
        let l = store.l
        HStack(spacing: 6) {
            switch kind {
            case .silverCapsule, .goldCapsule:
                if store.capsuleCandidates.isEmpty {
                    Text(l.dungeonNoCapsuleTarget).font(.caption2).foregroundStyle(.tertiary)
                } else {
                    Text(store.effectHint(for: kind)).font(.caption2).foregroundStyle(.tertiary).monospacedDigit()
                    Spacer()
                    Button(l.useItem) { nav.capsule = kind }.buttonStyle(.pill())
                }
            case .explorerChest:
                Text(store.effectHint(for: kind)).font(.caption2).foregroundStyle(.tertiary)
                Spacer()
                Button(l.dungeonOpen, action: openChest).buttonStyle(.pill(prominent: true))
            default:
                Image(systemName: "map.fill").font(.caption2).foregroundStyle(.secondary)
                Text(kind == .escapeRope || kind == .treasureMap || kind == .legendaryKey
                     ? l.dungeonItemHint : l.dungeonItemHint + " · " + store.effectHint(for: kind))
                    .font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                Spacer()
            }
        }
    }
}

/// A Capsule used on a graduated Pokémon: pick it, then the IV (Silver) or all of them (Gold).
@MainActor
struct CapsuleScreen: View {
    let store: CompanionStore
    let kind: ItemKind
    let onBack: () -> Void
    @State private var selected: String?
    @State private var raised = false

    var body: some View {
        let l = store.l
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Button { if selected != nil, !raised { selected = nil } else { onBack() } } label: {
                    Label(l.back, systemImage: "chevron.left").labelStyle(.titleAndIcon)
                }
                .buttonStyle(.borderless)
                .keyboardShortcut(.cancelAction)
                Spacer(minLength: 4)
                ItemIconView(kind: kind, size: 20)
                Text(l.itemName(kind)).font(.headline)
                Text("×\(store.itemCount(kind))").font(.caption.weight(.bold)).foregroundStyle(.secondary).monospacedDigit()
            }
            Text(l.itemDescription(kind)).font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if let id = selected, let entry = store.state.dex.first(where: { $0.id == id }) {
                detail(entry, l)
            } else {
                Text(l.dungeonCapsulePick).font(.caption.weight(.semibold))
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 62), spacing: 6)], spacing: 6) {
                        ForEach(store.capsuleCandidates) { entry in
                            Button { selected = entry.id } label: { cell(entry) }
                                .buttonStyle(.plain)
                        }
                    }
                    .reservesScrollerLane()
                }
            }
            Spacer(minLength: 0)
        }
        .padding(PopoverMetrics.padding)
        .frame(height: 520, alignment: .top)
    }

    private func total(_ entry: DexEntry) -> Int {
        guard let ivs = entry.profile?.ivs else { return 0 }
        return CompanionStore.ivKeyPaths.reduce(0) { $0 + ivs[keyPath: $1] }
    }

    private func cell(_ entry: DexEntry) -> some View {
        VStack(spacing: 2) {
            SpriteView(speciesID: entry.finalID, size: 40, shiny: entry.isShiny, form: entry.form, sameScale: true)
            Text("\(total(entry))/186").font(.caption2).foregroundStyle(.secondary).monospacedDigit()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
        .designSurface(cornerRadius: 10)
        .speciesNameTooltip(entry.finalID, form: entry.form, language: store.language)
    }

    @ViewBuilder
    private func detail(_ entry: DexEntry, _ l: L) -> some View {
        let ivs = entry.profile?.ivs
        HStack(spacing: 10) {
            SpriteView(speciesID: entry.finalID, size: 56, shiny: entry.isShiny, form: entry.form, sameScale: true)
            VStack(alignment: .leading, spacing: 2) {
                PokemonNameLabel(.pokemonSpecies, String(entry.finalID), language: store.language).font(.headline)
                Text("IV \(total(entry))/186").font(.caption).foregroundStyle(.secondary).monospacedDigit()
            }
        }
        if raised {
            Label(l.dungeonCapsuleDone, systemImage: "checkmark.seal.fill")
                .font(.callout.weight(.semibold)).foregroundStyle(Design.actionColor)
        } else if kind == .silverCapsule {
            Text(l.dungeonCapsulePickStat).font(.caption.weight(.semibold))
        }
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(PokemonStatCalculator.order.enumerated()), id: \.offset) { index, name in
                let value = ivs?[keyPath: CompanionStore.ivKeyPaths[index]] ?? 0
                HStack(spacing: 8) {
                    Text(l.statLabel(name)).font(.caption).frame(width: 70, alignment: .leading)
                    Text("\(value)").font(.caption.weight(.semibold)).monospacedDigit().frame(width: 22, alignment: .trailing)
                    ExpeditionBar(value: Double(value) / 31, color: value == 31 ? Design.actionColor : .secondary, height: 5)
                    if kind == .silverCapsule, !raised {
                        Button("→ 31") { raised = store.useCapsule(kind, on: entry.id, stat: index) }
                            .buttonStyle(.pill())
                            .disabled(value >= 31)
                            .opacity(value >= 31 ? 0 : 1)
                    }
                }
            }
        }
        if kind == .goldCapsule, !raised {
            HStack {
                Spacer()
                Button(l.dungeonCapsuleRaiseAll) { raised = store.useCapsule(kind, on: entry.id) }
                    .buttonStyle(.pill(prominent: true))
            }
        }
    }
}

/// A Dungeons medal's steps on its Achievements card: each dungeon of the tier, then the whole tier, with what it
/// gives and where it stands (claimed, ready, still to win), by glyph and color.
@MainActor
struct DungeonMedalPanel: View {
    let store: CompanionStore
    let tier: DungeonTier

    var body: some View {
        let l = store.l
        let dungeons = DungeonMedals.dungeons(tier)
        VStack(alignment: .leading, spacing: 4) {
            ForEach(store.regionTiers(DungeonMedals.medal(tier)), id: \.generation) { step in
                HStack(spacing: 6) {
                    if step.generation <= dungeons.count {
                        DungeonIcon(id: dungeons[step.generation - 1], size: 20)
                    } else {
                        Image(systemName: "crown.fill").font(.caption).frame(width: 20)
                    }
                    Text(l.medalStepName(tier, step: step.generation)).font(.caption)
                    Spacer(minLength: 4)
                    ForEach(Array(DungeonMedals.rewards(tier, step: step.generation).enumerated()), id: \.offset) { _, reward in
                        HStack(spacing: 1) {
                            ItemIconView(kind: reward.kind, size: 16)
                            if reward.count > 1 { Text("×\(reward.count)").font(.caption2).monospacedDigit() }
                        }
                        .hoverTip(l.itemName(reward.kind))
                    }
                    Image(systemName: step.isDone ? "checkmark.circle.fill" : step.isReady ? "gift.fill" : "circle")
                        .font(.caption)
                        .foregroundStyle(step.isDone ? Design.actionColor : step.isReady ? Color.readableOrange : .secondary)
                }
            }
        }
    }
}
