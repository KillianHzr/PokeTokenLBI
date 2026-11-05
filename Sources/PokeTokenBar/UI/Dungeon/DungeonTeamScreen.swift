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
    /// A challenge's boss as the screen opened: shown, estimated and set off against, even past midnight.
    @State private var shownBoss: BattleForm?
    /// Checked: the automatic throws may take the Master Ball at a legendary boss (the owner, 2026-11-04).
    @State private var useMasterBall = true
    @State private var search = ""
    /// The candidate under the pointer: its moves and their types show before it is picked (a player, 2026-11-05).
    @State private var hovered: String?

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
                DungeonIcon(id: dungeon, size: 20,
                            boss: (shownBoss ?? store.challengeBoss(dungeon)).map { ExpeditionBoss(speciesID: $0.speciesID, form: $0.form, isShiny: false) })
                Text(l.dungeonName(dungeon)).font(.headline)
            }
            rulesBox(size: size, rules: rules, team: candidates, l)
            teamRow(picked, size: size)
            if let focus, let entry = picked.first(where: { $0.id == focus }) {
                // The member's panel first: with the battle forms shown, the move picker shrank to a row and a half while
                // the candidates kept their room. The candidates scroll instead.
                VStack(alignment: .leading, spacing: 8) {
                    // A visible way out of the team: it was a right click only (a player, 2026-11-05).
                    HStack {
                        Spacer(minLength: 0)
                        Button(l.dungeonRemove, systemImage: "minus.circle") {
                            team.removeAll { $0 == entry.id }
                            self.focus = nil
                            editingSlot = nil
                        }
                        .buttonStyle(.borderless).controlSize(.small).font(.caption)
                    }
                    if !store.wonBattleForms(speciesID: entry.finalID).isEmpty {
                        BattleFormChooser(store: store, entry: entry)
                    }
                    LoopEditor(store: store, entry: entry, dungeon: dungeon, editingSlot: $editingSlot)
                }
                .layoutPriority(1)
            } else if let hovered, let entry = store.dungeonCandidates.first(where: { $0.id == hovered }) {
                CandidateMovesPreview(store: store, entry: entry, dungeon: dungeon)
            } else {
                // What to do next, said where it is done.
                Text(picked.count < size ? l.dungeonTeamPickHint(compose: l.dungeonComposeForMe) : l.dungeonTeamEditHint)
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            TextField(l.dexSearchPlaceholder, text: $search)
                .textFieldStyle(.roundedBorder).controlSize(.small)
            ScrollView {
                candidateList(size: size, rules: rules, l)
                    .reservesScrollerLane()
            }
            .frame(minHeight: 46)
            footer(size: size, rules: rules, team: candidates, l)
        }
        .padding(PopoverMetrics.padding)
        .frame(height: 520, alignment: .top)
        .onAppear {
            if dungeon.isChallenge, shownBoss == nil { shownBoss = store.challengeBoss(dungeon) }
            // The general team, as far as this dungeon's rules admit it (a player, 2026-11-05).
            if team.isEmpty { team = store.startingTeam(for: dungeon) }
        }
        // Again when a member changes form or moves: its spec changes with them, not the team's ids.
        .task(id: estimateKey) { await estimate() }
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

    /// The candidates, one cell per species, form and shininess: a player with nine Seedot saw nine identical cells
    /// (a player, 2026-11-05). Each cell stands for the copy picked already, else the one whose moves were chosen,
    /// else the best IVs; `count` its copies.
    static func candidateGroups(_ entries: [DexEntry], picked: [String], loops: [String: [String]])
        -> [(entry: DexEntry, count: Int)] {
        func ivTotal(_ e: DexEntry) -> Int {
            e.profile.map { $0.ivs.hp + $0.ivs.attack + $0.ivs.defense + $0.ivs.specialAttack + $0.ivs.specialDefense + $0.ivs.speed } ?? 0
        }
        func rank(_ e: DexEntry) -> (Int, Int, Int) { (picked.contains(e.id) ? 1 : 0, loops[e.id] == nil ? 0 : 1, ivTotal(e)) }
        var order: [String] = []
        var groups: [String: [DexEntry]] = [:]
        for e in entries {
            let key = "\(e.finalID)|\(e.form?.rawValue ?? "")|\(e.isShiny)"
            if groups[key] == nil { order.append(key) }
            groups[key, default: []].append(e)
        }
        return order.compactMap { key in
            guard let copies = groups[key], let best = copies.max(by: { rank($0) < rank($1) }) else { return nil }
            return (best, copies.count)
        }
    }

    private func candidateList(size: Int, rules: [DungeonRule], _ l: L) -> some View {
        let admitted = store.dungeonCandidates.filter { DungeonTeamRules.admits(DungeonCandidate($0), rules: rules) }
        return TeamCandidateGrid(store: store, candidates: admitted, size: size, query: search, team: $team, focus: $focus,
                                 hovered: $hovered)
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
            // The automatic throws take the Master Ball at a legendary boss unless it stays home for this one.
            if store.itemCount(.masterBall) > 0, store.mayMeetALegendary(dungeon, boss: shownBoss ?? store.challengeBoss(dungeon)) {
                Toggle(isOn: $useMasterBall) {
                    Text(l.dungeonUseMasterBall(l.itemName(.masterBall))).font(.caption)
                }
                .toggleStyle(.checkbox)
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
                    if store.startExpedition(dungeon, team: self.team, expectedBoss: shownBoss, keepsMasterBall: !useMasterBall) {
                        onDepart()
                    } else if dungeon.isChallenge {
                        // Midnight came: the new period's boss, shown and estimated before anything is spent.
                        shownBoss = store.challengeBoss(dungeon)
                    }
                }
                .buttonStyle(.pill(prominent: true))
                .disabled(!valid || !store.canEnter(dungeon))
            }
        }
    }

    /// R7: run off the main thread, the team's specs made here.
    /// The team, each member's battle form and loop: what the estimate depends on.
    private var estimateKey: [String] {
        team.map { id in
            "\(id)|\(store.dungeonProgress.battleFormChoice[id] ?? "")|\((store.dungeonProgress.moveLoops[id] ?? []).joined(separator: ","))"
        } + [shownBoss?.key ?? ""]
    }

    private func estimate() async {
        odds = nil
        let (size, rules) = store.teamRules(dungeon)
        let picked = team.compactMap { id in store.dungeonCandidates.first { $0.id == id } }
        guard DungeonTeamRules.isValid(picked.map(DungeonCandidate.init), size: size, rules: rules),
              let estimate = store.reachEstimate(team: team, for: dungeon, boss: shownBoss) else { return }
        try? await Task.sleep(for: .milliseconds(250))
        guard !Task.isCancelled else { return }
        // The Bag's berries and Revives go along, as at the departure; a challenge's boss stands at the end.
        let value = await BattleEngine.offMain { estimate.run() }
        guard !Task.isCancelled else { return }
        odds = value
    }
}

