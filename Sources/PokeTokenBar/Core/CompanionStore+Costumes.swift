import Foundation

extension CompanionStore {
    /// The costumed Pokémon collected (`CostumeEntry.key`): every stage of a costumed record's chain that wears its
    /// costume, sent off or graduated, and the one raised up to its stage; `shiny`, those of them collected shiny.
    func ownedCostumeKeys(includingActive: Bool = true) -> (all: Set<String>, shiny: Set<String>) {
        var all = Set<String>(), shiny = Set<String>()
        func add(_ code: String, chain: some Sequence<Int>, form: PokemonForm?, isShiny: Bool) {
            for id in chain {
                guard let entry = CostumeCatalog.entry(code: code, speciesID: id, form: form) else { continue }
                all.insert(entry.key)
                if isShiny { shiny.insert(entry.key) }
            }
        }
        for record in state.dex { if let code = record.costume { add(code, chain: record.chainOrder, form: record.form, isShiny: record.isShiny) } }
        if includingActive, let mon = state.active, let code = mon.costume {
            add(code, chain: mon.pathIDs.prefix(mon.stageIndex + 1), form: mon.form, isShiny: mon.displaysShiny)
        }
        return (all, shiny)
    }

    /// The month whose costumes the eggs earned now hold.
    var costumeMonth: Int { CostumeCatalog.month(ofDay: state.lastDate) ?? LocalUsageReader.gregorianCalendar().component(.month, from: currentDate) }

    /// The tokens still to use before the next Costume Egg.
    var tokensToNextCostumeEgg: Int { CostumeCatalog.tokensPerEgg - state.costumeEggTokens }
}
