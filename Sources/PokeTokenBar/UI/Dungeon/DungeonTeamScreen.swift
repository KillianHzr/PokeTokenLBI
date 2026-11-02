import SwiftUI

/// A dungeon's team screen (maquette 2): the rules ticked as the team forms, the team, the loop of the Pokémon picked
/// (R4: chosen among the moves it can learn, the locked ones greyed, details on hover), the graduated Pokémon the rules
/// admit, "Compose for me" (Q8) and the odds of reaching the boss (R7), then the departure.
@MainActor
struct DungeonTeamScreen: View {
    let store: CompanionStore
    let dungeon: DungeonID
    let onBack: () -> Void
    let onDepart: () -> Void

    @State private var team: [String] = []
    @State private var focus: String?
    @State private var editingSlot: Int?
    @State private var odds: Double?

    var body: some View {
        let l = store.l
        let (size, rules) = store.teamRules(dungeon)
        let picked = team.compactMap { id in store.dungeonCandidates.first { $0.id == id } }
        let candidates = picked.map(DungeonCandidate.init)
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Button { onBack() } label: { Label(l.back, systemImage: "chevron.left").labelStyle(.titleAndIcon) }
                    .buttonStyle(.borderless)
                    .keyboardShortcut(.cancelAction)
                Spacer(minLength: 4)
                DungeonIcon(id: dungeon, size: 20)
                Text(l.dungeonName(dungeon)).font(.headline)
            }
            rulesBox(size: size, rules: rules, team: candidates, l)
            teamRow(picked, size: size)
            if let focus, let entry = picked.first(where: { $0.id == focus }) {
                if !store.wonBattleForms(speciesID: entry.finalID).isEmpty {
                    BattleFormChooser(store: store, entry: entry)
                }
                LoopEditor(store: store, entry: entry, dungeon: dungeon, editingSlot: $editingSlot)
            } else {
                // What to do next, said where it is done.
                Text(picked.count < size ? l.dungeonTeamPickHint(compose: l.dungeonComposeForMe) : l.dungeonTeamEditHint)
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            ScrollView {
                candidateList(size: size, rules: rules, l)
                    .reservesScrollerLane()
            }
            footer(size: size, rules: rules, team: candidates, l)
        }
        .padding(PopoverMetrics.padding)
        .frame(height: 520, alignment: .top)
        .task(id: team) { await estimate() }
    }

    private func rulesBox(size: Int, rules: [DungeonRule], team: [DungeonCandidate], _ l: L) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            rule(l.dungeonTeamSize(size) + " · \(team.count)/\(size)",
                 met: team.count == size && DungeonTeamRules.distinctSpecies(team))
            ForEach(Array(rules.enumerated()), id: \.offset) { _, item in
                rule(l.dungeonRule(item), met: DungeonTeamRules.holds(item, for: team) && !team.isEmpty)
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .designSurface(cornerRadius: 10)
    }

    private func rule(_ text: String, met: Bool) -> some View {
        Label(text, systemImage: met ? "checkmark.circle.fill" : "circle")
            .font(.caption.weight(.semibold))
            .foregroundStyle(met ? Design.actionColor : .secondary)
    }

    private func teamRow(_ picked: [DexEntry], size: Int) -> some View {
        HStack(spacing: 6) {
            ForEach(picked, id: \.id) { entry in
                Button {
                    focus = focus == entry.id ? nil : entry.id
                    editingSlot = nil
                } label: {
                    SpriteView(speciesID: entry.finalID, size: 34, shiny: entry.isShiny, form: entry.form, sameScale: true)
                        .padding(2)
                        .background(RoundedRectangle(cornerRadius: 8).fill(focus == entry.id ? Design.actionColor.opacity(0.25) : .clear))
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button(store.l.dungeonRemove) {
                        team.removeAll { $0 == entry.id }
                        if focus == entry.id { focus = nil }
                    }
                }
                .speciesNameTooltip(entry.finalID, form: entry.form, language: store.language)
            }
            ForEach(0..<max(0, size - picked.count), id: \.self) { _ in
                RoundedRectangle(cornerRadius: 8).strokeBorder(.secondary.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [3]))
                    .frame(width: 38, height: 38)
            }
        }
    }

    @ViewBuilder
    private func candidateList(size: Int, rules: [DungeonRule], _ l: L) -> some View {
        let admitted = store.dungeonCandidates.filter { DungeonTeamRules.admits(DungeonCandidate($0), rules: rules) }
        if admitted.isEmpty {
            Text(l.dungeonNoCandidate).font(.caption).foregroundStyle(.secondary)
        } else {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 6), spacing: 4) {
                ForEach(admitted, id: \.id) { entry in
                    let chosen = team.contains(entry.id)
                    let blocked = !chosen && (team.count >= size
                        || team.contains { id in store.dungeonCandidates.first { $0.id == id }?.finalID == entry.finalID })
                    Button {
                        if chosen {
                            team.removeAll { $0 == entry.id }
                        } else if !blocked {
                            team.append(entry.id)
                        }
                    } label: {
                        SpriteView(speciesID: entry.finalID, size: 40, shiny: entry.isShiny, form: entry.form, sameScale: true)
                            .opacity(blocked ? 0.35 : 1)
                            .background(RoundedRectangle(cornerRadius: 8).fill(chosen ? Design.actionColor.opacity(0.25) : .clear))
                    }
                    .buttonStyle(.plain)
                    .speciesNameTooltip(entry.finalID, form: entry.form, language: store.language)
                }
            }
        }
    }

    private func footer(size: Int, rules: [DungeonRule], team: [DungeonCandidate], _ l: L) -> some View {
        let valid = DungeonTeamRules.isValid(team, size: size, rules: rules)
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(l.dungeonReachOdds).font(.caption).foregroundStyle(.secondary)
                Spacer()
                if valid {
                    Text(odds.map { "\(Int(($0 * 100).rounded())) %" } ?? "…")
                        .font(.callout.weight(.bold)).monospacedDigit()
                } else {
                    Text(l.dungeonTeamIncomplete).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                }
            }
            HStack(spacing: 8) {
                Button(l.dungeonComposeForMe) {
                    self.team = store.composeTeam(for: dungeon)
                    focus = nil
                }
                .buttonStyle(.pill())
                Spacer()
                let keys = store.keysToEnter(dungeon)
                Button(keys > 0 ? "\(l.dungeonSetOff) · 🗝️ \(keys)" : l.dungeonSetOff) {
                    if store.startExpedition(dungeon, team: self.team) { onDepart() }
                }
                .buttonStyle(.pill(prominent: true))
                .disabled(!valid || !store.canEnter(dungeon))
            }
        }
    }

    /// R7: run off the main thread, the team's specs made here.
    private func estimate() async {
        odds = nil
        let (size, rules) = store.teamRules(dungeon)
        let picked = team.compactMap { id in store.dungeonCandidates.first { $0.id == id } }
        guard DungeonTeamRules.isValid(picked.map(DungeonCandidate.init), size: size, rules: rules) else { return }
        let members = picked.compactMap { entry in
            store.dungeonSpec(entry, for: dungeon).map { ExpeditionMember(entryID: entry.id, spec: $0) }
        }
        let place = DungeonCatalog.dungeon(dungeon)
        try? await Task.sleep(for: .milliseconds(250))
        guard !Task.isCancelled else { return }
        let value = await Task.detached(priority: .utility) {
            DungeonTeamBuilder.reachOdds(team: members, dungeon: place)
        }.value
        guard !Task.isCancelled else { return }
        odds = value
    }
}

