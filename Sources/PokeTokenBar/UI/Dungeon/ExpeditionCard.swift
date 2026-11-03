import SwiftUI

/// Home while a team explores (maquettes 3, 4, 6): the floor and the tokens before the next, the team's HP, the rare
/// in gold, the journal; the emergency heal waiting for its answer (R5); the throws at the fallen boss (Q18).
@MainActor
struct ExpeditionCard: View {
    let store: CompanionStore
    let nav: PopoverNavigation
    @State private var confirmingAbandon = false
    @State private var confirmingLetGo = false

    var body: some View {
        if let e = store.expedition {
            VStack(alignment: .leading, spacing: 10) {
                header(e)
                switch e.phase {
                case .awaitingHeal(let price): heal(e, price: price)
                case .capture(let left): capture(e, throwsLeft: left)
                case .exploring, .finished: exploring(e)
                }
            }
            .designCard()
        }
    }

    private var l: L { store.l }

    private func header(_ e: Expedition) -> some View {
        HStack(spacing: 8) {
            DungeonIcon(id: e.dungeon, size: 30)
            VStack(alignment: .leading, spacing: 1) {
                Text(l.dungeonName(e.dungeon)).font(.callout.weight(.semibold))
                Text(floorLine(e)).font(.caption).foregroundStyle(.secondary).monospacedDigit()
            }
            Spacer(minLength: 4)
            if case .capture = e.phase {
                EmptyView()
            } else {
                // Where the boss waits, never who it is (Q17).
                Label(l.dungeonBossAt(e.floors), systemImage: "crown.fill")
                    .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    .hoverTip(l.dungeonBossHidden)
            }
        }
    }

    private func floorLine(_ e: Expedition) -> String {
        let floor = l.dungeonFloorOf(min(e.floor, e.floors), e.floors)
        if case .awaitingHeal = e.phase { return floor + " · " + l.dungeonPaused }
        return floor
    }

    // MARK: Exploring (maquette 3)

