import XCTest
@testable import PokeTokenBar

/// A goal of the Pokémon raised, clicked on Home, opens its achievement in its section.
@MainActor
final class AchievementNavigationTests: XCTestCase {
    func testAGoalOpensItsAchievementInItsSection() {
        let nav = PopoverNavigation()
        nav.showSettings = true
        nav.openAchievement(.oldSeaMap)
        XCTAssertEqual(nav.tab, .achievements)
        XCTAssertEqual(nav.achievementFocus, .oldSeaMap)
        XCTAssertFalse(nav.showSettings)
        XCTAssertEqual(AchievementsView.category(of: .oldSeaMap), .legendaryArtifacts)
        XCTAssertEqual(AchievementsView.category(of: .fireStone), .evolutionStones)
        XCTAssertEqual(AchievementsView.category(of: .boulderBadge), .gymBadges)
        XCTAssertEqual(AchievementsView.category(of: .unownLetters), .forms)
    }
}
