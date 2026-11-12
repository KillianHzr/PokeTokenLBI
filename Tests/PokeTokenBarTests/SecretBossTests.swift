import XCTest
@testable import PokeTokenBar

/// The secret bosses (the owner, 2026-11-10): one a dungeon, one expedition in a hundred, in the boss's place or after
/// Arceus, kept apart from the dungeons' bosses, their one Secret Egg.
@MainActor
final class SecretBossTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_790_000_000)

    private func graduated(_ id: Int, rarity: Rarity = .common) -> DexEntry {
        var entry = DexEntry(baseID: SpeciesInfo.baseID(of: id), finalID: id, chainOrder: [id], rarity: rarity, caughtAt: now)
        entry.id = "e\(id)"
        return entry
    }

    private var strong: [DexEntry] { [6, 9, 3, 25, 143, 130].map { graduated($0) } }

    private func store(dex: [DexEntry], inventory: [ItemKind: Int] = [:],
                       prepare: (inout CompanionState) -> Void = { _ in }) throws -> CompanionStore {
        var st = CompanionState()
        st.installBaselineSet = true
        st.lastDate = "d"
        st.claimedTodayTokensByProvider = ["test": 0]
        st.dex = dex
        st.active = MonState(baseID: 16, pathIDs: [16, 17, 18], stageIndex: 0, usedAtStage: 0, rarity: .common, totalForms: 3)
        st.inventory = Dictionary(uniqueKeysWithValues: inventory.map { ($0.key.rawValue, $0.value) })
        prepare(&st)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("secret-\(UUID().uuidString).json")
        try JSONEncoder().encode(st).write(to: url)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return CompanionStore(provider: StubProvider(value: EvoLine(baseID: 16, tree: EvoNode(speciesID: 16, children: []),
                                                                    rarity: .common, names: [:])),
                              clock: { self.now }, fileURL: url, rng: SeededRNG(seed: 3), difficulty: 0.1)
    }

    /// Every dungeon of the list has its secret, none of its own bosses (Galarian Articuno is not Articuno), the
    /// challenges and hideouts none.
    func testEachDungeonHasItsSecret() {
        let regular = DungeonID.allCases.filter { !$0.isChallenge && !$0.isHideout }
        for id in regular {
            let secrets = SecretBosses.candidates(id)
            XCTAssertFalse(secrets.isEmpty, "\(id)")
            let bosses = Set(DungeonCatalog.dungeon(id).bosses.map { SecretBosses.key(id, ExpeditionBoss(speciesID: $0, isShiny: false)) })
            XCTAssertTrue(secrets.allSatisfy { !bosses.contains(SecretBosses.key(id, $0)) }, "\(id): a boss of its own")
            XCTAssertTrue(secrets.allSatisfy { SpeciesInfo.lineRarity(of: $0.speciesID) == .legendary }, "\(id): legendary or mythical")
        }
        XCTAssertEqual(SecretBosses.candidates(.powerPlant).map(\.speciesID), [145], "Zapdos, the owner's example")
        XCTAssertEqual(SecretBosses.candidates(.seafoamIslands).first?.form, PokemonForm("galar"))
        XCTAssertEqual(SecretBosses.candidates(.mtCoronet).map(\.speciesID), [480, 481, 482])
        XCTAssertEqual(SecretBosses.candidates(.hallOfOrigin).map(\.speciesID), [483, 484, 487])
        XCTAssertTrue(SecretBosses.candidates(.hallOfOrigin).allSatisfy { $0.form == PokemonForm("origin") })
        for id in [DungeonID.daily, .weekly, .rocketHideout] { XCTAssertTrue(SecretBosses.candidates(id).isEmpty) }
        // None counts for Mt. Coronet's door.
        XCTAssertEqual(DungeonCatalog.bosses(of: DungeonCatalog.bossDungeons(before: .mtCoronet)).count, 28)
    }

    /// One expedition in a hundred, among the secrets not caught yet: caught, one never comes back (the owner,
    /// 2026-11-10), all caught, none; owned, its egg is shiny; the Hall of Origin's comes after Arceus, all three.
    func testOneExpeditionInAHundred() throws {
        let draws = 20_000
        let met = (0..<draws).compactMap { SecretBosses.draw(.viridianForest, seed: UInt64($0), caught: [], owned: { _ in false }) }
        XCTAssertEqual(Double(met.count) / Double(draws), 0.01, accuracy: 0.003)
        XCTAssertTrue(met.allSatisfy { $0.boss.speciesID == 251 && !$0.after && !$0.lootOnly && !$0.boss.isShiny })
        let seed = try XCTUnwrap((0..<UInt64(draws)).first {
            SecretBosses.draw(.mtCoronet, seed: $0, caught: [], owned: { _ in false }) != nil
        })
        let twoCaught: Set<String> = ["mtCoronet:480", "mtCoronet:481"]
        XCTAssertEqual(SecretBosses.draw(.mtCoronet, seed: seed, caught: twoCaught, owned: { _ in false })?.boss.speciesID, 482)
        XCTAssertNil(SecretBosses.draw(.mtCoronet, seed: seed, caught: twoCaught.union(["mtCoronet:482"]), owned: { _ in true }),
                     "all three caught: none comes back")
        XCTAssertNil(SecretBosses.draw(.viridianForest, seed: UInt64(try XCTUnwrap((0..<draws).first {
            SecretBosses.draw(.viridianForest, seed: UInt64($0), caught: [], owned: { _ in false }) != nil
        })), caught: ["viridianForest:251"], owned: { _ in false }), "Celebi caught: Viridian Forest's boss is its own again")
        XCTAssertEqual(SecretBosses.draw(.mtCoronet, seed: seed, caught: [], owned: { _ in true })?.boss.isShiny, true,
                       "owned: its egg is shiny")
        let hall = try XCTUnwrap((0..<UInt64(draws)).lazy.compactMap {
            SecretBosses.draw(.hallOfOrigin, seed: $0, caught: [], owned: { _ in false })
        }.first)
        XCTAssertTrue(hall.after)
        XCTAssertEqual(hall.foes?.count, 3)
        XCTAssertNil(SecretBosses.draw(.daily, seed: seed, caught: [], owned: { _ in false }))
    }

    /// A secret in the boss's place, caught: its Secret Egg, kept apart from the dungeon's bosses (Galarian Articuno
    /// beaten is not Articuno beaten, nor its egg won), the dungeon still won.
    func testASecretInTheBossPlaceIsKeptApart() throws {
        let galar = ExpeditionBoss(speciesID: 144, form: PokemonForm("galar"), isShiny: false)
        let s = try store(dex: strong, inventory: [.masterBall: 1, .legendaryKey: 1]) { st in
            for id in DungeonMedals.dungeons(.t3) { st.dungeons.wins[id.rawValue] = 1 }
        }
        XCTAssertTrue(s.startExpedition(.seafoamIslands, team: strong.map(\.id)))
        s.changeDungeons {
            $0.expedition?.secret = SecretEncounter(boss: galar, foes: nil, after: false, lootOnly: false)
            $0.expedition?.boss = galar
            $0.expedition?.bossReward = nil
            $0.expedition?.log.append(ExpeditionLogEntry(id: 0, floor: 12, date: self.now,
                                                         kind: .bossReached(speciesID: 144, isShiny: false,
                                                                            form: galar.form, secret: true), isRare: true))
            $0.expedition?.phase = .capture(throwsLeft: 3)
        }
        XCTAssertEqual(s.throwAtBoss(.masterBall), true)
        XCTAssertNil(s.expedition)
        let progress = s.dungeonProgress
        XCTAssertTrue(progress.secretsMet.contains("seafoamIslands:144:galar"))
        XCTAssertTrue(progress.secretsCaught.contains("seafoamIslands:144:galar"))
        XCTAssertFalse(progress.beat(144), "not Articuno beaten")
        XCTAssertFalse(progress.bossesReached.contains("seafoamIslands:144"))
        XCTAssertFalse(progress.legendaryEggsWon.contains(144), "Articuno's own egg still to win")
        XCTAssertEqual(s.bossReward(144), .ownEgg)
        XCTAssertEqual(progress.wins(.seafoamIslands), 1)
        let egg = try XCTUnwrap(progress.eggs.first { $0.sourceSpeciesID == 144 })
        XCTAssertEqual(egg.isSecret, true)
        XCTAssertEqual(egg.form, PokemonForm("galar"))
        XCTAssertEqual(progress.lastResult?.secret?.boss, galar)
    }

    /// The Origin trio after Arceus: Arceus caught stays his, the trio fought together, one of them caught with its own
    /// throws, the three met at once.
    func testTheOriginTrioComesAfterArceus() throws {
        let s = try store(dex: strong, inventory: [.masterBall: 2])
        let team = [248, 384, 150, 445, 149, 376].enumerated().compactMap { i, species -> ExpeditionMember? in
            BattlerSpec.make(id: "m\(i)", speciesID: species, level: 100, hpFactor: 40, statFactor: 3)
                .map { ExpeditionMember(entryID: "m\(i)", spec: $0) }
        }
        let context = ExpeditionContext(tier: .t5, shinyDenominator: 64, now: now)
        let arceus = ExpeditionBoss(speciesID: DungeonCatalog.arceusID, isShiny: false)
        var e = ExpeditionEngine.start(dungeon: DungeonCatalog.dungeon(.hallOfOrigin), team: team, rules: [], teamSize: 6, seed: 9,
                                       cost: 1, berries: [:], revives: [:], context: context, boss: arceus)
        let dialga = SecretBosses.trinity[0]
        e.secret = SecretEncounter(boss: dialga, foes: SecretBosses.trinity, after: true, lootOnly: false)
        e.log.append(ExpeditionLogEntry(id: 0, floor: e.floors, date: now, kind: .bossReached(speciesID: 493, isShiny: false),
                                        isRare: true))
        e.phase = .capture(throwsLeft: 3)
        s.changeDungeons { $0.expedition = e }
        XCTAssertEqual(s.throwAtBoss(.masterBall), true, "Arceus first")
        let after = try XCTUnwrap(s.expedition, "the trio waits")
        XCTAssertEqual(after.secret?.fought, true)
        XCTAssertEqual(after.secret?.capturing, true, "won by a team that strong: one of them to catch")
        XCTAssertTrue(after.log.contains { if case .bossReached(483, _, _, true?) = $0.kind { return true }; return false })
        XCTAssertEqual(s.throwAtBoss(.masterBall), true, "Dialga in his Origin Forme")
        XCTAssertNil(s.expedition)
        let progress = s.dungeonProgress
        XCTAssertTrue(progress.legendaryEggsWon.contains(493), "Arceus's egg won")
        XCTAssertFalse(progress.legendaryEggsWon.contains(483), "Dialga's own egg still to win at Mt. Coronet")
        XCTAssertEqual(progress.secretsMet, ["hallOfOrigin:483:origin", "hallOfOrigin:484:origin", "hallOfOrigin:487:origin"])
        XCTAssertEqual(progress.secretsCaught, ["hallOfOrigin:483:origin"])
        XCTAssertTrue(progress.eggs.contains { $0.sourceSpeciesID == 493 && $0.isSecret != true })
        XCTAssertTrue(progress.eggs.contains { $0.sourceSpeciesID == 483 && $0.isSecret == true && $0.form == PokemonForm("origin") })
        XCTAssertEqual(progress.lastResult?.caught, true, "Arceus caught")
        XCTAssertFalse(progress.beat(483), "Mt. Coronet's Dialga still to beat")
    }

    /// The trio caught already: beaten after Arceus for its loot, no throw.
    func testTheTrioCaughtIsBeatenOnly() throws {
        let team = [248, 384, 150, 445, 149, 376].enumerated().compactMap { i, species -> ExpeditionMember? in
            BattlerSpec.make(id: "m\(i)", speciesID: species, level: 100, hpFactor: 40, statFactor: 3)
                .map { ExpeditionMember(entryID: "m\(i)", spec: $0) }
        }
        let context = ExpeditionContext(tier: .t5, shinyDenominator: 64, now: now)
        var e = ExpeditionEngine.start(dungeon: DungeonCatalog.dungeon(.hallOfOrigin), team: team, rules: [], teamSize: 6, seed: 9,
                                       cost: 1, berries: [:], revives: [:], context: context,
                                       boss: ExpeditionBoss(speciesID: DungeonCatalog.arceusID, isShiny: false))
        e.secret = SecretEncounter(boss: SecretBosses.trinity[1], foes: SecretBosses.trinity, after: true, lootOnly: true)
        e.phase = .capture(throwsLeft: 1)
        ExpeditionEngine.endBoss(&e, context: context)
        XCTAssertEqual(e.secret?.fought, true)
        XCTAssertEqual(e.phase, .finished(won: true))
        XCTAssertNotEqual(e.secret?.capturing, true)
    }

    /// No "?" gives a secret away: it shows once met, after the bosses, a silhouette until caught.
    func testTheSlotsHideTheSecretUntilMet() throws {
        let dungeon = DungeonCatalog.dungeon(.viridianForest)
        func slots(_ prepare: (inout CompanionState) -> Void) throws -> [BossSlots.Slot] {
            let s = try store(dex: strong, prepare: prepare)
            return BossSlots(store: s, id: .viridianForest, dungeon: dungeon, size: 30, shownAtMost: 4).slots
        }
        XCTAssertEqual(try slots { _ in }.count, dungeon.bosses.count)
        let seen = try slots { $0.dungeons.secretsMet = ["viridianForest:251"] }
        XCTAssertEqual(seen.count, dungeon.bosses.count + 1)
        guard case .met(251, false, nil)? = seen.last else { return XCTFail("a silhouette: \(String(describing: seen.last))") }
        let caught = try slots {
            $0.dungeons.secretsMet = ["viridianForest:251"]
            $0.dungeons.secretsCaught = ["viridianForest:251"]
        }
        guard case .met(251, true, nil)? = caught.last else { return XCTFail("caught, whole") }
    }
}
