import XCTest
@testable import PokeTokenBar

final class Gen8GalarTests: XCTestCase {
    func testAnimatedSpeciesIDsCoversGen8() {
        XCTAssertEqual(PokemonAssets.animatedSpeciesIDs.lowerBound, 1)
        XCTAssertEqual(PokemonAssets.animatedSpeciesIDs.upperBound, 905)
        XCTAssertTrue(PokemonAssets.hasAnimatedSprite(speciesID: 810), "Grookey is in Gen 8")
        XCTAssertTrue(PokemonAssets.hasAnimatedSprite(speciesID: 813), "Scorbunny is in Gen 8")
        XCTAssertTrue(PokemonAssets.hasAnimatedSprite(speciesID: 816), "Sobble is in Gen 8")
        XCTAssertTrue(PokemonAssets.hasAnimatedSprite(speciesID: 888), "Zacian is in Gen 8")
        XCTAssertTrue(PokemonAssets.hasAnimatedSprite(speciesID: 892), "Urshifu is in Gen 8")
        XCTAssertTrue(PokemonAssets.hasAnimatedSprite(speciesID: 898), "Calyrex is in Gen 8")
        XCTAssertTrue(PokemonAssets.hasAnimatedSprite(speciesID: 902), "Basculegion is in Gen 8")
        XCTAssertTrue(PokemonAssets.hasAnimatedSprite(speciesID: 905), "Enamorus is in Gen 8 (Hisui)")
        XCTAssertFalse(PokemonAssets.hasAnimatedSprite(speciesID: 906), "Sprigatito (Gen 9) is not in Gen 8")
    }

    func testGen8AndRegionalSpriteURLsRouteCorrectly() {
        // Gen 8 animated sprite -> Showdown
        let grookeyAnimated = SpriteStore.spriteURL(speciesID: 810, animated: true, shiny: false)
        XCTAssertEqual(
            grookeyAnimated.absoluteString,
            "https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/showdown/810.gif"
        )

        // Gen 8 static PNG -> standard pokemon PNG
        let grookeyStatic = SpriteStore.spriteURL(speciesID: 810, animated: false, shiny: false)
        XCTAssertEqual(
            grookeyStatic.absoluteString,
            "https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/810.png"
        )

        // Galarian regional form on Gen 1 species -> variety ID in Showdown
        let galarPonytaAnimated = SpriteStore.spriteURL(
            speciesID: 77,
            animated: true,
            shiny: false,
            form: PokemonForm("galar")
        )
        XCTAssertEqual(
            galarPonytaAnimated.absoluteString,
            "https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/showdown/10162.gif"
        )

        // Hisuian regional form on Gen 2 species -> variety ID in Showdown
        let hisuiTyphlosionAnimated = SpriteStore.spriteURL(
            speciesID: 157,
            animated: true,
            shiny: false,
            form: PokemonForm("hisui")
        )
        XCTAssertEqual(
            hisuiTyphlosionAnimated.absoluteString,
            "https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/showdown/10233.gif"
        )
    }

    func testGen8FormsCatalog() {
        // Cramorant (#845)
        let cramorantForms = PokemonForm.forms(speciesID: 845)
        XCTAssertEqual(cramorantForms.map(\.rawValue), ["normal", "gulping", "gorging"])

        // Toxtricity (#849)
        let toxtricityForms = PokemonForm.forms(speciesID: 849)
        XCTAssertEqual(toxtricityForms.map(\.rawValue), ["amped", "low-key"])

        // Eiscue (#875)
        let eiscueForms = PokemonForm.forms(speciesID: 875)
        XCTAssertEqual(eiscueForms.map(\.rawValue), ["ice", "noice"])

        // Morpeko (#877)
        let morpekoForms = PokemonForm.forms(speciesID: 877)
        XCTAssertEqual(morpekoForms.map(\.rawValue), ["full-belly", "hangry"])

        // Zacian (#888) & Zamazenta (#889)
        XCTAssertEqual(PokemonForm.forms(speciesID: 888).map(\.rawValue), ["hero", "crowned"])
        XCTAssertEqual(PokemonForm.forms(speciesID: 889).map(\.rawValue), ["hero", "crowned"])

        // Urshifu (#892)
        XCTAssertEqual(PokemonForm.forms(speciesID: 892).map(\.rawValue), ["single-strike", "rapid-strike"])

        // Calyrex (#898)
        XCTAssertEqual(PokemonForm.forms(speciesID: 898).map(\.rawValue), ["normal", "ice", "shadow"])

        // Basculegion (#902) & Enamorus (#905)
        XCTAssertEqual(PokemonForm.forms(speciesID: 902).map(\.rawValue), ["male", "female"])
        XCTAssertEqual(PokemonForm.forms(speciesID: 905).map(\.rawValue), ["incarnate", "therian"])
    }

    func testRegionalEvolutionLineContinuity() {
        // Galarian Ponyta (#77) -> Rapidash (#78)
        XCTAssertEqual(PokemonForm.formSpecies(baseID: 77), [77, 78])
        XCTAssertEqual(
            PokemonForm.resolved(speciesID: 78, form: PokemonForm("galar")),
            PokemonForm("galar")
        )

        // Galarian Slowpoke (#79) -> Slowbro (#80) & Slowking (#199)
        XCTAssertEqual(PokemonForm.formSpecies(baseID: 79), [79, 80, 199])
        XCTAssertEqual(
            PokemonForm.resolved(speciesID: 199, form: PokemonForm("galar")),
            PokemonForm("galar")
        )

        // Galarian Zigzagoon (#263) -> Linoone (#264)
        XCTAssertEqual(PokemonForm.formSpecies(baseID: 263), [263, 264])

        // Hisuian Growlithe (#58) -> Arcanine (#59)
        XCTAssertEqual(PokemonForm.formSpecies(baseID: 58), [58, 59])
        XCTAssertEqual(
            PokemonForm.resolved(speciesID: 59, form: PokemonForm("hisui")),
            PokemonForm("hisui")
        )

        // Hisuian Voltorb (#100) -> Electrode (#101)
        XCTAssertEqual(PokemonForm.formSpecies(baseID: 100), [100, 101])

        // Hisuian Zorua (#570) -> Zoroark (#571)
        XCTAssertEqual(PokemonForm.formSpecies(baseID: 570), [570, 571])
        XCTAssertEqual(
            PokemonForm.resolved(speciesID: 571, form: PokemonForm("hisui")),
            PokemonForm("hisui")
        )
    }

    func testGen8MoveNormalization() {
        let swshMove = PokemonMoveVersionDTO(
            level_learned_at: 1,
            move_learn_method: NamedRef(name: "level-up", url: nil),
            version_group: NamedRef(name: "sword-shield", url: nil)
        )
        let moves = [
            PokemonMoveDTO(
                move: NamedRef(name: "branch-poke", url: nil),
                version_group_details: [swshMove]
            )
        ]

        let normalized = PokeAPIClient.normalizedMoves(moves, for: 810)
        XCTAssertEqual(normalized.count, 1)
        XCTAssertEqual(normalized.first?.name, "branch-poke")
    }
}
