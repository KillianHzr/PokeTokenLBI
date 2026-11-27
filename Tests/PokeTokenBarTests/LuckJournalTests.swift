import XCTest
@testable import PokeTokenBar

/// The luck journal (`LuckDraw`) and the past read back from a save from before it (`DungeonLuck`): the owner,
/// 2026-11-25, "le Groudon en boss secret et tout" must count, and the whole history kept, compressed.
final class LuckJournalTests: XCTestCase {
    private let day = Date(timeIntervalSince1970: 1_795_420_800)   // 2026-11-23 08:00 UTC, after the secret bosses

    private func at(_ hours: Double) -> Date { day.addingTimeInterval(hours * 3_600) }

    /// One line a day for each kind and odds: the draws add up, the day's latest moment kept; what could not miss or
    /// never hit is no luck.
    func testTheJournalKeepsALineADay() {
        var journal: [LuckDraw] = []
        journal.merge([LuckDraw(at: at(1), kind: .bossThrow, odds: 0.3, hits: 0),
                       LuckDraw(at: at(2), kind: .bossThrow, odds: 0.3, hits: 1),
                       LuckDraw(at: at(2), kind: .bossThrow, odds: 0.6, hits: 1),
                       LuckDraw(at: at(3), kind: .bossThrow, odds: 1, hits: 1),
                       LuckDraw(at: at(3), kind: .chestEgg, odds: 0, hits: 0)])
        XCTAssertEqual(journal.count, 2)
        XCTAssertEqual(journal[0].trials, 2)
        XCTAssertEqual(journal[0].hits, 1)
        XCTAssertEqual(journal[0].at, at(2))
        journal.merge([LuckDraw(at: at(30), kind: .bossThrow, odds: 0.3, hits: 1)])
        XCTAssertEqual(journal.count, 3, "the next day, its own line")
    }

    /// Short keys keep the save small; a save from before has no journal and reads its past back.
    func testTheJournalIsSaved() throws {
        let draw = LuckDraw(at: at(1), kind: .secretBoss, odds: 0.01, hits: 1)
        let json = String(decoding: try JSONEncoder().encode(draw), as: UTF8.self)
        XCTAssertTrue(json.contains("\"k\":\"secretBoss\""), json)
        XCTAssertLessThan(json.utf8.count, 90)
        XCTAssertEqual(try JSONDecoder().decode(LuckDraw.self, from: Data(json.utf8)), draw)
        var progress = DungeonProgress()
        XCTAssertNil(try JSONDecoder().decode(DungeonProgress.self, from: JSONEncoder().encode(progress)).luckDraws)
        progress.luckDraws = [draw]
        XCTAssertEqual(try JSONDecoder().decode(DungeonProgress.self, from: JSONEncoder().encode(progress)).luckDraws, [draw])
    }

    private func entry(_ floor: Int, _ kind: ExpeditionLogKind) -> ExpeditionLogEntry {
        ExpeditionLogEntry(id: floor * 10, floor: floor, date: day, kind: kind)
    }

    private func battle(_ kind: ExpeditionEventKind) -> ExpeditionLogKind {
        .battle(ExpeditionBattle(kind: kind, setup: BattleSetup(sides: [], seed: 0), won: true, duration: 1, foes: []))
    }

