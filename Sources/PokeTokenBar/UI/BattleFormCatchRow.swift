import SwiftUI

/// A battle form won in the daily or weekly dungeon, a line of the catch log (the owner, 2026-11-10): its species as
/// usual, then the new form, the dungeon that gave it and when. Each sprite opens the species' Pokédex page, the new
/// one in its form.
@MainActor
struct BattleFormCatchRow: View {
    let store: CompanionStore
    let won: BattleFormCatch
    let dexLinks: [Int: String]
    /// The Pokédex page (`DexSpecies.collectionID`) and the form it opens in, none for the usual one.
    let onOpen: (String, PokemonForm?) -> Void

    private static let thumb: CGFloat = 68
    private static let nameWidth = thumb + 6

    var body: some View {
        let l = store.l
        let facts = store.battleFormFacts(won.form)
        let form = won.form
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .top, spacing: 6) {
                WrappingHStack(spacing: 6, lineSpacing: 4) {
                    Badge(l.rarityLabel(facts.rarity).uppercased(), tint: .rarity(facts.rarity), size: 10)
                    Badge(l.battleFormBadge.uppercased(), tint: .orange, style: .tinted, size: 10)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Text(l.dungeonName(won.dungeon))
                    .font(.system(size: 11)).foregroundStyle(.secondary)
                    .fixedSize()
            }
            HStack(alignment: .top, spacing: 2) {
                stage(name: facts.speciesName, form: PokemonForm.battleBase(form), opens: nil)
                Image(systemName: "arrow.right").font(.system(size: Self.thumb * 0.2))
                    .foregroundStyle(.tertiary)
                    .frame(width: Self.thumb * 0.25)
                    .padding(.top, Self.thumb * 0.4)
                stage(name: PokemonForm.displayName(facts.speciesName, speciesID: form.speciesID, form: form.form,
                                                    language: store.language),
                      form: form.form, opens: form.form)
            }
            if let wonAt = won.wonAt {
                Text(wonAt, style: .relative).font(.system(size: 11)).foregroundStyle(.secondary)
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func stage(name: String, form: PokemonForm?, opens: PokemonForm?) -> some View {
        VStack(spacing: 1) {
            SpriteView(speciesID: won.form.speciesID, size: Self.thumb, form: form, sameScale: true, bottomAligned: true)
            Text(name)
                .font(.system(size: 11)).foregroundStyle(.secondary)
                .lineLimit(2).multilineTextAlignment(.center)
                .frame(maxWidth: Self.nameWidth)
        }
        .frame(width: Self.nameWidth)
        .modifier(DexEntryLink(target: dexLinks[won.form.speciesID], hint: store.l.dexOpenEntryHint,
                               accessibilityName: name, cornerRadius: 6,
                               open: { onOpen($0, opens) }))
    }
}