    /// What is going on, said once; the floors walked toward the boss; the team; what happened last.
    @ViewBuilder
    private func exploring(_ e: Expedition) -> some View {
        let floor = min(e.floor, e.floors)
        let have = TokenFormatter.compact(e.floorTokens)
        let need = TokenFormatter.compact(e.floorCost)
        let toBoss = (e.floors - floor) * e.floorCost + max(0, e.floorCost - e.floorTokens)
        Text(l.dungeonExploringNow).font(.caption).foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        VStack(alignment: .leading, spacing: 4) {
            ExpeditionFloors(floor: floor, floors: e.floors, progress: Double(e.floorTokens) / Double(max(1, e.floorCost)))
            Text(e.floor >= e.floors ? l.dungeonToBoss(have, need) : l.dungeonToNextFloor(have, need, next: e.floor + 1))
                .font(.caption2).foregroundStyle(.secondary).monospacedDigit()
            if e.floor < e.floors {
                Text(l.dungeonLeftToBoss(TokenFormatter.compact(toBoss)))
                    .font(.caption2).foregroundStyle(.secondary).monospacedDigit()
            }
        }
        sectionLabel(l.dungeonTeamTitle)
        ExpeditionTeamGrid(store: store, team: e.team)
        let rare = e.log.last(where: \.isRare)
        let recent = e.log.filter { $0.id != rare?.id }.suffix(4).reversed()
        if rare != nil || !recent.isEmpty { sectionLabel(l.dungeonRecentTitle) }
        if let rare {
            ExpeditionLogRow(store: store, nav: nav, entry: rare, team: e.team)
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(LegendaryHeroBackground.gold.opacity(0.16)))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(LegendaryHeroBackground.gold.opacity(0.55)))
                .overlay(alignment: .topTrailing) {
                    Badge("✦ " + l.dungeonRare.uppercased(), tint: .orange, style: .tinted).padding(4)
                }
        }
        if !recent.isEmpty {
            VStack(alignment: .leading, spacing: 5) {
                ForEach(Array(recent)) { entry in
                    ExpeditionLogRow(store: store, nav: nav, entry: entry, team: e.team)
                }
            }
        }
        if confirmingAbandon {
            abandonConfirmation
        } else {
            HStack(spacing: 8) {
                if e.log.count > 4 {
                    Button(l.dungeonWholeLog) { nav.showingExpeditionLog = true }
                        .buttonStyle(.borderless).controlSize(.small).font(.caption.weight(.semibold))
                }
                Spacer(minLength: 4)
                Button(l.dungeonAbandon) { confirmingAbandon = true }
                    .buttonStyle(.borderless).controlSize(.small).font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased()).font(.caption2.weight(.bold)).tracking(0.6).foregroundStyle(.secondary)
            .padding(.top, 2)
    }

    /// Inline, as the Bag's confirmations: a sheet or an alert left behind by the closing popover would swallow clicks.
    private var abandonConfirmation: some View {
        let hasRope = store.itemCount(.escapeRope) > 0
        return VStack(alignment: .leading, spacing: 6) {
            Text(l.dungeonAbandonCost(rope: l.itemName(.escapeRope), has: hasRope))
                .font(.caption).foregroundStyle(hasRope ? Color.secondary : Color.readableOrange)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                Spacer(minLength: 0)
                Button(l.cancel) { confirmingAbandon = false }
                    .buttonStyle(.borderless).controlSize(.small)
                Button(l.dungeonLeave) {
                    confirmingAbandon = false
                    store.abandonExpedition()
                }
                .buttonStyle(.pill(prominent: true))
            }
        }
    }

    // MARK: The emergency heal (R5, maquette 4)

    @ViewBuilder
    private func heal(_ e: Expedition, price: Int) -> some View {
        let available = store.availableTokens
        Label(l.dungeonTeamInDanger(Int((e.hpShare * 100).rounded())), systemImage: "exclamationmark.triangle.fill")
            .font(.callout.weight(.semibold)).foregroundStyle(Color.readableOrange)
        ExpeditionTeamGrid(store: store, team: e.team)
        Text(l.dungeonHealExplain).font(.caption).foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        Text(l.dungeonHealPrice(TokenFormatter.compact(price), have: TokenFormatter.compact(available)))
            .font(.caption.weight(.semibold)).monospacedDigit()
        HStack(spacing: 8) {
            Spacer(minLength: 0)
            Button(l.dungeonHealSkip) { store.answerEmergencyHeal(pay: false) }
                .buttonStyle(.pill())
            Button(l.dungeonHealPay(TokenFormatter.compact(price))) { store.answerEmergencyHeal(pay: true) }
                .buttonStyle(.pill(prominent: true))
                .disabled(available < price)
        }
        if e.reserve > 0 {
            Label(l.dungeonReserve(TokenFormatter.compact(e.reserve)), systemImage: "hourglass")
                .font(.caption2).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: The capture (Q18, maquette 6)

    @ViewBuilder
    private func capture(_ e: Expedition, throwsLeft: Int) -> some View {
        let misses = e.log.filter { if case .capture(_, _, false) = $0.kind { return true }; return false }.count
        Text(l.dungeonBossWas(e.floors)).font(.caption).foregroundStyle(.secondary)
        HStack(spacing: 12) {
            SpriteView(speciesID: e.boss.speciesID, size: 64, shiny: e.boss.isShiny, form: e.boss.form, sameScale: true)
            VStack(alignment: .leading, spacing: 4) {
                PokemonNameLabel(.pokemonSpecies, String(e.boss.speciesID), language: store.language)
                    .font(.headline)
                Text(l.dungeonBossBeatenThrow).font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if misses > 0 {
                    HStack(spacing: 4) {
                        ForEach(0..<misses, id: \.self) { _ in
                            Badge("✗ " + l.dungeonMissed, tint: .orange, style: .tinted)
                        }
                    }
                }
            }
        }
        Text(l.dungeonThrowsLeft(throwsLeft)).font(.caption.weight(.semibold)).monospacedDigit()
        VStack(alignment: .leading, spacing: 6) {
            throwButton(e, ball: nil, name: l.dungeonPokeBall, count: nil)
            ForEach([ItemKind.greatBall, .ultraBall, .masterBall], id: \.self) { ball in
                let count = store.itemCount(ball)
                if count > 0 { throwButton(e, ball: ball, name: l.itemName(ball), count: count) }
            }
        }
        if confirmingLetGo {
            VStack(alignment: .leading, spacing: 6) {
                Text(l.dungeonLetGoCost).font(.caption).foregroundStyle(Color.readableOrange)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 8) {
                    Spacer(minLength: 0)
                    Button(l.cancel) { confirmingLetGo = false }
                        .buttonStyle(.borderless).controlSize(.small)
                    Button(l.dungeonLetGo) {
                        confirmingLetGo = false
                        store.endCapture()
                    }
                    .buttonStyle(.pill(prominent: true))
                }
            }
        } else {
            HStack {
                Spacer()
                Button(l.dungeonLetGo) { confirmingLetGo = true }
                    .buttonStyle(.borderless).controlSize(.small).font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func throwButton(_ e: Expedition, ball: ItemKind?, name: String, count: Int?) -> some View {
        let percent = Int((ExpeditionEngine.throwOdds(e.boss, ball: ball) * 100).rounded())
        return Button { store.throwAtBoss(ball) } label: {
            HStack(spacing: 6) {
                if let ball { ItemIconView(kind: ball, size: 18) } else { Image(systemName: "circle.circle.fill") }
                Text(l.dungeonThrowOdds(name, percent)).monospacedDigit()
                Spacer(minLength: 4)
                if let count { Text("×\(count)").font(.caption).foregroundStyle(.secondary).monospacedDigit() }
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered).controlSize(.regular)
    }
}

/// The team's HP, two by row: blue bar, the share left; an orange "!" under a quarter, "K.O." once down.
@MainActor
struct ExpeditionTeamGrid: View {
    let store: CompanionStore
    let team: [ExpeditionMember]

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
                  alignment: .leading, spacing: 6) {
            ForEach(team, id: \.entryID) { member in
                row(member)
            }
        }
    }

    private func row(_ member: ExpeditionMember) -> some View {
        let spec = member.spec
        let share = Double(max(0, spec.hp)) / Double(max(1, spec.stats.hp))
        return HStack(spacing: 5) {
            SpriteView(speciesID: spec.speciesID, size: 24, shiny: spec.isShiny, form: spec.form, sameScale: true)
                .opacity(member.isFainted ? 0.35 : 1)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 3) {
                    PokemonNameLabel(.pokemonSpecies, String(spec.speciesID), language: store.language)
                        .font(.caption2.weight(.semibold)).lineLimit(1)
                    GenderGlyph(gender: spec.resolvedGender, l: store.l)
                    Spacer(minLength: 2)
                    if member.isFainted {
                        Text(store.l.battleKO).font(.caption2.weight(.bold)).foregroundStyle(.secondary)
                    } else {
                        if share < ExpeditionEngine.healThreshold {
                            Text("!").font(.caption2.weight(.heavy)).foregroundStyle(Color.readableOrange)
                        }
                        Text("\(Int((share * 100).rounded()))%").font(.caption2).monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }
                ExpeditionBar(value: share, color: .blue, height: 4)
            }
        }
    }
}

/// A thin bar: the HP left, the tokens toward the next floor.
@MainActor
struct ExpeditionBar: View {
    let value: Double
    let color: Color
    var height: CGFloat = 4

    var body: some View {
        Capsule().fill(Color.primary.opacity(0.12))
            .overlay(alignment: .leading) {
                GeometryReader { geometry in
                    Capsule().fill(color.opacity(0.85)).frame(width: geometry.size.width * min(1, max(0, value)))
                }
            }
            .frame(height: height)
    }
}

/// One line of the journal: its floor, what happened, the species as sprites (named on hover), the loot as icons; a
/// battle replays, live while it is still being fought.
@MainActor
struct ExpeditionLogRow: View {
    let store: CompanionStore
    let nav: PopoverNavigation
    let entry: ExpeditionLogEntry
    let team: [ExpeditionMember]

    private var l: L { store.l }

    var body: some View {
        HStack(alignment: .center, spacing: 6) {
            Text(l.dungeonFloor(entry.floor)).font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
                .frame(minWidth: 44, alignment: .leading)
            content
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch entry.kind {
        case .battle(let battle):
            battleLine(battle)
        case .chest(let loot):
            line("shippingbox.fill", loot.isEmpty ? l.dungeonLogEmptyChest : l.dungeonLogChest)
            ExpeditionLootIcons(loot: loot)
        case .trap(let percent, let item):
            line("exclamationmark.triangle", item.flatMap(ItemKind.init(rawValue:)).map { l.dungeonLogTrapItem(l.itemName($0)) }
                 ?? l.dungeonLogTrap(percent: percent))
        case .spring(let percent):
            line("drop.fill", l.dungeonLogSpring(percent: percent))
        case .center:
            line("cross.case.fill", l.dungeonLogCenter)
        case .lost(let species, let percent, let loot):
            sprite(species)
            line(nil, l.dungeonLogLost(percent: percent))
            ExpeditionLootIcons(loot: loot)
        case .shiny(let species, let caught):
            sprite(species, shiny: true)
            line("sparkles", l.dungeonLogShiny(caught: caught))
        case .branch(let roll, let risky):
            line(risky ? "dice.fill" : "dice", l.dungeonLogBranch(roll: roll, risky: risky))
        case .revive(let entryID, let max):
            if let member = team.first(where: { $0.entryID == entryID }) {
                sprite(member.spec.speciesID, shiny: member.spec.isShiny, form: member.spec.form)
            }
            ItemIconView(kind: max ? .maxRevive : .revive, size: 16)
            line(nil, l.dungeonLogItemUsed(l.itemName(max ? .maxRevive : .revive)))
        case .emergencyHeal(let paid):
            line("heart.fill", l.dungeonLogHeal(TokenFormatter.compact(paid)))
        case .bossReached(let species, let shiny):
            sprite(species, shiny: shiny)
            line("crown.fill", l.dungeonLogBoss)
        case .capture(let attempt, let ball, let caught):
            let kind = ball.flatMap(ItemKind.init(rawValue:))
            if let kind { ItemIconView(kind: kind, size: 16) }
            line(kind == nil ? "circle.circle" : nil,
                 l.dungeonLogThrow(attempt, ball: kind.map(l.itemName) ?? l.dungeonPokeBall, caught: caught))
        case .victory:
            line("flag.checkered", l.dungeonLogVictory)
        case .defeat:
            line("xmark.octagon", l.dungeonLogDefeat)
        case .abandon(let rope):
            line("figure.walk", l.dungeonLogAbandon(rope: rope ? l.itemName(.escapeRope) : nil))
        }
    }

    private func line(_ symbol: String?, _ text: String) -> some View {
        HStack(spacing: 4) {
            if let symbol { Image(systemName: symbol).font(.caption2).foregroundStyle(.secondary) }
            Text(text).font(.caption).fixedSize(horizontal: false, vertical: true)
        }
    }

    private func sprite(_ species: Int, shiny: Bool = false, form: PokemonForm? = nil) -> some View {
        SpriteView(speciesID: species, size: 20, shiny: shiny, form: form, sameScale: true)
            .speciesNameTooltip(species, form: form, language: store.language)
    }

    /// The team's sprites against the foes', the outcome by glyph and word, and the way to watch it.
    private func battleLine(_ battle: ExpeditionBattle) -> some View {
        let sides = battle.setup.sides
        let ours = sides.first?.battlers ?? []
        let theirs = sides.count > 1 ? sides[1].battlers : []
        let since = Int(Date().timeIntervalSince(entry.date) * 1000)
        let live = since >= 0 && since < battle.duration
        // Two sprites a side and words that never break: three a side cut "Horde" and "Replay" in two in English.
        return HStack(spacing: 4) {
            Text(l.battleKind(battle.kind)).font(.caption.weight(.semibold)).lineLimit(1).fixedSize()
            sprites(ours, limit: 2)
            Text("vs").font(.caption2).foregroundStyle(.secondary).fixedSize()
            sprites(theirs, limit: 2)
            Image(systemName: battle.won ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.caption2)
                .foregroundStyle(battle.won ? Design.actionColor : Color.readableOrange)
                .hoverTip(battle.won ? l.battleWon : l.battleLost)
            Spacer(minLength: 4)
            Button {
                nav.replayStart = live ? since : 0
                nav.replayBattle = battle
            } label: {
                // Live, the antenna alone: its word as well no longer fit the line in French or Spanish.
                Group {
                    if live { Image(systemName: "dot.radiowaves.left.and.right") } else { Text(l.dungeonReplay) }
                }
                .font(.caption2.weight(.semibold)).foregroundStyle(Design.actionColor)
                .lineLimit(1).fixedSize()
            }
            .buttonStyle(.plain)
            .hoverTip(live ? l.dungeonLive : nil)
            .accessibilityLabel(live ? l.dungeonLive : l.dungeonReplay)
        }
    }

    private func sprites(_ battlers: [BattlerSpec], limit: Int) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(battlers.prefix(limit).enumerated()), id: \.offset) { _, battler in
                sprite(battler.speciesID, shiny: battler.isShiny, form: battler.form)
            }
            if battlers.count > limit {
                Text("+\(battlers.count - limit)").font(.caption2).foregroundStyle(.secondary).fixedSize()
            }
        }
    }
}

