import XCTest
@testable import PokeTokenBar

final class Gen9PaldeaTests: XCTestCase {
    func testAnimatedSpeciesIDsCoversGen9() {
        XCTAssertEqual(PokemonAssets.animatedSpeciesIDs.lowerBound, 1)
        XCTAssertEqual(PokemonAssets.animatedSpeciesIDs.upperBound, 1025)
        XCTAssertTrue(PokemonAssets.hasAnimatedSprite(speciesID: 906), "Sprigatito is in Gen 9")
        XCTAssertTrue(PokemonAssets.hasAnimatedSprite(speciesID: 909), "Fuecoco is in Gen 9")
        XCTAssertTrue(PokemonAssets.hasAnimatedSprite(speciesID: 912), "Quaxly is in Gen 9")
        XCTAssertTrue(PokemonAssets.hasAnimatedSprite(speciesID: 1007), "Koraidon is in Gen 9")
        XCTAssertTrue(PokemonAssets.hasAnimatedSprite(speciesID: 1008), "Miraidon is in Gen 9")
        XCTAssertTrue(PokemonAssets.hasAnimatedSprite(speciesID: 1017), "Ogerpon is in Gen 9 (DLC)")
        XCTAssertTrue(PokemonAssets.hasAnimatedSprite(speciesID: 1024), "Terapagos is in Gen 9 (DLC)")
        XCTAssertTrue(PokemonAssets.hasAnimatedSprite(speciesID: 1025), "Pecharunt is the final Gen 9 Pokémon")
        XCTAssertFalse(PokemonAssets.hasAnimatedSprite(speciesID: 1026), "Beyond Gen 9 bound is not supported")
    }

    func testGen9AndPaldeanSpriteURLsRouteCorrectly() {
        // Gen 9 animated sprite -> Showdown
        let sprigatitoAnimated = SpriteStore.spriteURL(speciesID: 906, animated: true, shiny: false)
        XCTAssertEqual(
            sprigatitoAnimated.absoluteString,
            "https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/showdown/906.gif"
        )

        // Gen 9 static PNG -> standard pokemon PNG
        let sprigatitoStatic = SpriteStore.spriteURL(speciesID: 906, animated: false, shiny: false)
        XCTAssertEqual(
            sprigatitoStatic.absoluteString,
            "https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/906.png"
        )

        // Paldean Tauros (Combat Breed) -> Showdown variety 10250
        let taurosCombatAnimated = SpriteStore.spriteURL(
            speciesID: 128,
            animated: true,
            shiny: false,
            form: PokemonForm("paldea-combat")
        )
        XCTAssertEqual(
            taurosCombatAnimated.absoluteString,
            "https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/showdown/10250.gif"
        )

        // Paldean Wooper -> Showdown variety 10253
        let wooperPaldeaAnimated = SpriteStore.spriteURL(
            speciesID: 194,
            animated: true,
            shiny: false,
            form: PokemonForm("paldea")
        )
        XCTAssertEqual(
            wooperPaldeaAnimated.absoluteString,
            "https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/showdown/10253.gif"
        )
    }

    func testGen9FormsCatalog() {
        // Paldean Tauros (#128) - 4 breeds
        let taurosForms = PokemonForm.forms(speciesID: 128)
        XCTAssertEqual(taurosForms.map(\.rawValue), ["normal", "paldea-combat", "paldea-blaze", "paldea-aqua"])

        // Paldean Wooper (#194)
        let wooperForms = PokemonForm.forms(speciesID: 194)
        XCTAssertEqual(wooperForms.map(\.rawValue), ["normal", "paldea"])

        // Squawkabilly (#931) - 4 plumages
        let squawkabillyForms = PokemonForm.forms(speciesID: 931)
        XCTAssertEqual(squawkabillyForms.map(\.rawValue), ["green", "blue", "yellow", "white"])

        // Palafin (#964) - Zero & Hero
        let palafinForms = PokemonForm.forms(speciesID: 964)
        XCTAssertEqual(palafinForms.map(\.rawValue), ["zero", "hero"])

        // Tatsugiri (#978) - 3 forms
        let tatsugiriForms = PokemonForm.forms(speciesID: 978)
        XCTAssertEqual(tatsugiriForms.map(\.rawValue), ["curly", "droopy", "stretchy"])

        // Dudunsparce (#982) - Two & Three segments
        let dudunsparceForms = PokemonForm.forms(speciesID: 982)
        XCTAssertEqual(dudunsparceForms.map(\.rawValue), ["two-segment", "three-segment"])

        // Gimmighoul (#999) - Chest & Roaming
        let gimmighoulForms = PokemonForm.forms(speciesID: 999)
        XCTAssertEqual(gimmighoulForms.map(\.rawValue), ["chest", "roaming"])

        // Poltchageist (#1012) & Sinistcha (#1013)
        XCTAssertEqual(PokemonForm.forms(speciesID: 1012).map(\.rawValue), ["counterfeit", "artisan"])
        XCTAssertEqual(PokemonForm.forms(speciesID: 1013).map(\.rawValue), ["unremarkable", "masterpiece"])

        // Ogerpon (#1017) - 4 masks
        let ogerponForms = PokemonForm.forms(speciesID: 1017)
        XCTAssertEqual(ogerponForms.map(\.rawValue), ["teal", "wellspring", "hearthflame", "cornerstone"])

        // Terapagos (#1024) - 3 forms
        let terapagosForms = PokemonForm.forms(speciesID: 1024)
        XCTAssertEqual(terapagosForms.map(\.rawValue), ["normal", "terastal", "stellar"])
    }

    func testGen9MoveNormalization() {
        let svMove = PokemonMoveVersionDTO(
            level_learned_at: 1,
            move_learn_method: NamedRef(name: "level-up", url: nil),
            version_group: NamedRef(name: "scarlet-violet", url: nil)
        )
        let moves = [
            PokemonMoveDTO(
                move: NamedRef(name: "leafage", url: nil),
                version_group_details: [svMove]
            )
        ]

        let normalized = PokeAPIClient.normalizedMoves(moves, for: 906)
        XCTAssertEqual(normalized.count, 1)
        XCTAssertEqual(normalized.first?.name, "leafage")
    }

    func testStaticSpriteFallbackForSpeciesWithoutShowdownGifs() {
        // Terapagos (#1024) and Pecharunt (#1025) are valid species
        XCTAssertTrue(PokemonAssets.hasAnimatedSprite(speciesID: 1024))
        XCTAssertTrue(PokemonAssets.hasAnimatedSprite(speciesID: 1025))

        // Static sprite URLs resolve to standard PNGs
        let terapagosStatic = SpriteStore.spriteURL(speciesID: 1024, animated: false, shiny: false)
        XCTAssertEqual(
            terapagosStatic.absoluteString,
            "https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/1024.png"
        )
        let pecharuntStatic = SpriteStore.spriteURL(speciesID: 1025, animated: false, shiny: false)
        XCTAssertEqual(
            pecharuntStatic.absoluteString,
            "https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/1025.png"
        )
    }
}
