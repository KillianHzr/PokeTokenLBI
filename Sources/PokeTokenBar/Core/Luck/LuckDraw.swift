import Foundation

/// A kind of draw the luck journal keeps (`DungeonProgress.luckDraws`), each judged under one criterion.
enum LuckDrawKind: String, Codable, Sendable, CaseIterable {
    /// A throw at a boss, at its ball's odds (`ExpeditionEngine.throwOdds`).
    case bossThrow
    /// The throw at a shiny met on a floor.
    case shinyCatch
    /// A boss shiny at the departure, the Ruins of Alph's one time in a hundred too.
    case bossShiny
    /// A floor's shiny meeting, from T3.
    case shinyMeeting
    /// A secret boss, one expedition in a hundred while one is left to find.
    case secretBoss
    /// A floor's secret passage, from T2.
    case secretPassage
    /// A chest's egg, each egg of its table apart.
    case chestEgg
    /// A victory's extras (eggs, a key, a map, an Explorer Chest, a Master Ball), each apart.
    case victoryExtra
    /// What a hideout leader's chest gave, each drop of its table apart.
    case leaderChest
    case technicalCapsule
    /// A challenge's Wishing Piece.
    case wishingPiece
    /// The Explorer Kit's treasure, and the Explorer Chest's: each egg of the table apart.
    case explorerTreasure
    /// A Rare Candy the Shock Drive kept.
    case shockDrive

    var criterion: LuckCriterion {
        switch self {
        case .bossThrow, .shinyCatch: .capture
        case .bossShiny, .shinyMeeting: .dungeonShiny
        case .secretBoss, .secretPassage, .chestEgg, .victoryExtra, .leaderChest, .technicalCapsule, .wishingPiece,
             .explorerTreasure, .shockDrive: .find
        }
    }
}

/// Draws of one kind and odds on one day: how many, how many hit. The luck journal keeps every one for good, a line
/// a day for each (the owner, 2026-11-25: the whole history, compressed, with all the luck needs), so about a kilobyte
/// a day of play.
struct LuckDraw: Codable, Sendable, Equatable {
    /// The start of the local day.
    var day: Date
    /// The last draw added: where the day stands on the timeline.
    var at: Date
    var kind: LuckDrawKind
    var odds: Double
    var trials: Int
    var hits: Int

    enum CodingKeys: String, CodingKey {
        case day = "d", at = "t", kind = "k", odds = "o", trials = "n", hits = "h"
    }

    init(at date: Date, kind: LuckDrawKind, odds: Double, trials: Int = 1, hits: Int) {
        day = Calendar.current.startOfDay(for: date)
        at = date
        self.kind = kind
        self.odds = odds
        self.trials = trials
        self.hits = hits
    }

    /// Odds to the millionth: the same draw on the same day makes one line.
    var key: String { "\(Int(day.timeIntervalSinceReferenceDate)):\(kind.rawValue):\(Int((odds * 1_000_000).rounded()))" }

    /// Its own seed for the Luck screen's players (`LuckEvent.seed`): FNV-1a, `hashValue` changing from launch to launch.
    var seed: UInt64 {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in "luck:\(key)".utf8 { hash = (hash ^ UInt64(byte)) &* 0x100_0000_01b3 }
        return hash
    }
}

extension Array where Element == LuckDraw {
    /// Adds `draws`, each into the line of its day, kind and odds, the day's latest moment kept. A draw that could not
    /// miss, or never hit, is no luck and is left out.
    mutating func merge(_ draws: [LuckDraw]) {
        var index = Dictionary(enumerated().map { ($0.element.key, $0.offset) }, uniquingKeysWith: { a, _ in a })
        for draw in draws where draw.trials > 0 && draw.odds > 0 && draw.odds < 1 {
            if let i = index[draw.key] {
                self[i].trials += draw.trials
                self[i].hits += draw.hits
                self[i].at = Swift.max(self[i].at, draw.at)
            } else {
                index[draw.key] = count
                append(draw)
            }
        }
    }

    /// The same draws, dated `date`: an expedition's, noted as it went, take the day it ended.
    func dated(_ date: Date) -> [LuckDraw] {
        map { LuckDraw(at: date, kind: $0.kind, odds: $0.odds, trials: $0.trials, hits: $0.hits) }
    }
}