/// Loot as small icons with their counts: candies, items, eggs.
@MainActor
struct ExpeditionLootIcons: View {
    let loot: ExpeditionLoot

    var body: some View {
        HStack(spacing: 4) {
            if loot.candies > 0 { icon(.rareCandy, loot.candies) }
            ForEach(loot.items.filter { $0.value > 0 }.sorted { $0.key < $1.key }, id: \.key) { key, count in
                if let kind = ItemKind(rawValue: key) { icon(kind, count) }
            }
            ForEach(loot.eggs) { egg in
                SpriteView(speciesID: nil, size: 16, egg: .dungeon(egg.sourceSpeciesID))
            }
        }
    }

    private func icon(_ kind: ItemKind, _ count: Int) -> some View {
        HStack(spacing: 1) {
            ItemIconView(kind: kind, size: 16)
            if count > 1 { Text("×\(count)").font(.caption2).monospacedDigit().foregroundStyle(.secondary) }
        }
    }
}

/// The return (maquette 7): how it went, what came back to the Bag, what opened; until the player closes it.
@MainActor
struct ExpeditionResultCard: View {
    let store: CompanionStore
    let nav: PopoverNavigation

    var body: some View {
        if let r = store.dungeonProgress.lastResult {
            content(r, store.l)
        }
    }

