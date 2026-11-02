import AppKit
import SwiftUI

/// Green and orange for text and small symbols on the popover's surfaces: the system hues are light enough that
/// green or orange text on a light card, or a dim one on a dark card, read poorly. These are a shade darker in light
/// mode and a shade lighter in dark mode (`ReadableColorTests` checks their contrast on both).
extension Color {
    static let readableGreen = Color(nsColor: .readableGreen)
    static let readableOrange = Color(nsColor: .readableOrange)
}

extension NSColor {
    static let readableGreen = readable(light: (0.05, 0.45, 0.17), dark: (0.36, 0.86, 0.46))
    static let readableOrange = readable(light: (0.66, 0.30, 0.0), dark: (1.0, 0.70, 0.28))

    static func readable(light: (Double, Double, Double), dark: (Double, Double, Double)) -> NSColor {
        NSColor(name: nil) { appearance in
            let c = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
            return NSColor(srgbRed: c.0, green: c.1, blue: c.2, alpha: 1)
        }
    }
}

/// The popover's look in one place: rounded cards, small section titles, rounded type for titles and figures, and
/// the color of the Pokémon being raised, which tints the hero card and the selected tab.
enum Design {
    static let cornerRadius: CGFloat = 14
    static let cardPadding: CGFloat = 12
    static let sectionSpacing: CGFloat = 10
    /// The egg has no type: a warm gold until it hatches.
    static let eggColor = Color(.sRGB, red: 0.95, green: 0.72, blue: 0.30)
    /// Buttons, pickers and charts: one color whatever the Pokémon. In its type's color, a Dark or Ghost type
    /// made them dark on a dark popover and an Electric one yellow on white.
    static let actionColor = Color(.sRGB, red: 0.27, green: 0.52, blue: 0.98)
}

extension View {
    /// A raised card: a faint fill and a hairline border, in light and dark appearance alike.
    func designCard(padding: CGFloat = Design.cardPadding) -> some View {
        self.padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: Design.cornerRadius, style: .continuous)
                .fill(Color.primary.opacity(0.045)))
            .overlay(RoundedRectangle(cornerRadius: Design.cornerRadius, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08)))
    }

    /// The hero card: the card washed with `color`, strongest behind the sprite on the left.
    func heroCard(color: Color, padding: CGFloat = Design.cardPadding) -> some View {
        heroCard(colors: [color], padding: padding)
    }

    /// The hero card of a Pokémon with two types: the first type's color behind the sprite, blending into the
    /// second's towards the bottom right, with a border going from one to the other. One color: one type.
    func heroCard(colors: [Color], padding: CGFloat = Design.cardPadding) -> some View {
        let first = colors.first ?? .gray
        let second = colors.count > 1 ? colors[1] : nil
        return self.padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                let shape = RoundedRectangle(cornerRadius: Design.cornerRadius + 2, style: .continuous)
                shape.fill(LinearGradient(colors: second.map { [first.opacity(0.32), $0.opacity(0.24)] }
                                              ?? [first.opacity(0.30), first.opacity(0.07)],
                                          startPoint: .topLeading, endPoint: .bottomTrailing))
                    .overlay(alignment: .topLeading) {
                        RadialGradient(colors: [first.opacity(0.45), .clear], center: .center, startRadius: 4,
                                       endRadius: 70)
                            .frame(width: 140, height: 140)
                            .offset(x: -18, y: -22)
                    }
                    .overlay(alignment: .bottomTrailing) {
                        if let second {
                            RadialGradient(colors: [second.opacity(0.35), .clear], center: .center, startRadius: 4,
                                           endRadius: 90)
                                .frame(width: 180, height: 180)
                                .offset(x: 40, y: 50)
                        }
                    }
                    .clipShape(shape)
                    .overlay(shape.strokeBorder(LinearGradient(colors: [first.opacity(0.4), (second ?? first).opacity(0.4)],
                                                               startPoint: .topLeading, endPoint: .bottomTrailing)))
                    // Decoration only: the glow reaches past the card, and would take the clicks of what sits above it
                    // (the tab bar on Home, the Normal/Shiny picker in the Pokédex).
                    .allowsHitTesting(false)
            }
    }
}

