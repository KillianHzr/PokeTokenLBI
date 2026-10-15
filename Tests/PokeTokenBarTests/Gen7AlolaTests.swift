import XCTest
@testable import PokeTokenBar

final class Gen7AlolaTests: XCTestCase {
    func testAnimatedSpeciesIDsCoversGen7() {
        XCTAssertEqual(PokemonAssets.animatedSpeciesIDs.lowerBound, 1)
        XCTAssertGreaterThanOrEqual(PokemonAssets.animatedSpeciesIDs.upperBound, 809)
        XCTAssertTrue(PokemonAssets.hasAnimatedSprite(speciesID: 722), "Rowlet is in Gen 7")
        XCTAssertTrue(PokemonAssets.hasAnimatedSprite(speciesID: 741), "Oricorio is in Gen 7")
        XCTAssertTrue(PokemonAssets.hasAnimatedSprite(speciesID: 745), "Lycanroc is in Gen 7")
        XCTAssertTrue(PokemonAssets.hasAnimatedSprite(speciesID: 778), "Mimikyu is in Gen 7")
        XCTAssertTrue(PokemonAssets.hasAnimatedSprite(speciesID: 800), "Necrozma is in Gen 7")
        XCTAssertTrue(PokemonAssets.hasAnimatedSprite(speciesID: 809), "Melmetal is in Gen 7")
    }

    func testGen7AndAlolanSpriteURLsRouteCorrectly() {
        // Gen 7 animated sprite -> Showdown
        let rowletAnimated = SpriteStore.spriteURL(speciesID: 722, animated: true, shiny: false)
        XCTAssertEqual(
            rowletAnimated.absoluteString,
            "https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/showdown/722.gif"
        )

        // Gen 7 static PNG -> standard pokemon PNG
        let rowletStatic = SpriteStore.spriteURL(speciesID: 722, animated: false, shiny: false)
        XCTAssertEqual(
            rowletStatic.absoluteString,
            "https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/722.png"
        )

        // Alolan regional form on Gen 1 species -> variety ID in Showdown
        let alolanVulpixAnimated = SpriteStore.spriteURL(
            speciesID: 37,
            animated: true,
            shiny: false,
            form: PokemonForm("alola")
        )
        XCTAssertEqual(
            alolanVulpixAnimated.absoluteString,
            "https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/showdown/10103.gif"
        )

        // Alolan regional static PNG -> variety ID PNG
        let alolanVulpixStatic = SpriteStore.spriteURL(
            speciesID: 37,
            animated: false,
            shiny: false,
            form: PokemonForm("alola")
        )
        XCTAssertEqual(
            alolanVulpixStatic.absoluteString,
            "https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/10103.png"
        )

        // Standard Gen 1 animated sprite stays in Gen-V Black/White animated
        let regularVulpixAnimated = SpriteStore.spriteURL(speciesID: 37, animated: true, shiny: false)
        XCTAssertEqual(
            regularVulpixAnimated.absoluteString,
            "https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/versions/generation-v/black-white/animated/37.gif"
        )
    }

    func testGen7FormsCatalog() {
        // Oricorio (#741) - 4 styles
        let oricorioForms = PokemonForm.forms(speciesID: 741)
        XCTAssertEqual(oricorioForms.count, 4)
        XCTAssertEqual(oricorioForms.map(\.rawValue), ["baile", "pom-pom", "pau", "sensu"])

        // Lycanroc (#745) - 3 forms
        let lycanrocForms = PokemonForm.forms(speciesID: 745)
        XCTAssertEqual(lycanrocForms.count, 3)
        XCTAssertEqual(lycanrocForms.map(\.rawValue), ["midday", "midnight", "dusk"])
        XCTAssertEqual(
            PokemonForm.staticAssetName(speciesID: 745, form: PokemonForm("dusk")),
            "10152"
        )

        // Wishiwashi (#746) - Solo & School
        let wishiwashiForms = PokemonForm.forms(speciesID: 746)
        XCTAssertEqual(wishiwashiForms.map(\.rawValue), ["solo", "school"])

        // Silvally (#773) - 18 types
        let silvallyForms = PokemonForm.forms(speciesID: 773)
        XCTAssertEqual(silvallyForms.count, 18)
        XCTAssertEqual(silvallyForms.first?.rawValue, "normal")
        XCTAssertTrue(silvallyForms.contains(PokemonForm("fairy")))

        // Minior (#774) - Meteor + 7 cores
        let miniorForms = PokemonForm.forms(speciesID: 774)
        XCTAssertEqual(miniorForms.count, 8)
        XCTAssertEqual(miniorForms.first?.rawValue, "meteor")

        // Mimikyu (#778) - Disguised & Busted
        let mimikyuForms = PokemonForm.forms(speciesID: 778)
        XCTAssertEqual(mimikyuForms.map(\.rawValue), ["disguised", "busted"])

        // Alolan evolution line continuity: Vulpix (#37) -> Ninetales (#38)
        XCTAssertEqual(PokemonForm.formSpecies(baseID: 37), [37, 38])
        XCTAssertEqual(
            PokemonForm.resolved(speciesID: 38, form: PokemonForm("alola")),
            PokemonForm("alola")
        )

        // Alolan evolution line continuity: Geodude (#74) -> Graveler (#75) -> Golem (#76)
        XCTAssertEqual(PokemonForm.formSpecies(baseID: 74), [74, 75, 76])
    }

    func testGen7MoveNormalization() {
        let usumMove = PokemonMoveVersionDTO(
            level_learned_at: 1,
            move_learn_method: NamedRef(name: "level-up", url: nil),
            version_group: NamedRef(name: "ultra-sun-ultra-moon", url: nil)
        )
        let moves = [
            PokemonMoveDTO(
                move: NamedRef(name: "leafage", url: nil),
                version_group_details: [usumMove]
            )
        ]

        let normalized = PokeAPIClient.normalizedMoves(moves, for: 722)
        XCTAssertEqual(normalized.count, 1)
        XCTAssertEqual(normalized.first?.name, "leafage")
    }
}
