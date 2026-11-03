import SwiftUI

/// How lucky the player's draws were (`HatchLuck`), from the clover on Home: the score and its six criteria, their
/// curves, and the hatches one by one. Nothing until the species index is loaded.
@MainActor
struct LuckScreen: View {
    let store: CompanionStore
    let nav: PopoverNavigation
    let onBack: () -> Void

    /// Hatches shown before "Show the others".
    private static let firstHatches = 8
    @State private var showingAllHatches = false

    var body: some View {
        @Bindable var nav = nav
        let l = store.l
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Button { onBack() } label: {
                    Label(l.back, systemImage: "chevron.left").labelStyle(.titleAndIcon)
                }
                .buttonStyle(.borderless)
                .keyboardShortcut(.cancelAction)
                Spacer(minLength: 4)
                Text(l.luckTitle).font(.headline)
            }
            PillPicker(selection: $nav.luckTab, options: PopoverNavigation.LuckTab.allCases.map { ($0, l.luckTab($0)) })
            if let luck = store.hatchLuck {
                if luck.hatches.count < 2 {
                    Text(l.luckTooFew).font(.callout).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    ScrollView {
                        Group {
                            switch nav.luckTab {
                            case .summary: summary(luck, l)
                            case .curves: curves(luck, l)
                            case .hatches: hatches(luck, l)
                            }
                        }
                        .reservesScrollerLane()
                    }
                }
            } else {
                ProgressView().controlSize(.small).frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(PopoverMetrics.padding)
        .frame(height: 540, alignment: .top)
        .task(id: store.luckInputs) { await store.loadHatchLuck() }
    }

    // MARK: Summary

