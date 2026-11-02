import SwiftUI

/// Prof. Oak's advice, at the top of the Shop in place of the balance card: one sentence in his bubble, then the steps
/// in order, one line each, and the balance. His details page explains each step. Nothing runs from the card: a step
/// done in another tab links to it.
@MainActor
struct OakAdviceCard: View {
    let store: CompanionStore
    let nav: PopoverNavigation
    @State private var oak = SpriteLoader.cachedItemImage(name: SpriteStore.oakPortrait)

    private static let bustWidth: CGFloat = 84
    /// Head and chest at least, beside a short bubble.
    private static let bustHeight: CGFloat = 90
    private static let tail: CGFloat = 6

    var body: some View {
        let l = store.l
        let words = OakWords(store)
        VStack(alignment: .leading, spacing: 8) {
            SectionTitle(text: l.oakAdviceTitle)
            bubble(words)
                .frame(minHeight: Self.bustHeight, alignment: .top)
                .padding(.leading, Self.bustWidth + 4)
                .background(alignment: .topLeading) {
                    bust.frame(width: Self.bustWidth).frame(minHeight: 0, maxHeight: .infinity, alignment: .top).clipped()
                }
            stepList(l, words)
            balance(l)
            Button { nav.showingOakDetails = true } label: {
                HStack(spacing: 4) {
                    Text(l.recapDetails)
                    Image(systemName: "chevron.right").font(.system(size: 9, weight: .bold))
                }
                .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .heroCard(colors: store.themeColors)
        .task {
            guard oak == nil else { return }
            oak = await SpriteLoader.itemImage(name: SpriteStore.oakPortrait)
        }
    }

    /// Oak from the top, cut by the bottom of his bubble.
    @ViewBuilder
    private var bust: some View {
        if let oak {
            Image(nsImage: oak)
                .resizable()
                .frame(width: Self.bustWidth, height: Self.bustWidth * oak.size.height / max(1, oak.size.width))
                .accessibilityHidden(true)
        } else {
            Image(systemName: "graduationcap.fill")
                .font(.system(size: 26))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
        }
    }

    private func bubble(_ words: OakWords) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            OakVerdictLabel(store: store, verdict: words.verdict)
            Text(words.bubble)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 8).padding(.trailing, 10).padding(.leading, 10 + Self.tail)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SpeechBubble(tail: Self.tail).fill(Color(nsColor: .textBackgroundColor).opacity(0.85)))
    }

    @ViewBuilder
    private func stepList(_ l: L, _ words: OakWords) -> some View {
        if !words.steps.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(words.steps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        OakStepNumber(index + 1)
                        Text(words.title(step)).font(.caption.weight(.semibold))
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 4)
                        switch words.place(step) {
                        case .bag?:
                            link(l.treasureOpenBag) { nav.tab = .bag }
                        case .home?:
                            link(l.home) { nav.tab = .home }
                        case nil:
                            EmptyView()
                        }
                    }
                }
            }
        }
    }

    /// A step's link to the tab where it is done.
    private func link(_ title: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 2) {
                Text(title)
                Image(systemName: "chevron.right").font(.system(size: 8, weight: .bold))
            }
            .font(.caption.weight(.semibold)).foregroundStyle(Design.actionColor)
            .lineLimit(1).fixedSize()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func balance(_ l: L) -> some View {
        HStack(spacing: 5) {
            Image(systemName: "creditcard.fill").font(.system(size: 9, weight: .bold))
            Text(l.spendableTokens)
            Spacer(minLength: 4)
            Text(TokenFormatter.compact(store.availableTokens)).fontWeight(.bold).monospacedDigit()
        }
        .font(.caption).foregroundStyle(.secondary)
    }
}

/// Prof. Oak's advice in full, opened from his card: the verdict, each step with its why, the Shiny Charm, then why
/// overall. It takes over the popover like the Bonuses page.
@MainActor
struct OakAdviceScreen: View {
    let store: CompanionStore
    let onBack: () -> Void

