import AppKit
import SwiftUI
import XCTest
@testable import PokeTokenBar

/// The egg is drawn in the app, like the 3D sprites: its look follows its guarantee, and it idles in a loop.
@MainActor
final class DrawnEggTests: XCTestCase {
    private func pixels(_ image: NSImage) throws -> NSBitmapImageRep {
        NSBitmapImageRep(cgImage: try XCTUnwrap(image.cgImage(forProposedRect: nil, context: nil, hints: nil)))
    }

    /// The average color of the egg's opaque pixels.
    private func averageColor(_ image: NSImage) throws -> (r: Double, g: Double, b: Double) {
        let rep = try pixels(image)
        var sum = (0.0, 0.0, 0.0), count = 0.0
        for y in 0..<rep.pixelsHigh {
            for x in 0..<rep.pixelsWide {
                guard let c = rep.colorAt(x: x, y: y)?.usingColorSpace(.sRGB), c.alphaComponent > 0.5 else { continue }
                sum.0 += c.redComponent; sum.1 += c.greenComponent; sum.2 += c.blueComponent
                count += 1
            }
        }
        return (sum.0 / count, sum.1 / count, sum.2 / count)
    }

    func testTheGuaranteeDecidesTheEgg() {
        XCTAssertEqual(EggKind(tier: nil), .plain)
        XCTAssertEqual(EggKind(tier: .rare), .tier(.rare))
        XCTAssertEqual(EggKind(tier: .uncommon, type: .fire), .type(.fire), "a type egg shows its type")
        XCTAssertTrue(EggKind.tier(.uncommon).isColoredShell)
        XCTAssertFalse(EggKind.plain.isColoredShell)
        XCTAssertFalse(EggKind.type(.water).isColoredShell)
        XCTAssertNotNil(EggKind.tier(.rare).glow)
        XCTAssertNil(EggKind.plain.glow)
        XCTAssertNil(EggKind.type(.grass).glow)
    }

    func testTheStoreIncubatesItsGuaranteesEgg() throws {
        let suite = "DrawnEgg-\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("\(suite).json")
        defer { try? FileManager.default.removeItem(at: file) }
        var state = CompanionState()
        state.installBaselineSet = true
        state.eggTier = .rare
        try JSONEncoder().encode(state).write(to: file)
        let rare = CompanionStore(provider: PokeAPIClient.shared, fileURL: file, defaults: defaults)
        XCTAssertEqual(rare.eggKind, .tier(.rare))

        state.eggTier = nil
        state.eggTypeGuarantee = .water
        try JSONEncoder().encode(state).write(to: file)
        XCTAssertEqual(CompanionStore(provider: PokeAPIClient.shared, fileURL: file, defaults: defaults).eggKind,
                       .type(.water))
    }

    /// An egg shape at the sprites' density: opaque in the middle, empty in the corners, a darker outline.
    func testTheStillIsAnEggAtTheSpritesDensity() throws {
        let still = EggRenderer.still(.plain)
        XCTAssertEqual(still.size, NSSize(width: EggRenderer.pixels, height: EggRenderer.pixels))
        XCTAssertTrue(EggRenderer.still(.plain) === still, "rendered once")
        let rep = try pixels(still)
        let middle = try XCTUnwrap(rep.colorAt(x: rep.pixelsWide / 2, y: rep.pixelsHigh / 2))
        XCTAssertEqual(middle.alphaComponent, 1, accuracy: 0.01)
        for (x, y) in [(0, 0), (rep.pixelsWide - 1, 0), (0, rep.pixelsHigh - 1), (rep.pixelsWide - 1, rep.pixelsHigh - 1)] {
            XCTAssertEqual(rep.colorAt(x: x, y: y)?.alphaComponent ?? 0, 0, accuracy: 0.01)
        }
        // Narrower at the top than at the bottom, like an egg.
        func width(atRow y: Int) -> Int {
            (0..<rep.pixelsWide).filter { (rep.colorAt(x: $0, y: y)?.alphaComponent ?? 0) > 0.5 }.count
        }
        let rows = (0..<rep.pixelsHigh).filter { width(atRow: $0) > 0 }
        let top = try XCTUnwrap(rows.first), bottom = try XCTUnwrap(rows.last)
        let quarter = (bottom - top) / 4
        XCTAssertLessThan(width(atRow: top + quarter), width(atRow: bottom - quarter))
        // Hard edges: every pixel is egg or empty, no half-transparent ones.
        for y in 0..<rep.pixelsHigh {
            for x in 0..<rep.pixelsWide {
                let a = rep.colorAt(x: x, y: y)?.alphaComponent ?? 0
                XCTAssertTrue(a < 0.01 || a > 0.99, "pixel (\(x), \(y)) is \(a) opaque")
            }
        }
    }