    private func summary(_ luck: HatchLuck, _ l: L) -> some View {
        let score = Int(luck.score.rounded())
        let unknownEggs = luck.hatches.filter { $0.egg == nil }.count
        return VStack(alignment: .leading, spacing: 12) {
            if unknownEggs > 0 {
                unknownEggsBanner(unknownEggs, l)
            }
            VStack(alignment: .leading, spacing: 8) {
                SectionTitle(text: l.luckScoreTitle)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(score)").font(.system(size: 40, weight: .bold, design: .rounded)).monospacedDigit()
                    Text("/ 100").font(.callout).foregroundStyle(.secondary)
                }
                if let best = luck.strongest, let worst = luck.weakest {
                    let sentence = l.luckSentence(hatches: luck.hatches.count, score: score,
                                                  best: (best.criterion, best.percentile),
                                                  worst: (worst.criterion, worst.percentile))
                    Text((try? AttributedString(markdown: sentence)) ?? AttributedString(sentence))
                        .font(.callout).fixedSize(horizontal: false, vertical: true)
                }
                LuckMeter(share: luck.score / 100, height: 10)
                HStack {
                    Text(l.luckScaleLow)
                    Spacer(minLength: 4)
                    Text(l.luckScaleMiddle)
                    Spacer(minLength: 4)
                    Text(l.luckScaleHigh)
                }
                .font(.caption2).foregroundStyle(.secondary)
            }
            .designCard()
            VStack(alignment: .leading, spacing: 10) {
                SectionTitle(text: l.luckByCriterion)
                Text(l.luckByCriterionHint).font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                ForEach(luck.criteria, id: \.criterion) { result in
                    HStack(spacing: 8) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(l.luckCriterion(result.criterion)).font(.callout.weight(.semibold))
                            Group {
                                Text(l.luckCounts(hits: result.hits, expected: result.expected))
                                Text(l.luckSinceLast(result.sinceLast))
                            }
                            .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 4)
                        LuckMeter(share: result.percentile, height: 8).frame(width: 64)
                        Text(l.luckPercent(result.percentile))
                            .font(.system(.callout, design: .rounded).weight(.bold)).monospacedDigit()
                            .frame(width: 44, alignment: .trailing)
                    }
                }
            }
            .designCard()
        }
    }

    // MARK: Curves

    private func curves(_ luck: HatchLuck, _ l: L) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ScoreCurve(luck: luck, l: l, name: name)
            SectionTitle(text: l.luckCriteriaCurvesTitle)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible())], spacing: 8) {
                ForEach(luck.criteria, id: \.criterion) { result in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(l.luckCriterion(result.criterion)).lineLimit(1).minimumScaleFactor(0.8)
                            Spacer(minLength: 4)
                            Text(l.luckPercent(result.percentile)).monospacedDigit()
                        }
                        .font(.caption.weight(.semibold))
                        LuckLine(values: luck.hatches.map { $0.percentiles[result.criterion] ?? 0.5 }).frame(height: 30)
                    }
                    .designCard(padding: 8)
                }
            }
        }
    }

    // MARK: Hatches

    private func hatches(_ luck: HatchLuck, _ l: L) -> some View {
        let newestFirst = Array(luck.hatches.reversed())
        let shown = showingAllHatches ? newestFirst : Array(newestFirst.prefix(Self.firstHatches))
        let drawItems = ItemKind.drawItems.filter { store.itemCount($0) > 0 }
        let toPick = newestFirst.filter { $0.egg == nil }
        return VStack(alignment: .leading, spacing: 12) {
            if !toPick.isEmpty {
                eggsToPickCard(toPick, l)
            }
            if !drawItems.isEmpty, luck.hatches.contains(where: { $0.entry.hatch?.itemsFromDates != false }) {
                drawItemsCard(drawItems, since: luck.itemsSince, l)
            }
            if !luck.improbable.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    SectionTitle(text: l.luckImprobableTitle)
                    ForEach(luck.improbable, id: \.number) { hatch in
                        let odds = hatch.lineOdds ?? 0
                        HStack(spacing: 10) {
                            sprite(hatch, size: 34)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(name(hatch.entry, hatch.isDitto ? PokemonOdds.dittoSpeciesID : hatch.entry.baseID))
                                    .font(.callout.weight(.semibold))
                                Text(l.luckOneIn(odds) + " · " + l.luckHatchNumber(hatch.number)).font(.caption)
                                if let pace = luck.hatchesPerWeek {
                                    Text(l.luckWait(HatchLuck.averageWait(odds: odds, perWeek: pace)))
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
                .designCard()
            }
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    SectionTitle(text: l.luckHistoryTitle)
                    Spacer(minLength: 4)
                    Text(l.luckOnScore).font(.caption).foregroundStyle(.secondary)
                }
                LazyVStack(alignment: .leading, spacing: 10) {
                    ForEach(shown, id: \.number) { hatch in
                        historyRow(hatch, afterRelease: hatch.number > 1 && luck.hatches[hatch.number - 2].entry.isReleased, l)
                    }
                }
                if !showingAllHatches, newestFirst.count > shown.count {
                    Button(l.luckShowMore(newestFirst.count - shown.count)) { showingAllHatches = true }
                        .buttonStyle(.plain)
                        .font(.caption.weight(.semibold)).foregroundStyle(Design.actionColor)
                }
            }
            .designCard()
        }
    }

    private func historyRow(_ hatch: HatchLuck.Hatch, afterRelease: Bool, _ l: L) -> some View {
        let entry = hatch.entry
        let rarity = Badge(tint: .rarity(hatch.isDitto ? nil : hatch.rarity), style: .tinted) {
            Text(hatch.isDitto ? l.luckCriterion(.ditto) : l.rarityLabel(hatch.rarity))
        }
        let odds = { (badge: Badge<Text>, odds: HatchLuck.OddsRange) in
            HStack(spacing: 4) {
                badge
                Text(l.luckOdds(odds)).font(.caption).foregroundStyle(.secondary).monospacedDigit()
            }
        }
        let novelty = Badge(tint: hatch.bringsNew ? .green : .secondary, style: .tinted) {
            Text(hatch.bringsNew ? l.luckNew : l.luckNothingNew)
        }
        let direction = HatchLuck.effectDirection(hatch.effect)
        return HStack(alignment: .top, spacing: 8) {
            Text("\(hatch.number)").font(.caption2).foregroundStyle(.secondary).monospacedDigit()
                .frame(width: 24, alignment: .trailing).padding(.top, 9)
            sprite(hatch, size: 30)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    Text(name(entry, hatch.isDitto ? PokemonOdds.dittoSpeciesID : entry.baseID))
                        .font(.callout.weight(.semibold)).lineLimit(1)
                    if !hatch.isDitto, entry.finalID != entry.baseID {
                        Text("→ " + name(entry, entry.finalID)).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                    if entry.isShiny {
                        Image(systemName: "sparkle").font(.system(size: 9, weight: .bold)).foregroundStyle(Color.readableOrange)
                    }
                    if hatch.isActive {
                        Badge(tint: .accent, style: .tinted) { Text(l.dexRaising) }
                    }
                }
                .loadsFormNames(entry.form == nil ? 0 : entry.baseID)
                .loadsFormNames(entry.form == nil ? 0 : entry.finalID)
                if let newOdds = hatch.newOdds {
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 8) {
                            odds(rarity, hatch.rarityOdds)
                            odds(novelty, newOdds)
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            odds(rarity, hatch.rarityOdds)
                            odds(novelty, newOdds)
                        }
                    }
                } else {
                    odds(rarity, hatch.rarityOdds)
                }
                if hatch.asksEgg {
                    eggMenu(hatch, l)
                } else if afterRelease {
                    Text(eggName(hatch.egg, l)).font(.caption2).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 4)
            Text(l.luckEffect(hatch.effect))
                .font(.system(.callout, design: .rounded).weight(.semibold)).monospacedDigit()
                .foregroundStyle(direction > 0 ? Color.readableGreen : direction < 0 ? Color.red : Color.secondary)
                .padding(.top, 7)
        }
    }

    /// A dungeon egg by the Pokémon it hatches, as in the Bag; the others by `L.hatchEggName`.
    private func eggName(_ egg: HatchEgg?, _ l: L) -> String {
        if case .dungeon(let baseID, _, _) = egg { return DungeonEggTitle.text(baseID, l: l, language: store.language) }
        return l.hatchEggName(egg)
    }

    private func eggMenu(_ hatch: HatchLuck.Hatch, _ l: L) -> some View {
        HStack(spacing: 4) {
            if hatch.egg == nil {
                Image(systemName: "questionmark.circle.fill").font(.caption).foregroundStyle(Color.readableOrange)
            } else if hatch.eggDeduced {
                Text(l.luckDeduced).font(.caption2).foregroundStyle(.secondary)
            }
            menu(hatch, l)
        }
    }

    private func menu(_ hatch: HatchLuck.Hatch, _ l: L) -> some View {
        Menu {
            ForEach(hatch.possibleEggs, id: \.self) { egg in
                Button { store.chooseHatchEgg(egg, forEntry: hatch.entry.id) } label: {
                    HStack {
                        Text(l.hatchEggName(egg))
                        if hatch.egg == egg { Image(systemName: "checkmark") }
                    }
                }
            }
            Divider()
            Button { store.chooseHatchEgg(nil, forEntry: hatch.entry.id) } label: {
                HStack {
                    Text(l.hatchEggName(nil))
                    if hatch.egg == nil { Image(systemName: "checkmark") }
                }
            }
        } label: {
            Text(eggName(hatch.egg, l)).font(.caption)
        }
        .menuStyle(.button)
        .controlSize(.small)
        .fixedSize()
        .hoverTip(l.luckEggOfHatch)
        .accessibilityLabel(l.luckEggOfHatch)
    }

    /// Hatches whose egg is unknown only count for the shiny: the score leaves them out of the rest.
    private func unknownEggsBanner(_ count: Int, _ l: L) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Color.readableOrange)
            VStack(alignment: .leading, spacing: 4) {
                Text(l.luckApproximate).font(.caption.weight(.semibold))
                Text(l.luckUnknownEggs(count)).font(.caption).fixedSize(horizontal: false, vertical: true)
                Button(l.luckPickEggsAction) { nav.luckTab = .hatches }
                    .buttonStyle(.link).font(.caption.weight(.semibold))
            }
            Spacer(minLength: 0)
        }
        .padding(8)
        .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
    }

    private func eggsToPickCard(_ hatches: [HatchLuck.Hatch], _ l: L) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionTitle(text: l.luckEggsToPick)
            Text(l.luckUnknownEggs(hatches.count)).font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button(l.luckDontRemember) { store.deduceUnknownEggs() }
                .buttonStyle(.link).font(.caption.weight(.semibold))
                .hoverTip(l.luckDontRememberHint)
            ForEach(hatches, id: \.number) { hatch in
                HStack(spacing: 8) {
                    sprite(hatch, size: 30)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(name(hatch.entry, hatch.isDitto ? PokemonOdds.dittoSpeciesID : hatch.entry.baseID))
                            .font(.callout.weight(.semibold)).lineLimit(1)
                        Text(l.luckHatchNumber(hatch.number)).font(.caption).foregroundStyle(.secondary)
                    }
                    .loadsFormNames(hatch.entry.form == nil ? 0 : hatch.entry.baseID)
                    Spacer(minLength: 4)
                    eggMenu(hatch, l)
                }
            }
        }
        .designCard()
    }

    private func drawItemsCard(_ items: [ItemKind], since dates: [ItemKind: Date], _ l: L) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionTitle(text: l.luckDrawItemsTitle)
            Text(l.luckDrawItemsHint).font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            ForEach(items, id: \.self) { item in
                HStack(spacing: 6) {
                    Text(l.itemName(item)).font(.callout.weight(.semibold)).lineLimit(1)
                    Spacer(minLength: 4)
                    if let since = dates[item] {
                        Text(l.luckObtainedOn).font(.caption).foregroundStyle(.secondary)
                        Text(since.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted)
                            .locale(store.language.displayLocale)))
                            .font(.caption.monospacedDigit())
                    }
                }
            }
        }
        .designCard()
    }

    private func sprite(_ hatch: HatchLuck.Hatch, size: CGFloat) -> some View {
        SpriteView(speciesID: hatch.isDitto ? PokemonOdds.dittoSpeciesID : hatch.entry.baseID, size: size,
                   shiny: hatch.entry.isShiny, form: hatch.isDitto ? nil : hatch.entry.form, sameScale: true)
            .frame(width: size, height: size)
    }

    private func name(_ entry: DexEntry, _ speciesID: Int) -> String {
        guard let raw = store.language.resolveName(entry.names?[speciesID] ?? [:]) else { return "#\(speciesID)" }
        return PokemonForm.displayName(raw, speciesID: speciesID, form: entry.form, language: store.language)
    }
}

