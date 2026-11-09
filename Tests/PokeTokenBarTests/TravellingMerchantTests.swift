import XCTest
@testable import PokeTokenBar

/// The travelling merchant (the owner, 2026-11-05 and 2026-11-09): one day in five, one ware drawn among all he buys,
/// a third of the Shop's price, the owner's figures for the rest; never a Fossil Egg.
@MainActor
final class TravellingMerchantTests: XCTestCase {
    private final class Clock: @unchecked Sendable { var date = Date() }

    private func day(_ offset: Int) -> String {
        let date = Date(timeIntervalSince1970: 1_800_000_000 + Double(offset) * 86_400)
        let c = Calendar(identifier: .iso8601).dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    /// About one day in five over ten years, every ware some day, the ten stones together about as often as one ware.
    func testHeComesOneDayInFiveWithEveryWare() {
        var visits = 0, stones = 0
        var seen: Set<ItemKind> = []
        for offset in 0..<3650 {
            guard let ware = TravellingMerchant.ware(on: day(offset)) else { continue }
            visits += 1
            seen.insert(ware)
            if ware.stoneType != nil { stones += 1 }
        }
        XCTAssertEqual(Double(visits) / 3650, 0.20, accuracy: 0.03)
        XCTAssertTrue(Set(TravellingMerchant.wares).isSubset(of: seen), "every ware comes some day")
        XCTAssertEqual(Double(stones) / Double(visits), 1.0 / Double(TravellingMerchant.wares.count + 1), accuracy: 0.03,
                       "the stones share one draw")
        XCTAssertEqual(TravellingMerchant.ware(on: "2026-11-09"), TravellingMerchant.ware(on: "2026-11-09"), "the same all day")
    }

    /// The owner's prices at the players' difficulty (10%): a third of the Shop's, and his figures for the rest.
    func testWhatHePays() {
        func paid(_ kind: ItemKind) -> Int? { TravellingMerchant.buyBackBase(kind).map { PokemonBalance.scaled($0) } }
        let expected: [(ItemKind, Int)] = [
            (.rareCandy, 16_666_667), (.pokemonEgg, 33_333_333), (.uncommonEgg, 83_333_333), (.rareEgg, 133_333_333),
            (.greatBall, 83_333_333), (.ultraBall, 133_333_333), (.legendaryEgg, 1_000_000_000), (.masterBall, 400_000_000),
            (.legendaryKey, 200_000_000), (.treasureMap, 200_000_000), (.oranBerry, 5_000_000), (.sitrusBerry, 15_000_000),
            (.revive, 10_000_000), (.maxRevive, 30_000_000), (.silverCapsule, 50_000_000), (.goldCapsule, 150_000_000),
            (.explorerChest, 28_000_000), (.fireStone, 25_000_000), (.shinyStone, 25_000_000),
        ]
        for (kind, price) in expected { XCTAssertEqual(paid(kind), price, "\(kind)") }
        XCTAssertEqual(TravellingMerchant.stones.count, 10)
        XCTAssertTrue(TravellingMerchant.sellable.allSatisfy { TravellingMerchant.buyBackBase($0) != nil })
        XCTAssertEqual(Set(TravellingMerchant.sellable).count, TravellingMerchant.sellable.count)
    }

    /// Buying to sell back never pays: with the Rainbow Wing and the Jade Orb an egg still costs 0.6 of its price.
    func testSellingBackNeverPays() {
        for kind in TravellingMerchant.sellable {
            guard let shop = TravellingMerchant.shopBase(kind) else { continue }
            XCTAssertLessThan(Double(TravellingMerchant.buyBackBase(kind) ?? .max), Double(shop) * 0.75 * 0.8, "\(kind)")
        }
    }

    /// Never a Fossil Egg (one per fossil line missing), an artifact, a badge, a medal or an event egg.
    func testWhatHeNeverBuys() {
        XCTAssertNil(TravellingMerchant.buyBackBase(.fossilEgg))
        for kind in ItemKind.allCases where !TravellingMerchant.sellable.contains(kind) {
            XCTAssertNil(TravellingMerchant.buyBackBase(kind), "\(kind)")
        }
        XCTAssertFalse(TravellingMerchant.sellable.contains { $0.isPassive || $0.badgeType != nil || $0 == .birthdayEgg })
        XCTAssertNil(TravellingMerchant.portraitURLs.keys.first { !$0.hasPrefix("merchant-") })
    }

    private func store(clock: Clock, inventory: [ItemKind: Int], used: Int = 1_000) throws -> CompanionStore {
        var st = CompanionState()
        st.installBaselineSet = true
        st.lastDate = "d"
        st.claimedTodayTokensByProvider = ["test": 0]
        st.usedSinceInstall = used
        st.active = MonState(baseID: 16, pathIDs: [16, 17, 18], stageIndex: 0, usedAtStage: 0, rarity: .common, totalForms: 3)
        st.inventory = Dictionary(uniqueKeysWithValues: inventory.map { ($0.key.rawValue, $0.value) })
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("merchant-\(UUID().uuidString).json")
        try JSONEncoder().encode(st).write(to: url)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return CompanionStore(provider: StubProvider(value: EvoLine(baseID: 16, tree: EvoNode(speciesID: 16, children: []),
                                                                    rarity: .common, names: [:])),
                              clock: { clock.date }, fileURL: url, rng: SeededRNG(seed: 3), difficulty: 0.1)
    }

    /// The first day from 2026-11-09 the merchant brings `ware` (or any ware), and one he stays away.
    private func date(bringing ware: ItemKind?) -> Date {
        let start = Date(timeIntervalSince1970: 1_793_000_000)
        for offset in 0..<5000 {
            let date = start.addingTimeInterval(Double(offset) * 86_400)
            let c = Calendar(identifier: .iso8601).dateComponents([.year, .month, .day], from: date)
            let key = String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
            let drawn = TravellingMerchant.ware(on: key)
            if let ware, drawn == ware { return date }
            if ware == nil, drawn == nil { return date }
        }
        return start
    }

    /// Sold: they leave the Bag, their price goes to the wallet, kept by the save; never more than the Bag holds, never
    /// another ware, nothing the days he stays away.
    func testSellingFillsTheWallet() throws {
        let clock = Clock()
        clock.date = date(bringing: .rareCandy)
        let s = try store(clock: clock, inventory: [.rareCandy: 3, .rareEgg: 1])
        XCTAssertEqual(s.merchantWare, .rareCandy)
        let price = try XCTUnwrap(s.merchantPrice(of: .rareCandy))
        XCTAssertEqual(price, 16_666_667)
        let wallet = s.availableTokens
        XCTAssertFalse(s.sellToMerchant(4), "more than the Bag holds")
        XCTAssertTrue(s.sellToMerchant(1))
        XCTAssertEqual(s.itemCount(.rareCandy), 2)
        XCTAssertEqual(s.availableTokens, wallet + price)
        XCTAssertTrue(s.sellToMerchant(2))
        XCTAssertEqual(s.itemCount(.rareCandy), 0)
        XCTAssertEqual(s.availableTokens, wallet + 3 * price)
        XCTAssertFalse(s.sellToMerchant(1), "none left")
        XCTAssertEqual(s.itemCount(.rareEgg), 1, "only today's ware")
        XCTAssertEqual(s.state.merchantTokens, 3 * price, "growth untouched, the wallet only")
        clock.date = date(bringing: nil)
        XCTAssertNil(s.merchantWare)
        XCTAssertFalse(s.sellToMerchant(1))
        // Kept by the save and its import.
        let data = try JSONEncoder().encode(s.state)
        let decoded = try JSONDecoder().decode(CompanionState.self, from: data)
        XCTAssertEqual(decoded.merchantTokens, 3 * price)
        XCTAssertEqual(SaveTransfer.sanitized(decoded).merchantTokens, 3 * price)
    }

    /// A save from before the merchant has no `merchantTokens`: none.
    func testASaveFromBeforeHasNoMerchantTokens() throws {
        var json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(CompanionState())) as? [String: Any] ?? [:]
        json.removeValue(forKey: "merchantTokens")
        let state = try JSONDecoder().decode(CompanionState.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertEqual(state.merchantTokens, 0)
    }
}
