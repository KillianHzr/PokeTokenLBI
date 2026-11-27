import Foundation

struct WearerEgg: Codable, Sendable, Equatable, Identifiable {
    var id: String
    var formKey: String

    init(id: String = UUID().uuidString, formKey: String) {
        self.id = id
        self.formKey = formKey
    }

    var form: BattleForm? { BattleForms.form(key: formKey) }
    var speciesID: Int { form?.speciesID ?? 0 }
    var baseID: Int { SpeciesInfo.baseID(of: speciesID) }
    var hatchForm: PokemonForm? { PokemonForm.resolved(baseID: baseID, form: form?.wearerForm) }
    var hasGigantamaxFactor: Bool { form?.needsGigantamaxFactor == true }
}
