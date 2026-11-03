import Foundation

/// A battle at one moment, folded from its events: what the live view and the replay draw (maquette 5).
struct BattleFrame: Equatable, Sendable {
    struct Unit: Equatable, Sendable {
        let id: String
        let side: Int
        var speciesID: Int
        var form: PokemonForm?
        let isShiny: Bool
        var gender: PokemonGender? = nil
        let maxHP: Int
        var hp: Int
        var onField = false
        var fainted = false
        var castMove: String?
        var castStart = 0
        var castEnds = 0
        var status: BattleAilment?

        /// How far its cast has gone, 0 to 1.
        func castProgress(at time: Int) -> Double {
            guard castMove != nil, castEnds > castStart else { return 0 }
            return min(1, max(0, Double(time - castStart) / Double(castEnds - castStart)))
        }
    }

    var units: [Unit]
    /// The last moves that landed, newest last: (time, attacker, move, target, damage).
    var recentHits: [(time: Int, attacker: String, move: String, target: String, damage: Int)]

    static func == (lhs: BattleFrame, rhs: BattleFrame) -> Bool {
        lhs.units == rhs.units && lhs.recentHits.count == rhs.recentHits.count
    }

    /// The battle at `time`, from the start of its events.
    static func at(_ time: Int, setup: BattleSetup, events: [TimedBattleEvent], keepHits: Int = 4) -> BattleFrame {
        var units: [Unit] = []
        for (side, spec) in setup.sides.enumerated() {
            for battler in spec.battlers {
                units.append(Unit(id: battler.id, side: side, speciesID: battler.speciesID, form: battler.form,
                                  isShiny: battler.isShiny, gender: battler.resolvedGender, maxHP: battler.stats.hp,
                                  hp: battler.hp))
            }
        }
        var index: [String: Int] = [:]
        for (i, unit) in units.enumerated() { index[unit.id] = i }
        var hits: [(time: Int, attacker: String, move: String, target: String, damage: Int)] = []
        for timed in events where timed.time <= time {
            switch timed.event {
            case .enter(_, _, let id):
                if let i = index[id] { units[i].onField = true }
            case .leave(let id):
                if let i = index[id] {
                    units[i].onField = false
                    units[i].castMove = nil
                    units[i].speciesID = setup.sides[units[i].side].battlers.first { $0.id == id }?.speciesID ?? units[i].speciesID
                    units[i].form = setup.sides[units[i].side].battlers.first { $0.id == id }?.form
                }
            case .cast(let id, let move, _, let ends):
                if let i = index[id] {
                    units[i].castMove = move
                    units[i].castStart = timed.time
                    units[i].castEnds = ends
                }
            case .hit(let attacker, let target, let move, let damage, let hp, _, _):
                if let i = index[target] { units[i].hp = hp }
                hits.append((timed.time, attacker, move, target, damage))
                if hits.count > keepHits { hits.removeFirst() }
            case .hurt(let id, _, let hp, _), .heal(let id, _, let hp, _):
                if let i = index[id] {
                    units[i].hp = hp
                    // Revival Blessing: back from a knock-out, on the bench.
                    if units[i].fainted, hp > 0 { units[i].fainted = false }
                }
            case .faint(let id):
                if let i = index[id] {
                    units[i].hp = 0
                    units[i].fainted = true
                    units[i].onField = false
                    units[i].castMove = nil
                }
            case .status(let id, let ailment):
                if let i = index[id], ailment != .confusion, ailment != .trap, ailment != .leechSeed, ailment != .yawn {
                    units[i].status = ailment
                    if ailment == .sleep || ailment == .freeze { units[i].castMove = nil }
                }
            case .cure(let id, let ailment):
                if let i = index[id], units[i].status == ailment { units[i].status = nil }
            case .transform(let id, let into):
                if let i = index[id], let j = index[into] {
                    units[i].speciesID = units[j].speciesID
                    units[i].form = units[j].form
                }
            default:
                break
            }
        }
        return BattleFrame(units: units, recentHits: hits)
    }
}
