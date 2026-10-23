import SwiftUI

/// 가방(인벤토리) — 소유 아이템 카드 + 사용. 빈 상태는 움직이는 잠만보(컬렉션의 피카츄 패턴).
@MainActor
struct BagView: View {
    let store: CompanionStore
    let nav: PopoverNavigation
    @State private var section: Section = .items

    /// The Bag's sections, as the Achievements tabs: items (Shop, candies, stones), gym badges, artifacts. The
    /// 18 badges used to fill the list and hide the other items.
    enum Section: CaseIterable, Hashable {
        case items, badges, artifacts

        static func of(_ kind: ItemKind) -> Section {
            switch kind.collectorGroup {
            case .gymBadges?: return .badges
            case .legendaryArtifacts?: return .artifacts
            case .evolutionStones?, nil: return .items
            }
        }
    }

    var body: some View {
        let owned = store.ownedItems
        if owned.isEmpty {
            emptyState
        } else {
            let sections = Section.allCases.filter { s in owned.contains { Section.of($0.kind) == s } }
            let current = sections.contains(section) ? section : sections[0]
            let items = owned.filter { Section.of($0.kind) == current }
            // 고정 높이 — 컬렉션과 동일(팝오버 재오픈 시 fitting size 축소 방지).
            VStack(alignment: .leading, spacing: 8) {
                if sections.count > 1 {
                    PillPicker(selection: Binding(get: { current }, set: { section = $0 }),
                               options: sections.map { s in
                                   (s, "\(title(s)) \(owned.filter { Section.of($0.kind) == s }.count)")
                               })
                }
                ScrollView {
                    if current == .badges {
                        badgeGrid(items.map(\.kind))
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(items, id: \.kind) { item in
                                ItemCard(store: store, nav: nav, kind: item.kind, count: item.count)
                            }
                        }
                        .reservesScrollerLane()
                    }
                }
            }
            .frame(height: 520)
        }
    }

    private func title(_ section: Section) -> String {
        switch section {
        case .items: return store.l.bagItemsTitle
        case .badges: return store.l.collectorGroupTitle(.gymBadges)
        case .artifacts: return store.l.collectorGroupTitle(.legendaryArtifacts)
        }
    }

    /// The badges in two columns: icon, name and bonus so far, with the effect said once above them.
    private func badgeGrid(_ kinds: [ItemKind]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(store.l.bagBadgesHint)
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6)], spacing: 6) {
                ForEach(kinds, id: \.self) { kind in
                    BadgeTile(store: store, kind: kind)
                }
            }
        }
        .reservesScrollerLane()
    }

    /// 빈 가방 — 움직이는 잠만보(143) + 안내(특정 아이템명 미언급, 확장 대비).
    private var emptyState: some View {
        VStack(spacing: 10) {
            SpriteView(speciesID: 143, size: 96, animated: true)   // 잠만보(움직임)
            Text(store.l.bagEmptyTitle)
                .font(.callout.weight(.semibold))
            Button(store.l.shop) { nav.tab = .shop }
                .buttonStyle(.pill())
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
    }
}

/// 아이템 1장 — 아이콘·이름·개수·설명 + 인라인 확인 사용.
/// 확인은 인라인(버튼 morph) — .sheet/.alert 금지: transient 팝오버가 닫힐 때 고아 시트가
/// 이후 클릭을 먹통내는 기존 결함(PopoverView 주석) 회피.
@MainActor
private struct ItemCard: View {
    let store: CompanionStore
    let nav: PopoverNavigation
    let kind: ItemKind
    let count: Int
    @State private var confirming = false
    @State private var candyCount = 1

    private var selectedCandyCount: Int { min(candyCount, max(1, store.maxRareCandyUseCount)) }

