import SwiftUI

/// One of the luckiest draws (`HatchLuck.Highlight`): a hatch's with its sprite and name, the journal's with its kind,
/// each with its odds and day.
@MainActor
struct HighlightRow: View {
    let store: CompanionStore
    let luck: HatchLuck
    let highlight: HatchLuck.Highlight
    let name: (DexEntry, Int) -> String

    var body: some View {
        let l = store.l
        HStack(spacing: 10) {
            icon
            VStack(alignment: .leading, spacing: 1) {
                Text(title(l)).font(.callout.weight(.semibold)).lineLimit(1)
                Text(subtitle(l)).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 0)
        }
    }

    private var hatch: HatchLuck.Hatch? { highlight.hatch.map { luck.hatches[$0] } }

    @ViewBuilder
    private var icon: some View {
        if let hatch {
            SpriteView(speciesID: hatch.isDitto ? PokemonOdds.dittoSpeciesID : hatch.entry.baseID, size: 30,
                       shiny: hatch.entry.isShiny, form: hatch.isDitto ? nil : hatch.entry.form, sameScale: true)
                .frame(width: 30, height: 30)
        } else {
            Image(systemName: Self.symbol(highlight.criterion))
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.readableOrange)
                .frame(width: 30, height: 30)
        }
    }

    static func symbol(_ criterion: LuckCriterion) -> String {
        switch criterion {
        case .capture: "circle.circle"
        case .dungeonShiny, .shiny: "sparkles"
        case .find: "star.circle"
        case .rarity, .new, .ditto, .ivs, .hiddenAbility: "suit.club.fill"
        }
    }

    private func title(_ l: L) -> String {
        guard let hatch else { return highlight.draw.map(l.luckDrawName) ?? l.luckCriterion(highlight.criterion) }
        let pokemon = name(hatch.entry, hatch.isDitto ? PokemonOdds.dittoSpeciesID : hatch.entry.baseID)
        let detail: String
        switch highlight.criterion {
        case .rarity: detail = highlight.rarity.map(l.rarityLabel) ?? l.luckCriterion(.rarity)
        case .ivs: detail = "IV \(hatch.ivTotal ?? 0)/186"
        // A Ditto is its own news: its name says it.
        case .ditto: return pokemon
        default: detail = l.luckCriterion(highlight.criterion)
        }
        return "\(pokemon) · \(detail)"
    }

    private func subtitle(_ l: L) -> String {
        let odds = l.luckOneIn(highlight.odds)
        guard let date = highlight.date else { return odds }
        return odds + " · " + date.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted)
            .locale(store.language.displayLocale))
    }
}

/// The Luck summary as an image (`CardSnapshotButton`, the owner, 2026-11-25: "comme la capture en cours"): the score
/// and its mood, each family's, every criterion's, the luckiest draw, the day and the app.
@MainActor
struct LuckCard: View {
    let store: CompanionStore
    let luck: HatchLuck
    let period: HatchLuck.Period
    let recent: Bool
    let name: (DexEntry, Int) -> String

    var body: some View {
        let l = store.l
        let score = Int(period.score.rounded())
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "suit.club.fill").foregroundStyle(Design.actionColor)
                Text(l.luckTitle).font(.headline)
                Spacer(minLength: 4)
                Text(l.luckPeriod(recent: recent)).font(.caption).foregroundStyle(.secondary)
            }
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(score)").font(.system(size: 40, weight: .bold, design: .rounded)).monospacedDigit()
                Text("/ 100").font(.callout).foregroundStyle(.secondary)
                Spacer(minLength: 4)
                Text(l.luckMood(score)).font(.callout.weight(.semibold)).multilineTextAlignment(.trailing)
            }
            LuckMeter(share: period.score / 100, height: 10)
            ForEach(LuckFamily.allCases.filter { period.families[$0] != nil }, id: \.self) { family in
                VStack(alignment: .leading, spacing: 4) {
                    let share = period.families[family] ?? 0.5
                    HStack(spacing: 8) {
                        Text(l.luckFamily(family)).font(.callout.weight(.semibold))
                        Spacer(minLength: 4)
                        LuckMeter(share: share, height: 6).frame(width: 64)
                        Text(l.luckPercent(share)).font(.callout.monospacedDigit().weight(.bold))
                            .frame(width: 44, alignment: .trailing)
                    }
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible())], alignment: .leading,
                              spacing: 3) {
                        ForEach(period.criteria.filter { $0.criterion.family == family }, id: \.criterion) { result in
                            HStack(spacing: 4) {
                                Text(l.luckCriterion(result.criterion)).lineLimit(1).minimumScaleFactor(0.8)
                                Spacer(minLength: 2)
                                Text(l.luckPercent(result.percentile)).monospacedDigit()
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            if !recent, let best = luck.highlights.first {
                HighlightRow(store: store, luck: luck, highlight: best, name: name)
            }
            HStack {
                Text(Date().formatted(Date.FormatStyle(date: .abbreviated, time: .omitted).locale(store.language.displayLocale)))
                Spacer(minLength: 4)
                Text(CatchBanner.brand)
            }
            .font(.system(size: 9, weight: .medium))
            .foregroundStyle(.secondary)
        }
        .designCard()
    }
}
