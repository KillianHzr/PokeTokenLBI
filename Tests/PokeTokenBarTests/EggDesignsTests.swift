import AppKit
import SwiftUI
import XCTest
@testable import PokeTokenBar

/// The rarer guarantees, the types and the Type: Null Egg are drawn by designs of their own: gems, flames, a stone, a
/// sand tomb… Every egg the app shows for them comes from their design, each its own, hard-edged like the sprites,
/// looping without a jump.
@MainActor
final class EggDesignsTests: XCTestCase {
    private static let designed: [EggKind] = [.tier(.uncommon), .tier(.rare), .tier(.legendary)]
        + PokemonType.allCases.map { .type($0) } + [.typeNull]

    /// The RGBA bytes of an image.
    private func bytes(_ image: CGImage) throws -> [UInt8] {
        let rep = NSBitmapImageRep(cgImage: image)
        let data = try XCTUnwrap(rep.bitmapData)
        return Array(UnsafeBufferPointer(start: data, count: rep.bytesPerRow * rep.pixelsHigh))
    }

    private func bytes(_ image: NSImage) throws -> [UInt8] {
        try bytes(try XCTUnwrap(image.cgImage(forProposedRect: nil, context: nil, hints: nil)))
    }

    /// The renderer hands every designed kind its design, and only those: the plain egg keeps its spots.
    func testEveryGuaranteeHasItsOwnEgg() throws {
        var seen: [[UInt8]] = []
        for kind in Self.designed {
            XCTAssertNotNil(EggDesigns.design(for: kind), "\(kind)")
            let still = EggRenderer.still(kind)
            XCTAssertTrue(still === EggDesigns.still(kind), "\(kind) is drawn by its design")
            XCTAssertEqual(still.size, NSSize(width: EggDesigns.pixels, height: EggDesigns.pixels))
            let loop = EggRenderer.idleFrames(kind), designedLoop = try XCTUnwrap(EggDesigns.idleFrames(kind))
            XCTAssertEqual(loop.count, EggRenderer.frameCount)
            XCTAssertTrue(zip(loop, designedLoop).allSatisfy { $0.image === $1.image }, "\(kind) idles in its design")
            let pixels = try bytes(still)
            XCTAssertFalse(seen.contains(pixels), "\(kind) looks like another egg")
            seen.append(pixels)
        }
        XCTAssertNil(EggDesigns.still(.plain))
        XCTAssertEqual(EggRenderer.still(.plain).size, NSSize(width: EggRenderer.pixels, height: EggRenderer.pixels))
    }

    /// Like the sprites: every pixel opaque or empty, the egg in the middle, empty corners.
    func testEveryDesignIsHardEdged() throws {
        let n = EggDesigns.pixels
        for kind in Self.designed {
            let design = try XCTUnwrap(EggDesigns.design(for: kind))
            for phase in [0, Double.pi / 2, .pi, 3 * Double.pi / 2] {
                let pixels = try bytes(try XCTUnwrap(EggDesigns.render(design, phase: phase)))
                for i in stride(from: 3, to: pixels.count, by: 4) {
                    XCTAssertTrue(pixels[i] == 0 || pixels[i] == 255, "\(kind) at \(phase): a half-transparent pixel")
                }
                XCTAssertEqual(pixels[((n / 2) * n + n / 2) * 4 + 3], 255, "\(kind) at \(phase): the egg in the middle")
                for (x, y) in [(0, 0), (n - 1, 0), (0, n - 1), (n - 1, n - 1)] {
                    XCTAssertEqual(pixels[(y * n + x) * 4 + 3], 0, "\(kind) at \(phase): corner (\(x), \(y))")
                }
            }
        }
    }

    /// Each loop moves, and its end meets its start: flames, sand and embers scroll by whole periods over the loop.
    func testEveryLoopMovesAndClosesWithoutAJump() throws {
        for kind in Self.designed {
            let design = try XCTUnwrap(EggDesigns.design(for: kind))
            let start = try bytes(try XCTUnwrap(EggDesigns.render(design, phase: 0)))
            let quarter = try bytes(try XCTUnwrap(EggDesigns.render(design, phase: .pi / 2)))
            let end = try bytes(try XCTUnwrap(EggDesigns.render(design, phase: 2 * .pi)))
            func changed(_ a: [UInt8], _ b: [UInt8]) -> Int {
                stride(from: 0, to: a.count, by: 4).filter { a[$0..<$0 + 4] != b[$0..<$0 + 4] }.count
            }
            XCTAssertGreaterThan(changed(start, quarter), 40, "\(kind) moves")
            XCTAssertLessThanOrEqual(changed(start, end), 8, "\(kind): the loop's end meets its start")
        }
    }

    /// The Type: Null Egg is steel: gray, neither cream nor colored.
    func testTheTypeNullEggIsSteel() throws {
        let pixels = try bytes(EggRenderer.still(.typeNull))
        var sum = (0.0, 0.0, 0.0), count = 0.0
        for i in stride(from: 0, to: pixels.count, by: 4) where pixels[i + 3] == 255 {
            sum.0 += Double(pixels[i]); sum.1 += Double(pixels[i + 1]); sum.2 += Double(pixels[i + 2])
            count += 255
        }
        let (r, g, b) = (sum.0 / count, sum.1 / count, sum.2 / count)
        XCTAssertLessThan(max(r, g, b) - min(r, g, b), 0.1, "gray")
        XCTAssertLessThan(r, 0.75, "darker than the cream eggs")
    }

    /// The view draws a type's egg from its design, still (the shop) and animated (Home, the pet): the fire egg's
    /// black lava shell in its flames, not a cream egg with red spots.
    func testSpriteViewDrawsTheFireEgg() async throws {
        for animated in [false, true] {
            let view = SpriteView(speciesID: nil, size: 80, animated: animated, egg: .type(.fire))
                .frame(width: 80, height: 80).background(Color.white)
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
            // At 2× whatever the screen: CI's runners draw at 1×, a Retina Mac at 2×.
            let bitmap = try XCTUnwrap(NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 160, pixelsHigh: 160,
                bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                bytesPerRow: 0, bitsPerPixel: 0))
            bitmap.size = host.bounds.size
            host.cacheDisplay(in: host.bounds, to: bitmap)
            var flames = 0.0, lava = 0.0
            for y in 0..<bitmap.pixelsHigh {
                for x in 0..<bitmap.pixelsWide {
                    guard let c = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) else { continue }
                    if c.redComponent > 0.85, c.greenComponent > 0.4, c.blueComponent < 0.35 { flames += 1 }
                    if max(c.redComponent, c.greenComponent, c.blueComponent) < 0.35 { lava += 1 }
                }
            }
            // Shares of the box: about 10% flames and 8% lava; the spotted egg has 3 to 4.5% and about 1%.
            let pixels = Double(bitmap.pixelsWide * bitmap.pixelsHigh)
            XCTAssertGreaterThan(flames / pixels, 0.07, "animated \(animated): the fire egg's flames")
            XCTAssertGreaterThan(lava / pixels, 0.04, "animated \(animated): the fire egg's lava shell")
        }
    }
}