    var body: some View {
        let l = store.l
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                ItemIconView(kind: kind, size: 30)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(l.itemName(kind)).font(.callout.weight(.semibold))
                        if let type = kind.stoneType {
                            Badge(l.typeName(type).uppercased(), tint: .type(type))
                        }
                        if !kind.isPassive {   // 보유형은 개수 개념이 없음(1회 구매·영구)
                            Text("×\(count)").font(.caption.weight(.bold))
                                .foregroundStyle(.secondary).monospacedDigit()
                        }
                        Spacer(minLength: 4)
                        if kind == .rareCandy, store.canUseRareCandy {
                            Stepper(value: $candyCount, in: 1...max(1, store.maxRareCandyUseCount)) {
                                Text("×\(selectedCandyCount)").font(.callout.weight(.semibold)).monospacedDigit()
                            }
                            .fixedSize()
                            .accessibilityLabel(l.itemName(.rareCandy))
                            .accessibilityValue("\(selectedCandyCount)")
                        }
                    }
                    Text(l.itemDescription(kind))
                        .font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    // A stone sends the companion off like a Shop egg: say what stays, as the egg card does.
                    if kind.stoneType != nil, store.hasActive {
                        Text(l.eggReleaseNote)
                            .font(.caption2).foregroundStyle(.tertiary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            if kind == .rareCandy, let preview = store.planRareCandyUse(count: selectedCandyCount) {
                if preview.graduates {
                    Text(l.candyGraduates).font(.caption2).foregroundStyle(.secondary)
                }
                if preview.discardedXP > 0 {
                    Text(l.candyDiscardedXP(TokenFormatter.compact(preview.discardedXP)))
                        .font(.caption2).foregroundStyle(.orange).fixedSize(horizontal: false, vertical: true)
                } else if preview.evolves && !preview.graduates {
                    Text(l.candyCarryoverXP(TokenFormatter.compact(preview.carryoverXP)))
                        .font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
            }
            useControls(l)
        }
        .padding(12)
        .designSurface(cornerRadius: Design.cornerRadius)
        .onChange(of: store.maxRareCandyUseCount) { _, _ in
            candyCount = selectedCandyCount
        }
    }

    /// 이 아이템을 지금 쓸 수 있나 (kind 별 — 사탕은 라인 로딩 필요, 민트는 활성 포켓몬만).
    private var canUse: Bool {
        switch kind {
        case .rareCandy: return store.canUseRareCandy
        case .mint:      return store.canUseMint
        // 보유형: 사용 개념 없음(상시 효과). Stones have their own controls (`useControls`).
        default:         return false
        }
    }
    /// 사용 컨트롤 효과 힌트 ("+XP" / "성격 랜덤 변경").
    private func effectHint(_ l: L) -> String {
        if kind == .rareCandy { return "+\(TokenFormatter.compact(selectedCandyCount * store.rareCandyXP)) XP" }
        return store.effectHint(for: kind)
    }
    private func performUse() {
        switch kind {
        case .rareCandy: _ = store.useRareCandy(count: selectedCandyCount)
        case .mint:      _ = store.useMint()
        default:         break   // 보유형: 사용 동작 없음
        }
    }

    @ViewBuilder
    private func useControls(_ l: L) -> some View {
        if kind.stoneType != nil {
            // Using a stone sends the companion off for a typed egg: the Shop egg's confirmations apply.
            ReleaseForEggControls(store: store, nav: nav, detail: effectHint(l), actionTitle: l.useItem,
                                  isAvailable: store.canUseStone(kind), unavailableText: l.useNeedsPokemon,
                                  confirmText: l.stoneConfirm(store.displayName, l.itemName(kind))) {
                store.useStone(kind)
            }
        } else if kind == .typeNullEgg {
            ReleaseForEggControls(store: store, nav: nav, detail: effectHint(l), actionTitle: l.useItem,
                                  isAvailable: store.canUseTypeNullEgg(), unavailableText: l.useNeedsPokemon,
                                  confirmText: l.stoneConfirm(store.displayName, l.itemName(kind))) {
                store.useTypeNullEgg()
            }
        } else if kind == .legendaryEgg {
            ReleaseForEggControls(store: store, nav: nav, detail: effectHint(l), actionTitle: l.useItem,
                                  isAvailable: store.canUseLegendaryEgg(), unavailableText: l.useNeedsPokemon,
                                  confirmText: l.stoneConfirm(store.displayName, l.itemName(kind))) {
                store.useLegendaryEgg()
            }
        } else if kind.isPassive {
            // 보유형(패시브 아이템): 사용 버튼 대신 상시 효과 표시.
            HStack(spacing: 6) {
                Image(systemName: "checkmark.seal.fill").font(.caption2).foregroundStyle(.green)
                Text(effectHint(l)).font(.caption2.weight(.semibold)).foregroundStyle(.green)
                Spacer()
            }
        } else if canUse {
            if confirming {
                HStack(spacing: 8) {
                    Text(l.useOnCurrent(store.displayName))
                        .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                    Spacer()
                    Button(kind == .rareCandy ? "\(l.use) ×\(selectedCandyCount)" : l.use) { useNow() }
                        .buttonStyle(.pill(prominent: true))
                    Button(l.cancel) { confirming = false }
                        .buttonStyle(.borderless).controlSize(.small)
                }
            } else {
                HStack {
                    Text(effectHint(l))
                        .font(.caption2).foregroundStyle(.tertiary).monospacedDigit()
                    Spacer()
                    Button(l.useItem) { confirming = true }
                        .buttonStyle(.pill())
                }
            }
        } else {
            // 알(부화 전)/활성 없음/(사탕만)라인 미로딩 — 비활성 + 사유
            Text(store.isEgg ? l.useAfterHatch : l.useNeedsPokemon)
                .font(.caption2).foregroundStyle(.tertiary)
        }
    }

    /// 사용 → 항상 Home 탭으로 전환(진화/졸업 연출·"+XP"·성격 변경 토스트는 Home 의 CompanionHeader 에서 재생).
    private func useNow() {
        confirming = false
        performUse()
        nav.tab = .home
    }
}

/// One gym badge in the Bag's grid: its icon, name and growth bonus so far out of its maximum.
@MainActor
private struct BadgeTile: View {
    let store: CompanionStore
    let kind: ItemKind

