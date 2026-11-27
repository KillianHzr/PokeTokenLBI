import Foundation

enum GigantamaxFactor {
    static let speciesIDs = Set(BattleForms.all.filter { $0.kind == .gigantamax }.map(\.speciesID))

    private static let meowthID = 52

    static func stopIndex(in plan: [Int], form: PokemonForm?) -> Int? {
        plan.dropLast().firstIndex { id in
            speciesIDs.contains(id) && (id != meowthID || PokemonForm.isDefault(form, speciesID: meowthID))
        }
    }

    static func rolls(roll: UInt64, hasWearer: Bool) -> Bool { roll % (hasWearer ? 10 : 2) == 0 }
}