    private func content(_ r: ExpeditionResult, _ l: L) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                DungeonIcon(id: r.dungeon, size: 30)
                Label(l.dungeonResultTitle(won: r.won, roped: r.roped),
                      systemImage: r.won ? "checkmark.seal.fill" : r.roped ? "arrow.uturn.left.circle.fill" : "xmark.seal.fill")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(r.won ? Design.actionColor : Color.readableOrange)
                Spacer(minLength: 4)
                if r.firstVictory { Badge(l.dungeonFirstVictory.uppercased(), tint: .blue, style: .tinted) }
            }
            Text([l.dungeonName(r.dungeon), TokenFormatter.compact(r.tokens),
                  l.longDuration(r.endedAt.timeIntervalSince(r.startedAt)), l.dungeonBattles(r.battles)]
                .joined(separator: " · "))
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            // A challenge's boss is no capture: the form it gave says it below.
            if r.won, !r.dungeon.isChallenge {
                HStack(spacing: 8) {
                    SpriteView(speciesID: r.boss.speciesID, size: 36, shiny: r.boss.isShiny, form: r.boss.form,
                               sameScale: true)
                    VStack(alignment: .leading, spacing: 1) {
                        PokemonNameLabel(.pokemonSpecies, String(r.boss.speciesID), language: store.language)
                            .font(.caption.weight(.semibold))
                        Text(r.caught ? l.dungeonBossCaught : l.dungeonBossNotCaught)
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }
            if r.loot.isEmpty, !r.won {
                Text(l.dungeonLootLost).font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                lootRows(r, l)
            }
            if !r.unlocked.isEmpty {
                Label(l.dungeonUnlocked(r.unlocked.map(l.dungeonName).joined(separator: ", ")), systemImage: "lock.open.fill")
                    .font(.caption.weight(.semibold))
            }
            if let key = r.battleForm, let form = BattleForms.form(key: key) {
                HStack(spacing: 6) {
                    SpriteView(speciesID: form.speciesID, size: 28, form: form.form, sameScale: true)
                    BattleFormTitle(form: form, language: store.language, wrap: l.challengeFormWon)
                        .font(.callout.weight(.semibold))
                }
            }
            if let move = r.unlockedMove {
                HStack(spacing: 4) {
                    Image(systemName: "opticaldisc.fill").font(.caption)
                    Text(l.dungeonTechnicalCapsule).font(.caption)
                    Text("·").font(.caption).foregroundStyle(.secondary)
                    PokemonNameLabel(.move, move, language: store.language).font(.caption.weight(.semibold))
                }
            }
            Label(l.dungeonGrowthResumes, systemImage: "play.circle").font(.caption2).foregroundStyle(.secondary)
            HStack(spacing: 8) {
                Button(l.dungeonSeeLog) { nav.showingExpeditionLog = true }
                    .buttonStyle(.borderless).controlSize(.small).font(.caption.weight(.semibold))
                Spacer(minLength: 4)
                if store.expedition == nil, store.isDungeonOpen(r.dungeon) {
                    Button(l.dungeonGoAgain) {
                        store.dismissExpeditionResult()
                        nav.dungeonTeam = r.dungeon
                    }
                    .buttonStyle(.pill())
                    .disabled(!store.canEnter(r.dungeon))
                }
                Button(l.close) { store.dismissExpeditionResult() }
                    .buttonStyle(.pill(prominent: true))
            }
        }
        .designCard()
    }

    private func lootRows(_ r: ExpeditionResult, _ l: L) -> some View {
        let items = r.loot.items.filter { $0.value > 0 }.compactMap { key, count in ItemKind(rawValue: key).map { ($0, count) } }
            .sorted { $0.0.rawValue < $1.0.rawValue }
        return VStack(alignment: .leading, spacing: 3) {
            if r.loot.candies > 0 {
                lootRow(.rareCandy, r.loot.candies, l, doubled: r.firstVictory)
            }
            ForEach(items, id: \.0) { kind, count in
                lootRow(kind, count, l, doubled: false)
            }
            ForEach(r.loot.eggs) { egg in
                HStack(spacing: 6) {
                    SpriteView(speciesID: nil, size: 18, egg: .dungeon(egg.sourceSpeciesID))
                    DungeonEggTitle(speciesID: egg.baseID, l: l, language: store.language).font(.caption)
                    if egg.isShiny { Image(systemName: "sparkles").font(.caption2).foregroundStyle(.secondary) }
                }
            }
        }
    }

    private func lootRow(_ kind: ItemKind, _ count: Int, _ l: L, doubled: Bool) -> some View {
        HStack(spacing: 6) {
            ItemIconView(kind: kind, size: 18)
            Text("\(l.itemName(kind)) ×\(count)").font(.caption).monospacedDigit()
            if doubled, count > 1 {
                Text("(\(count / 2) ×2)").font(.caption2).foregroundStyle(.secondary).monospacedDigit()
            }
        }
    }
}

