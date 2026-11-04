import Foundation

/// A hidden form that decides what its Pokémon brings: the odds it brings something, in lowest terms, and the stage
/// that shows it.
struct FormMystery: Equatable, Sendable {
    let chances: Int
    let outOf: Int
    let revealSpeciesID: Int

    var isCertain: Bool { chances == outOf }
}

/// A Pokémon whose form is rolled, with more than one it could be, while no stage reached shows it (a Cubone until it
/// is a Marowak, an Oshawott until it is a Samurott). Everything said of it holds for each form it can carry.
struct FormSuspense: Equatable, Sendable {
    struct Outcome: Equatable, Sendable {
        let form: PokemonForm
        /// Its weight in the roll (`PokemonForm.rollWeights`).
        let weight: Int
        let news: CompanionStore.ActiveNews
        /// Its line already graduated in this form: it grows as a repeat.
        let isRepeat: Bool
        let isNewForm: Bool
    }

    let revealSpeciesID: Int
    let outcomes: [Outcome]

    /// Its forms would not all bring the same: its form decides what it is worth.
    var isUncertain: Bool { Set(outcomes.map { [$0.isRepeat, $0.news.isDuplicate] }).count > 1 }

    var mystery: FormMystery? {
        guard isUncertain else { return nil }
        let total = outcomes.reduce(0) { $0 + $1.weight }
        let new = outcomes.filter { !$0.news.isDuplicate }.reduce(0) { $0 + $1.weight }
        let divisor = Self.greatestCommonDivisor(new, total)
        return FormMystery(chances: new / divisor, outOf: total / divisor, revealSpeciesID: revealSpeciesID)
    }

    /// What holds whichever form it carries.
    var news: CompanionStore.ActiveNews {
        var species: [Int] = []
        for id in outcomes.flatMap(\.news.newSpecies) where !species.contains(id) { species.append(id) }
        return CompanionStore.ActiveNews(newSpecies: species, firstShiny: outcomes.allSatisfy(\.news.firstShiny),
                                         costume: outcomes.allSatisfy(\.news.costume), mystery: mystery)
    }

    private static func greatestCommonDivisor(_ a: Int, _ b: Int) -> Int { b == 0 ? a : greatestCommonDivisor(b, a % b) }
}
