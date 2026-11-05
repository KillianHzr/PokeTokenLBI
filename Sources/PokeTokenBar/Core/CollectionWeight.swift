/// Shared duplicate reduction for species and form selection. Keep every candidate selectable.
enum CollectionWeight {
    /// A collected one weighs `1 / divisor`: half, or less with the Tauros and Necrozma artifacts (`HatchDraw`).
    static func adjusted(_ weight: Int, isCollected: Bool, divisor: Int = 2) -> Int {
        isCollected ? max(1, weight / max(1, divisor)) : max(1, weight)
    }
}
