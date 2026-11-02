import XCTest
@testable import PokeTokenBar

/// The egg being incubated goes by its own name on Home, never "Token Egg", nor does a Pokémon whose line is loading.
@MainActor
final class IncubatingEggNameTests: XCTestCase {
    private func store(inventory: [ItemKind: Int] = [:], active: Bool = true,
                       language: AppLanguage = .fr) throws -> CompanionStore {
        var st = CompanionState()
        st.installBaselineSet = true
        st.language = language
        if active {
            st.active = MonState(baseID: 16, pathIDs: [16], stageIndex: 0, usedAtStage: 0, rarity: .common, totalForms: 1)
        }
        st.inventory = Dictionary(uniqueKeysWithValues: inventory.map { ($0.key.rawValue, $0.value) })
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("egg-name-\(UUID().uuidString).json")
        try JSONEncoder().encode(st).write(to: url)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return CompanionStore(provider: StubProvider(value: EvoLine(baseID: 16, tree: EvoNode(speciesID: 16, children: []),
                                                                  rarity: .common, names: [:])),
                              fileURL: url, rng: SeededRNG(seed: 1))
    }

    private func incubating(_ item: ItemKind, use: (CompanionStore) -> Bool) throws -> String {
        let s = try store(inventory: [item: 1])
        XCTAssertTrue(use(s), "\(item.rawValue) starts an egg")
        XCTAssertNil(s.state.active)
        return s.displayName
    }

    /// Until its line loads (launch, offline), a raised Pokémon has no name yet.
    func testAPokemonWhoseLineIsLoadingWaitsForItsName() throws {
        let s = try store()
        XCTAssertNil(s.currentLine)
        XCTAssertEqual(s.displayName, "…")
    }

    func testTheFirstEggIsAPokemonEgg() throws {
        XCTAssertEqual(try store(active: false).displayName, "Œuf Pokémon")
    }

    func testTheBagsEggsGoByTheirNames() throws {
        XCTAssertEqual(try incubating(.pokemonEgg) { $0.useBagEgg(.pokemonEgg) }, "Œuf Pokémon")
        XCTAssertEqual(try incubating(.uncommonEgg) { $0.useBagEgg(.uncommonEgg) }, "Œuf peu commun")
        XCTAssertEqual(try incubating(.rareEgg) { $0.useBagEgg(.rareEgg) }, "Œuf rare")
        XCTAssertEqual(try incubating(.legendaryEgg) { $0.useLegendaryEgg() }, "Œuf légendaire")
        XCTAssertEqual(try incubating(.typeNullEgg) { $0.useTypeNullEgg() }, "Œuf de Type:0")
        XCTAssertEqual(try incubating(.birthdayEgg) { $0.useBirthdayEgg() }, "Œuf d'anniversaire")
        XCTAssertEqual(try incubating(.fossilEgg) { $0.useFossilEgg() }, "Œuf fossile")
    }

    /// The Legendary Egg goes by the Bag's name, not the Shop's tier name, which differs in Korean.
    func testTheLegendaryEggGoesByItsBagName() throws {
        let s = try store(inventory: [.legendaryEgg: 1], language: .ko)
        XCTAssertTrue(s.useLegendaryEgg())
        XCTAssertEqual(s.displayName, "전설의 알")
    }

    /// A stone's egg is a Pokémon Egg: its type is on its badge.
    func testAStonesEggIsAPokemonEgg() throws {
        XCTAssertEqual(try incubating(.fireStone) { $0.useStone(.fireStone) }, "Œuf Pokémon")
    }

    /// The graduation message names no "Token Egg" either: the egg that arrives goes by its name on Home.
    func testTheGraduationMessageNamesNoTokenEgg() {
        for language in AppLanguage.allCases {
            XCTAssertFalse(L(language).graduated("Pidgeot").contains("Token Egg"), language.rawValue)
        }
    }

    func testAnEventEggGoesByItsName() throws {
        for egg in EventEgg.allCases {
            let s = try store(inventory: [egg.item: 1])
            XCTAssertTrue(s.useEventEgg(egg))
            XCTAssertEqual(s.displayName, s.l.itemName(egg.item), egg.rawValue)
        }
    }
}