/// A legendary Pokémon is an event: its hero card gets light rays turning behind the sprite on a golden glow and
/// twinkling stars. Animated only while the popover shows it, at a capped frame rate, and still with Reduce Motion.
@MainActor
struct LegendaryHeroBackground: View {
    let color: Color
    /// A second type's color, which the card blends into towards the bottom right.
    var secondColor: Color? = nil
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static let gold = Color(.sRGB, red: 1.0, green: 0.80, blue: 0.30)
    /// Twelve rays, each clear → gold → clear, ending where they start: no seam where the circle closes.
    static let rayStops: [Gradient.Stop] = (0..<12).flatMap { ray -> [Gradient.Stop] in
        let start = Double(ray) / 12
        return [.init(color: .clear, location: start), .init(color: gold.opacity(0.34), location: start + 1.0 / 24)]
    } + [.init(color: .clear, location: 1)]

    /// The rays turn by a repeating animation (12° a second), which redraws no body: a 30 fps timeline redrew the
    /// whole card for them. Only the stars keep a timeline, at 10 fps.
    @State private var turning = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Design.cornerRadius + 2, style: .continuous)
        ZStack {
            shape.fill(LinearGradient(colors: [color.opacity(0.42), Self.gold.opacity(0.10),
                                               (secondColor ?? color).opacity(secondColor == nil ? 0.10 : 0.26)],
                                      startPoint: .topLeading, endPoint: .bottomTrailing))
            // Light rays turning behind the sprite, on a golden glow.
            AngularGradient(gradient: Gradient(stops: Self.rayStops), center: .center)
                .rotationEffect(.degrees(turning ? 360 : 0))
                .animation(reduceMotion ? nil : .linear(duration: 30).repeatForever(autoreverses: false), value: turning)
                .mask(RadialGradient(colors: [.white, .white.opacity(0.6), .clear], center: .center,
                                     startRadius: 4, endRadius: 92))
                .frame(width: 200, height: 200)
                .position(x: 54, y: 52)
            RadialGradient(colors: [Self.gold.opacity(0.55), .clear], center: .center, startRadius: 2,
                           endRadius: 55)
                .frame(width: 110, height: 110)
                .position(x: 54, y: 52)
            TimelineView(.animation(minimumInterval: 1.0 / 10, paused: reduceMotion)) { context in
                // Seconds into a 15 min cycle: phases built on the absolute date (8e8 s) lose their precision.
                sparkles(reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 900))
            }
        }
        .clipShape(shape)
        // The same border as every hero card: the type color.
        .overlay(shape.strokeBorder(LinearGradient(colors: [color.opacity(0.4), (secondColor ?? color).opacity(0.4)],
                                                   startPoint: .topLeading, endPoint: .bottomTrailing)))
        .onAppear { if !reduceMotion { turning = true } }
    }

    /// A few stars at fixed spots, each twinkling on its own phase.
    private func sparkles(_ t: TimeInterval) -> some View {
        GeometryReader { geo in
            let spots: [(x: CGFloat, y: CGFloat, size: CGFloat, phase: Double)] = [
                (0.08, 0.15, 9, 0), (0.30, 0.10, 6, 1.3), (0.88, 0.14, 8, 2.1), (0.95, 0.55, 6, 0.7),
                (0.62, 0.86, 7, 2.8), (0.22, 0.78, 6, 1.9), (0.75, 0.40, 5, 3.4),
            ]
            ForEach(Array(spots.enumerated()), id: \.offset) { _, spot in
                let glow = (sin(t * 2.2 + spot.phase) + 1) / 2
                Image(systemName: "sparkle")
                    .font(.system(size: spot.size, weight: .bold))
                    .foregroundStyle(Self.gold)
                    .opacity(0.25 + 0.75 * glow)
                    .scaleEffect(0.7 + 0.5 * glow)
                    .position(x: geo.size.width * spot.x, y: geo.size.height * spot.y)
            }
        }
        .allowsHitTesting(false)
    }
}

