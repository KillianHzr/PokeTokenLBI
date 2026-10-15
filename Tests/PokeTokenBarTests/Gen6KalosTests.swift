import XCTest
@testable import PokeTokenBar

final class Gen6KalosTests: XCTestCase {
    func testAnimatedSpeciesIDsCoversGen6() {
        XCTAssertEqual(PokemonAssets.animatedSpeciesIDs.lowerBound, 1)
        XCTAssertEqual(PokemonAssets.animatedSpeciesIDs.upperBound, 721)
        XCTAssertTrue(PokemonAssets.hasAnimatedSprite(speciesID: 1))
        XCTAssertTrue(PokemonAssets.hasAnimatedSprite(speciesID: 649))
        XCTAssertTrue(PokemonAssets.hasAnimatedSprite(speciesID: 650), "Chespin is in Gen 6")
        XCTAssertTrue(PokemonAssets.hasAnimatedSprite(speciesID: 658), "Greninja is in Gen 6")
        XCTAssertTrue(PokemonAssets.hasAnimatedSprite(speciesID: 700), "Sylveon is in Gen 6")
        XCTAssertTrue(PokemonAssets.hasAnimatedSprite(speciesID: 721), "Volcanion is in Gen 6")
        XCTAssertFalse(PokemonAssets.hasAnimatedSprite(speciesID: 722), "Rowlet (Gen 7) is not in Gen 6")
    }

    func testGen6SpriteURLsRouteToShowdown() {
        // Gen 6 animated sprite -> Showdown
        let greninjaAnimated = SpriteStore.spriteURL(speciesID: 658, animated: true, shiny: false)
        XCTAssertEqual(
            greninjaAnimated.absoluteString,
            "https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/showdown/658.gif"
        )

        // Gen 6 shiny animated sprite -> Showdown shiny
        let greninjaShiny = SpriteStore.spriteURL(speciesID: 658, animated: true, shiny: true)
        XCTAssertEqual(
            greninjaShiny.absoluteString,
            "https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/showdown/shiny/658.gif"
        )

        // Gen 6 static sprite -> standard pokemon PNG
        let greninjaStatic = SpriteStore.spriteURL(speciesID: 658, animated: false, shiny: false)
        XCTAssertEqual(
            greninjaStatic.absoluteString,
            "https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/658.png"
        )

        // Gen 6 form variety (Aegislash Blade) -> variety ID in Showdown
        let aegislashBlade = SpriteStore.spriteURL(
            speciesID: 681,
            animated: true,
            shiny: false,
            form: PokemonForm("blade")
        )
        XCTAssertEqual(
            aegislashBlade.absoluteString,
            "https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/showdown/10026.gif"
        )

        // Gen 1-5 animated sprites remain Black/White animated
        let genesectAnimated = SpriteStore.spriteURL(speciesID: 649, animated: true, shiny: false)
        XCTAssertEqual(
            genesectAnimated.absoluteString,
            "https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/versions/generation-v/black-white/animated/649.gif"
        )
    }

    func testGen6FormsCatalog() {
        // Vivillon (#666) - 20 patterns
        let vivillonForms = PokemonForm.forms(speciesID: 666)
        XCTAssertEqual(vivillonForms.count, 20)
        XCTAssertEqual(vivillonForms.first?.rawValue, "meadow")
        XCTAssertTrue(vivillonForms.contains(PokemonForm("poke-ball")))

        // Flabébé line (#669, #670, #671) - 5 flower colors linked to base #669
        for speciesID in [669, 670, 671] {
            let forms = PokemonForm.forms(speciesID: speciesID)
            XCTAssertEqual(forms.count, 5)
            XCTAssertEqual(forms.map(\.rawValue), ["red", "yellow", "orange", "blue", "white"])
        }
        XCTAssertEqual(PokemonForm.formSpecies(baseID: 669), [669, 670, 671])
        XCTAssertEqual(
            PokemonForm.resolved(speciesID: 671, form: PokemonForm("blue")),
            PokemonForm("blue")
        )

        // Furfrou (#676) - 10 trims
        let furfrouForms = PokemonForm.forms(speciesID: 676)
        XCTAssertEqual(furfrouForms.count, 10)
        XCTAssertEqual(furfrouForms.first?.rawValue, "natural")
        XCTAssertTrue(furfrouForms.contains(PokemonForm("heart")))

        // Meowstic (#678) - Male & Female
        let meowsticForms = PokemonForm.forms(speciesID: 678)
        XCTAssertEqual(meowsticForms.map(\.rawValue), ["male", "female"])
        XCTAssertEqual(
            PokemonForm.staticAssetName(speciesID: 678, form: PokemonForm("female")),
            "10025"
        )

        // Aegislash (#681) - Shield & Blade
        let aegislashForms = PokemonForm.forms(speciesID: 681)
        XCTAssertEqual(aegislashForms.map(\.rawValue), ["shield", "blade"])
        XCTAssertEqual(
            PokemonForm.staticAssetName(speciesID: 681, form: PokemonForm("blade")),
            "10026"
        )

        // Pumpkaboo (#710) & Gourgeist (#711) - 4 sizes linked to base #710
        for speciesID in [710, 711] {
            let forms = PokemonForm.forms(speciesID: speciesID)
            XCTAssertEqual(forms.count, 4)
            XCTAssertEqual(forms.map(\.rawValue), ["average", "small", "large", "super"])
        }
        XCTAssertEqual(PokemonForm.formSpecies(baseID: 710), [710, 711])

        // Zygarde (#718) - 50%, 10%, Complete
        let zygardeForms = PokemonForm.forms(speciesID: 718)
        XCTAssertEqual(zygardeForms.map(\.rawValue), ["50", "10", "complete"])
        XCTAssertEqual(
            PokemonForm.staticAssetName(speciesID: 718, form: PokemonForm("10")),
            "10181"
        )
        XCTAssertEqual(
            PokemonForm.staticAssetName(speciesID: 718, form: PokemonForm("complete")),
            "10120"
        )
    }

