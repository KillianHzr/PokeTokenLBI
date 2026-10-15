import AppKit
import SwiftUI
import XCTest
@testable import PokeTokenBar

final class Gen7ScreenshotTests: XCTestCase {
    @MainActor
    func testGenerateGen7Screenshots() throws {
        guard let directory = ProcessInfo.processInfo.environment["PTB_SCREENSHOT_DIR"] else {
            throw XCTSkip("PTB_SCREENSHOT_DIR not set")
        }
        let outDir = URL(fileURLWithPath: directory)
        try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

        func makeCard(isBefore: Bool) -> some View {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(isBefore ? "Pokédex — Avant (Gen 1–6 uniquement)" : "Pokédex — Après (Gen 7 Alola débloquée)")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.primary)
                    Spacer()
                    Text(isBefore ? "Max: #721" : "Max: #809")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(isBefore ? Color.secondary.opacity(0.15) : Color.orange.opacity(0.2))
                        .foregroundStyle(isBefore ? Color.secondary : Color.orange)
                        .clipShape(Capsule())
                }

                if isBefore {
                    Text("Derniers Pokémon répertoriés (Gen 6 Kalos) :")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)

                    HStack(spacing: 8) {
                        let gen6Items: [(Int, String, String)] = [
                            (718, "Zygarde", "Dragon / Sol"),
                            (719, "Diancie", "Roche / Fée"),
                            (720, "Hoopa", "Psy / Spectre"),
                            (721, "Volcanion", "Feu / Eau")
                        ]
                        ForEach(gen6Items, id: \.0) { id, name, types in
                            VStack(spacing: 3) {
                                Text("#\(id)")
                                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                Text(name)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(.primary)
                                Text(types)
                                    .font(.system(size: 8))
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, minHeight: 56)
                            .background(Color.secondary.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }

                    Text("Les Pokémon d'Alola (#722+) et formes régionales sont tronqués.")
                        .font(.system(size: 10, weight: .regular))
                        .foregroundStyle(.secondary.opacity(0.8))
                } else {
                    Text("Nouveaux Pokémon d'Alola et formes régionales disponibles :")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        let gen7Items: [(String, String, String)] = [
                            ("#722", "Brindibou", "Plante / Vol"),
                            ("#727", "Félinferno", "Feu / Ténèbres"),
                            ("#741", "Plumeline", "4 styles"),
                            ("#745", "Lougaroc", "3 formes"),
                            ("#773", "Silvallié", "18 types"),
                            ("#778", "Mimiqui", "Spectre / Fée"),
                            ("#800", "Necrozma", "Psy"),
                            ("#809", "Melmetal", "Acier"),
                            ("#037", "Goupix d'Alola", "Glace"),
                            ("#026", "Raichu d'Alola", "Électrik / Psy"),
                            ("#103", "Noadkoko Alola", "Plante / Dragon"),
                            ("#105", "Ossatueur Alola", "Feu / Spectre")
                        ]
                        ForEach(gen7Items, id: \.0) { id, name, types in
                            VStack(spacing: 3) {
                                Text(id)
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                    .foregroundStyle(.orange)
                                Text(name)
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(.primary)
                                Text(types)
                                    .font(.system(size: 8))
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .background(Color.orange.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(Color.orange.opacity(0.2), lineWidth: 0.5)
                            )
                        }
                    }
                }
            }
            .padding(14)
            .frame(width: 440)
            .background(Color(red: 41 / 255, green: 41 / 255, blue: 42 / 255))
            .environment(\.colorScheme, .dark)
        }

        func captureView<V: View>(_ view: V) throws -> Data {
            let host = NSHostingController(rootView: view)
            host.view.setFrameSize(NSSize(width: 440, height: host.view.fittingSize.height))
            let window = NSWindow(contentRect: host.view.frame, styleMask: [.borderless], backing: .buffered, defer: false)
            window.appearance = NSAppearance(named: .darkAqua)
            window.contentView = host.view
            host.view.layoutSubtreeIfNeeded()
            window.displayIfNeeded()
            let bounds = host.view.bounds
            let rep = try XCTUnwrap(NSBitmapImageRep(
                bitmapDataPlanes: nil,
                pixelsWide: Int(bounds.width) * 2, pixelsHigh: Int(bounds.height) * 2,
                bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0))
            rep.size = bounds.size
            host.view.cacheDisplay(in: bounds, to: rep)
            return try XCTUnwrap(rep.representation(using: .png, properties: [:]))
        }

        let beforeData = try captureView(makeCard(isBefore: true))
        try beforeData.write(to: outDir.appendingPathComponent("before.png"))

        let afterData = try captureView(makeCard(isBefore: false))
        try afterData.write(to: outDir.appendingPathComponent("after.png"))
    }
}
