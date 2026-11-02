import SwiftUI

/// A dungeon battle played at its own pace (maquette 5): the same seed replays it to the millisecond. Each Pokémon on
/// the field has its HP bar (blue) and its cast bar (purple) under its sprite; the last moves that landed below.
@MainActor
struct BattleReplayView: View {
    let store: CompanionStore
    let battle: ExpeditionBattle
    let onBack: () -> Void

    @State private var outcome: BattleOutcome?
    @State private var elapsed = 0
    @State private var playing = true

    private static let step = 100

    var body: some View {
        let l = store.l
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Button { onBack() } label: { Label(l.back, systemImage: "chevron.left").labelStyle(.titleAndIcon) }
                    .buttonStyle(.borderless)
                    .keyboardShortcut(.cancelAction)
                Spacer(minLength: 4)
                Text(l.battleKind(battle.kind)).font(.headline)
                Text(Self.clock(elapsed)).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }
            if let outcome {
                let frame = BattleFrame.at(elapsed, setup: outcome.setup, events: outcome.events)
                HStack(alignment: .top, spacing: 12) {
                    side(frame, 0)
                    side(frame, 1)
                }
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(Array(frame.recentHits.reversed().enumerated()), id: \.offset) { _, hit in
                        HStack(spacing: 4) {
                            Text(Self.clock(hit.time)).font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
                            PokemonNameLabel(.move, hit.move, language: store.language).font(.caption)
                            Text("-\(hit.damage)").font(.caption.weight(.bold)).monospacedDigit()
                        }
                    }
                }
                Spacer(minLength: 0)
                HStack {
                    Button(playing ? l.battlePause : l.battlePlay) { playing.toggle() }
                        .buttonStyle(.bordered).controlSize(.small)
                    Spacer()
                    if elapsed >= outcome.duration {
                        Label(outcome.winner == 0 ? l.battleWon : l.battleLost,
                              systemImage: outcome.winner == 0 ? "checkmark.seal.fill" : "xmark.seal.fill")
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(outcome.winner == 0 ? Design.actionColor : .orange)
                    } else {
                        Button(l.battleSkip) { elapsed = outcome.duration }
                            .buttonStyle(.bordered).controlSize(.small)
                    }
                }
            } else {
                ProgressView().frame(maxWidth: .infinity)
            }
        }
        .padding(PopoverMetrics.padding)
        .frame(height: 520, alignment: .top)
        .task {
            let setup = battle.setup
            let ran = await Task.detached(priority: .userInitiated) { BattleEngine.run(setup) }.value
            outcome = ran
            while !Task.isCancelled, elapsed < ran.duration {
                try? await Task.sleep(for: .milliseconds(Self.step))
                if playing { elapsed = min(ran.duration, elapsed + Self.step) }
            }
        }
    }

    private func side(_ frame: BattleFrame, _ side: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(frame.units.filter { $0.side == side && ($0.onField || $0.fainted) }, id: \.id) { unit in
                UnitRow(store: store, unit: unit, elapsed: elapsed)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    static func clock(_ ms: Int) -> String { String(format: "%d:%02d", ms / 60_000, ms / 1000 % 60) }
}

@MainActor
private struct UnitRow: View {
    let store: CompanionStore
    let unit: BattleFrame.Unit
    let elapsed: Int

    var body: some View {
        HStack(spacing: 6) {
            SpriteView(speciesID: unit.speciesID, size: 30, shiny: unit.isShiny, form: unit.form, sameScale: true)
                .opacity(unit.fainted ? 0.35 : 1)
            VStack(alignment: .leading, spacing: 2) {
                bar(Double(unit.hp) / Double(max(1, unit.maxHP)), color: .blue)
                bar(unit.castProgress(at: elapsed), color: .purple)
                HStack(spacing: 4) {
                    if unit.fainted {
                        Text(store.l.battleKO).font(.caption2.weight(.bold))
                    } else if let move = unit.castMove {
                        PokemonNameLabel(.move, move, language: store.language).font(.caption2)
                    }
                    if let status = unit.status {
                        Text(store.l.ailmentName(status)).font(.caption2).foregroundStyle(.secondary)
                    }
                }
                .lineLimit(1)
            }
        }
    }

    private func bar(_ value: Double, color: Color) -> some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.primary.opacity(0.12))
                Capsule().fill(color.opacity(0.85)).frame(width: geometry.size.width * max(0, min(1, value)))
            }
        }
        .frame(height: 4)
    }
}