/// A share on a bar, with a mark at the middle: 50 % is average.
@MainActor
private struct LuckMeter: View {
    let share: Double
    var height: CGFloat = 8

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            ZStack(alignment: .leading) {
                Capsule().fill(Color.primary.opacity(0.1))
                Capsule().fill(Design.actionColor).frame(width: max(height, width * min(1, max(0, share))))
                Rectangle().fill(Color.secondary).frame(width: 1.5, height: height + 4).position(x: width / 2, y: height / 2)
            }
        }
        .frame(height: height)
    }
}

/// Values from 0 to 1, hatch after hatch, with the average dashed and a dot on `highlighted`, the last by default.
@MainActor
private struct LuckLine: View {
    let values: [Double]
    var highlighted: Int?

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let point = { (i: Int) in
                CGPoint(x: values.count > 1 ? size.width * CGFloat(i) / CGFloat(values.count - 1) : size.width,
                        y: size.height * (1 - CGFloat(min(1, max(0, values[i])))))
            }
            ZStack {
                Path { path in
                    path.move(to: CGPoint(x: 0, y: size.height / 2))
                    path.addLine(to: CGPoint(x: size.width, y: size.height / 2))
                }
                .stroke(Color.secondary.opacity(0.6), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                Path { path in
                    for i in values.indices {
                        if i == 0 { path.move(to: point(i)) } else { path.addLine(to: point(i)) }
                    }
                }
                .stroke(Design.actionColor, style: StrokeStyle(lineWidth: 1.5, lineJoin: .round))
                if !values.isEmpty {
                    Circle().fill(Design.actionColor).frame(width: 6, height: 6)
                        .position(point(highlighted ?? values.count - 1))
                }
            }
        }
    }
}