    func testEachEggWearsItsColors() throws {
        let plain = try averageColor(EggRenderer.still(.plain))
        XCTAssertGreaterThan(plain.r, 0.6, "a light shell")
        XCTAssertGreaterThan(plain.g, plain.b, "cream with green spots")
        let rare = try averageColor(EggRenderer.still(.tier(.rare)))
        XCTAssertGreaterThan(rare.b, rare.r + 0.2, "the rare egg's shell is blue")
        let uncommon = try averageColor(EggRenderer.still(.tier(.uncommon)))
        XCTAssertGreaterThan(uncommon.g, uncommon.r + 0.1, "the uncommon egg's shell is green")
        let fire = try averageColor(EggRenderer.still(.type(.fire)))
        XCTAssertGreaterThan(fire.r - fire.g, plain.r - plain.g, "the fire egg burns")
    }

    /// The idle loop moves: frames differ, the loop repeats every couple of seconds.
    func testTheIdleLoopMoves() throws {
        let frames = EggRenderer.idleFrames(.plain)
        XCTAssertEqual(frames.count, EggRenderer.frameCount)
        XCTAssertEqual(frames.map(\.delay).reduce(0, +), 2.16, accuracy: 0.01)
        let first = try XCTUnwrap(try pixels(frames[0].image).bitmapData)
        let quarter = try XCTUnwrap(try pixels(frames[EggRenderer.frameCount / 4].image).bitmapData)
        let byteCount = EggRenderer.pixels * EggRenderer.pixels * 4
        XCTAssertNotEqual(Data(bytes: first, count: byteCount), Data(bytes: quarter, count: byteCount))
        // It turns on itself: from a quarter to three quarters of the loop the spots slide sideways, not only up
        // and down.
        func spotsCenterX(_ image: NSImage) throws -> Double {
            let rep = try pixels(image)
            var sum = 0.0, count = 0.0
            for y in 0..<rep.pixelsHigh {
                for x in 0..<rep.pixelsWide {
                    guard let c = rep.colorAt(x: x, y: y)?.usingColorSpace(.sRGB), c.alphaComponent > 0.5,
                          c.greenComponent > c.redComponent + 0.15 else { continue }
                    sum += Double(x); count += 1
                }
            }
            return sum / max(1, count)
        }
        let right = try spotsCenterX(frames[EggRenderer.frameCount / 4].image)
        let left = try spotsCenterX(frames[EggRenderer.frameCount * 3 / 4].image)
        XCTAssertGreaterThan(abs(right - left), 2, "the spots turn with the egg")
    }

    /// The Type: Null Egg hatches in its own egg (`EggDesignsTests`). A plain egg that pre-rolled Type: Null stays a plain
    /// egg: the roll is not given away. An older save, without the mark, has a plain egg.
    func testTheTypeNullEggIsItsOwn() throws {
        func store(_ edit: (inout CompanionState) -> Void) throws -> CompanionStore {
            let suite = "TypeNullEgg-\(UUID())"
            let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
            addTeardownBlock { defaults.removePersistentDomain(forName: suite) }
            let file = FileManager.default.temporaryDirectory.appendingPathComponent("\(suite).json")
            addTeardownBlock { try? FileManager.default.removeItem(at: file) }
            var state = CompanionState()
            state.installBaselineSet = true
            edit(&state)
            try JSONEncoder().encode(state).write(to: file)
            return CompanionStore(provider: PokeAPIClient.shared, fileURL: file, defaults: defaults)
        }
        let raising = try store {
            $0.active = MonState(baseID: 4, pathIDs: [4], plannedPathIDs: [4], stageIndex: 0, usedAtStage: 0,
                                 rarity: .common, totalForms: 1, nature: .hardy)
            $0.inventory[ItemKind.typeNullEgg.rawValue] = 1
        }
        XCTAssertTrue(raising.useTypeNullEgg())
        XCTAssertEqual(raising.eggKind, .typeNull)
        XCTAssertTrue(raising.buyEgg(nil) == false || raising.eggKind != .typeNull, "a new egg is not the Type: Null one")

        let preRolled = try store { $0.pendingHatchID = PokemonForm.typeNullSpeciesID }
        XCTAssertEqual(preRolled.eggKind, .plain, "a plain egg that pre-rolled Type: Null")

        let older = try JSONDecoder().decode(CompanionState.self, from: JSONEncoder().encode(CompanionState()))
        XCTAssertFalse(older.eggFromTypeNullEgg)
    }

