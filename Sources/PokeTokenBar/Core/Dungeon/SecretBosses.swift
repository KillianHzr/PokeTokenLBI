import Foundation

/// A secret boss met in an expedition (the owner, 2026-11-10): a legendary or mythical of the dungeon's place in the
/// games, one time in a hundred. In T1 to T4 it takes the boss's place; in the Hall of Origin it comes after Arceus,
/// never in his place, three at once (`after`). Kept apart from the dungeon's bosses: it counts for none of their
/// records (Mt. Coronet's door, the medals), Galarian Articuno beaten is not Articuno beaten.
struct SecretEncounter: Codable, Sendable, Equatable {
    /// The one its capture gives.
    var boss: ExpeditionBoss
    /// Its team when it fights with others: the Origin trio.
    var foes: [ExpeditionBoss]?
    /// After the dungeon's own boss rather than in its place (the Hall of Origin).
    var after: Bool
    /// Caught once already: beaten for its loot only, no throw.
    var lootOnly: Bool
    /// The fight after the boss was played (whatever its end); its throws under way; caught.
    var fought: Bool?
    var capturing: Bool?
    var caught: Bool?
}

enum SecretBosses {
    /// One expedition in a hundred.
    static let odds = 100

    /// Each dungeon's secret (validated by the owner, 2026-11-10): from his list of the games' places when it names one,
    /// else the closest in spirit. Mt. Coronet's is one of the lake trio, the Hall of Origin's the Origin trio.
    static func candidates(_ id: DungeonID) -> [ExpeditionBoss] {
        func one(_ species: Int, _ form: String? = nil) -> ExpeditionBoss {
            ExpeditionBoss(speciesID: species, form: form.map { PokemonForm($0) }, isShiny: false)
        }
        switch id {
        case .viridianForest: return [one(251)]          // Celebi, the forests' guardian
        case .diglettsCave: return [one(383)]            // Groudon, under the ground
        case .mtMoon: return [one(488)]                  // Cresselia, the moon's
        case .mtEmber: return [one(146)]                 // Moltres, Mt. Ember (FireRed, LeafGreen)
        case .victoryRoad: return [one(639)]             // Terrakion, Unova's Victory Road
        case .pokemonTower: return [one(802)]            // Marshadow, in the shadows
        case .dragonsDen: return [one(384)]              // Rayquaza, the dragon of the legends
        case .powerPlant: return [one(145)]              // Zapdos, the Power Plant
        case .seafoamIslands: return [one(144, "galar")] // Galarian Articuno: Articuno is a boss there already
        case .ceruleanCave: return [one(151)]            // Mew, Mewtwo's origin
        case .mtCoronet: return [one(480), one(481), one(482)] // Uxie, Mesprit, Azelf, the lakes at its foot
        case .ruinsOfAlph: return [one(486)]             // Regigigas, the king of the ruins' Regis
        case .hallOfOrigin: return trinity
        case .daily, .weekly, .skullHideout, .magmaHideout, .aquaHideout, .galacticHideout, .rocketHideout: return []
        }
    }

    /// Dialga, Palkia and Giratina in their Origin Forme, together in the Hall of Origin.
    static let trinity = [ExpeditionBoss(speciesID: 483, form: PokemonForm("origin"), isShiny: false),
                          ExpeditionBoss(speciesID: 484, form: PokemonForm("origin"), isShiny: false),
                          ExpeditionBoss(speciesID: 487, form: PokemonForm("origin"), isShiny: false)]

    /// The record a secret is kept under in its dungeon: "seafoamIslands:144:galar".
    static func key(_ dungeon: DungeonID, _ boss: ExpeditionBoss) -> String {
        "\(dungeon.rawValue):\(boss.speciesID)" + (boss.form.map { ":\($0.rawValue)" } ?? "")
    }

    /// The expedition's secret, drawn from its seed: one in `odds`, among those not caught yet. A secret caught never
    /// comes back (the owner, 2026-11-10: it would take a run from the bosses Mt. Coronet waits for); a dungeon whose
    /// secrets are all caught has none left. `owned` makes its egg shiny ("si on les a déjà ça nous donne l'oeuf en
    /// shiny").
    static func draw(_ id: DungeonID, seed: UInt64, caught: Set<String>, owned: (ExpeditionBoss) -> Bool) -> SecretEncounter? {
        let left = candidates(id).filter { !caught.contains(key(id, $0)) }
        guard !left.isEmpty else { return nil }
        var random = BattleRandom(seed: seed ^ 0x5EC2_E7B0_0D05)
        guard random.below(odds) == 0 else { return nil }
        var boss = left[random.below(left.count)]
        boss.isShiny = owned(boss)
        return SecretEncounter(boss: boss, foes: id == .hallOfOrigin ? trinity : nil, after: id == .hallOfOrigin,
                               lootOnly: false)
    }
}
