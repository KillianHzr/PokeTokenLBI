import Foundation

/// The Collection's statistics (the owner, 2026-11-10: "voir tout ce qu'on a accompli et tout ce qu'il nous reste à
/// faire"): the counter's four totals, the Pokédex as a map of generations by types, the categories and the battle
/// forms, and what is closest to done. Owned is graduated, as the counter reads it.
struct CollectionStats: Sendable {
    /// A Pokémon still to have: a species, or one of its battle forms.
    struct Missing: Hashable, Sendable {
        let speciesID: Int
        var form: PokemonForm? = nil
    }

    struct Tally: Equatable, Sendable {
        let owned: Int
        let total: Int
        let missing: [Missing]
        var isDone: Bool { owned >= total }
        var left: Int { total - owned }
        var fraction: Double { total == 0 ? 1 : Double(owned) / Double(total) }
    }

    enum Category: String, CaseIterable, Sendable {
        case legendaries, mythicals, ultraBeasts, paradoxes, fossils, starters

        var species: [Int] {
            switch self {
            case .legendaries: SpeciesGoal.legendaries
            case .mythicals: SpeciesGoal.mythicals
            case .ultraBeasts: SpeciesGoal.ultraBeasts
            case .paradoxes: SpeciesGoal.paradoxes
            case .fossils: SpeciesGoal.fossils
            case .starters: DungeonCatalog.finalStarters
            }
        }
    }

    /// A set the screen counts: a generation, a type, one of their cells, a category, a kind of battle form.
    enum Group: Hashable, Sendable {
        case generation(Int)
        case type(PokemonType)
        case cell(generation: Int, type: PokemonType)
        case category(Category)
        case battle(BattleFormKind)
    }

    let species: Tally
    let forms: (owned: Int, total: Int)
    let lines: (owned: Int, total: Int)
    let shinies: (owned: Int, total: Int)
    private let tallies: [Group: Tally]

    static let generationCount = PokemonTypeData.generations.count
    static let battleKinds: [BattleFormKind] = [.mega, .gigantamax, .primal]

    init(owned: Set<Int>, battleFormsWon: Set<String>, progress: CompanionStore.CollectionProgress, shinySpecies: Int) {
        let all = Array(PokemonAssets.animatedSpeciesIDs)
        func tally(_ ids: [Int]) -> Tally {
            Tally(owned: ids.filter(owned.contains).count, total: ids.count,
                  missing: ids.filter { !owned.contains($0) }.map { Missing(speciesID: $0) })
        }
        var tallies: [Group: Tally] = [:]
        let types = Dictionary(uniqueKeysWithValues: all.map { ($0, PokemonTypeData.types(forSpeciesID: $0)) })
        for (index, range) in PokemonTypeData.generations.enumerated() {
            let generation = index + 1
            tallies[.generation(generation)] = tally(Array(range))
            for type in PokemonType.allCases {
                tallies[.cell(generation: generation, type: type)] = tally(range.filter { types[$0]?.contains(type) == true })
            }
        }
        for type in PokemonType.allCases { tallies[.type(type)] = tally(all.filter { types[$0]?.contains(type) == true }) }
        for category in Category.allCases { tallies[.category(category)] = tally(category.species.sorted()) }
        for kind in Self.battleKinds {
            let forms = BattleForms.all.filter { $0.kind == kind }
            let left = forms.filter { !battleFormsWon.contains($0.key) }
            tallies[.battle(kind)] = Tally(owned: forms.count - left.count, total: forms.count,
                                           missing: left.map { Missing(speciesID: $0.speciesID, form: $0.form) })
        }
        self.tallies = tallies
        species = tally(all)
        forms = (progress.forms, progress.formsTotal)
        lines = (progress.lines, progress.linesTotal)
        shinies = (shinySpecies, all.count)
    }

    func tally(_ group: Group) -> Tally { tallies[group] ?? Tally(owned: 0, total: 0, missing: []) }

    /// What is closest to done, the fewest left first (the larger set first on a tie): generations, types,
    /// categories and battle forms at least half done, never one complete nor a single cell of the map. Half done at
    /// least: the two Primal Reversions, none won, were not "almost done" for being two.
    func almostDone(_ count: Int = 5) -> [Group] {
        let groups: [Group] = (1...Self.generationCount).map { .generation($0) } + PokemonType.allCases.map { .type($0) }
            + Category.allCases.map { .category($0) } + Self.battleKinds.map { .battle($0) }
        return Array(groups.filter { !tally($0).isDone && tally($0).fraction >= 0.5 }
            .sorted { a, b in
                let (x, y) = (tally(a), tally(b))
                return x.left != y.left ? x.left < y.left : x.total > y.total
            }
            .prefix(count))
    }
}

extension CompanionStore {
    /// The Collection's statistics, from the graduated Pokémon as the counter counts them.
    var collectionStats: CollectionStats {
        CollectionStats(owned: graduatedSpeciesIDs, battleFormsWon: state.dungeons.battleForms,
                        progress: graduatedCollectionProgress,
                        shinySpecies: Set(dexSpecies.filter(\.isShiny).map(\.id)).count)
    }
}
