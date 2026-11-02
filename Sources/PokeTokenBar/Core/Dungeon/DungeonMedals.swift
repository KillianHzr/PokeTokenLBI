import Foundation

/// The Dungeons achievements (Q32 A, rewards chosen 2026-11-02): a medal per tier, claimed in steps, one per dungeon
/// won once and one for the whole tier. The Ruins of Alph stay out: a secret until a Treasure Map shows them.
enum DungeonMedals {
    static func medal(_ tier: DungeonTier) -> ItemKind {
        switch tier {
        case .t1: .discoveryMedal
        case .t2: .adventureMedal
        case .t3: .expertMedal
        case .t4: .legendsMedal
        case .t5: .originMedal
        }
    }

    /// The tier's dungeons a medal asks for, in the tab's order.
    static func dungeons(_ tier: DungeonTier) -> [DungeonID] {
        DungeonCatalog.all.filter { $0.tier == tier && $0.id != .ruinsOfAlph && !$0.id.isChallenge }.map(\.id)
    }

    /// Whether this step is the whole tier rather than one dungeon.
    static func isWholeTier(_ tier: DungeonTier, step: Int) -> Bool { step > dungeons(tier).count }

    /// One step per dungeon (numbered from 1), then the whole tier when it has more than one. A dungeon's goal is one
    /// of its bosses beaten; the tier's, one boss of each.
    static func goals(_ tier: DungeonTier) -> [(generation: Int, goal: SpeciesGoal)] {
        let list = dungeons(tier).map(DungeonCatalog.dungeon)
        var goals = list.enumerated().map { ($0.offset + 1, SpeciesGoal($0.element.bosses, needed: 1)) }
        if list.count > 1 { goals.append((list.count + 1, SpeciesGoal(list.compactMap(\.bosses.first)))) }
        return goals
    }

    /// What a step puts in the Bag (validated 2026-11-02, modest and never a Legendary Key): a dungeon a ball or a
    /// Capsule, the whole tier an egg or a Gold Capsule.
    static func rewards(_ tier: DungeonTier, step: Int) -> [(kind: ItemKind, count: Int)] {
        if isWholeTier(tier, step: step) {
            switch tier {
            case .t1: return [(.pokemonEgg, 1)]
            case .t2: return [(.uncommonEgg, 1)]
            case .t3: return [(.rareEgg, 1)]
            case .t4, .t5: return [(.goldCapsule, 1)]
            }
        }
        switch tier {
        case .t1: return [(.greatBall, 1)]
        case .t2, .t3: return [(.ultraBall, 1)]
        case .t4: return [(.silverCapsule, 1)]
        case .t5: return [(.goldCapsule, 1)]
        }
    }
}

extension ItemKind {
    /// The tier a Dungeons medal stands for; nil for any other item.
    var dungeonTier: DungeonTier? {
        switch self {
        case .discoveryMedal: .t1
        case .adventureMedal: .t2
        case .expertMedal: .t3
        case .legendsMedal: .t4
        case .originMedal: .t5
        default: nil
        }
    }
}

/// The Battle Forms Medal (2026-11-02): a step at 5, 15, 30, 60 and 100 battle forms won, then at every one, each a
/// modest reward, the Master Ball last.
enum BattleFormsMedal {
    static let steps = [5, 15, 30, 60, 100, BattleForms.all.count]

    static let goals: [(generation: Int, goal: SpeciesGoal)] = steps.enumerated().map {
        ($0.offset + 1, SpeciesGoal(BattleForms.all.map(\.pokemonID), needed: $0.element))
    }

    static func rewards(step: Int) -> [(kind: ItemKind, count: Int)] {
        switch step {
        case 1: [(.ultraBall, 2)]
        case 2: [(.silverCapsule, 1)]
        case 3: [(.goldCapsule, 1)]
        case 4: [(.rareEgg, 1)]
        case 5: [(.legendaryEgg, 1)]
        default: [(.masterBall, 1)]
        }
    }
}
