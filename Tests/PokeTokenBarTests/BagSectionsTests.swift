import XCTest
@testable import PokeTokenBar

/// The Bag by the Shop's sections (the owner, 2026-11-09: the balls and eggs were mixed, the Legendary Egg among the
/// artifacts), the stones with the eggs, the Legendary Egg under the Rare one; a recap shows the exceptional finds apart.
@MainActor
final class BagSectionsTests: XCTestCase {
    func testEachItemHasItsSection() {
        for egg: ItemKind in [.pokemonEgg, .uncommonEgg, .rareEgg, .legendaryEgg, .fossilEgg, .typeNullEgg, .birthdayEgg] {
            XCTAssertEqual(CompanionStore.bagSection(of: egg), .eggs, "\(egg)")
        }
        XCTAssertEqual(CompanionStore.bagSection(of: .fireStone), .eggs, "a stone trades the Pokémon for an egg too")
        for item: ItemKind in [.greatBall, .ultraBall, .masterBall, .oranBerry, .revive, .goldCapsule, .legendaryKey] {
            XCTAssertEqual(CompanionStore.bagSection(of: item), .dungeons, "\(item)")
        }
        XCTAssertEqual(CompanionStore.bagSection(of: .rareCandy), .raising)
        XCTAssertEqual(CompanionStore.bagSection(of: .shinyCharm), .keptForGood)
    }

    /// The Legendary Egg and Type: Null's are items to use, no longer filed with the artifacts; badges and artifacts
    /// keep their tabs.
    func testEggsAreItemsNotArtifacts() {
        XCTAssertEqual(BagView.Section.of(.legendaryEgg), .items)
        XCTAssertEqual(BagView.Section.of(.typeNullEgg), .items)
        XCTAssertEqual(BagView.Section.of(.boulderBadge), .badges)
        XCTAssertEqual(BagView.Section.of(.rainbowWing), .artifacts)
    }

    /// The Rare Candies first (the owner, 2026-11-09 evening), then the Shop's sections; among the eggs its three by
    /// rarity, the Legendary Egg under the Rare one, the other eggs, the stones last.
    func testTheItemsTabFollowsTheShop() {
        let held: [(kind: ItemKind, count: Int)] = [(.fireStone, 1), (.greatBall, 2), (.legendaryEgg, 1), (.rareCandy, 3),
                                                     (.fossilEgg, 1), (.rareEgg, 2), (.pokemonEgg, 1), (.oranBerry, 4)]
        let sections = BagView.itemSections(held, dungeonEggs: false)
        XCTAssertEqual(sections.map(\.section), [.raising, .eggs, .dungeons])
        XCTAssertEqual(sections[0].items.map(\.kind), [.rareCandy])
        XCTAssertEqual(sections[1].items.map(\.kind), [.pokemonEgg, .rareEgg, .legendaryEgg, .fossilEgg, .fireStone])
        XCTAssertEqual(sections[2].items.map(\.kind), [.greatBall, .oranBerry])
        XCTAssertEqual(BagView.itemSections([(.rareCandy, 1)], dungeonEggs: true).map(\.section), [.raising, .eggs],
                       "the eggs' section for the dungeon eggs alone")
    }

    /// A recap shows a Legendary Egg and a Master Ball apart, the rest in the Bag's order.
    func testARecapShowsTheExceptionalFindsApart() {
        var loot = ExpeditionLoot(candies: 2)
        for item: ItemKind in [.oranBerry, .goldCapsule, .legendaryEgg, .rareEgg, .masterBall, .revive] { loot.add(item) }
        let (finds, rest) = ExpeditionResultCard.lootItems(loot)
        XCTAssertEqual(finds.map(\.0), [.legendaryEgg, .masterBall])
        XCTAssertEqual(rest.map(\.0), [.rareEgg, .oranBerry, .revive, .goldCapsule])
    }
}
