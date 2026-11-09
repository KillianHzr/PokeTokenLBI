import Foundation

/// The travelling merchant (the owner's idea of 2026-11-05, built on 2026-11-09): every day one comes to the Shop and
/// buys back one kind of item, as many as the player wants to sell, then leaves at midnight, never the one of the day
/// before (the owner: one day in five was too rare for one ware each). The same day brings the same merchant to every
/// player, as the daily dungeon's boss.
///
/// He pays a third of what the Shop asks for what it sells: with the Rainbow Wing (-25%) and the Jade Orb (-20% on eggs)
/// an egg still costs 0.6 of its price, so buying to sell back never pays. What the Shop does not sell has the owner's
/// figures (2026-11-09). He never buys a Fossil Egg (one per fossil line missing), an artifact, a badge or a medal.
enum TravellingMerchant {
    /// The evolution stones share one draw and one merchant: ten draws of their own would bring them one day in three.
    static let stones: [ItemKind] = ItemKind.allCases.filter { $0.stoneType != nil }

    /// What he may buy, one draw each, the stones as one.
    static let wares: [ItemKind] = [.rareCandy, .pokemonEgg, .uncommonEgg, .rareEgg, .legendaryEgg, .greatBall, .ultraBall,
                                    .masterBall, .oranBerry, .sitrusBerry, .revive, .maxRevive, .silverCapsule,
                                    .goldCapsule, .explorerChest, .legendaryKey, .treasureMap]

    /// Everything he may buy, the ten stones included.
    static var sellable: [ItemKind] { wares + stones }

    /// What he pays for one, before the players' difficulty (`PokemonBalance.scaled`), as the Shop's prices are.
    static func buyBackBase(_ kind: ItemKind) -> Int? {
        if let price = shopBase(kind) { return price / 3 }
        if kind.stoneType != nil { return 250_000_000 }
        switch kind {
        // About ten Rare Eggs give a legendary (4B), a third of that rounded down.
        case .legendaryEgg: return 10_000_000_000
        // About three Ultra Balls.
        case .masterBall: return 4_000_000_000
        // A third of the T3 walks a key takes (300M each, one in two); the map opens a T4 as a key does.
        case .legendaryKey, .treasureMap: return 2_000_000_000
        case .oranBerry: return 50_000_000
        case .sitrusBerry: return 150_000_000
        case .revive: return 100_000_000
        case .maxRevive: return 300_000_000
        case .silverCapsule: return 500_000_000
        case .goldCapsule: return 1_500_000_000
        // A third of what its treasure is worth on average (85% a Rare Candy, 12% an Uncommon Egg, 3% a Rare Egg).
        case .explorerChest: return 280_000_000
        default: return nil
        }
    }

    /// The Shop's price before the difficulty and the discounts, for what it sells.
    static func shopBase(_ kind: ItemKind) -> Int? {
        switch kind {
        case .pokemonEgg, .uncommonEgg, .rareEgg: FreshEgg.price(guaranteeing: kind.bagEggTier)
        case .rareCandy, .greatBall, .ultraBall: kind.shopPrice
        default: nil
        }
    }

    /// The name his portrait is cached under (`SpriteStore.data(itemName:)`): one merchant per ware, the same for the
    /// ten stones.
    static func portraitName(for kind: ItemKind) -> String {
        "merchant-" + (kind.stoneType != nil ? "stones" : kind.rawValue)
    }

