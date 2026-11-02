import Foundation

/// The egg a Pokémon hatched from.
enum HatchEgg: Codable, Sendable, Hashable {
    /// A Pokémon Egg (nil: the egg after a graduation, or the Shop's plain egg), or an egg of a guaranteed rarity, bought
    /// or given by an achievement: the same Bag item.
    case tier(Rarity?)
    case stone(PokemonType)
    case legendary
    case typeNull
    case birthday
    case fossil
    /// `key`: the claim it came from (`CompanionState.eggEventKey`).
    case event(EventEgg, key: String?)

    /// The guarantees its pool keeps; nil for the eggs with a draw of their own.
    var spec: CompanionStore.EggSpec? {
        switch self {
        case .tier(let tier): return .init(tier: tier)
        case .stone(let type): return .init(type: type)
        case .legendary: return .init(legendaryEgg: true)
        case .event(let event, _): return .init(tier: event.tier, type: event.type, event: event)
        case .typeNull, .birthday, .fossil: return nil
        }
    }

    /// The egg a Bag item gives when used; nil for an item that is no egg.
    init?(item: ItemKind) {
        switch item {
        case .typeNullEgg: self = .typeNull
        case .fossilEgg: self = .fossil
        case .birthdayEgg: self = .birthday
        case .legendaryEgg: self = .legendary
        default:
            if item.isShopEgg { self = .tier(item.bagEggTier) }
            else if let type = item.stoneType { self = .stone(type) }
            else if let event = EventEgg(item: item) { self = .event(event, key: nil) }
            else { return nil }
        }
    }
}

/// How a Pokémon hatched, kept with it from its hatch to its graduation or release, for the Luck screen to replay its
/// rolls (`HatchDraw`): its egg, and the draw items each roll met.
struct HatchRecord: Codable, Sendable, Equatable {
    var egg: HatchEgg
    /// The draw items owned when its species was rolled, its form with it: as the egg started, or at the hatch when
    /// nothing was rolled before.
    var rollItems: Set<ItemKind> = []
    /// The draw items owned when it hatched: its shiny and Ditto rolls.
    var hatchItems: Set<ItemKind> = []
    /// The egg was chosen by the player, for a hatch from before the record: its draw items then come from their dates.
    var chosenByPlayer = false

    init(egg: HatchEgg, rollItems: Set<ItemKind> = [], hatchItems: Set<ItemKind> = [], chosenByPlayer: Bool = false) {
        self.egg = egg
        self.rollItems = rollItems
        self.hatchItems = hatchItems
        self.chosenByPlayer = chosenByPlayer
    }

    /// An item a later build added is left out, not the record.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        egg = try c.decode(HatchEgg.self, forKey: .egg)
        func items(_ key: CodingKeys) -> Set<ItemKind> {
            Set(((try? c.decodeIfPresent([String].self, forKey: key)) ?? nil)?.compactMap(ItemKind.init(rawValue:)) ?? [])
        }
        rollItems = items(.rollItems)
        hatchItems = items(.hatchItems)
        chosenByPlayer = (try? c.decodeIfPresent(Bool.self, forKey: .chosenByPlayer)) ?? false
    }
}

extension CompanionState {
    /// The egg incubating, as its record names it.
    var incubatingHatchEgg: HatchEgg {
        if let eggEvent { return .event(eggEvent, key: eggEventKey) }
        if eggFromTypeNullEgg { return .typeNull }
        if eggFromBirthdayEgg { return .birthday }
        if eggFromFossilEgg { return .fossil }
        if eggFromLegendaryEgg { return .legendary }
        if let eggTypeGuarantee { return .stone(eggTypeGuarantee) }
        return .tier(eggTier)
    }
}