    /// A run's journal gives its throws at their ball's odds, its boss's shiny roll, its floors' shiny meetings and
    /// passages, its chests' eggs.
    func testARunsJournalGivesItsDraws() {
        var egg = ExpeditionLoot()
        egg.add(.rareEgg)
        let log = [entry(1, battle(.wild)), entry(2, .chest(egg)), entry(3, .shiny(speciesID: 92, caught: true)),
                   entry(4, .center), entry(4, .secretPassage(skipped: false, loot: ExpeditionLoot())),
                   entry(5, battle(.trainer)), entry(5, .chest(ExpeditionLoot())), entry(6, battle(.boss)),
                   entry(6, .bossReached(speciesID: 94, isShiny: false)),
                   entry(6, .capture(attempt: 1, ball: nil, caught: false)),
                   entry(6, .capture(attempt: 2, ball: ItemKind.greatBall.rawValue, caught: true)), entry(6, .victory)]
        let draws = DungeonLuck.draws(dungeon: .pokemonTower, log: log, at: day, shinyDenominator: 64)
        func line(_ kind: LuckDrawKind, _ odds: Double) -> LuckDraw? {
            draws.first { $0.kind == kind && abs($0.odds - odds) < 1e-9 }
        }
        // At Gengar's line's odds a throw, half as much again with a Great Ball.
        let gengar = ExpeditionEngine.captureOdds(SpeciesInfo.lineRarity(of: 94))
        XCTAssertLessThan(gengar * 1.5, 1, "a throw that could miss")
        XCTAssertEqual(line(.bossThrow, gengar)?.hits, 0)
        XCTAssertEqual(line(.bossThrow, ExpeditionEngine.perMilleOdds(gengar * 1.5))?.hits, 1)
        XCTAssertEqual(line(.bossShiny, 1.0 / 64)?.hits, 0)
        XCTAssertEqual(line(.shinyMeeting, 0.01)?.trials, 4, "the floors with an event: 1, 2, 3 and 5")
        XCTAssertEqual(line(.shinyMeeting, 0.01)?.hits, 1)
        XCTAssertEqual(line(.shinyCatch, ExpeditionEngine.captureOdds(SpeciesInfo.lineRarity(of: 92)))?.hits, 1, "a Gastly")
        XCTAssertEqual(line(.secretPassage, 0.04)?.trials, 5, "the event floors and the Pokémon Center's")
        XCTAssertEqual(line(.secretPassage, 0.04)?.hits, 1)
        XCTAssertEqual(line(.chestEgg, 0.1)?.trials, 3, "two chests and the hidden room's")
        XCTAssertEqual(line(.chestEgg, 0.1)?.hits, 1)
    }

    private func run(_ dungeon: DungeonID, _ hours: Double, boss: Int, caught: Bool, log: [ExpeditionLogEntry]? = nil)
        -> DungeonRunRecord {
        DungeonRunRecord(dungeon: dungeon, endedAt: at(hours), won: true, left: false, floor: 5, floors: 5, tokens: 1,
                         candies: 0, eggs: 0, items: 0, bossSpeciesID: boss, caught: caught, log: log)
    }

    /// The secret bosses read back: from a journal, from a line whose boss is none of its dungeon's, never before they
    /// came, never once caught.
    func testTheSecretBossesAreReadBack() {
        let groudon = [entry(5, .bossReached(speciesID: 383, isShiny: false, secret: true)),
                       entry(5, .capture(attempt: 1, ball: ItemKind.ultraBall.rawValue, caught: true))]
        let history = [
            run(.diglettsCave, -24 * 20, boss: 51, caught: true),          // before the secret bosses: no draw
            run(.diglettsCave, 1, boss: 76, caught: true),                 // a draw that missed
            run(.diglettsCave, 2, boss: 383, caught: true, log: groudon),  // Groudon
            run(.diglettsCave, 3, boss: 51, caught: true),                 // Groudon caught: none left to draw
            run(.mtMoon, 4, boss: 488, caught: false),                     // Cresselia, from its line alone
            run(.daily, 5, boss: 6, caught: false),                        // a challenge has none
        ]
        let draws = DungeonLuck.backfill(history) { _ in 64 }.filter { $0.kind == .secretBoss }
        XCTAssertEqual(draws.reduce(0) { $0 + $1.trials }, 3)
        XCTAssertEqual(draws.reduce(0) { $0 + $1.hits }, 2)
        // Groudon's throw counts too, at an Ultra Ball's odds on a legendary.
        let throwsBack = DungeonLuck.backfill(history) { _ in 64 }.filter { $0.kind == .bossThrow }
        XCTAssertEqual(throwsBack.first?.odds ?? 0, 0.24, accuracy: 1e-9)
        XCTAssertEqual(throwsBack.first?.hits, 1)
    }

    /// The shiny odds of each run's day: the Shiny Charm's from the day it came.
    func testTheBackfillTakesEachDaysShinyOdds() {
        let reached = [entry(5, .bossReached(speciesID: 51, isShiny: false))]
        let history = [run(.diglettsCave, 1, boss: 51, caught: false, log: reached),
                       run(.diglettsCave, 30, boss: 51, caught: false, log: reached)]
        let draws = DungeonLuck.backfill(history) { $0 < self.at(10) ? 64 : 48 }.filter { $0.kind == .bossShiny }
        XCTAssertEqual(Set(draws.map(\.odds)), [1.0 / 64, 1.0 / 48])
    }

    /// A legendary boss shiny may have come so for its egg: no roll to judge.
    func testAShinyLegendaryBossIsNoRoll() {
        let log = [entry(5, .bossReached(speciesID: 144, isShiny: true))]
        XCTAssertTrue(DungeonLuck.draws(dungeon: .seafoamIslands, log: log, at: day, shinyDenominator: 64)
            .filter { $0.kind == .bossShiny }.isEmpty)
    }
}