    /// Each merchant's portrait: an anonymous trainer class of Pokémon Masters EX, its official 3D render, fetched from
    /// WikiDex as Prof. Oak's (the owner, 2026-11-09: "un rendu 3D officiel comme le prof Chen", no named character, kept
    /// for trainer battles to come).
    static let portraitURLs: [String: String] = {
        let base = "https://images.wikidexcdn.net/mwuploads/wikidex/"
        return [
        // Preschooler
        "merchant-rareCandy": base + "5/57/latest/20200526024948/Preescolar_%28ni%C3%B1a%29_Masters.png",
        // Pokémon Breeder
        "merchant-pokemonEgg": base + "2/24/latest/20250819160339/Criapok%C3%A9mon_%28chica%29_Masters.png",
        // Poké Fan
        "merchant-uncommonEgg": base + "b/b9/latest/20200526024248/Pok%C3%A9fan_%28hombre%29_Masters.png",
        // Pokémon Ranger
        "merchant-rareEgg": base + "b/b8/latest/20200526024559/Pok%C3%A9mon_Ranger_%28mujer%29_Masters.png",
        // Furisode Girl
        "merchant-legendaryEgg": base + "5/51/latest/20231226064005/Jovencita_con_kimono_%282%29_Masters.png",
        // Youngster
        "merchant-greatBall": base + "b/b0/latest/20200525234943/Joven_Masters.png",
        // Ace Trainer
        "merchant-ultraBall": base + "4/4d/latest/20200525234108/Entrenadora_guay_Masters.png",
        // Veteran
        "merchant-masterBall": base + "4/41/latest/20250819160238/Veterano_Masters.png",
        // Camper
        "merchant-oranBerry": base + "4/46/latest/20200525232346/Campista_Masters.png",
        // Sightseer
        "merchant-sitrusBerry": base + "d/d5/latest/20220825062445/Veraneante_%28chica%29_Masters.png",
        // Aether Foundation Employee
        "merchant-revive": base + "c/c6/latest/20230425070515/Empleada_de_la_Fundaci%C3%B3n_%C3%86ther_Masters.png",
        // Aether Foundation Employee
        "merchant-maxRevive": base + "0/0c/latest/20230425070455/Empleado_de_la_Fundaci%C3%B3n_%C3%86ther_Masters.png",
        // Scientist
        "merchant-silverCapsule": base + "c/cf/latest/20200525233616/Cient%C3%ADfico_Masters.png",
        // Gentleman
        "merchant-goldCapsule": base + "3/3d/latest/20250819160413/Arist%C3%B3crata_Masters.png",
        // Collector
        "merchant-explorerChest": base + "8/89/latest/20200526024017/Pok%C3%A9colector_Masters.png",
        // Hex Maniac
        "merchant-legendaryKey": base + "f/f2/latest/20220926062606/Bruja_Masters.png",
        // Sightseer
        "merchant-treasureMap": base + "e/ef/latest/20220825062425/Veraneante_%28chico%29_Masters.png",
        // Hiker
        "merchant-stones": base + "8/8b/latest/20200526023147/Monta%C3%B1ero_Masters.png",
        ]
    }()

    /// The day's ware (`yyyy-MM-dd`), nil for a day that is no date. Even days draw their merchant freely, odd days among
    /// those neither neighbour brought: no day needs the history before it, and two days in a row never bring the
    /// same merchant (the stones' one included). Then the stone, when it is his day.
    static func ware(on day: String) -> ItemKind? {
        guard let number = dayNumber(day) else { return nil }
        let slots = wares.count + 1
        var random = dayRandom(number)
        let slot: Int
        if number.isMultiple(of: 2) {
            slot = random.below(slots)
        } else {
            let taken: Set<Int> = [freeSlot(number - 1), freeSlot(number + 1)]
            let left = (0..<slots).filter { !taken.contains($0) }
            slot = left[random.below(left.count)]
        }
        return slot < wares.count ? wares[slot] : stones[random.below(stones.count)]
    }

    /// An even day's merchant, drawn first from its own sequence: what its odd neighbours leave out.
    private static func freeSlot(_ number: Int) -> Int {
        var random = dayRandom(number)
        return random.below(wares.count + 1)
    }

    /// The day's own sequence. FNV-1a: `hashValue` changes from launch to launch.
    private static func dayRandom(_ number: Int) -> BattleRandom {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in "merchant:\(number)".utf8 { hash = (hash ^ UInt64(byte)) &* 0x100_0000_01b3 }
        return BattleRandom(seed: hash)
    }

    /// Days since 1970-01-01 of a `yyyy-MM-dd` date, by the proleptic Gregorian calendar (no time zone involved).
    static func dayNumber(_ day: String) -> Int? {
        let parts = day.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3, (1...12).contains(parts[1]), (1...31).contains(parts[2]) else { return nil }
        let month = parts[1], date = parts[2]
        let year = parts[0] - (month <= 2 ? 1 : 0)
        let era = (year >= 0 ? year : year - 399) / 400
        let yearOfEra = year - era * 400
        let dayOfYear = (153 * ((month + 9) % 12) + 2) / 5 + date - 1
        let dayOfEra = yearOfEra * 365 + yearOfEra / 4 - yearOfEra / 100 + dayOfYear
        return era * 146_097 + dayOfEra - 719_468
    }
}