    var body: some View {
        let l = store.l
        let type = kind.badgeType
        let claimed = type.map(store.claimedBadgeTierCount) ?? 0
        let regions = type.map { PokemonTypeData.badgeGenerations(for: $0).count } ?? 0
        HStack(spacing: 6) {
            ItemIconView(kind: kind, size: 24)
            VStack(alignment: .leading, spacing: 1) {
                Text(l.itemName(kind)).font(.caption.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.75)
                Text(l.badgeBonus(Double(claimed) * CollectorBonus.badgeRegionBonus * 100,
                                  of: Double(regions) * CollectorBonus.badgeRegionBonus * 100))
                    .font(.caption2.weight(.semibold)).monospacedDigit()
                    .foregroundStyle(claimed > 0 ? .green : .secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .designSurface(cornerRadius: 10)
        .accessibilityElement(children: .combine)
    }
}

extension CompanionStore {
    /// An item's effect in a few words, as the Bag shows it under the item ("Final stage +25% · active").
    func effectHint(for kind: ItemKind) -> String {
        switch kind {
        case .rareCandy: return "+\(TokenFormatter.compact(rareCandyXP)) XP"
        case .mint:      return l.mintEffectHint
        case .shinyCharm: return l.shinyCharmEffectHint
        case .legendCharm: return l.legendCharmEffectHint
        case .silverWing: return l.silverWingEffectHint
        case .oldSeaMap: return l.oldSeaMapEffectHint
        case .clearBell: return l.clearBellEffectHint
        case .rainbowWing: return l.rainbowWingEffectHint
        case .magmaStone: return l.magmaStoneEffectHint
        case .soulDew: return l.soulDewEffectHint
        case .jadeOrb: return l.jadeOrbEffectHint
        case .gracidea: return l.gracideaEffectHint
        case .griseousOrb: return l.griseousOrbEffectHint
        case .libertyPass: return l.libertyPassEffectHint
        case .revealGlass: return l.revealGlassEffectHint
        case .dnaSplicers: return l.dnaSplicersEffectHint
        case .zygardeCube: return l.zygardeCubeEffectHint(Int((zygardeCubeMultiplier - 1) * 100 + 0.5))
        case .prisonBottle: return l.prisonBottleEffectHint
        case .sparklingStone: return l.sparklingStoneEffectHint
        case .sunFlute: return l.sunFluteEffectHint
        case .beastBall: return l.beastBallEffectHint
        case .rustedSword: return l.rustedSwordEffectHint
        case .reinsOfUnity: return l.reinsOfUnityEffectHint
        case .boosterEnergy: return l.boosterEnergyEffectHint
        case .tealMask: return l.tealMaskEffectHint
        case .teraOrb: return l.teraOrbEffectHint
        case .relicStatue: return l.relicStatueEffectHint
        case .typeNullEgg: return l.typeNullEggHint
        case .legendaryEgg: return l.legendaryEggHint
        case .ovalCharm: return l.ovalCharmEffectHint
        case .glimmeringCharm: return l.glimmeringCharmEffectHint
        case .boulderBadge, .cascadeBadge, .thunderBadge, .rainbowBadge,
             .soulBadge, .marshBadge, .volcanoBadge, .earthBadge,
             .zephyrBadge, .hiveBadge, .plainBadge, .fogBadge,
             .stormBadge, .mineralBadge, .glacierBadge, .risingBadge,
             .darkBadge, .fairyBadge:
            let tiers = kind.badgeType.map(claimedBadgeTierCount) ?? 0
            return l.badgeEffectHint(Double(tiers) * CollectorBonus.badgeRegionBonus * 100, type: kind.badgeType)
        case .leafStone, .fireStone, .waterStone, .thunderStone, .sunStone,
             .moonStone, .duskStone, .iceStone, .dawnStone, .shinyStone:
            return kind.stoneType.map(l.eggTypeGuaranteeHint) ?? ""
        }
    }
}
