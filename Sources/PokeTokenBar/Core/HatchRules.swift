import Foundation

/// The changes the updates made to the egg roll, each in force from the day of the What's New entry that tells it:
/// the Luck screen replays an egg with the rules of the day it was rolled. A change no entry tells counts as always
/// there.
struct HatchRules: Sendable, Equatable {
    enum Change: String, CaseIterable, Sendable {
        /// Lines hatch in their alternate forms.
        case forms = "2026-10-15-forms"
        /// Generations 6 to 9 hatch.
        case laterGenerations = "2026-10-20-gen-6-9"
        /// A legendary no egg hatches in the games weighs like Mewtwo rather than its capture rate.
        case unbreedableLegendariesLikeMewtwo = "2026-10-20-legendary-weights"
        /// Every line of a rarity weighs the same (`BaseSpecies.hatchWeight`).
        case rarityWeights = "2026-10-26-rarity-weights"
        /// A stone's egg lowers a line complete in its type to a quarter, and no egg brings the line hatched last.
        case stoneEggDuplicates = "2026-10-26-stone-egg-duplicates"
        /// A fossil line hatches from Fossil Eggs only until it graduates.
        case fossilEggsOnly = "2026-10-27-fossil-pool"

        var day: Substring { rawValue.prefix(10) }
    }

    let changes: Set<Change>

    static let current = HatchRules(changes: Set(Change.allCases))

    init(changes: Set<Change>) {
        self.changes = changes
    }

    /// The rules of an egg rolled at `date`, by its day where the player is; today's for a roll of unknown date.
    init(rolledAt date: Date?, timeZone: TimeZone = .current) {
        guard let date else {
            self = .current
            return
        }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let d = calendar.dateComponents([.year, .month, .day], from: date)
        let day = String(format: "%04d-%02d-%02d", d.year ?? 0, d.month ?? 0, d.day ?? 0)
        changes = Set(Change.allCases.filter { $0.day <= day })
    }

    func has(_ change: Change) -> Bool { changes.contains(change) }

    /// A line's weight in the roll, before its collection lowers it.
    func weight(_ e: BaseSpecies) -> Int {
        if has(.rarityWeights) { return e.hatchWeight }
        if has(.unbreedableLegendariesLikeMewtwo) && e.isUnbreedableLegendary { return PokemonOdds.hatchWeight(.legendary) }
        return e.captureRate
    }
}