/// The candidates of a team, one cell per species, form and shininess (`candidateGroups`), searchable: a click picks or
/// drops one, the pointer shows its moves (`CandidateMovesPreview`). The team screens' shared grid.
@MainActor
struct TeamCandidateGrid: View {
    let store: CompanionStore
    let candidates: [DexEntry]
    let size: Int
    var query = ""
    @Binding var team: [String]
    @Binding var focus: String?
    @Binding var hovered: String?

    var body: some View {
        let l = store.l
        let shown = CompanionStore.DexSearchMatcher(query).map { matcher in candidates.filter { matcher.matches($0) } } ?? candidates
        if shown.isEmpty {
            Text(l.dungeonNoCandidate).font(.caption).foregroundStyle(.secondary)
        } else {
            let groups = DungeonTeamScreen.candidateGroups(shown, picked: team, loops: store.dungeonProgress.moveLoops)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 6), spacing: 4) {
                ForEach(groups, id: \.entry.id) { group in
                    cell(group.entry, count: group.count, l)
                }
            }
        }
    }

    private func cell(_ entry: DexEntry, count: Int, _ l: L) -> some View {
        let chosen = team.contains(entry.id)
        let blocked = !chosen && (team.count >= size
            || team.contains { id in store.dungeonCandidates.first { $0.id == id }?.finalID == entry.finalID })
        return Button {
            if chosen {
                team.removeAll { $0 == entry.id }
                if focus == entry.id { focus = nil }
            } else if !blocked {
                team.append(entry.id)
            }
        } label: {
            SpriteView(speciesID: entry.finalID, size: 40, shiny: entry.isShiny, form: entry.form, sameScale: true)
                .opacity(blocked ? 0.35 : 1)
                .background(RoundedRectangle(cornerRadius: 8).fill(chosen ? Design.actionColor.opacity(0.25) : .clear))
                .overlay(alignment: .bottomTrailing) {
                    if count > 1 {
                        Text(l.catchCount(count)).font(.system(size: 9, weight: .bold)).monospacedDigit()
                            .padding(.horizontal, 3).background(Capsule().fill(.background.opacity(0.85)))
                    }
                }
        }
        .buttonStyle(.plain)
        .onHover { inside in
            if inside { hovered = entry.id } else if hovered == entry.id { hovered = nil }
        }
        .speciesNameTooltip(entry.finalID, form: entry.form, language: store.language)
    }
}

