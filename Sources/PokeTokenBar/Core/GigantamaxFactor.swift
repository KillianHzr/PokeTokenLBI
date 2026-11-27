import Foundation

enum GigantamaxFactor {
    static let speciesIDs = Set(BattleForms.all.filter { $0.kind == .gigantamax }.map(\.speciesID))

    private static let meowthID = 52
    static let oddsWhileNoWearer: UInt64 = 2
    static let oddsOnceAWearer: UInt64 = 10

    static func stopIndex(in plan: [Int], form: PokemonForm?) -> Int? {
        plan.dropLast().firstIndex { id in
            speciesIDs.contains(id) && (id != meowthID || PokemonForm.isDefault(form, speciesID: meowthID))
        }
    }

    static func rolls(roll: UInt64, hasWearer: Bool) -> Bool { roll % (hasWearer ? oddsOnceAWearer : oddsWhileNoWearer) == 0 }
}

extension GigantamaxFactor {
    static func bringsFirstWearer(finalID: Int, hasFactor: Bool, among dex: [DexEntry]) -> Bool {
        guard hasFactor, let form = BattleForms.forms(speciesID: finalID).first(where: { $0.kind == .gigantamax }) else { return false }
        return !dex.contains(where: form.isWorn)
    }
}