/// The "LEGENDARY" pill of a legendary hero card: flat gold with a shine sweeping across every few seconds. No
/// bevel, border or shadow.
@MainActor
struct LegendaryBadge: View {
    let text: String
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        // Frames only while the shine crosses: at rest, half of each cycle, the badge is not redrawn 30 times a second.
        TimelineView(ShineSchedule(paused: reduceMotion)) { context in
            // 0…1 over 3 s; the shine crosses during the first half, then rests.
            let phase = reduceMotion ? 0.25 : ShineSchedule.phase(at: context.date)
            Text(text)
            .font(.system(size: 9, weight: .heavy, design: .rounded))
            .foregroundStyle(Color(.sRGB, red: 0.36, green: 0.22, blue: 0.0))
            .padding(.horizontal, 7).padding(.vertical, 2)
            .background {
                GeometryReader { geo in
                    let width = geo.size.width
                    LinearGradient(colors: [.clear, .white.opacity(0.75), .clear], startPoint: .leading,
                                   endPoint: .trailing)
                        .frame(width: 22)
                        .rotationEffect(.degrees(20))
                        .offset(x: -30 + (width + 60) * min(1, phase * 2))
                }
                .background(LegendaryHeroBackground.gold)
                .clipShape(Capsule())
            }
        }
    }
}

/// The legendary badge's frames: 30 a second while the shine crosses (the first half of each 3 s cycle), one where it
/// ends, then none until the next cycle.
struct ShineSchedule: TimelineSchedule {
    static let cycle: TimeInterval = 3
    static let sweep: TimeInterval = 1.5
    static let frame: TimeInterval = 1.0 / 30
    var paused = false

    /// 0…1 through the cycle.
    static func phase(at date: Date) -> Double {
        date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: cycle) / cycle
    }

    /// The frame after `date`.
    static func next(after date: Date) -> Date {
        let into = date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: cycle)
        if into + frame < sweep { return date.addingTimeInterval(frame) }
        // A millisecond of slack: a date of 8e8 s holds 1e-7 s, and a jump to the exact end could land just before it.
        if into < sweep - 0.001 { return date.addingTimeInterval(sweep - into) }
        return date.addingTimeInterval(cycle - into)
    }

    func entries(from startDate: Date, mode: TimelineScheduleMode) -> AnyIterator<Date> {
        var date: Date? = startDate
        let paused = paused
        return AnyIterator {
            guard let current = date else { return nil }
            date = paused ? nil : Self.next(after: current)
            return current
        }
    }
}

extension View {
    /// `heroCard`, or its legendary version for a legendary Pokémon.
    @ViewBuilder
    func heroCard(colors: [Color], legendary: Bool) -> some View {
        if legendary {
            self.padding(Design.cardPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(LegendaryHeroBackground(color: colors.first ?? .gray,
                                                    secondColor: colors.count > 1 ? colors[1] : nil)
                    .allowsHitTesting(false))
        } else {
            heroCard(colors: colors)
        }
    }
}

extension View {
    /// The surface of a list card (Shop, Bag, Achievements…): `designCard`'s fill and border around a view that
    /// already has its padding.
    func designSurface(cornerRadius: CGFloat = Design.cornerRadius) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return background(shape.fill(Color.primary.opacity(0.045)))
            .overlay(shape.strokeBorder(Color.primary.opacity(0.08)))
            .clipShape(shape)
    }
}

/// A segmented control drawn like the tab bar: equal segments, the selected one on a pill in `accent`. Each
/// title must fit its segment, shrunk to `minimumLabelScale` at most, in every language.
@MainActor
struct PillPicker<Value: Hashable>: View {
    @Binding var selection: Value
    let options: [(value: Value, title: String)]
    var accent: Color = Design.actionColor

