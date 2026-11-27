import Foundation

/// The luck journal's side of the store (`LuckDraw`): what the dungeons, the Explorer Kit and the Shock Drive drew.
extension CompanionStore {
    /// The luck journal, read back from the history for a save from before it.
    var luckJournal: [LuckDraw] { state.dungeons.luckDraws ?? luckBackfill(state.dungeons.history) }

    /// A save from before the journal's past (`DungeonLuck.backfill`), each run at the shiny odds of its day: the Shiny
    /// Charm and the Reveal Glass from the day they came.
    func luckBackfill(_ history: [DungeonRunRecord]) -> [LuckDraw] {
        let charm = drawItemSince(.shinyCharm), glass = drawItemSince(.revealGlass)
        return DungeonLuck.backfill(history) { date in
            Int(Self.shinyDenominator(charmOwned: charm.map { $0 <= date } ?? false,
                                      revealGlassOwned: glass.map { $0 <= date } ?? false))
        }
    }

    /// Adds draws to the luck journal, its past read back first in a save from before it.
    func noteLuck(_ draws: [LuckDraw]) {
        guard !draws.isEmpty else { return }
        let past = state.dungeons.luckDraws == nil ? luckBackfill(state.dungeons.history) : nil
        changeDungeons { progress in
            var journal = progress.luckDraws ?? past ?? []
            journal.merge(draws)
            progress.luckDraws = journal
        }
    }

    /// A treasure of the Explorer Kit or the Explorer Chest (`ExplorerKit.treasure`): each egg of its table apart, the
    /// Rare Candy left being no luck.
    func noteTreasure(_ kind: ItemKind) {
        let range = Double(ExplorerKit.rollRange)
        let eggs: [(ItemKind, Int)] = [(.legendaryEgg, ExplorerKit.legendaryEggRolls), (.rareEgg, ExplorerKit.rareEggRolls),
                                       (.uncommonEgg, ExplorerKit.uncommonEggRolls)]
        noteLuck(eggs.map { egg, rolls in
            LuckDraw(at: currentDate, kind: .explorerTreasure, odds: Double(rolls) / range, hits: kind == egg ? 1 : 0)
        })
    }
}