/// A Pokémon's loop for a dungeon (R4): its four moves with their cast time; one clicked opens the moves it can learn,
/// the locked ones greyed. Each move's details show on hover.
@MainActor
struct LoopEditor: View {
    let store: CompanionStore
    let entry: DexEntry
    /// The dungeon whose theme the suggestion plays against; none on the Pokédex page.
    let dungeon: DungeonID?
    @Binding var editingSlot: Int?
    /// A card of its own, as the Pokédex page's sections, rather than a panel inside the team screen's.
    var asCard = false

    var body: some View {
        let l = store.l
        let spec = store.dungeonSpec(entry, for: dungeon)
        let loop = spec?.moves ?? []
        let frozen = store.isExploring(entry.id)
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                SectionTitle(text: l.dungeonLoopTitle)
                Spacer()
                if store.dungeonProgress.moveLoops[entry.id] != nil, !frozen {
                    Button(l.dungeonSuggestLoop) { store.setMoveLoop([], for: entry.id) }
                        .buttonStyle(.borderless).font(.caption)
                }
            }
            ForEach(Array(loop.enumerated()), id: \.offset) { index, slug in
                Button { editingSlot = editingSlot == index ? nil : index } label: {
                    MoveRow(store: store, slug: slug, speed: spec?.stats.speed ?? 100, number: index + 1,
                            selected: editingSlot == index)
                }
                .buttonStyle(.plain)
                .disabled(frozen)
            }
            if frozen {
                Label(l.dungeonLoopFrozen, systemImage: "lock.fill").font(.caption2).foregroundStyle(.secondary)
            } else if let slot = editingSlot {
                movePicker(slot: slot, loop: loop, spec: spec)
            } else {
                Text(l.dungeonLoopHint).font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
        .modifier(LoopEditorFrame(asCard: asCard))
    }

