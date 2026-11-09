import Foundation

/// A battle told line by line under its arena (the owner, 2026-11-09: "qui a fait quoi à qui", both sides, the whole
/// battle to scroll back through; it showed the last four moves that did damage). Each line is one side's (its moves) or
/// nobody's (who enters, falls, is burned, heals, eats a berry), read from the battle's events.
struct BattleLogLine: Equatable, Sendable, Identifiable {
    enum Result: Equatable, Sendable {
        case hit(damage: Int, effectiveness: Double, critical: Bool)
        case miss
        case noEffect
        case failed
        /// A move that does no damage (Swords Dance, Will-O-Wisp), landed.
        case used
    }

    enum Kind: Equatable, Sendable {
        case move(attacker: String, target: String?, move: String, result: Result)
        case enter(String)
        case faint(String)
        case status(String, BattleAilment)
        case heal(String, amount: Int)
        case hurt(String, amount: Int)
        case berry(String, BattleBerry)
    }

    let id: Int
    let time: Int
    /// 0 for the player's side, 1 for the foes'; nil for a line about one Pokémon rather than a move.
    let side: Int?
    let kind: Kind
}

enum BattleLog {
    /// Every line of the battle, in time order: what each move did, and what happened to whom. A move that does no
    /// damage counts when it lands (its cast's end), unless its user fell or left before, or its own line (missed,
    /// failed) says it already. A berry's heal is said by the berry's line.
    static func lines(_ events: [TimedBattleEvent], setup: BattleSetup) -> [BattleLogLine] {
        var side: [String: Int] = [:]
        for (index, spec) in setup.sides.enumerated() { for battler in spec.battlers { side[battler.id] = index } }
        var said = Set<String>()
        var gone: [String: [Int]] = [:]
        for timed in events {
            switch timed.event {
            case .hit(let attacker, _, let move, _, _, _, _), .miss(let attacker, _, let move),
                 .noEffect(let attacker, _, let move):
                said.insert("\(attacker)|\(move)|\(timed.time)")
            case .fail(let battler, let move, _):
                said.insert("\(battler)|\(move)|\(timed.time)")
            case .faint(let id), .leave(let id):
                gone[id, default: []].append(timed.time)
            default:
                break
            }
        }
        // A plain struct, not a tuple: a newer compiler gave up on sorting labeled tuples (defect log, 2026-11-09).
        struct Pending { let time: Int; let order: Int; let side: Int?; let kind: BattleLogLine.Kind }
        var lines: [Pending] = []
        func add(_ time: Int, _ order: Int, _ side: Int?, _ kind: BattleLogLine.Kind) {
            lines.append(Pending(time: time, order: order, side: side, kind: kind))
        }
        for (order, timed) in events.enumerated() {
            let t = timed.time
            switch timed.event {
            case .enter(_, _, let id):
                add(t, order, nil, .enter(id))
            case .hit(let attacker, let target, let move, let damage, _, let effectiveness, let critical):
                add(t, order, side[attacker], .move(attacker: attacker, target: target, move: move,
                                                              result: .hit(damage: damage, effectiveness: effectiveness,
                                                                           critical: critical)))
            case .miss(let attacker, let target, let move):
                add(t, order, side[attacker], .move(attacker: attacker, target: target, move: move, result: .miss))
            case .noEffect(let attacker, let target, let move):
                add(t, order, side[attacker], .move(attacker: attacker, target: target, move: move,
                                                              result: .noEffect))
            case .fail(let battler, let move, _):
                add(t, order, side[battler], .move(attacker: battler, target: nil, move: move, result: .failed))
            case .cast(let battler, let move, let target, let ends):
                guard MoveTable.move(move)?.isDamaging == false, !said.contains("\(battler)|\(move)|\(ends)"),
                      !(gone[battler] ?? []).contains(where: { $0 >= t && $0 < ends }) else { continue }
                add(ends, order, side[battler], .move(attacker: battler, target: target, move: move, result: .used))
            case .faint(let id):
                add(t, order, nil, .faint(id))
            case .status(let id, let ailment):
                add(t, order, nil, .status(id, ailment))
            case .heal(let id, let amount, _, let cause) where cause != .berry && amount > 0:
                add(t, order, nil, .heal(id, amount: amount))
            case .hurt(let id, let amount, _, _) where amount > 0:
                add(t, order, nil, .hurt(id, amount: amount))
            case .berry(let id, let berry):
                add(t, order, nil, .berry(id, berry))
            default:
                break
            }
        }
        // By time, then as the events came: a move used at its cast's end sits among what happened then.
        let sorted = lines.sorted { (a: Pending, b: Pending) -> Bool in
            if a.time != b.time { return a.time < b.time }
            return a.order < b.order
        }
        var result: [BattleLogLine] = []
        for (index, line) in sorted.enumerated() {
            result.append(BattleLogLine(id: index, time: line.time, side: line.side, kind: line.kind))
        }
        return result
    }
}