    static var labelFont: NSFont { .systemFont(ofSize: 12, weight: .semibold) }
    static var minimumLabelScale: CGFloat { 0.75 }
    /// The width a title gets in one of `count` segments across `width`: 3 pt padding, 2 pt between segments,
    /// 4 pt inside each.
    static func labelWidth(count: Int, in width: CGFloat) -> CGFloat {
        (width - 6 - 2 * CGFloat(max(0, count - 1))) / CGFloat(max(1, count)) - 8
    }

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options.indices, id: \.self) { index in
                let option = options[index]
                let selected = option.value == selection
                Button { selection = option.value } label: {
                    Text(option.title)
                        .font(Font(Self.labelFont))
                        .lineLimit(1)
                        .minimumScaleFactor(Self.minimumLabelScale)
                        .foregroundStyle(selected ? AnyShapeStyle(accent) : AnyShapeStyle(.secondary))
                        .padding(.horizontal, 4)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 5)
                        .background(RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(selected ? accent.opacity(0.16) : .clear))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(3)
        .background(RoundedRectangle(cornerRadius: 11, style: .continuous).fill(Color.primary.opacity(0.05)))
        .animation(.easeOut(duration: 0.15), value: selection)
    }
}

/// A capsule button. Prominent (Buy, Use, Claim): filled with `tint`; otherwise a faint wash of it. Disabled: grey.
struct PillButtonStyle: ButtonStyle {
    var prominent = false
    var tint: Color = Design.actionColor
    /// Text on a prominent fill.
    var textOnTint: Color = .white

    func makeBody(configuration: Configuration) -> some View {
        PillButtonLabel(configuration: configuration, style: self)
    }

    @MainActor
    private struct PillButtonLabel: View {
        let configuration: ButtonStyleConfiguration
        let style: PillButtonStyle
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            let fill: Color = !isEnabled ? Color.primary.opacity(0.08)
                : style.prominent ? style.tint : style.tint.opacity(0.15)
            let text: Color = !isEnabled ? Color.secondary : style.prominent ? style.textOnTint : style.tint
            configuration.label
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .lineLimit(1)
                .foregroundStyle(text)
                .padding(.horizontal, 12).padding(.vertical, 5)
                .background(Capsule().fill(fill))
                .opacity(configuration.isPressed ? 0.7 : 1)
                .contentShape(Capsule())
        }
    }
}

/// Small uppercase title above a card's content.
@MainActor
struct SectionTitle: View {
    let text: String
    var systemImage: String? = nil

    var body: some View {
        HStack(spacing: 5) {
            if let systemImage { Image(systemName: systemImage).font(.system(size: 9, weight: .bold)) }
            Text(text.uppercased())
        }
        .font(.system(size: 10, weight: .bold, design: .rounded))
        .tracking(0.6)
        .foregroundStyle(.secondary)
    }
}

/// A round icon button for card corners (Bonuses, recap).
@MainActor
struct CircleIconButton: View {
    let systemImage: String
    let help: String
    var tint: Color = .secondary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 26, height: 26)
                .background(Circle().fill(Color.primary.opacity(0.07)))
        }
        .buttonStyle(.plain)
        .hoverTip(help)
        .accessibilityLabel(help)
    }
}

extension CompanionStore {
    /// The colors of the Pokémon being raised, two for a dual type: what the hero card blends. Gold for the egg.
    var themeColors: [Color] {
        // An egg: the type it guarantees, like a Pokémon's card; otherwise the egg's own color.
        guard hasActive, let id = currentSpeciesID else { return [eggTypeGuarantee?.color ?? Design.eggColor] }
        let colors = PokemonTypeData.types(forSpeciesID: id, form: currentForm).prefix(2).map(\.color)
        return colors.isEmpty ? [Design.eggColor] : Array(colors)
    }
}

extension ButtonStyle where Self == PillButtonStyle {
    /// A capsule button in `Design.actionColor`: Buy, Use, Claim and their secondary actions.
    static func pill(prominent: Bool = false) -> PillButtonStyle { PillButtonStyle(prominent: prominent) }
}