    private func movePicker(slot: Int, loop: [String], spec: BattlerSpec?) -> some View {
        let data = SpeciesBattleTable.data(speciesID: entry.finalID, form: entry.form)
        let learnable = store.pokemonDetails(speciesID: entry.finalID, form: entry.form)?.moves.map(\.name) ?? []
        let options = Array(Set((data?.pool ?? []) + learnable + loop)).compactMap(MoveTable.move)
            .filter { !loop.contains($0.slug) }
            .sorted { ($0.isDamaging ? $0.power : -1, $1.slug) > ($1.isDamaging ? $1.power : -1, $0.slug) }
        let unlocked = store.dungeonProgress.unlockedMoves
        return ScrollView {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(options, id: \.slug) { move in
                    let locked = move.isLocked && !unlocked.contains(move.slug)
                    Button {
                        var next = loop
                        next[slot] = move.slug
                        store.setMoveLoop(next, for: entry.id)
                        editingSlot = nil
                    } label: {
                        MoveRow(store: store, slug: move.slug, speed: spec?.stats.speed ?? 100, number: nil, selected: false)
                            .opacity(locked || !move.hasEffect ? 0.4 : 1)
                    }
                    .buttonStyle(.plain)
                    .disabled(locked)
                }
            }
            .reservesScrollerLane()
        }
        .frame(maxHeight: 120)
    }
}

@MainActor
private struct LoopEditorFrame: ViewModifier {
    let asCard: Bool

    func body(content: Content) -> some View {
        if asCard {
            content.designCard()
        } else {
            content.padding(8).designSurface(cornerRadius: 10)
        }
    }
}

/// One move: its name, type, power and cast time at the caster's speed (R1); the details on hover.
@MainActor
struct MoveRow: View {
    let store: CompanionStore
    let slug: String
    let speed: Int
    let number: Int?
    let selected: Bool

    var body: some View {
        let l = store.l
        let move = MoveTable.move(slug)
        HStack(spacing: 6) {
            if let number {
                Text("\(number)").font(.caption2.weight(.bold)).monospacedDigit().frame(width: 14)
            }
            PokemonNameLabel(.move, slug, language: store.language).font(.caption.weight(.semibold))
            if let move {
                Badge(l.typeName(move.type).uppercased(), tint: .type(move.type))
            }
            Spacer(minLength: 4)
            if let move {
                if move.isLocked && !store.dungeonProgress.unlockedMoves.contains(slug) {
                    Image(systemName: "lock.fill").font(.system(size: 9)).foregroundStyle(.secondary)
                }
                Text(move.power > 0 ? "\(move.power)" : "-").font(.caption2).monospacedDigit().foregroundStyle(.secondary)
                Text(l.dungeonCast(Double(move.castBase) * 300 / (100 + Double(speed)) / Double(BattleRules.speedUp) / 1000))
                    .font(.caption2).monospacedDigit().foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2).padding(.horizontal, 4)
        .background(RoundedRectangle(cornerRadius: 6).fill(selected ? Design.actionColor.opacity(0.2) : .clear))
        .contentShape(Rectangle())
        .hoverTip(move.map { HoverTip(id: "move:\(slug)", title: l.moveDetails($0, unlocked: store.dungeonProgress.unlockedMoves)) })
    }
}

/// A placeholder until the live view lands: the battle's outcome.
@MainActor
struct BattleReplayScreen: View {
    let store: CompanionStore
    let battle: ExpeditionBattle
    var startAt = 0
    let onBack: () -> Void

    var body: some View {
        BattleReplayView(store: store, battle: battle, startAt: startAt, onBack: onBack)
    }
}

/// The form a team member fights in: its usual one or a battle form its species won, never used up (2026-11-02).
@MainActor
struct BattleFormChooser: View {
    let store: CompanionStore
    let entry: DexEntry

    var body: some View {
        let l = store.l
        let chosen = store.battleFormChoice(for: entry)
        VStack(alignment: .leading, spacing: 4) {
            Text(l.battleFormPickTitle).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            HStack(spacing: 6) {
                option(l.battleFormUsual, selected: chosen == nil) { store.setBattleForm(nil, for: entry.id) }
                ForEach(store.wonBattleForms(speciesID: entry.finalID), id: \.key) { form in
                    option(l.battleFormLabel(form), selected: chosen == form) { store.setBattleForm(form, for: entry.id) }
                }
            }
        }
    }

    private func option(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: selected ? "checkmark.circle.fill" : "circle")
                .font(.caption.weight(.semibold))
                .foregroundStyle(selected ? AnyShapeStyle(Design.actionColor) : AnyShapeStyle(.secondary))
        }
        .buttonStyle(.plain)
        .disabled(store.isExploring(entry.id))
    }
}
