import Foundation

/// The Wishing Piece (the owner, 2026-11-25): an item of the Bag that swaps the daily or weekly dungeon's boss for
/// another before that day's try. Never sold.
enum WishingPiece {
    /// Given once to every player, a save from before included.
    static let starting = 3

    /// What a swap spends.
    static func cost(_ id: DungeonID) -> Int { id == .weekly ? 3 : 1 }

    /// The chance in percent that a challenge won drops one.
    static func victoryChance(_ id: DungeonID) -> Double { id == .weekly ? 15 : 5 }
}

extension CompanionStore {
    /// Whether the boss swap is offered, the Bag aside: before this day's try, the challenge not won, its own run not
    /// under way (one set off before midnight), and another form left to draw.
    func canSwapChallengeBoss(_ id: DungeonID) -> Bool {
        guard id.isChallenge, expedition?.dungeon != id, !challengeTried(id), challengeBeaten(id) == nil,
              challengeBoss(id) != nil else { return false }
        return challengeCandidates(id).count > 1
    }

    /// Spends the challenge's Wishing Pieces for another boss, drawn among the forms left but the one swapped away: a
    /// boss swapped before may come back. It stays for the period, as a boss drawn by the day or the week does.
    @discardableResult
    func swapChallengeBoss(_ id: DungeonID) -> BattleForm? {
        let cost = WishingPiece.cost(id)
        guard canSwapChallengeBoss(id), itemCount(.wishingPiece) >= cost, let current = challengeBoss(id) else { return nil }
        let others = challengeCandidates(id).filter { $0 != current }
        let next = others[Int(drawSeed() % UInt64(others.count))]
        changeBag(.wishingPiece, by: -cost)
        let key = DungeonProgress.challengeKey(id, at: currentDate)
        changeDungeons { $0.challengeDraws[key] = next.key }
        AppLog.write("dungeon: wishing piece, \(id.rawValue) boss \(current.key) -> \(next.key) (\(itemCount(.wishingPiece)) left)")
        persist()
        return next
    }
}
