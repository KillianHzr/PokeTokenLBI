import Foundation

/// What the Bag's counts say of the eggs of the hatches from before the record. An egg only claims give, minus what is
/// left of it, was used: on one of the hatches it could have brought.
struct EggStock: Sendable, Equatable {
    /// Of each counted egg, how many no record accounts for.
    let left: [HatchEgg: Int]
    /// The first moment each dated egg could be in the Bag.
    let earliest: [HatchEgg: Date]
    /// The eggs that may also come from elsewhere, for which `left` is only a minimum.
    let floors: Set<HatchEgg>

    struct Slot: Sendable, Equatable {
        /// When its egg started: it had to be in the Bag by then. Nil when unknown.
        var started: Date?
        var possible: [HatchEgg]
        var egg: HatchEgg?
        /// Whether its egg is still open: a hatch after a release, without a record of the app.
        var asked = true
        var isSure = false
    }

    init(left: [HatchEgg: Int], earliest: [HatchEgg: Date] = [:], floors: Set<HatchEgg> = []) {
        self.left = left
        self.earliest = earliest
        self.floors = floors
    }

    /// `entries`: the Pokédex in hatch order, the Pokémon raised last.
    init(today: CompanionState, entries: [DexEntry]) {
        var left = Self.used(in: today)
        let noted = entries.compactMap(\.hatch).filter { !$0.isOpenToPlayer }.map(\.egg)
        for egg in noted + (today.active == nil ? [today.incubatingHatchEgg] : []) {
            if let count = left[egg.withoutKey] { left[egg.withoutKey] = max(0, count - 1) }
        }
        var earliest: [HatchEgg: Date] = [:]
        earliest[.birthday] = today.lastBirthdayGiftClaimedAt
        let firstCatch = entries.compactMap(\.caughtAt).min()
        let calendar = LocalUsageReader.gregorianCalendar()
        for event in EventEgg.allCases {
            earliest[.event(event, key: nil)] = today.claimedEventEggs.compactMap { key -> Date? in
                guard key.hasPrefix(event.rawValue + "@"), let year = Int(key.dropFirst(event.rawValue.count + 1)) else { return nil }
                return event.days(in: year, firstCatch: firstCatch, calendar: calendar)?.start
            }.min()
        }
        let hasKit = (today.inventory[ItemKind.explorerKit.rawValue] ?? 0) > 0
        self.init(left: left, earliest: earliest, floors: hasKit ? [.legendary] : [])
    }

    /// How many of each counted egg left the Bag. Not the Shop's eggs, whose purchases nothing counts; not the Fossil
    /// Egg, which a Pokémon sent off gives back.
    static func used(in s: CompanionState) -> [HatchEgg: Int] {
        var used: [HatchEgg: Int] = [:]
        for (item, egg) in countedEggs {
            used[egg] = max(0, given(item, in: s) - (s.inventory[item.rawValue] ?? 0))
        }
        return used
    }

    private static let countedEggs: [(item: ItemKind, egg: HatchEgg)] = ItemKind.allCases.compactMap { item in
        guard item != .fossilEgg, !item.isShopEgg, let egg = HatchEgg(item: item) else { return nil }
        return (item, egg)
    }

    private static func given(_ item: ItemKind, in s: CompanionState) -> Int {
        func keys(_ set: Set<String>, of name: String) -> Int { set.filter { $0.hasPrefix(name + "@") }.count }
        if item == .legendaryEgg { return keys(s.claimedAchievements, of: item.rawValue) }
        if item == .birthdayEgg { return s.lastBirthdayGiftYear == nil ? 0 : 1 }
        if let event = EventEgg(item: item) { return keys(s.claimedEventEggs, of: event.rawValue) }
        return s.claimedAchievements.contains(item.rawValue) ? item.achievementRewardCount : 0
    }

    /// Settles what the counts allow, over and over since each settled hatch changes the count. An egg none is left of
    /// leaves the lists, unless it would empty one: something brought that hatch. As many left as hatches that could
    /// have used it makes them all sure, whatever the player said; a surplus is left out. Never a Fossil Egg right after
    /// a Fossil Egg's Pokémon, sent off for free.
    func settle(_ slots: [Slot]) -> [Slot] {
        var out = slots
        var left = left
        func isOpen(_ i: Int) -> Bool { out[i].asked && !out[i].isSure }
        func makeSure(_ i: Int, _ egg: HatchEgg) {
            out[i].egg = egg
            out[i].possible = [egg]
            out[i].isSure = true
            if let count = left[egg] { left[egg] = max(0, count - 1) }
        }
        for i in out.indices where isOpen(i) {
            guard let started = out[i].started else { continue }
            let inTime = out[i].possible.filter { egg in earliest[egg].map { $0 <= started } ?? true }
            if !inTime.isEmpty { out[i].possible = inTime }
        }
        var changed = true
        while changed {
            changed = false
            for i in out.indices where isOpen(i) {
                if i > 0, out[i - 1].egg == .fossil, let fossil = out[i].possible.firstIndex(of: .fossil) {
                    out[i].possible.remove(at: fossil)
                    changed = true
                }
                if let said = out[i].egg, !out[i].possible.contains(said) {
                    out[i].egg = nil
                    changed = true
                }
                if out[i].possible.count == 1 {
                    makeSure(i, out[i].possible[0])
                    changed = true
                }
            }
            for (_, egg) in Self.countedEggs {
                let open = out.indices.filter { isOpen($0) && out[$0].possible.contains(egg) }
                guard !open.isEmpty, let count = left[egg] else { continue }
                if count >= open.count {
                    for i in open { makeSure(i, egg) }
                    changed = true
                } else if count == 0, !floors.contains(egg) {
                    for i in open where out[i].possible.count > 1 {
                        out[i].possible.removeAll { $0 == egg }
                        changed = true
                    }
                }
            }
        }
        return out
    }
}
