import AppKit
import SwiftUI
import XCTest
@testable import PokeTokenBar

/// The dungeon screens hold in the popover's width in every language (review of 2026-11-04): a row of fixed parts
/// wider than the width it is given pushes the popover wider and cuts its right edge.
@MainActor
final class DungeonLayoutTests: XCTestCase {
    private func store(_ language: AppLanguage, _ prepare: (inout CompanionState) -> Void = { _ in }) throws -> CompanionStore {
        var st = CompanionState()
        st.language = language
        st.installBaselineSet = true
        prepare(&st)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("dungeon-layout-\(UUID().uuidString).json")
        try JSONEncoder().encode(st).write(to: url)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return CompanionStore(provider: StubProvider(value: EvoLine(baseID: 16, tree: EvoNode(speciesID: 16, children: []),
                                                                    rarity: .common, names: [:])),
                              fileURL: url, rng: SeededRNG(seed: 3), difficulty: 0.1)
    }

    /// The width a view takes when offered `width`: more than it when its fixed parts do not fit.
    private func width<V: View>(_ view: V, in width: CGFloat) -> CGFloat {
        NSHostingController(rootView: view).sizeThatFits(in: CGSize(width: width, height: 10_000)).width
    }

    /// Every dungeon open, every boss met: Mt. Coronet's four types in Russian, the Ruins of Alph's bosses by the
    /// hundred, the German entry button beside its keys.
    func testEveryDungeonCardFits() throws {
        let available = PopoverMetrics.scrollContentWidth
        for language in AppLanguage.allCases {
            let s = try store(language) { st in
                st.dex = (1...1025).map { id in
                    DexEntry(baseID: id, finalID: id, chainOrder: [id],
                             rarity: SpeciesGoal.legendaries.contains(id) ? .legendary : .common, caughtAt: nil)
                }
                st.inventory = [ItemKind.treasureMap.rawValue: 1]
                for dungeon in DungeonCatalog.all where !dungeon.id.isChallenge {
                    st.dungeons.wins[dungeon.id.rawValue] = 1
                    // Reached all, beaten one in two: silhouettes and sprites side by side.
                    for (index, boss) in dungeon.bosses.enumerated() {
                        st.dungeons.bossesReached.insert(DungeonProgress.bossKey(dungeon.id, boss))
                        if index % 2 == 0 { st.dungeons.bossesBeaten.insert(DungeonProgress.bossKey(dungeon.id, boss)) }
                    }
                }
            }
            for dungeon in DungeonCatalog.all where !dungeon.id.isChallenge && !dungeon.id.isHideout {
                // Won, so open: Mt. Coronet's door (every boss before it beaten and caught) is not met one boss in two.
                XCTAssertTrue(s.isDungeonOpen(dungeon.id), "\(dungeon.id) open")
                let used = width(DungeonCard(store: s, id: dungeon.id) {}, in: available)
                XCTAssertLessThanOrEqual(used, available + 0.5, "\(language) \(dungeon.id): \(used) pt for \(available)")
            }
        }
    }

    /// Each team's hideout card, holding what it took, in every language.
    func testHideoutCardsFit() throws {
        let available = PopoverMetrics.scrollContentWidth
        for language in AppLanguage.allCases {
            let s = try store(language) { st in
                st.dungeons.stashes = VillainTeam.allCases.map {
                    VillainStash(team: $0, items: [ItemKind.shinyCharm.rawValue: 1, ItemKind.rareCandy.rawValue: 3,
                                                   ItemKind.masterBall.rawValue: 1])
                }
            }
            for team in VillainTeam.allCases {
                XCTAssertTrue(s.isDungeonOpen(team.hideoutID))
                let used = width(HideoutCard(store: s, team: team) {}, in: available)
                XCTAssertLessThanOrEqual(used, available + 0.5, "\(language) \(team): \(used) pt for \(available)")
            }
        }
    }

    /// Mt. Coronet locked, its doors listed, the bosses still to beat and catch counted (never shown: no spoiler).
    func testMtCoronetLockedCardFits() throws {
        let available = PopoverMetrics.scrollContentWidth
        for language in AppLanguage.allCases {
            let s = try store(language) { st in
                for id in DungeonMedals.dungeons(.t1) + DungeonMedals.dungeons(.t2) { st.dungeons.wins[id.rawValue] = 1 }
            }
            XCTAssertGreaterThan(s.bossesLeft(DungeonCatalog.bossDungeons(before: .mtCoronet)).count, 10)
            XCTAssertFalse(s.isDungeonOpen(.mtCoronet))
            let used = width(DungeonCard(store: s, id: .mtCoronet) {}, in: available)
            XCTAssertLessThanOrEqual(used, available + 0.5, "\(language): \(used) pt for \(available)")
        }
    }

    /// Tatsugiri's three Megas named by their own form ("Mega (Curly Form)") do not fit on one line beside "Usual".
    func testTheBattleFormChooserFits() throws {
        let available = PopoverMetrics.contentWidth
        for language in AppLanguage.allCases {
            for species in [978, 892, 849] {
                var entry = DexEntry(baseID: species, finalID: species, chainOrder: [species], rarity: .common, caughtAt: nil)
                entry.id = "e\(species)"
                let s = try store(language) { st in
                    st.dex = [entry]
                    st.dungeons.battleForms = Set(BattleForms.forms(speciesID: species).map(\.key))
                }
                let used = width(BattleFormChooser(store: s, entry: entry), in: available)
                XCTAssertLessThanOrEqual(used, available + 0.5, "\(language) #\(species): \(used) pt for \(available)")
            }
        }
    }

    /// The expedition under way on Home, paused for its heal, in the longest dungeon names.
    func testAnExpeditionCardFits() throws {
        let available = PopoverMetrics.scrollContentWidth
        for language in AppLanguage.allCases {
            for id in [DungeonID.mtCoronet, .ceruleanCave, .seafoamIslands, .ruinsOfAlph, .hallOfOrigin, .dragonsDen] {
                let dungeon = DungeonCatalog.dungeon(id)
                let team: [ExpeditionMember] = [248, 635, 94, 445, 373, 130].compactMap { species in
                    var entry = DexEntry(baseID: species, finalID: species, chainOrder: [species], rarity: .common, caughtAt: nil)
                    entry.id = "e\(species)"
                    entry.profile = PokemonProfile.generate(seed: UInt64(species))
                    return DungeonTeamBuilder.spec(for: entry, theme: dungeon.themeTypes).map { ExpeditionMember(entryID: entry.id, spec: $0) }
                }
                let context = ExpeditionContext(tier: dungeon.tier, shinyDenominator: 64, now: Date())
                for paused in [false, true] {
                    var e = ExpeditionEngine.start(dungeon: dungeon, team: team, rules: dungeon.rules, teamSize: 6, seed: 7,
                                                   cost: 600_000_000, berries: [:], revives: [:], context: context)
                    e.floor = e.floors
                    if paused { e.phase = .awaitingHeal(price: 12) }
                    for index in e.team.indices.prefix(2) { e.team[index].spec.hp = 0 }
                    let s = try store(language) { $0.dungeons.expedition = e }
                    let used = width(ExpeditionCard(store: s, nav: PopoverNavigation()), in: available)
                    XCTAssertLessThanOrEqual(used, available + 0.5, "\(language) \(id) paused=\(paused): \(used) pt for \(available)")
                }
            }
        }
    }
}
