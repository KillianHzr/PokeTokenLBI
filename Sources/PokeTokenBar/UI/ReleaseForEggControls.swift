import SwiftUI

/// Controls of every action that sends the current Pokémon off for a new egg (a Shop egg, an evolution
/// stone from the Bag): disabled while an egg incubates, one confirmation, and a second one for a shiny or
/// legendary companion. A successful action switches to Home to show the new egg.
@MainActor
struct ReleaseForEggControls: View {
    let store: CompanionStore
    let nav: PopoverNavigation
    /// Line left of the button: an egg's price, a stone's guaranteed type.
    let detail: String
    let actionTitle: String
    let isAvailable: Bool
    /// Shown instead of the button when a companion is there but the action is not available.
    let unavailableText: String
    let confirmText: String
    /// Why the button is greyed out though a companion is there (a Fossil Egg's own Pokémon), under it.
    var lockedHint: String? = nil
    let action: @MainActor () -> Bool
    @State private var stage: Stage = .idle
    @State private var failed = false
    private enum Stage { case idle, confirm, preciousConfirm }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            controls
            ActionFailedNote(failed: $failed, text: store.l.actionFailed)
        }
    }

    @ViewBuilder
    private var controls: some View {
        let l = store.l
        // 알 상태: 리롤 대상이 없다. A legendary boss's egg's Pokémon is never sent off; a Fossil Egg's own: the
        // caller's reason.
        let locked = !store.hasActive ? l.eggShopLockedHint
            : store.expedition != nil ? l.candiesPausedForDungeon
            : store.isRaisingLegendaryBossPokemon ? l.legendaryBossPokemonLocked : lockedHint
        switch stage {
        case .idle:
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(detail)
                        .font(.caption2).foregroundStyle(.tertiary).monospacedDigit()
                    Spacer()
                    if locked != nil {
                        // 알 상태: 리롤 대상이 없어 실행만 막는다(canUseBagEgg/canUseStone 게이트). 항목을 숨기는 대신
                        // 비활성 버튼으로 "있긴 하다"를 보이고, 사유는 아래 한 줄로.
                        Button(actionTitle) {}
                            .buttonStyle(.pill()).disabled(true)
                    } else if isAvailable {
                        Button(actionTitle) { stage = .confirm }
                            .buttonStyle(.pill())
                    } else {
                        Text(unavailableText).font(.caption2).foregroundStyle(.tertiary)
                    }
                }
                if let locked {
                    Text(locked)
                        .font(.caption2).foregroundStyle(.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        case .confirm:
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(confirmText)
                        .font(.caption2).foregroundStyle(.secondary).lineLimit(2)
                    Spacer()
                    // 이로치나 전설 등 고가치 포켓몬이면 한 번 더 경고, 아니면 즉시 실행.
                    Button(actionTitle) {
                        if store.isHighValueCompanion { stage = .preciousConfirm } else { commit() }
                    }
                    .buttonStyle(.pill(prominent: true))
                    Button(l.cancel) { stage = .idle }
                        .buttonStyle(.borderless).controlSize(.small)
                }
                // What it would stop counting for: nothing new to lose, no sentence.
                if let goals = ActiveGoalsList.sentence(store) {
                    Label(goals, systemImage: "exclamationmark.circle")
                        .font(.caption2).foregroundStyle(Color.readableOrange)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        case .preciousConfirm:
            // The warning on its own line: beside the buttons, French and German left it a few letters.
            VStack(alignment: .leading, spacing: 6) {
                Text(store.rarity == .legendary ? l.freshEggLegendaryWarning : l.freshEggShinyWarning)
                    .font(.caption2.weight(.semibold)).foregroundStyle(Color.readableOrange)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 8) {
                    Spacer()
                    Button(store.currentIsShiny && store.rarity != .legendary ? l.freshEggDiscardShiny : l.freshEggDiscardValuable) { commit() }
                        .buttonStyle(PillButtonStyle(prominent: true, tint: .orange))
                    Button(l.cancel) { stage = .idle }
                        .buttonStyle(.borderless).controlSize(.small)
                }
            }
        }
    }

    /// 실행 → 새 알을 볼 수 있게 Home 으로 전환(가방 사용과 동일 패턴).
    private func commit() {
        stage = .idle
        if action() { nav.tab = .home } else { failed = true }
    }
}

/// A short line when a purchase or a release did not go through: it failed without a word, the button just came back.
/// Gone after a few seconds.
@MainActor
struct ActionFailedNote: View {
    @Binding var failed: Bool
    let text: String

    var body: some View {
        if failed {
            Label(text, systemImage: "exclamationmark.triangle.fill")
                .font(.caption2).foregroundStyle(Color.readableOrange)
                .task {
                    try? await Task.sleep(for: .seconds(4))
                    failed = false
                }
        }
    }
}