/// A candidate's four moves with their types, before it is picked: what it would loop in this dungeon.
@MainActor
struct CandidateMovesPreview: View {
    let store: CompanionStore
    let entry: DexEntry
    let dungeon: DungeonID?

    var body: some View {
        let l = store.l
        let spec = store.dungeonSpec(entry, for: dungeon)
        VStack(alignment: .leading, spacing: 3) {
            PokemonNameLabel(.pokemonSpecies, String(entry.finalID), language: store.language)
                .font(.caption.weight(.semibold))
            LazyVGrid(columns: [GridItem(.flexible(), alignment: .leading), GridItem(.flexible(), alignment: .leading)],
                      alignment: .leading, spacing: 3) {
                ForEach(spec?.moves ?? [], id: \.self) { slug in
                    HStack(spacing: 4) {
                        if let move = MoveTable.move(slug) {
                            let type = spec.map { move.type(for: $0) } ?? move.type
                            Badge(l.typeName(type).uppercased(), tint: .type(type))
                        }
                        PokemonNameLabel(.move, slug, language: store.language).font(.caption2).lineLimit(1)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
                            selected: editingSlot == index, spec: spec)
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
            .filter { !loop.contains($0.slug) && !$0.isZOrMax }
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
                        MoveRow(store: store, slug: move.slug, speed: spec?.stats.speed ?? 100, number: nil, selected: false,
                                spec: spec)
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
    /// The Pokémon it is shown for: Hidden Power, Judgment and the others take their type from it.
    var spec: BattlerSpec?

    var body: some View {
        let l = store.l
        let move = MoveTable.move(slug)
        let type = move.map { move in spec.map { move.type(for: $0) } ?? move.type }
        HStack(spacing: 6) {
            if let number {
                Text("\(number)").font(.caption2.weight(.bold)).monospacedDigit().frame(width: 14)
            }
            PokemonNameLabel(.move, slug, language: store.language).font(.caption.weight(.semibold))
            if let type {
                Badge(l.typeName(type).uppercased(), tint: .type(type))
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
        .hoverTip(move.map { HoverTip(id: "move:\(slug)", title: l.moveDetails($0, unlocked: store.dungeonProgress.unlockedMoves, type: type)) })
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
            // On one line when they fit, else one under the other: "Mega (Curly Form)" thrice does not.
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 6) { options(chosen, l) }
                VStack(alignment: .leading, spacing: 3) { options(chosen, l) }
            }
        }
    }

    @ViewBuilder
    private func options(_ chosen: BattleForm?, _ l: L) -> some View {
        option(l.battleFormUsual, selected: chosen == nil) { store.setBattleForm(nil, for: entry.id) }
        ForEach(store.wonBattleForms(speciesID: entry.finalID), id: \.key) { form in
            // Its own form named when the species has several (Tatsugiri, Urshifu, Toxtricity).
            option(PokemonForm.label(speciesID: form.speciesID, form: form.form, language: store.language) ?? l.battleFormLabel(form),
                   selected: chosen == form) { store.setBattleForm(form, for: entry.id) }
        }
    }

    private func option(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: selected ? "checkmark.circle.fill" : "circle")
                .font(.caption.weight(.semibold))
                .foregroundStyle(selected ? AnyShapeStyle(Design.actionColor) : AnyShapeStyle(.secondary))
                .fixedSize()
        }
        .buttonStyle(.plain)
        .disabled(store.isExploring(entry.id))
    }
}
