import SwiftUI

extension CompanionStore {
    /// "Repeat (already graduated) ×2", "Badges +5%", "Sun Flute +25%": one growth factor in words.
    func growthFactorLine(_ factor: GrowthFactor) -> String {
        "\(growthFactorName(factor.source)) \(growthFactorValue(factor))"
    }

    /// "×2" for the repeat boost, which multiplies; "+25%" for a bonus, which adds to the others.
    func growthFactorValue(_ factor: GrowthFactor) -> String {
        factor.source == .repeatBoost
            ? "×\(l.multiplierNumber(factor.multiplier))"
            : "+\(l.percentNumber((factor.multiplier - 1) * 100))%"
    }

    /// How the factors combine, when there is something to combine: the bonuses' sum, then the repeat boost.
    func growthSumNote(_ factors: [GrowthFactor]) -> String? {
        let bonuses = factors.filter { $0.source != .repeatBoost }
        let repeatBoost = factors.first { $0.source == .repeatBoost }
        guard !bonuses.isEmpty, bonuses.count >= 2 || repeatBoost != nil else { return nil }
        return l.bonusSumNote(l.percentNumber(Self.bonusSum(bonuses) * 100),
                              repeatMultiplier: repeatBoost.map { l.multiplierNumber($0.multiplier) })
    }

    func growthFactorName(_ source: GrowthFactor.Source) -> String {
        switch source {
        case .repeatBoost: return l.bonusRepeat
        case .badges: return l.collectorGroupTitle(.gymBadges)
        case .item(let kind): return l.itemName(kind)
        }
    }

    /// An item's effect without the Bag's "· active" ending: on the Bonuses page every item listed is active.
    func bonusEffect(for kind: ItemKind) -> String {
        let hint = effectHint(for: kind)
        guard let range = hint.range(of: " · ", options: .backwards) else { return hint }
        return String(hint[..<range.lowerBound])
    }
}

/// Every bonus in one place: the current Pokémon's growth, factor by factor, then what the passive items do,
/// by theme. Opened from Home like the usage recap, and from the growth badge.
@MainActor
struct BonusScreen: View {
    let store: CompanionStore
    let onBack: () -> Void

    var body: some View {
        let l = store.l
        let owned = store.ownedItems.map(\.kind).filter { BonusTheme.of($0) != nil }
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Button { onBack() } label: {
                    Label(l.back, systemImage: "chevron.left").labelStyle(.titleAndIcon)
                }
                .buttonStyle(.borderless)
                .keyboardShortcut(.cancelAction)
                Spacer(minLength: 4)
                Text(l.bonusTitle).font(.headline)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    if store.hasActive { currentGrowth(l) }
                    if owned.isEmpty {
                        Text(l.bonusNoneYet).font(.callout).foregroundStyle(.secondary)
                    }
                    ForEach(BonusTheme.allCases, id: \.self) { theme in
                        section(theme, kinds: owned.filter { BonusTheme.of($0) == theme }, l)
                    }
                }
                .reservesScrollerLane()
            }
            .frame(height: 470)
        }
        .padding(PopoverMetrics.padding)
    }

    /// The current Pokémon's growth multiplier, each factor of it, and how they combine.
    private func currentGrowth(_ l: L) -> some View {
        let factors = store.currentGrowthFactors
        let total = store.currentGrowthTotal
        // Orange for a repeat, blue for bonuses alone, as on Home.
        let tint: Color = store.activeIsRepeat ? .orange : .blue
        return VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                // The name needs the loaded line; until then the section keeps its generic title.
                if store.currentLine != nil {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(store.displayName).font(.system(size: 15, weight: .bold, design: .rounded))
                        Text(l.bonusCurrent).font(.caption2).foregroundStyle(.secondary)
                    }
                } else {
                    Text(l.bonusCurrent).font(.callout.weight(.semibold))
                }
                Spacer(minLength: 4)
                Text(l.growthBoost(total)).font(.system(size: 16, weight: .bold, design: .rounded)).monospacedDigit()
                    .foregroundStyle(total > 1.0001 ? tint : Color.secondary)
            }
            if factors.isEmpty {
                Text(l.bonusNoGrowth).font(.caption).foregroundStyle(.secondary)
            }
            ForEach(Array(factors.enumerated()), id: \.offset) { _, factor in
                HStack(spacing: 8) {
                    icon(factor.source).frame(width: 22, height: 22)
                    Text(store.growthFactorName(factor.source)).font(.caption)
                    Spacer(minLength: 4)
                    Text(store.growthFactorValue(factor)).font(.caption.weight(.semibold)).monospacedDigit()
                }
            }
            if let note = store.growthSumNote(factors) {
                Text(note).font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
        .heroCard(color: tint)
    }

    @ViewBuilder
    private func icon(_ source: CompanionStore.GrowthFactor.Source) -> some View {
        switch source {
        case .repeatBoost: Image(systemName: "arrow.triangle.2.circlepath").foregroundStyle(Color.readableOrange)
        case .badges: Image(systemName: "rosette").foregroundStyle(.blue)
        case .item(let kind): ItemIconView(kind: kind, size: 22)
        }
    }

    /// One theme: a summary of its effect now (egg threshold, shiny odds), then its items. Badges are one line.
    @ViewBuilder
    private func section(_ theme: BonusTheme, kinds: [ItemKind], _ l: L) -> some View {
        let badges = kinds.filter { $0.badgeType != nil }
        let items = kinds.filter { $0.badgeType == nil }
        if !kinds.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text(l.bonusThemeTitle(theme)).font(.callout.weight(.semibold))
                if let summary = summary(theme, l) {
                    Text(summary).font(.caption.weight(.semibold)).foregroundStyle(Color.readableGreen).monospacedDigit()
                }
                if !badges.isEmpty {
                    row(icon: AnyView(ItemIconView(kind: badges[0], size: 22)),
                        name: "\(l.collectorGroupTitle(.gymBadges)) (\(badges.count))", effect: l.bagBadgesHint)
                }
                ForEach(items, id: \.self) { kind in
                    row(icon: AnyView(ItemIconView(kind: kind, size: 22)), name: l.itemName(kind),
                        effect: store.bonusEffect(for: kind))
                }
            }
            .padding(12)
            .designSurface(cornerRadius: Design.cornerRadius)
        }
    }

    private func row(icon: AnyView, name: String, effect: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            icon.frame(width: 22, height: 22)
            VStack(alignment: .leading, spacing: 1) {
                Text(name).font(.caption.weight(.semibold))
                Text(effect).font(.caption2).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }

    /// What a theme's items add up to now, when a number says it better than the list.
    private func summary(_ theme: BonusTheme, _ l: L) -> String? {
        switch theme {
        case .eggs:
            let base = PokemonBalance.scaled(PokemonBalance.eggHatchThreshold, by: store.growthDifficulty)
            let current = store.eggHatchThreshold
            // A legendary boss's egg takes its 200M whatever the items: they speed none of it.
            guard current != base, !store.incubatesLegendaryBossEgg else { return nil }
            return l.eggThresholdSummary(TokenFormatter.compact(current), instead: TokenFormatter.compact(base))
        case .shiny:
            return store.ownsGlimmeringCharm ? nil : l.shinyOddsSummary(Int(store.shinyDenominator))
        case .growth, .shop, .candies:
            return nil
        }
    }
}