    var body: some View {
        let l = store.l
        let words = OakWords(store)
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Button { onBack() } label: {
                    Label(l.back, systemImage: "chevron.left").labelStyle(.titleAndIcon)
                }
                .buttonStyle(.borderless)
                .keyboardShortcut(.cancelAction)
                Spacer(minLength: 4)
                Text(l.oakAdviceTitle).font(.headline)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        OakVerdictLabel(store: store, verdict: words.verdict)
                        Text(words.verdictInFull).font(.callout).fixedSize(horizontal: false, vertical: true)
                    }
                    ForEach(Array(words.steps.enumerated()), id: \.offset) { index, step in
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            OakStepNumber(index + 1)
                            explained(words.title(step), words.detail(step))
                        }
                    }
                    if store.proposesShinyCharm, let price = store.price(of: .shinyCharm) {
                        let odds = store.shinyCharmOdds
                        explained(l.oakShinyCharm(l.itemName(.shinyCharm)),
                                  l.oakShinyCharmWhy(TokenFormatter.compact(price)) + " "
                                      + l.shinyOddsChange(from: odds.now, to: odds.withCharm))
                    }
                    SectionTitle(text: l.oakWhyTitle)
                    let eggs = l.oakWhyEgg(rare: l.eggName(.rare), uncommon: l.eggName(.uncommon), amber: l.itemName(.oldAmber))
                    ForEach([l.oakWhy(flute: l.itemName(.legendCharm)), eggs, l.oakWhyStock, l.oakWhyCandies], id: \.self) {
                        Text($0).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .reservesScrollerLane()
            }
        }
        .padding(PopoverMetrics.padding)
        .frame(height: 520, alignment: .top)
    }

    private func explained(_ title: String, _ detail: String?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.callout.weight(.semibold)).fixedSize(horizontal: false, vertical: true)
            if let detail {
                Text(detail).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// The tab where a step is done, when it is not the Shop.
private enum OakPlace {
    case bag, home
}

/// Prof. Oak's advice read once: the verdict on the Pokémon raised, what a Spare goes for, the balance's plan and the
/// steps (`CompanionStore.oakSteps`), with their words.
@MainActor
private struct OakWords {
    let store: CompanionStore
    let verdict: ActiveVerdict?
    let release: OakRelease?
    let budget: OakBudget?
    let steps: [OakStep]

    init(_ store: CompanionStore) {
        self.store = store
        verdict = store.activeVerdict
        release = store.oakRelease
        budget = store.oakBudget(after: release)
        steps = store.oakSteps(after: release, budget: budget)
    }

    private var l: L { store.l }
    private var name: String { store.displayName }

    /// One sentence: what to do with a Spare, else what the Pokémon brings.
    var bubble: String {
        if let release { return l.oakReleaseBubble(release) }
        return verdict.map(said) ?? l.oakEggBubble
    }

    var verdictInFull: String {
        guard let verdict else { return l.oakEggBubble }
        return release.map { said(verdict) + " " + l.oakReleaseBubble($0) } ?? said(verdict)
    }

    private func said(_ verdict: ActiveVerdict) -> String {
        l.oakBubble(verdict, name: name, newFormName: newFormName(verdict))
    }

    /// The species it brings in its form, named in it ("Ninetales [Alolan Form]").
    private func newFormName(_ verdict: ActiveVerdict) -> String {
        guard case .newForm(let id) = verdict else { return "" }
        return store.formDisplayName(store.currentLine?.localizedName(id, store.state.language) ?? "#\(id)",
                                     speciesID: id, form: store.state.active?.form)
    }

    func title(_ step: OakStep) -> String {
        switch step {
        case .raise:
            return l.oakRaise(name)
        case .release(let release):
            switch release {
            case .bag(let kind, _): return l.oakUseFromBag(l.itemName(kind))
            case .claim(let egg, _): return l.oakClaimThenUse(l.itemName(egg.item))
            case .buy(let tier, _): return l.oakBuyThenUse(l.eggName(tier))
            case .wait(let tier, _, _): return l.oakKeepThenBuy(name, l.eggName(tier))
            case .finish(let left, _): return l.oakLetFinish(name, left: TokenFormatter.compact(left))
            }
        case .stock(let budget):
            let egg = l.eggName(budget.egg?.bagEggTier)
            return budget.buyAhead > 0
                ? l.oakBuyAhead(budget.buyAhead, egg)
                : l.oakSetAside(TokenFormatter.compact(budget.reserve), count: budget.target - budget.held, egg: egg)
        case .candies(let buy, let give, let keep):
            if buy > 0 { return give > 0 ? l.oakBuyAndGiveCandies(buy, give, to: name) : l.oakBuyAndKeepCandies(buy) }
            return give > 0 ? l.oakGiveCandies(give, to: name) : l.oakKeepCandies(keep)
        }
    }

    func detail(_ step: OakStep) -> String? {
        switch step {
        case .raise: return nil
        case .release(let release): return releaseDetail(release)
        case .stock(let budget): return stockDetail(budget)
        case .candies(let buy, let give, let keep): return candiesDetail(buy: buy, give: give, keep: keep)
        }
    }

    func place(_ step: OakStep) -> OakPlace? {
        switch step {
        case .raise, .release(.wait), .release(.finish), .stock: return nil
        case .release(.bag), .release(.buy): return .bag
        case .release(.claim): return .home
        case .candies(_, let give, _): return give > 0 ? .bag : nil
        }
    }

    private func percent(_ p: Double) -> String { l.oddsPercent(Int((p * 100).rounded()), share: p) }

    private func releaseDetail(_ release: OakRelease) -> String {
        func price(_ tier: Rarity?) -> String { TokenFormatter.compact(store.price(of: .egg(tier))) }
        let amber = store.itemCount(.oldAmber) > 0 ? " " + l.oakAmberKeeps(l.itemName(.oldAmber), name: name) : ""
        switch release {
        case .bag(_, let p):
            return l.oakSendsOff(name, odds: percent(p)) + amber
        case .claim(_, let p):
            return l.oakClaimWaits + " " + l.oakSendsOff(name, odds: percent(p)) + amber
        case .buy(let tier, let p):
            return l.oakEggCosts(price(tier)) + " " + l.oakSendsOff(name, odds: percent(p)) + amber
        case .wait(let tier, let p, let short):
            let eta = store.timeToEarn(short).map { l.oakAtYourPace(l.shortDuration($0)) } ?? ""
            return l.oakWaitForEgg(price: price(tier), short: TokenFormatter.compact(short), eta: eta, odds: percent(p))
                + amber
        case .finish(_, .noBetterEgg):
            return l.oakNoEggBeatsGraduation
        case .finish(_, .tooFarAlong):
            return l.oakTooFarAlong + (amber.isEmpty ? "" : " " + l.oakEvenWithAmber(l.itemName(.oldAmber)))
        case .finish(_, .outgrowsTheWait):
            return l.oakOutgrowsTheWait
        }
    }

    private func stockDetail(_ budget: OakBudget) -> String {
        var detail = l.oakStockFor(budget.target, takes: Int((1 / budget.odds).rounded()), odds: percent(budget.odds))
        if budget.held > 0 { detail += " " + l.oakStockHeld(budget.held) }
        if budget.buyAhead > 0, budget.reserve > 0 { detail += " " + l.oakAlsoSetAside(TokenFormatter.compact(budget.reserve)) }
        if budget.waitsForNext { detail += " " + l.oakNotYet }
        return detail
    }

    /// Where the candies bought come from, then why they are given or kept.
    private func candiesDetail(buy: Int, give: Int, keep: Int) -> String? {
        var parts: [String] = []
        if buy > 0 { parts.append(budget?.egg == nil ? l.oakNoShopEggBeatsGraduation : l.oakCandiesFromTheRest) }
        let need = store.growthToGraduation
        if verdict == nil {
            parts.append(l.oakCandiesForTheHatch)
        } else if verdict == .spare, release?.sendsOff != false {
            parts.append(l.oakNoCandyBeforeRelease)
        } else if need > 0 {
            let xp = TokenFormatter.compact(store.rareCandyXP)
            if give > 0 {
                parts.append(l.oakCandiesGoIn(give, need: TokenFormatter.compact(need), xp: xp))
                if give * store.rareCandyXP > need { parts.append(l.oakLastCandyLosesLittle) }
                if keep > 0 { parts.append(l.oakKeepOtherCandies(keep)) }
            } else {
                parts.append(l.oakCandyWouldLose(need: TokenFormatter.compact(need), xp: xp, name: name))
            }
            if store.reinsCandyOnGraduation { parts.append(l.oakReinsCandy(l.itemName(.reinsOfUnity))) }
        }
        return parts.isEmpty ? nil : parts.joined(separator: " ")
    }
}

/// The Pokémon raised and Oak's verdict on it, as a badge. Nothing for an egg.
@MainActor
private struct OakVerdictLabel: View {
    let store: CompanionStore
    let verdict: ActiveVerdict?

    var body: some View {
        if let verdict {
            HStack(spacing: 6) {
                Text(store.displayName).font(.caption.weight(.bold))
                Badge(store.l.oakVerdictLabel(verdict).uppercased(), tint: tint(verdict), style: .tinted)
                    .lineLimit(1).fixedSize()
            }
        }
    }

    private func tint(_ verdict: ActiveVerdict) -> BadgeTint {
        switch verdict {
        case .spare: return .secondary
        case .newForm: return .blue
        case .lineToComplete, .costume, .shinyToKeep, .keptForAchievement: return .green
        }
    }
}

@MainActor
private struct OakStepNumber: View {
    let number: Int

    init(_ number: Int) { self.number = number }

    var body: some View {
        Text("\(number)")
            .font(.caption2.weight(.bold)).monospacedDigit()
            .frame(width: 16, height: 16)
            .background(Circle().fill(Color.primary.opacity(0.1)))
    }
}

/// A rounded bubble whose tail points left, to the one speaking.
private struct SpeechBubble: Shape {
    let tail: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path(roundedRect: CGRect(x: rect.minX + tail, y: rect.minY, width: rect.width - tail, height: rect.height),
                        cornerRadius: 10, style: .continuous)
        path.move(to: CGPoint(x: rect.minX + tail, y: rect.minY + 12))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + 18))
        path.addLine(to: CGPoint(x: rect.minX + tail, y: rect.minY + 24))
        path.closeSubpath()
        return path
    }
}
