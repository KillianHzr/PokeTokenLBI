import XCTest
@testable import PokeTokenBar

/// The battle's journal (the owner, 2026-11-09: "qui a fait quoi à qui", both sides, the whole battle; it showed the
/// last four moves that did damage) and the replay at half speed.
@MainActor
final class BattleLogTests: XCTestCase {
    private func setup() throws -> BattleSetup {
        let ours = try XCTUnwrap(BattlerSpec.make(id: "a", speciesID: 445, level: 100))
        let foe = try XCTUnwrap(BattlerSpec.make(id: "b", speciesID: 229, level: 100))
        return BattleSetup(sides: [BattleSideSpec(battlers: [ours], active: 1), BattleSideSpec(battlers: [foe], active: 1)],
                           seed: 1)
    }

    private func at(_ time: Int, _ event: BattleEvent) -> TimedBattleEvent { TimedBattleEvent(time: time, event: event) }

    /// Each side's moves on its side, what happened to a Pokémon in the middle; a move without damage when it lands,
    /// not when its user falls first nor twice when it missed; a berry's heal said once.
    func testWhoDidWhatToWhom() throws {
        let events = [
            at(0, .enter(side: 0, slot: 0, battler: "a")),
            at(0, .enter(side: 1, slot: 0, battler: "b")),
            at(0, .cast(battler: "a", move: "swords-dance", target: nil, ends: 500)),
            at(0, .cast(battler: "b", move: "tackle", target: "a", ends: 600)),
            at(600, .hit(attacker: "b", target: "a", move: "tackle", damage: 40, hp: 300, effectiveness: 0.5, critical: false)),
            at(600, .cast(battler: "a", move: "will-o-wisp", target: "b", ends: 1500)),
            at(600, .cast(battler: "b", move: "growl", target: "a", ends: 2000)),
            at(900, .berry(battler: "a", berry: .sitrus)),
            at(900, .heal(battler: "a", amount: 120, hp: 340, cause: .berry)),
            at(1000, .hurt(battler: "b", amount: 30, hp: 200, cause: .weather)),
            at(1500, .miss(attacker: "a", target: "b", move: "will-o-wisp")),
            at(1800, .faint(battler: "b")),
        ]
        let lines = BattleLog.lines(events, setup: try setup())
        XCTAssertEqual(lines.map(\.kind), [
            .enter("a"), .enter("b"),
            .move(attacker: "a", target: nil, move: "swords-dance", result: .used),
            .move(attacker: "b", target: "a", move: "tackle", result: .hit(damage: 40, effectiveness: 0.5, critical: false)),
            .berry("a", .sitrus),
            .hurt("b", amount: 30),
            .move(attacker: "a", target: "b", move: "will-o-wisp", result: .miss),
            .faint("b"),
        ], "Growl never landed: its user fell at 1800, before its cast's end")
        XCTAssertEqual(lines.map(\.side), [nil, nil, 0, 1, nil, nil, 0, nil])
        XCTAssertEqual(lines.map(\.time), [0, 0, 500, 600, 900, 1000, 1500, 1800])
        XCTAssertEqual(lines.map(\.id), Array(0..<8))
    }

    /// A real battle: every move that landed has its line, on its user's side, with its damage.
    func testEveryHitIsSaid() throws {
        let outcome = BattleEngine.run(try setup())
        let lines = BattleLog.lines(outcome.events, setup: outcome.setup)
        let hits = outcome.events.compactMap { timed -> (String, Int)? in
            if case .hit(let attacker, _, _, let damage, _, _, _) = timed.event { return (attacker, damage) } else { return nil }
        }
        XCTAssertFalse(hits.isEmpty)
        let said = lines.compactMap { line -> (String, Int, Int?)? in
            if case .move(let attacker, _, _, .hit(let damage, _, _)) = line.kind { return (attacker, damage, line.side) }
            return nil
        }
        XCTAssertEqual(said.map(\.0), hits.map(\.0))
        XCTAssertEqual(said.map(\.1), hits.map(\.1))
        XCTAssertEqual(said.map(\.2), hits.map { $0.0 == "a" ? 0 : 1 })
        XCTAssertEqual(lines.map(\.time), lines.map(\.time).sorted())
    }

    func testTheReplayPlaysAtHalfSpeed() {
        XCTAssertEqual(BattleReplayView.speed, 0.5)
    }

    /// The one hitting leaps and the one hit is knocked back, quickly (the owner, 2026-11-10): nothing before the hit,
    /// the peak halfway, nothing again after a quarter of a second on screen.
    func testTheLeapAndTheKnockBackAreQuick() {
        XCTAssertEqual(BattleArena.bump(-10, length: 150), 0)
        XCTAssertEqual(BattleArena.bump(75, length: 150), 1, accuracy: 0.001)
        XCTAssertEqual(BattleArena.bump(150, length: 150), 0)
        XCTAssertLessThanOrEqual(max(BattleArena.hopLength, BattleArena.recoilLength) / BattleReplayView.speed, 300,
                                 "a quarter of a second, about, on screen")
    }

    func testItsWordsInEveryLanguage() {
        for language in AppLanguage.allCases {
            let l = L(language)
            for text in [l.battleLogEnters, l.battleLogMiss, l.battleLogNoEffect, l.battleLogFailed, l.expeditionLive,
                         l.expeditionWaitsForYou, l.challengeLostDay, l.challengeWonDay, l.challengeNextDay,
                         l.challengeTryTomorrow, l.challengeWonWeek, l.challengeNextWeek, l.challengeWeekWonTip] {
                XCTAssertFalse(text.isEmpty, "\(language)")
                XCTAssertFalse(text.contains("\u{2014}") || text.contains("\u{2013}"), "\(language): \(text)")
            }
        }
    }
}