/// The score after each hatch, the hatch under the pointer named above it.
@MainActor
private struct ScoreCurve: View {
    let luck: HatchLuck
    let l: L
    let name: (DexEntry, Int) -> String
    @State private var hovered: Int?

    private static let height: CGFloat = 100

    var body: some View {
        let count = luck.hatches.count
        let hatch = luck.hatches[min(hovered ?? count - 1, count - 1)]
        VStack(alignment: .leading, spacing: 6) {
            SectionTitle(text: l.luckCurveTitle)
            Text(l.luckCurvePoint(number: hatch.number,
                                  name: name(hatch.entry, hatch.isDitto ? PokemonOdds.dittoSpeciesID : hatch.entry.baseID),
                                  score: Int(hatch.score.rounded())))
                .font(.caption).foregroundStyle(.secondary).lineLimit(1)
            HStack(alignment: .top, spacing: 6) {
                VStack(alignment: .trailing) {
                    Text("100")
                    Spacer(minLength: 0)
                    Text("50")
                    Spacer(minLength: 0)
                    Text("0")
                }
                .font(.caption2).foregroundStyle(.secondary).monospacedDigit()
                .frame(height: Self.height + 8)
                VStack(spacing: 4) {
                    LuckLine(values: luck.hatches.map { $0.score / 100 }, highlighted: hovered)
                        .frame(height: Self.height)
                        .padding(.vertical, 4)
                        .overlay {
                            GeometryReader { geometry in
                                Color.clear.contentShape(Rectangle())
                                    .onContinuousHover { phase in
                                        switch phase {
                                        case .active(let at):
                                            let share = at.x / max(1, geometry.size.width)
                                            hovered = min(count - 1, max(0, Int((share * CGFloat(count - 1)).rounded())))
                                        case .ended:
                                            hovered = nil
                                        }
                                    }
                            }
                        }
                    GeometryReader { geometry in
                        ForEach(Self.ticks(count), id: \.self) { tick in
                            Text("\(tick)").font(.caption2).foregroundStyle(.secondary).monospacedDigit().fixedSize()
                                .position(x: count > 1 ? geometry.size.width * CGFloat(tick - 1) / CGFloat(count - 1) : 0,
                                          y: 6)
                        }
                    }
                    .frame(height: 12)
                }
            }
        }
        .designCard()
    }

    /// The hatch numbers under the curve: the first, then every 1, 2 or 5 tens, hundreds…, eight at most.
    private static func ticks(_ count: Int) -> [Int] {
        let unit = pow(10, floor(log10(Double(max(1, count)))))
        let step = max(1, Int([1.0, 2, 5, 10].map { $0 * unit }.first { Double(count) / $0 <= 8 } ?? unit))
        return [1] + stride(from: step, through: count, by: step).filter { $0 > 1 }
    }
}
