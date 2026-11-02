import SwiftUI

/// The Bag tab: what the player holds, and the achievements that fill it, under one switch. Six tabs left the labels
/// no room, and the achievements' rewards land in the Bag anyway. `PopoverTab.achievements` is this tab on its
/// achievements, so Home's goals and the claim notices still open them.
@MainActor
struct BagHubView: View {
    let store: CompanionStore
    let nav: PopoverNavigation

    /// The switch's height and the gap under it, taken from the tab's 520 pt.
    static let switchHeight: CGFloat = 30
    static let gap: CGFloat = 8

    var body: some View {
        let l = store.l
        let ready = store.unclaimedAchievementsCount
        let height = 520 - Self.switchHeight - Self.gap
        VStack(alignment: .leading, spacing: Self.gap) {
            HStack(spacing: 0) {
                part(.bag, title: l.bagItemsTitle, icon: "bag.fill", count: 0)
                part(.achievements, title: l.achievements, icon: "trophy.fill", count: ready)
            }
            .frame(height: Self.switchHeight)
            if nav.tab == .achievements {
                AchievementsView(store: store, nav: nav, height: height)
            } else {
                BagView(store: store, nav: nav, height: height)
            }
        }
    }

    /// One half of the switch: its icon and title, the rewards waiting as a count, a line under the one shown.
    private func part(_ tab: PopoverTab, title: String, icon: String, count: Int) -> some View {
        let selected = nav.tab == tab
        return Button { nav.tab = tab } label: {
            VStack(spacing: 4) {
                HStack(spacing: 5) {
                    Image(systemName: icon).font(.system(size: 11, weight: .semibold))
                    Text(title).font(.callout.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.8)
                    if count > 0 {
                        Text("\(count)")
                            .font(.system(size: 9, weight: .bold, design: .rounded)).foregroundStyle(.white)
                            .padding(.horizontal, 5).padding(.vertical, 1)
                            .background(Capsule().fill(Color.red))
                    }
                }
                .foregroundStyle(selected ? AnyShapeStyle(Design.actionColor) : AnyShapeStyle(.secondary))
                Capsule().fill(selected ? Design.actionColor : Color.primary.opacity(0.08)).frame(height: selected ? 2.5 : 1)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
