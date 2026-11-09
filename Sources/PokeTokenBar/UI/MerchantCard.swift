import SwiftUI

/// The top of the Shop: Prof. Oak's advice and, the days the travelling merchant comes, his card, an arrow going from
/// one to the other (the owner, 2026-11-05: "une flèche façon slider"). The merchant comes first: he leaves at midnight.
@MainActor
struct ShopHeadCards: View {
    let store: CompanionStore
    let nav: PopoverNavigation
    @State private var showingOak = false

    var body: some View {
        let merchant = store.merchantWare
        let oak = store.oakAdviceEnabled
        if let merchant, oak {
            Group {
                if showingOak {
                    OakAdviceCard(store: store, nav: nav)
                        .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .trailing)).combined(with: .opacity))
                } else {
                    MerchantCard(store: store, ware: merchant)
                        .transition(.asymmetric(insertion: .move(edge: .leading), removal: .move(edge: .leading)).combined(with: .opacity))
                }
            }
            .overlay(alignment: .topTrailing) { pager(store.l) }
            .clipped()
        } else if let merchant {
            MerchantCard(store: store, ware: merchant)
        } else if oak {
            OakAdviceCard(store: store, nav: nav)
        }
    }

    /// Two dots, the card shown filled, and the arrow to the other one.
    private func pager(_ l: L) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.25)) { showingOak.toggle() }
        } label: {
            HStack(spacing: 5) {
                if showingOak { Image(systemName: "chevron.left").font(.system(size: 9, weight: .bold)) }
                Circle().fill(showingOak ? Color.secondary.opacity(0.35) : Color.primary.opacity(0.75)).frame(width: 5, height: 5)
                Circle().fill(showingOak ? Color.primary.opacity(0.75) : Color.secondary.opacity(0.35)).frame(width: 5, height: 5)
                if !showingOak { Image(systemName: "chevron.right").font(.system(size: 9, weight: .bold)) }
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 7).padding(.vertical, 4)
            .background(Capsule().fill(Color.primary.opacity(0.08)))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .hoverTip(showingOak ? l.merchantTitle : l.oakAdviceTitle)
        .accessibilityLabel(showingOak ? l.merchantTitle : l.oakAdviceTitle)
        .padding(Design.cardPadding - 2)
    }
}

/// The travelling merchant's card: his bust beside his bubble (the ware, what he pays for one, how many the Bag holds),
/// then "Sell 1" and "Sell all", which asks once more with the total, nothing sold coming back.
@MainActor
struct MerchantCard: View {
    let store: CompanionStore
    let ware: ItemKind
    @State private var confirming = false
    @State private var sold: Int?

    var body: some View {
        let l = store.l
        let held = store.itemCount(ware)
        let price = store.merchantPrice(of: ware) ?? 0
        VStack(alignment: .leading, spacing: 8) {
            SectionTitle(text: l.merchantTitle)
            bubble(l, held: held, price: price)
                .frame(minHeight: 90, alignment: .top)
                .padding(.leading, OakAdviceCard.bustWidth + 4)
                .background(alignment: .topLeading) {
                    PortraitBust(name: TravellingMerchant.portraitName(for: ware), width: OakAdviceCard.bustWidth,
                                 symbol: "bag.fill")
                        .frame(width: OakAdviceCard.bustWidth).frame(minHeight: 0, maxHeight: .infinity, alignment: .top)
                        .clipped()
                }
            if held > 0 {
                HStack(spacing: 8) {
                    if let sold {
                        Label(l.merchantSold(TokenFormatter.compact(sold)), systemImage: "checkmark.circle")
                            .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                    Button(l.merchantSellOne) { sell(1, price: price) }
                        .buttonStyle(.pill())
                    Button(confirming ? l.merchantConfirm(TokenFormatter.compact(price * held)) : l.merchantSellAll(held)) {
                        if confirming { sell(held, price: price) } else { confirming = true }
                    }
                    .buttonStyle(.pill(prominent: true))
                }
            } else if let sold {
                Label(l.merchantSold(TokenFormatter.compact(sold)), systemImage: "checkmark.circle")
                    .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            }
            Label(l.merchantLeaves, systemImage: "moon.stars")
                .font(.caption2).foregroundStyle(.secondary)
        }
        .heroCard(colors: store.themeColors)
        .onChange(of: held) { _, _ in confirming = false }
    }

    private func bubble(_ l: L, held: Int, price: Int) -> some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                Text(l.merchantOffer(l.itemName(ware), price: TokenFormatter.compact(price)))
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
                Text(held > 0 ? l.merchantHeld(held) : l.merchantNoneHeld)
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            ItemIconView(kind: ware, size: 28)
        }
        .padding(.vertical, 8).padding(.trailing, 10).padding(.leading, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SpeechBubble(tail: 6).fill(Color(nsColor: .textBackgroundColor).opacity(0.85)))
    }

    private func sell(_ count: Int, price: Int) {
        if store.sellToMerchant(count) { sold = (sold ?? 0) + price * count }
        confirming = false
    }
}
