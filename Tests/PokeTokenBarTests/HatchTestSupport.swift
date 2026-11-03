import Foundation
@testable import PokeTokenBar

/// Real species, with lines from the offline evolution data, so forms, types, fossils, mythicals and events apply.
struct RosterProvider: PokeProviding {
    static let entries: [BaseSpecies] = [
        BaseSpecies(id: 16, captureRate: 255), BaseSpecies(id: 19, captureRate: 255),
        BaseSpecies(id: 10, captureRate: 255), BaseSpecies(id: 37, captureRate: 190),
        BaseSpecies(id: 52, captureRate: 255), BaseSpecies(id: 50, captureRate: 255),
        BaseSpecies(id: 74, captureRate: 255), BaseSpecies(id: 585, captureRate: 190),
        BaseSpecies(id: 370, captureRate: 225), BaseSpecies(id: 102, captureRate: 90),
        BaseSpecies(id: 58, captureRate: 100), BaseSpecies(id: 618, captureRate: 75),
        BaseSpecies(id: 1, captureRate: 45), BaseSpecies(id: 4, captureRate: 45),
        BaseSpecies(id: 133, captureRate: 45), BaseSpecies(id: 138, captureRate: 45),
        BaseSpecies(id: 142, captureRate: 45), BaseSpecies(id: 696, captureRate: 45),
        BaseSpecies(id: 144, captureRate: 3, isUnbreedableLegendary: true),
        BaseSpecies(id: 150, captureRate: 3, isUnbreedableLegendary: true),
        BaseSpecies(id: 151, captureRate: 45, isUnbreedableLegendary: true),
        BaseSpecies(id: 490, captureRate: 3, isLegendary: true),
        BaseSpecies(id: 772, captureRate: 3, isUnbreedableLegendary: true),
    ]

    static func tree(_ id: Int) -> EvoNode {
        EvoNode(speciesID: id, children: (PokemonEvolutionData.children[id] ?? []).map(tree))
    }

    func line(baseSpeciesID: Int) async throws -> EvoLine {
        let rarity = Self.entries.first { $0.id == baseSpeciesID }?.rarity ?? .common
        return EvoLine(baseID: baseSpeciesID, tree: Self.tree(baseSpeciesID), rarity: rarity, names: [:])
    }
    func baseSpeciesIndex() async throws -> [BaseSpecies] { Self.entries }
    func baseSpecies(id: Int) async throws -> BaseSpecies? { Self.entries.first { $0.id == id } }
}
