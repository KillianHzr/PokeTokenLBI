import Foundation

/// What the app's log says of the eggs used: every format its writer ever had, for the hatches from before the record.
struct EggJournal: Equatable, Sendable {
    struct Use: Equatable, Sendable {
        let at: Date
        let egg: HatchEgg
    }

    /// A Ditto hatched, and the line its egg rolled.
    struct Disguise: Equatable, Sendable {
        let at: Date
        let baseID: Int
    }

    let uses: [Use]
    let disguises: [Disguise]

    init(text: String) {
        let dates = ISO8601DateFormatter()
        var uses: [Use] = [], disguises: [Disguise] = []
        text.enumerateLines { line, _ in
            guard line.hasPrefix("["), let close = line.firstIndex(of: "]") else { return }
            let message = line[line.index(after: close)...].dropFirst()
            let isDisguise = message.hasPrefix("hatch: base=") && message.contains(" ditto=true")
            guard isDisguise || message.contains("discarded active"),
                  let at = dates.date(from: String(line[line.index(after: line.startIndex)..<close])) else { return }
            if isDisguise {
                if let base = Self.value(of: "base", in: message).flatMap({ Int($0) }) {
                    disguises.append(Disguise(at: at, baseID: base))
                }
            } else if let egg = Self.egg(named: message) {
                uses.append(Use(at: at, egg: egg))
            }
        }
        self.uses = uses
        self.disguises = disguises
    }

    private static func egg(named message: Substring) -> HatchEgg? {
        switch message {
        case "fresh egg: discarded active, reverted to egg": return .tier(nil)
        case "type null egg used, discarded active": return .typeNull
        case "legendary egg used, discarded active": return .legendary
        case "birthday egg used, discarded active": return .birthday
        case "fossil egg used, discarded active": return .fossil
        default: break
        }
        if message.hasPrefix("bag egg used: ") || message.hasPrefix("egg purchased: ") {
            guard let tier = value(of: "tier", in: message) else { return nil }
            if tier == "none" { return .tier(nil) }
            return Rarity(rawValue: String(tier)).map { .tier($0) }
        }
        if message.hasPrefix("stone used: ") || message.hasPrefix("stone purchased: ") {
            return value(of: "type", in: message).flatMap { PokemonType(rawValue: String($0)) }.map { .stone($0) }
        }
        if message.hasPrefix("event egg used: ") {
            let name = message.dropFirst("event egg used: ".count).prefix { $0 != "," }
            return EventEgg(rawValue: String(name)).map { .event($0, key: nil) }
        }
        return nil
    }

    /// The value of `key=value` in a line of them.
    private static func value(of key: String, in message: Substring) -> Substring? {
        message.split(whereSeparator: { $0 == " " || $0 == ":" || $0 == "," })
            .first { $0.hasPrefix(key + "=") }?.dropFirst(key.count + 1)
    }
}
