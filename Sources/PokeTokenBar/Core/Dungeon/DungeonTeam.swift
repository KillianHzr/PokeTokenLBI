import Foundation

/// A graduated Pokémon as a dungeon's rules see it.
struct DungeonCandidate: Sendable, Equatable {
    /// Its Pokédex entry (`DexEntry.id`).
    let entryID: String
    /// The species it graduated as.
    let speciesID: Int
    let baseID: Int
    let form: PokemonForm?
    let rarity: Rarity
    let isShiny: Bool

    var types: [PokemonType] { PokemonTypeData.types(forSpeciesID: speciesID, form: form) }
    var generation: Int { SpeciesInfo.all[speciesID]?.generation ?? 0 }
    var isLegendary: Bool { rarity == .legendary }
    var isStarter: Bool { CollectorBonus.starterLines.contains(baseID) || CollectorBonus.starterLines.contains(speciesID) }

    init(entryID: String, speciesID: Int, baseID: Int, form: PokemonForm?, rarity: Rarity, isShiny: Bool) {
        self.entryID = entryID
        self.speciesID = speciesID
        self.baseID = baseID
        self.form = form
        self.rarity = rarity
        self.isShiny = isShiny
    }

    init(_ entry: DexEntry) {
        self.init(entryID: entry.id, speciesID: entry.finalID, baseID: entry.baseID, form: entry.form,
                  rarity: entry.rarity, isShiny: entry.isShiny)
    }
}

/// The rules of a team (Q5, Q6, Q7): its size, one Pokémon per species, and the dungeon's rules, each checked on its
/// own so the team screen ticks them as the team forms.
enum DungeonTeamRules {
    /// Whether this Pokémon may join at all: a rule it breaks alone keeps it out. The rules on the whole team (a
    /// shared type, one region, a single legendary) are checked with `holds`.
    static func admits(_ candidate: DungeonCandidate, rules: [DungeonRule]) -> Bool {
        rules.allSatisfy { rule in
            switch rule {
            case .noLegendary: !candidate.isLegendary
            case .onlyLegendaries: candidate.isLegendary
            case .onlyStarters: candidate.isStarter
            case .maxRarity(let cap): candidate.rarity.sortRank <= cap.sortRank
            case .bannedType(let type): !candidate.types.contains(type)
            case .onlyShinies: candidate.isShiny
            case .atMostOneLegendary, .sharedType, .oneRegion: true
            }
        }
    }

    /// Whether a rule holds for the team as it stands.
    static func holds(_ rule: DungeonRule, for team: [DungeonCandidate]) -> Bool {
        switch rule {
        case .atMostOneLegendary:
            return team.filter(\.isLegendary).count <= 1
        case .sharedType:
            guard let first = team.first else { return true }
            return !team.dropFirst().reduce(Set(first.types)) { $0.intersection($1.types) }.isEmpty
        case .oneRegion:
            return Set(team.map(\.generation)).count <= 1
        default:
            return team.allSatisfy { admits($0, rules: [rule]) }
        }
    }

    /// One species once (Q6).
    static func distinctSpecies(_ team: [DungeonCandidate]) -> Bool {
        Set(team.map(\.speciesID)).count == team.count
    }

    /// Whether the team may set off: its exact size, one species once, every rule held.
    static func isValid(_ team: [DungeonCandidate], size: Int, rules: [DungeonRule]) -> Bool {
        team.count == size && distinctSpecies(team) && rules.allSatisfy { holds($0, for: team) }
    }
}