    /// Home's card behind an egg takes the type it guarantees, as a Pokémon's takes its own; another egg keeps the
    /// egg's color.
    func testATypeEggTintsItsCard() throws {
        func store(_ edit: (inout CompanionState) -> Void) throws -> CompanionStore {
            let suite = "EggTint-\(UUID())"
            let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
            addTeardownBlock { defaults.removePersistentDomain(forName: suite) }
            let file = FileManager.default.temporaryDirectory.appendingPathComponent("\(suite).json")
            addTeardownBlock { try? FileManager.default.removeItem(at: file) }
            var state = CompanionState()
            state.installBaselineSet = true
            edit(&state)
            try JSONEncoder().encode(state).write(to: file)
            return CompanionStore(provider: PokeAPIClient.shared, fileURL: file, defaults: defaults)
        }
        XCTAssertEqual(try store { $0.eggTypeGuarantee = .fire }.themeColors, [PokemonType.fire.color])
        XCTAssertEqual(try store { $0.eggTier = .rare }.themeColors, [Design.eggColor])
        XCTAssertEqual(try store { _ in }.themeColors, [Design.eggColor])
    }

    func testAnotherEggIsAnotherTask() {
        XCTAssertNotEqual(SpriteView.frameTaskID(speciesID: nil, shiny: false, floor: 0, egg: .plain),
                          SpriteView.frameTaskID(speciesID: nil, shiny: false, floor: 0, egg: .tier(.rare)))
        XCTAssertEqual(SpriteView.frameTaskID(speciesID: 25, shiny: false, floor: 0, egg: .plain),
                       SpriteView.frameTaskID(speciesID: 25, shiny: false, floor: 0, egg: .tier(.rare)),
                       "a Pokémon ignores the egg")
    }

    /// The view draws the guaranteed egg, not the old pixel egg nor the 🥚 glyph.
    func testSpriteViewDrawsTheGuaranteedEgg() async throws {
        // Still (the shop) and animated (Home, the pet): each must draw the guaranteed egg.
        for animated in [false, true] {
            try await assertDrawsTheRareEgg(animated: animated)
        }
    }

    private func assertDrawsTheRareEgg(animated: Bool) async throws {
        let view = SpriteView(speciesID: nil, size: 80, animated: animated, egg: .tier(.rare))
            .frame(width: 80, height: 80).background(Color.black)
        let host = NSHostingView(rootView: view)
        host.frame = NSRect(x: 0, y: 0, width: 80, height: 80)
        let window = NSWindow(contentRect: NSRect(x: -10000, y: -10000, width: 80, height: 80),
                              styleMask: .borderless, backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = host
        window.orderFront(nil)
        defer { window.close() }
        try await Task.sleep(for: .milliseconds(200))
        host.layoutSubtreeIfNeeded()
        let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
        host.cacheDisplay(in: host.bounds, to: bitmap)
        // The egg's pixels on the black background: blue overall, cream spots and all.
        var sum = (r: 0.0, b: 0.0), count = 0.0
        for y in 0..<bitmap.pixelsHigh {
            for x in 0..<bitmap.pixelsWide {
                guard let c = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.sRGB),
                      c.redComponent + c.greenComponent + c.blueComponent > 0.45 else { continue }
                sum.r += c.redComponent; sum.b += c.blueComponent; count += 1
            }
        }
        XCTAssertGreaterThan(count, 500, "animated \(animated): an egg is drawn")
        XCTAssertGreaterThan(sum.b / count, sum.r / count + 0.2, "animated \(animated): the rare egg's blue shell")
    }
}