    func testSylveonKeptInEvolutionTree() {
        // Eevee (#133) tree with Gen 1-6 evolutions and a future hypothetical Gen 7 branch (#722)
        let eeveeTree = EvoNode(
            speciesID: 133,
            children: [
                EvoNode(speciesID: 134, children: []), // Vaporeon
                EvoNode(speciesID: 135, children: []), // Jolteon
                EvoNode(speciesID: 136, children: []), // Flareon
                EvoNode(speciesID: 196, children: []), // Espeon
                EvoNode(speciesID: 197, children: []), // Umbreon
                EvoNode(speciesID: 470, children: []), // Leafeon
                EvoNode(speciesID: 471, children: []), // Glaceon
                EvoNode(speciesID: 700, children: []), // Sylveon (Gen 6)
                EvoNode(speciesID: 722, children: []), // Rowlet (Gen 7 - beyond Gen 6 bound)
            ]
        )

        let filtered = eeveeTree.keepingAnimatedSprites()
        XCTAssertNotNil(filtered)
        let keptIDs = filtered?.finalIDs ?? []
        XCTAssertTrue(keptIDs.contains(700), "Sylveon (#700) must be kept in the tree")
        XCTAssertFalse(keptIDs.contains(722), "Gen 7 species (#722) must be pruned until Gen 7 is enabled")
        XCTAssertEqual(keptIDs.count, 8, "Eevee has exactly 8 valid evolutions through Gen 6")
    }

    func testGen6MoveNormalizationUsesGen6VersionGroups() {
        let orasMove = PokemonMoveVersionDTO(
            level_learned_at: 8,
            move_learn_method: NamedRef(name: "level-up", url: nil),
            version_group: NamedRef(name: "omega-ruby-alpha-sapphire", url: nil)
        )
        let bwMove = PokemonMoveVersionDTO(
            level_learned_at: 1,
            move_learn_method: NamedRef(name: "level-up", url: nil),
            version_group: NamedRef(name: "black-2-white-2", url: nil)
        )
        let moves = [
            PokemonMoveDTO(
                move: NamedRef(name: "wood-hammer", url: nil),
                version_group_details: [orasMove]
            ),
            PokemonMoveDTO(
                move: NamedRef(name: "tackle", url: nil),
                version_group_details: [bwMove, orasMove]
            )
        ]

        // When normalizing for Chespin (#650, Gen 6), it should use ORAS moves
        let normalized = PokeAPIClient.normalizedMoves(moves, for: 650)
        XCTAssertEqual(normalized.count, 2)
        XCTAssertEqual(normalized.map(\.name), ["tackle", "wood-hammer"])

        // When normalizing for an older Gen species without ORAS, B2W2 is used
        let gen5Moves = [
            PokemonMoveDTO(
                move: NamedRef(name: "tackle", url: nil),
                version_group_details: [bwMove]
            )
        ]
        let normalizedGen5 = PokeAPIClient.normalizedMoves(gen5Moves, for: 494)
        XCTAssertEqual(normalizedGen5.count, 1)
        XCTAssertEqual(normalizedGen5.first?.name, "tackle")
    }
}