/// The whole journal, of the expedition under way or of the last one back.
@MainActor
struct ExpeditionLogScreen: View {
    let store: CompanionStore
    let nav: PopoverNavigation

    var body: some View {
        let l = store.l
        let e = store.expedition
        let log = e?.log ?? store.dungeonProgress.lastResult?.log ?? []
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Button { nav.showingExpeditionLog = false } label: {
                    Label(l.back, systemImage: "chevron.left").labelStyle(.titleAndIcon)
                }
                .buttonStyle(.borderless)
                .keyboardShortcut(.cancelAction)
                Spacer(minLength: 4)
                Text(l.dungeonLogTitle).font(.headline)
            }
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 6) {
                    ForEach(log.reversed()) { entry in
                        ExpeditionLogRow(store: store, nav: nav, entry: entry, team: e?.team ?? [])
                    }
                }
                .reservesScrollerLane()
            }
        }
        .padding(PopoverMetrics.padding)
        .frame(height: 520, alignment: .top)
    }
}

/// The Pokémon raised (or its egg) while a team explores: one small line under the expedition, its growth paused. The
/// whole card comes back as soon as the growth does, at the boss's fall or the team's defeat.
@MainActor
struct PausedCompanionStrip: View {
    let store: CompanionStore

    var body: some View {
        let l = store.l
        HStack(spacing: 8) {
            Group {
                if store.hasActive {
                    SpriteView(speciesID: store.currentSpeciesID, size: 26, shiny: store.state.active?.isShiny == true,
                               form: store.currentForm, sameScale: true)
                } else {
                    SpriteView(speciesID: nil, size: 26, egg: store.eggKind)
                }
            }
            .frame(width: 30, height: 30)
            .background(Circle().fill(Color.primary.opacity(0.06)))
            VStack(alignment: .leading, spacing: 1) {
                Text(store.displayName).font(.caption.weight(.semibold)).lineLimit(1)
                Text(l.companionPausedForExpedition).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 4)
            Image(systemName: "pause.circle.fill").font(.callout).foregroundStyle(.secondary)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .designSurface(cornerRadius: Design.cornerRadius)
        .accessibilityElement(children: .combine)
    }
}

/// The dungeon's floors as segments: those walked full, the current one filling with the tokens, the boss's last
/// under a crown. Full and empty differ by fill, not only by color.
@MainActor
struct ExpeditionFloors: View {
    let floor: Int
    let floors: Int
    let progress: Double

    var body: some View {
        HStack(spacing: 2) {
            ForEach(1...max(1, floors), id: \.self) { n in
                GeometryReader { geo in
                    let share = n < floor ? 1 : n == floor ? min(1, max(0, progress)) : 0
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.primary.opacity(0.1))
                        Capsule().fill(Design.actionColor).frame(width: geo.size.width * share)
                    }
                }
                .frame(height: 6)
            }
            Image(systemName: "crown.fill").font(.system(size: 9, weight: .bold)).foregroundStyle(.secondary)
                .padding(.leading, 2)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityValue("\(floor)/\(floors)")
    }
}
