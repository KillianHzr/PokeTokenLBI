import Foundation

/// The effects PokéAPI has no data for: the Legends: Arceus and Scarlet and Violet moves come with a power, an
/// accuracy and a priority, nothing else (2026-11-03). Their critical-hit stage, drain or recoil, hits, status, flinch
/// and stat changes, as the games have them, fill those fields when the table is read; what no field can say is played
/// by the engine (`BattleSimulation`, under each move's name).
struct RecentMoveEffect {
    var critStage = 0
    var drain = 0
    var hits: (min: Int, max: Int)?
    var ailment: BattleAilment?
    var ailmentChance = 0
    var flinchChance = 0
    /// Changes to the target's stats (`damage-lower`) or, with `onUser`, to the user's (`damage-raise`).
    var statChanges: [BattleMove.StatChange] = []
    var statChance = 100
    var onUser = false

    static func stats(_ changes: [(BattleStat, Int)], chance: Int = 100, onUser: Bool = false, crit: Int = 0) -> Self {
        RecentMoveEffect(critStage: crit, statChanges: changes.map { BattleMove.StatChange(stat: $0.0, change: $0.1) },
                         statChance: chance, onUser: onUser)
    }

    static func ailment(_ ailment: BattleAilment, _ chance: Int, crit: Int = 0, drain: Int = 0) -> Self {
        RecentMoveEffect(critStage: crit, drain: drain, ailment: ailment, ailmentChance: chance)
    }

    static let all: [String: RecentMoveEffect] = [
        // Dire Claw's status is drawn among three at the hit (`BattleSimulation`); poison stands in.
        "dire-claw": .ailment(.poison, 50, crit: 1),
        "psyshield-bash": .stats([(.defense, 1)], onUser: true),
        "stone-axe": RecentMoveEffect(critStage: 1),
        "springtide-storm": .stats([(.attack, -1)], chance: 30),
        "mystical-power": .stats([(.specialAttack, 1)], onUser: true),
        "wave-crash": RecentMoveEffect(drain: -33),
        "mountain-gale": RecentMoveEffect(flinchChance: 30),
        "headlong-rush": .stats([(.defense, -1), (.specialDefense, -1)], onUser: true),
        "esper-wing": .stats([(.speed, 1)], onUser: true, crit: 1),
        "triple-arrows": RecentMoveEffect(critStage: 1, flinchChance: 30,
                                          statChanges: [BattleMove.StatChange(stat: .defense, change: -1)], statChance: 50),
        "ceaseless-edge": RecentMoveEffect(critStage: 1),
        "bleakwind-storm": .stats([(.speed, -1)], chance: 30),
        "wildbolt-storm": .ailment(.paralysis, 20),
        "sandsear-storm": .ailment(.burn, 20),
        "axe-kick": .ailment(.confusion, 30),
        "lumina-crash": .stats([(.specialDefense, -2)]),
        "spin-out": .stats([(.speed, -2)], onUser: true),
        "population-bomb": RecentMoveEffect(hits: (10, 10)),
        "triple-dive": RecentMoveEffect(hits: (3, 3)),
        "flower-trick": RecentMoveEffect(critStage: 3),
        "torch-song": .stats([(.specialAttack, 1)], onUser: true),
        "aqua-step": .stats([(.speed, 1)], onUser: true),
        "make-it-rain": .stats([(.specialAttack, -1)], onUser: true),
        "pounce": .stats([(.speed, -1)]),
        "trailblaze": .stats([(.speed, 1)], onUser: true),
        "chilling-water": .stats([(.attack, -1)]),
        "twin-beam": RecentMoveEffect(hits: (2, 2)),
        "armor-cannon": .stats([(.defense, -1), (.specialDefense, -1)], onUser: true),
        "bitter-blade": RecentMoveEffect(drain: 50),
        "aqua-cutter": RecentMoveEffect(critStage: 1),
        "blazing-torque": .ailment(.burn, 30),
        "wicked-torque": .ailment(.sleep, 10),
        "noxious-torque": .ailment(.poison, 30),
        "combat-torque": .ailment(.paralysis, 30),
        "magical-torque": .ailment(.confusion, 30),
        "matcha-gotcha": .ailment(.burn, 20, drain: 50),
        "ivy-cudgel": RecentMoveEffect(critStage: 1),
        "tachyon-cutter": RecentMoveEffect(hits: (2, 2)),
        "upper-hand": RecentMoveEffect(flinchChance: 100),
        "malignant-chain": .ailment(.badPoison, 50),
    ]
}

extension BattleMove {
    /// The move with the effects PokéAPI lacks for it filled in.
    func completed(by effect: RecentMoveEffect) -> BattleMove {
        let category: MoveMetaCategory
        if !effect.statChanges.isEmpty {
            category = effect.onUser ? .damageRaise : .damageLower
        } else if effect.ailment != nil {
            category = .damageAilment
        } else {
            category = .damage
        }
        let chance = max(effect.ailmentChance, effect.flinchChance, effect.statChanges.isEmpty ? 0 : effect.statChance)
        return BattleMove(slug: slug, type: type, moveClass: moveClass, power: power, accuracy: accuracy, priority: priority,
                          target: target, effectChance: chance, ailment: effect.ailment ?? ailment,
                          ailmentChance: effect.ailmentChance, critStage: effect.critStage, drain: effect.drain,
                          healing: healing, flinchChance: effect.flinchChance, minHits: effect.hits?.min ?? minHits,
                          maxHits: effect.hits?.max ?? maxHits, minTurns: minTurns, maxTurns: maxTurns,
                          statChance: effect.statChanges.isEmpty ? statChance : effect.statChance,
                          statChanges: effect.statChanges.isEmpty ? statChanges : effect.statChanges,
                          category: category, flags: flags)
    }
}
