import CoreGraphics
import Foundation

/// The dungeons' sprites (R15, validated 2026-10-30): one small diorama of voxels per dungeon, lit like the eggs (top
/// lit, sides in shade, the dark outline), drawn in code on the eggs' 64-pixel canvas, still.
enum DungeonSprites {
    typealias C = EggColor

    static func rgb(_ hex: Int) -> C {
        C(Double((hex >> 16) & 0xFF) / 255, Double((hex >> 8) & 0xFF) / 255, Double(hex & 0xFF) / 255)
    }

    static func h(_ i: Int, _ j: Int, _ seed: Int) -> Double { EggDesigns.hash(i, j, 0, seed: seed) }

    struct Vox { var x, y, z: Int; var top, left, right: C }

    /// Voxels on an 8 × 8 grid, x toward the right-back, z toward the left-back, y up.
    struct Scene {
        var map: [Int: Vox] = [:]
        var base = 34.0
        static let tw = 3.0, th = 1.5, vh = 3.0

        mutating func add(_ x: Int, _ y: Int, _ z: Int, _ c: C, left: C? = nil, right: C? = nil, glow: Bool = false) {
            let l = left ?? c.mixed(with: .black, glow ? 0.05 : 0.2)
            let r = right ?? c.mixed(with: .black, glow ? 0.12 : 0.38)
            map[x + 64 * (y + 64 * z) + 100_000] = Vox(x: x, y: y, z: z, top: glow ? c : c.mixed(with: .white, 0.1), left: l, right: r)
        }

        mutating func box(_ xs: ClosedRange<Int>, _ ys: ClosedRange<Int>, _ zs: ClosedRange<Int>, _ c: C) {
            for x in xs { for y in ys { for z in zs { add(x, y, z, c) } } }
        }

        /// Columns of ground up to a height per cell, the top voxel in `top`, the ones under it in `side`.
        mutating func ground(_ height: (Int, Int) -> Int, top: (Int, Int, Int) -> C, side: C) {
            for x in 0..<8 {
                for z in 0..<8 {
                    let hgt = height(x, z)
                    guard hgt > 0 else { continue }
                    for y in 0..<hgt { add(x, y, z, y == hgt - 1 ? top(x, z, y) : side.mixed(with: .black, h(x, z, 3) * 0.08)) }
                }
            }
        }

        func point(_ x: Double, _ z: Double, _ y: Double) -> (Double, Double) {
            (32 + (x - z) * Self.tw, base + (x + z) * Self.th - y * Self.vh)
        }

        func draw(_ canvas: inout EggCanvas) {
            let sorted = map.values.sorted { a, b in (a.x + a.z, a.y, a.x) < (b.x + b.z, b.y, b.x) }
            for v in sorted {
                let X = Double(v.x), Y = Double(v.y), Z = Double(v.z)
                let back = point(X, Z, Y + 1), right = point(X + 1, Z, Y + 1), front = point(X + 1, Z + 1, Y + 1), left = point(X, Z + 1, Y + 1)
                let frontLow = point(X + 1, Z + 1, Y), leftLow = point(X, Z + 1, Y), rightLow = point(X + 1, Z, Y)
                DungeonSprites.poly(&canvas, [left, front, frontLow, leftLow], v.left)
                DungeonSprites.poly(&canvas, [front, right, rightLow, frontLow], v.right)
                DungeonSprites.poly(&canvas, [back, right, front, left], v.top)
            }
        }
    }

    /// A polygon pushed out a little from its middle, so faces that share an edge leave no gap between them.
    static func poly(_ canvas: inout EggCanvas, _ points: [(Double, Double)], _ c: C) {
        let cx = points.map(\.0).reduce(0, +) / Double(points.count), cy = points.map(\.1).reduce(0, +) / Double(points.count)
        let grown = points.map { p -> (Double, Double) in
            let dx = p.0 - cx, dy = p.1 - cy, l = max(0.01, (dx * dx + dy * dy).squareRoot())
            return (p.0 + dx / l * 0.4, p.1 + dy / l * 0.4)
        }
        canvas.polygon(grown, c, shade: false)
    }

    static func water(_ x: Int, _ z: Int, _ phase: Double, _ c: C) -> C {
        c.mixed(with: .white, 0.22 * max(0, sin(Double(x) * 1.3 + Double(z) * 0.9 - phase * 2)))
    }

    static func flag(_ canvas: inout EggCanvas, _ x: Double, _ y: Double, _ phase: Double, _ c: C) {
        canvas.line(x, y, x, y - 9, width: 1, rgb(0x5A4A3A))
        let wave = 1.2 * sin(phase * 2)
        canvas.polygon([(x + 0.5, y - 9), (x + 7, y - 7.5 + wave), (x + 0.5, y - 5)], c)
    }

    // MARK: The dungeons

    /// Viridian Forest: grass, three firs and a bush; a Butterfree flutters over them.
    static func viridianForest(_ t: Double, _ canvas: inout EggCanvas) {
        let phase = 2 * Double.pi * t
        var s = Scene()
        s.ground({ x, z in x + z < 3 ? 2 : 1 }, top: { x, z, _ in rgb(0x6CC24A).mixed(with: rgb(0x4FA33A), h(x, z, 5)) }, side: rgb(0x8A5A30))
        for (x, z, hgt) in [(1, 1, 3), (5, 2, 2), (2, 5, 2)] {
            let ground = x + z < 3 ? 2 : 1
            for y in ground..<(ground + hgt) { s.add(x, y, z, rgb(0x7A4A24)) }
            let top = ground + hgt
            for dx in -1...1 { for dz in -1...1 where (0..<8).contains(x + dx) && (0..<8).contains(z + dz) { s.add(x + dx, top, z + dz, rgb(0x2F8A3A)) } }
            for (dx, dz) in [(0, 0), (1, 0), (-1, 0), (0, 1), (0, -1)] where (0..<8).contains(x + dx) && (0..<8).contains(z + dz) {
                s.add(x + dx, top + 1, z + dz, rgb(0x3B9E44))
            }
            s.add(x, top + 2, z, rgb(0x5BBE52))
        }
        s.box(6...7, 1...1, 6...6, rgb(0x3B9E44))
        s.draw(&canvas)
        // Butterfree: two pairs of wings beating, on a figure of eight over the trees.
        let bx = 32 + 14 * sin(phase), by = 14 + 4 * sin(phase * 2)
        let flap = abs(sin(phase * 4))
        canvas.ellipse(bx - 2.5, by, 2.6, 1 + 1.6 * flap, rgb(0xF2F2FA), gloss: 0.2)
        canvas.ellipse(bx + 2.5, by, 2.6, 1 + 1.6 * flap, rgb(0xF2F2FA), gloss: 0.2)
        canvas.ball(bx, by, 1.2, rgb(0x6E58C8), gloss: 0.3)
        canvas.outline(rgb(0x1E3A14))
    }

    /// Diglett's Cave: dirt, a rocky mound with the cave's mouth, three holes a Diglett pops out of in turn.
    static func diglettsCave(_ t: Double, _ canvas: inout EggCanvas) {
        let phase = 2 * Double.pi * t
        var s = Scene()
        s.ground({ _, _ in 1 }, top: { x, z, _ in rgb(0xC9945A).mixed(with: rgb(0xB07C46), h(x, z, 7)) }, side: rgb(0x8E5E33))
        for x in 0...3 { for z in 0...2 {
            let hgt = 1 + max(1, 4 - abs(x - 1) - abs(z - 1))
            for y in 1..<hgt { s.add(x, y, z, rgb(0x9C8A74).mixed(with: rgb(0x7E6E5C), h(x, y + z * 9, 11))) }
        } }
        // The cave's mouth on the mound's front left face.
        for x in 1...2 { for y in 1...2 { s.add(x, y, 2, rgb(0x9C8A74), left: rgb(0x1E120A)) } }
        let holes: [(Int, Int)] = [(5, 5), (6, 2), (2, 6)]
        for (x, z) in holes { s.add(x, 0, z, rgb(0x2A1A0E)) }
        s.draw(&canvas)
        for (k, (x, z)) in holes.enumerated() {
            let rise = max(0, sin(phase + Double(k) * 2.1))
            guard rise > 0.05 else { continue }
            let (px, py) = s.point(Double(x) + 0.5, Double(z) + 0.5, 1)
            let top = py - 1 - rise * 5
            canvas.fill(px - 2.6, top - 2.6, px + 2.6, py) { x, y in
                let dx = x - px, dy = y - top
                guard abs(dx) < 2.6, y < py, dy > -2.6 else { return nil }
                if dy < 0, dx * dx + dy * dy > 2.6 * 2.6 { return nil }
                return rgb(0x9C6A3A).mixed(with: .white, dx < -1 && dy < 0 ? 0.15 : 0)
            }
            canvas.ellipse(px, top + 1.6, 1.3, 0.9, rgb(0xF08AA8), gloss: 0.3)
            EggDesigns.light(&canvas, px - 1.2, top - 0.4, .black, behind: false)
            EggDesigns.light(&canvas, px + 1, top - 0.4, .black, behind: false)
        }
        canvas.outline(rgb(0x2E1B0C))
    }

    /// Mt. Moon: a grey mountain with a crater under a crescent moon, stars twinkling, a moon stone glinting.
    static func mtMoon(_ t: Double, _ canvas: inout EggCanvas) {
        let phase = 2 * Double.pi * t
        var s = Scene()
        s.base = 42
        s.ground({ x, z in
            let d = abs(Double(x) - 3.5) + abs(Double(z) - 3.5)
            let hgt = max(1, Int((9.5 - d * 1.9).rounded()))
            return d < 1.1 ? hgt - 1 : hgt
        }, top: { x, z, y in rgb(0xC4C4D4).mixed(with: rgb(0x8E8FA3), Double(8 - y) / 10 + h(x, z, 13) * 0.2) }, side: rgb(0x7E8094))
        s.draw(&canvas)
        let (gx, gy) = s.point(4.5, 5.5, 4)
        canvas.sparkle(gx, gy, 1 + 2 * max(0, sin(phase * 2)), rgb(0xD8E4FF))
        canvas.outline(rgb(0x2A2C3A))
        let mx = 52.0, my = 9.0
        canvas.fill(mx - 6, my - 6, mx + 6, my + 6) { x, y in
            let d1 = ((x - mx) * (x - mx) + (y - my) * (y - my)).squareRoot(), d2 = ((x - mx - 2.4) * (x - mx - 2.4) + (y - my + 1.5) * (y - my + 1.5)).squareRoot()
            return d1 < 5.5 && d2 > 4.6 ? rgb(0xFFE27A) : nil
        }
        for (i, (x, y)) in [(10.0, 8.0), (22, 4), (40, 10), (8, 22)].enumerated() {
            let tw = max(0, sin(phase * 2 + Double(i) * 1.7))
            if tw > 0.2 { EggDesigns.star(&canvas, x, y, tw > 0.7 ? 2 : 1, rgb(0xFFF3B0), behind: true) }
        }
    }

    /// Mt. Ember: a volcano of dark rock, lava glowing in its crater and running down its front, smoke and embers.
    static func mtEmber(_ t: Double, _ canvas: inout EggCanvas) {
        let phase = 2 * Double.pi * t
        var s = Scene()
        s.base = 38
        let lava = rgb(0xFF7A1A), hot = rgb(0xFFC23A)
        s.ground({ x, z in
            let d = ((Double(x) - 3.5) * (Double(x) - 3.5) + (Double(z) - 3.5) * (Double(z) - 3.5)).squareRoot()
            return max(1, Int((7.6 - d * 1.7).rounded()))
        }, top: { x, z, _ in rgb(0x5A4640).mixed(with: rgb(0x3E302C), h(x, z, 17)) }, side: rgb(0x3A2C29))
        for x in 3...4 { for z in 3...4 { s.add(x, 6, z, lava.mixed(with: hot, max(0, sin(phase * 2 + Double(x + z)))), glow: true) } }
        // The flow: down the front, its light running down.
        for (k, (x, z)) in [(4, 5), (5, 5), (5, 6), (6, 6), (6, 7)].enumerated() {
            let d = ((Double(x) - 3.5) * (Double(x) - 3.5) + (Double(z) - 3.5) * (Double(z) - 3.5)).squareRoot()
            let y = max(0, Int((7.6 - d * 1.7).rounded()) - 1)
            s.add(x, y, z, lava.mixed(with: hot, max(0, sin(Double(k) * 1.2 - phase * 2))), glow: true)
        }
        s.draw(&canvas)
        canvas.outline(rgb(0x22140F))
        let (cx, cy) = s.point(4, 4, 7)
        for k in 0..<3 {
            let age = (t + Double(k) / 3).truncatingRemainder(dividingBy: 1)
            canvas.ball(cx - 2 + age * 6, cy - 3 - age * 16, 2 + age * 3, rgb(0xB5ACA6).mixed(with: rgb(0x6E6460), age), gloss: 0)
        }
        for i in 0..<5 {
            let age = (t * 2 + h(i, 1, 21)).truncatingRemainder(dividingBy: 1)
            EggDesigns.light(&canvas, cx + (h(i, 0, 21) - 0.5) * 18 * age, cy - age * 20, age < 0.5 ? hot : lava, behind: true)
        }
    }

    /// Victory Road: rocky ground, a cliff behind, the stone gate of the Pokémon League with its banner waving.
    static func victoryRoad(_ t: Double, _ canvas: inout EggCanvas) {
        let phase = 2 * Double.pi * t
        var s = Scene()
        s.ground({ x, z in x == 0 && z == 0 ? 4 : (x == 0 || z == 0 ? 2 : 1) }, top: { x, z, y in
            y == 0 && (x == 3 || x == 4) ? rgb(0xE2D6BC) : rgb(0xB8A27E).mixed(with: rgb(0x9C8A6C), h(x, z, 23))
        }, side: rgb(0x8C7A5E))
        let stone = rgb(0xDCD2BE)
        for y in 1...6 { s.add(2, y, 4, stone); s.add(5, y, 4, stone) }
        for x in 2...5 { s.add(x, 7, 4, stone.mixed(with: .white, 0.15)) }
        s.draw(&canvas)
        let (fx, fy) = s.point(4, 4.5, 8)
        flag(&canvas, fx, fy, phase, rgb(0xE04848))
        canvas.outline(rgb(0x2E2618))
        let (lx, ly) = s.point(3.5, 5, 7.5)
        EggDesigns.star(&canvas, lx, ly, max(0, sin(phase * 2)) > 0.5 ? 2 : 1, rgb(0xFFE38A), behind: true)
    }

    /// Pokémon Tower: a tall purple tower, its windows flickering, gravestones at its foot, a Gastly floating round it.
    static func pokemonTower(_ t: Double, _ canvas: inout EggCanvas) {
        let phase = 2 * Double.pi * t
        var s = Scene()
        s.base = 40
        s.ground({ _, _ in 1 }, top: { x, z, _ in rgb(0x6E6280).mixed(with: rgb(0x5A4F6A), h(x, z, 29)) }, side: rgb(0x4A4058))
        for y in 1...8 { for x in 2...4 { for z in 2...4 { s.add(x, y, z, rgb(0x8A6FB0).mixed(with: rgb(0x7A60A0), h(x + y, z, 31))) } } }
        for (x, y, z) in [(4, 3, 4), (3, 6, 4), (4, 5, 3), (4, 7, 2)] {
            let on = sin(phase * 3 + Double(x * 3 + y)) > -0.3
            s.add(x, y, z, rgb(0x8A6FB0), left: z == 4 && on ? rgb(0xFFD86B) : nil, right: x == 4 && on ? rgb(0xF0C050) : nil)
        }
        s.box(2...4, 9...9, 2...4, rgb(0x4B3A66))
        s.add(3, 10, 3, rgb(0x4B3A66))
        for (x, z) in [(6, 1), (1, 6), (6, 6)] { s.add(x, 1, z, rgb(0xA8A4B4)) }
        s.draw(&canvas)
        let (tx, ty) = s.point(3.5, 3.5, 11)
        canvas.line(tx, ty, tx, ty - 5, width: 1, rgb(0x4B3A66))
        canvas.outline(rgb(0x1E1628))
        // Gastly: a dark ball in a ragged violet haze, going round the tower.
        let a = phase
        let gx = 32 + cos(a) * 20, gy = 22 + sin(a) * 6
        canvas.fill(gx - 6, gy - 6, gx + 6, gy + 6) { x, y in
            let d = ((x - gx) * (x - gx) + (y - gy) * (y - gy)).squareRoot()
            let ragged = 4.6 + 1.2 * sin(atan2(y - gy, x - gx) * 5 + phase * 3)
            return d < ragged && d > 3.2 && (Int(x) + Int(y)).isMultiple(of: 2) ? rgb(0xB48CE6) : nil
        }
        canvas.ball(gx, gy, 3.2, rgb(0x3A2850), gloss: 0.4)
        EggDesigns.light(&canvas, gx - 1.5, gy - 0.5, .white, behind: false)
        EggDesigns.light(&canvas, gx + 1.2, gy - 0.5, .white, behind: false)
    }

    /// Dragon's Den: a cave of dark rock round a deep pool, a wooden shrine on its islet, a Dratini rising from the
    /// water.
    static func dragonsDen(_ t: Double, _ canvas: inout EggCanvas) {
        let phase = 2 * Double.pi * t
        var s = Scene()
        s.base = 38
        let rock = rgb(0x4E586E), rockDark = rgb(0x3A4254)
        s.ground({ x, z in
            if x == 0 && z == 0 { return 5 }
            if x == 0 || z == 0 { return 2 + Int(h(x, z, 81) * 2) }
            if x == 7 || z == 7 { return 1 + Int(h(x, z, 82) * 2) }
            if (3...4).contains(x), (3...4).contains(z) { return 2 }
            return 1
        }, top: { x, z, y in
            if y == 0 { return water(x, z, phase, rgb(0x23607F)) }
            if (3...4).contains(x), (3...4).contains(z), y == 1 { return rgb(0x8C8A80) }
            return rock.mixed(with: rgb(0x66708A), h(x, z, 83) * 0.5)
        }, side: rockDark)
        // A two-tiered pagoda: wooden posts and walls, tiled roofs of green-blue, gold at their corners and on top.
        let wood = rgb(0xA0623A), tiles = rgb(0x2F7A6A), gold = rgb(0xD8AE45)
        for y in 2...3 { for x in 3...4 { for z in 3...4 { s.add(x, y, z, wood, left: z == 4 && y == 3 ? rgb(0x3A2418) : nil, right: x == 4 && y == 3 ? rgb(0x2E1C12) : nil) } } }
        s.box(2...5, 4...4, 2...5, tiles)
        for (x, z) in [(2, 2), (5, 2), (2, 5), (5, 5)] { s.add(x, 4, z, gold) }
        s.box(3...4, 5...5, 3...4, wood)
        s.box(3...4, 6...6, 3...4, tiles.mixed(with: .white, 0.08))
        s.draw(&canvas)
        let (sx, sy) = s.point(4, 4, 7)
        canvas.line(sx, sy, sx, sy - 4, width: 1.2, gold)
        canvas.ball(sx, sy - 4.5, 1.1, gold, gloss: 0.6)
        // Dratini: its neck rising out of the water in front, swaying, a white snout and its white ear fins.
        let (bx, by) = s.point(1.6, 5, 1)
        let sway = 1.5 * sin(phase)
        var head = (bx, by)
        for k in 0..<5 {
            let u = Double(k) / 4
            let x = bx - 2 * u + sway * u, y = by - 1 - u * 11
            canvas.ball(x, y, 2.4 - u * 0.4, rgb(0x5E8FE6), gloss: 0.5)
            head = (x, y)
        }
        canvas.ball(head.0 + 1.8, head.1 + 0.6, 1.3, rgb(0xF2F4FA), gloss: 0.3)
        canvas.polygon([(head.0 - 1.5, head.1 - 1), (head.0 - 4.5, head.1 - 3.5), (head.0 - 2.5, head.1 + 0.5)], rgb(0xF2F4FA))
        EggDesigns.light(&canvas, head.0 + 0.5, head.1 - 0.8, rgb(0x1A1A2A), behind: false)
        canvas.ellipse(bx, by + 0.5, 4, 1.2, rgb(0x9CC8E8), flat: true)
        canvas.outline(rgb(0x141A26))
    }

    /// Power Plant: a power plant, its chimney and pylon, lit windows, lightning leaping between them.
    static func powerPlant(_ t: Double, _ canvas: inout EggCanvas) {
        let phase = 2 * Double.pi * t
        var s = Scene()
        s.base = 38
        s.ground({ _, _ in 1 }, top: { x, z, _ in rgb(0x9DA4AC).mixed(with: rgb(0x8A9199), h(x, z, 41)) }, side: rgb(0x6E757E))
        for x in 1...4 { for z in 1...4 { for y in 1...4 {
            let window = (y == 2 || y == 3) && (z == 4 || x == 4) && (x + z + y).isMultiple(of: 2)
            let lit = sin(phase * 2 + Double(x + y)) > 0
            s.add(x, y, z, rgb(0xB9C0C8), left: window && z == 4 ? (lit ? rgb(0xFFE16B) : rgb(0x5C6470)) : nil,
                  right: window && x == 4 ? (lit ? rgb(0xF2CC4A) : rgb(0x4E5560)) : nil)
        } } }
        for y in 5...8 { s.add(2, y, 2, rgb(0x7A818A)) }
        for y in 1...6 { s.add(6, y, 6, rgb(0x6E757E)) }
        s.add(6, 7, 6, rgb(0xFFD23F), glow: true)
        s.draw(&canvas)
        canvas.outline(rgb(0x20252C))
        let frame = EggDesigns.loopFrame(t)
        if frame % 6 < 3 {
            let a = s.point(6.5, 6.5, 7.5), b = s.point(4.5, 4.5, 5)
            var points: [(Double, Double)] = [a]
            for k in 1..<5 {
                let u = Double(k) / 5
                points.append((a.0 + (b.0 - a.0) * u + (h(frame, k, 43) - 0.5) * 5, a.1 + (b.1 - a.1) * u + (h(frame, k, 44) - 0.5) * 3))
            }
            points.append(b)
            canvas.path(points, width: 2.2, rgb(0xFFD23F))
            canvas.path(points, width: 1, rgb(0xFFFBE0))
        }
        let (cx, cy) = s.point(2.5, 2.5, 9)
        canvas.ball(cx + 1, cy - 2 - t * 6, 2 + t * 2, rgb(0xC9CDD3).mixed(with: rgb(0x9DA4AC), t), gloss: 0)
    }

    // MARK: The villains' hideouts (issue #180, the owner, 2026-11-10: "design l'icône de donjon de chaque team")

    static func hideout(_ team: VillainTeam) -> (Double, inout EggCanvas) -> Void {
        switch team {
        case .skull: skullHideout
        case .magma: magmaHideout
        case .aqua: aquaHideout
        case .galactic: galacticHideout
        case .rocket: rocketHideout
        }
    }

    /// Team Skull's Shady House: a run-down mansion on wet asphalt, its broken roof, a white skull sprayed on its front,
    /// a fence round it, rain falling.
    static func skullHideout(_ t: Double, _ canvas: inout EggCanvas) {
        let phase = 2 * Double.pi * t
        var s = Scene()
        s.base = 38
        s.ground({ _, _ in 1 }, top: { x, z, _ in
            (x + z) % 5 == 0 ? rgb(0x4A5A6E) : rgb(0x3A3F48).mixed(with: rgb(0x30343C), h(x, z, 91))
        }, side: rgb(0x2A2D33))
        let wall = rgb(0x6E6A7A), dark = rgb(0x4A4656)
        for x in 1...5 { for z in 1...5 { for y in 1...4 {
            let window = y == 3 && (x == 5 || z == 5) && (x + z).isMultiple(of: 2)
            s.add(x, y, z, wall.mixed(with: dark, h(x + y, z, 92) * 0.5),
                  left: window && z == 5 ? rgb(0x1E1A24) : nil, right: window && x == 5 ? rgb(0x18141E) : nil)
        } } }
        // A pitched roof, gaps where it fell in.
        for x in 1...5 { for z in 1...5 where !(x == 2 && z == 3) && !(x == 4 && z == 4) {
            s.add(x, 5, z, rgb(0x3A2E40))
        } }
        s.box(2...4, 6...6, 2...4, rgb(0x2E2434))
        for x in [0, 7] { for z in stride(from: 0, to: 8, by: 2) { s.add(x, 1, z, rgb(0x8A8A92)) } }
        for z in [0, 7] { for x in stride(from: 1, to: 8, by: 2) { s.add(x, 1, z, rgb(0x8A8A92)) } }
        s.draw(&canvas)
        // The skull, sprayed white on the left face.
        let (fx, fy) = s.point(2.6, 6, 3)
        canvas.ball(fx, fy, 3.2, rgb(0xF2F2F2), gloss: 0)
        canvas.polygon([(fx - 2, fy + 2), (fx + 2, fy + 2), (fx + 1.2, fy + 4.2), (fx - 1.2, fy + 4.2)], rgb(0xF2F2F2), shade: false)
        EggDesigns.light(&canvas, fx - 1.2, fy - 0.2, rgb(0x14101A), behind: false)
        EggDesigns.light(&canvas, fx + 1.2, fy - 0.2, rgb(0x14101A), behind: false)
        canvas.outline(rgb(0x121016))
        for k in 0..<9 {
            let x = (Double(k) * 7.3).truncatingRemainder(dividingBy: 60) + 2
            let y = (Double(k) * 13 + t * 64).truncatingRemainder(dividingBy: 50)
            canvas.line(x, y, x - 1, y + 3, width: 0.7, rgb(0x9DB4D0))
        }
        _ = phase
    }

    /// Team Magma's hideout: inside a volcano's dark rock, a steel door with a red light, lava glowing in the cracks,
    /// smoke rising.
    static func magmaHideout(_ t: Double, _ canvas: inout EggCanvas) {
        let phase = 2 * Double.pi * t
        var s = Scene()
        s.base = 40
        s.ground({ x, z in max(1, 6 - max(abs(x - 3), abs(z - 3)) - (x + z) / 6) }, top: { x, z, y in
            let crack = (x * 3 + z * 5) % 7 == 0
            let glow = 0.5 + 0.5 * sin(phase * 2 + Double(x + z))
            return crack ? rgb(0xFF6A1A).mixed(with: rgb(0xFFC23A), glow * 0.6) : rgb(0x4A2A26).mixed(with: rgb(0x3A1E1C), h(x, z, 101))
        }, side: rgb(0x2E1816))
        s.draw(&canvas)
        // The door in the slope, its red lamp blinking, the Magma's triangle above it.
        let (dx, dy) = s.point(4.2, 7, 2)
        canvas.polygon([(dx - 4, dy - 6), (dx + 3, dy - 3.5), (dx + 3, dy + 2.5), (dx - 4, dy)], rgb(0x6E7076))
        canvas.line(dx - 0.5, dy - 4.6, dx - 0.5, dy + 1.2, width: 0.8, rgb(0x3A3C42))
        canvas.polygon([(dx - 1.5, dy - 10), (dx + 1.8, dy - 8.6), (dx - 0.3, dy - 6.4)], rgb(0xE0342A))
        if sin(phase * 4) > 0 { canvas.ball(dx + 2.2, dy - 6.5, 1, rgb(0xFF3A2A), gloss: 0.6) }
        canvas.outline(rgb(0x140A08))
        let (cx, cy) = s.point(3.5, 3.5, 7)
        canvas.ball(cx, cy - 2 - t * 7, 2.2 + t * 2, rgb(0x8A7E7A).mixed(with: rgb(0x5A504C), t), gloss: 0)
    }

    /// Team Aqua's hideout: a sea cave in dark rock, its submarine at the dock, the water rippling, a blue flag.
    static func aquaHideout(_ t: Double, _ canvas: inout EggCanvas) {
        let phase = 2 * Double.pi * t
        var s = Scene()
        s.base = 38
        s.ground({ x, z in
            if x <= 1 || z <= 1 { return 3 + Int(h(x, z, 111) * 2) }
            if x == 2 || z == 2 { return 2 }
            return 1
        }, top: { x, z, y in
            y == 0 ? water(x, z, phase, rgb(0x1E5A8C)) : rgb(0x3E4A5A).mixed(with: rgb(0x2E3846), h(x, z, 112))
        }, side: rgb(0x26303C))
        // The cave's mouth, a dark arch in the back wall.
        s.add(1, 3, 4, rgb(0x3E4A5A), left: rgb(0x0E141C))
        s.add(1, 3, 5, rgb(0x3E4A5A), left: rgb(0x0E141C))
        // The submarine: a blue hull with a white band, its tower.
        for x in 3...6 { s.add(x, 1, 5, rgb(0x2E6FD0), left: rgb(0xF0F4FA)) }
        s.add(4, 2, 5, rgb(0x2E6FD0))
        s.add(4, 3, 5, rgb(0x2458B0))
        s.draw(&canvas)
        let (fx, fy) = s.point(1, 1, 6)
        flag(&canvas, fx, fy, phase, rgb(0x2A7AE6))
        canvas.outline(rgb(0x0C1420))
    }

    /// Team Galactic's headquarters: a tower of steel and glass, its round top, the yellow G of the team over the door.
    static func galacticHideout(_ t: Double, _ canvas: inout EggCanvas) {
        let phase = 2 * Double.pi * t
        var s = Scene()
        s.base = 42
        s.ground({ _, _ in 1 }, top: { x, z, _ in rgb(0x8E98A4).mixed(with: rgb(0x7A8490), h(x, z, 121)) }, side: rgb(0x5E6670))
        for x in 2...5 { for z in 2...5 { for y in 1...7 {
            let glass = (y % 2 == 0) && (x == 5 || z == 5)
            let lit = sin(phase * 2 + Double(y + x)) > 0.2
            s.add(x, y, z, rgb(0xB8C4D0), left: glass && z == 5 ? (lit ? rgb(0x7FE0FF) : rgb(0x4A8AA8)) : nil,
                  right: glass && x == 5 ? (lit ? rgb(0x66C8EA) : rgb(0x3E7894)) : nil)
        } } }
        s.box(3...4, 8...8, 3...4, rgb(0x5AB8D8))
        for (x, z) in [(1, 6), (6, 1)] { for y in 1...2 { s.add(x, y, z, rgb(0x6E7884)) } }
        s.draw(&canvas)
        // The G, yellow on the front.
        let (gx, gy) = s.point(3.6, 6, 3)
        for k in 0..<10 {
            let a = Double.pi * 0.25 + Double(k) / 9 * Double.pi * 1.6
            canvas.ball(gx + cos(a) * 2.6, gy + sin(a) * 2.6, 0.75, rgb(0xFFD23A), gloss: 0)
        }
        canvas.line(gx, gy, gx + 2.4, gy, width: 1.2, rgb(0xFFD23A))
        canvas.outline(rgb(0x1A2028))
        let (tx, ty) = s.point(3.5, 3.5, 9)
        canvas.ball(tx, ty, 1 + 0.4 * sin(phase * 3), rgb(0xFFF2A0), gloss: 0.8)
    }

    /// Team Rocket's hideout: a dark building, the big red R on its front, a searchlight sweeping the sky, a guard rail.
    static func rocketHideout(_ t: Double, _ canvas: inout EggCanvas) {
        let phase = 2 * Double.pi * t
        var s = Scene()
        s.base = 40
        s.ground({ _, _ in 1 }, top: { x, z, _ in rgb(0x4A4E56).mixed(with: rgb(0x3E4249), h(x, z, 131)) }, side: rgb(0x30333A))
        for x in 1...5 { for z in 1...5 { for y in 1...6 {
            let window = y == 5 && (x == 5 || z == 5) && (x + z).isMultiple(of: 2)
            s.add(x, y, z, rgb(0x3A3A44).mixed(with: rgb(0x2E2E38), h(x + y, z, 132)),
                  left: window && z == 5 ? rgb(0xD8343A) : nil, right: window && x == 5 ? rgb(0xB82A30) : nil)
        } } }
        s.box(1...5, 7...7, 1...5, rgb(0x2A2A32))
        s.add(5, 8, 5, rgb(0x8A8E96))
        for x in [0, 7] { for z in 0..<8 where z % 2 == 0 { s.add(x, 1, z, rgb(0xC8A43A)) } }
        s.draw(&canvas)
        // The R, red, painted on the left face.
        let (rx, ry) = s.point(2.4, 6, 4.2)
        let red = rgb(0xE8262E)
        canvas.line(rx - 2, ry - 4, rx - 2, ry + 4, width: 1.6, red)
        canvas.path([(rx - 2, ry - 4), (rx + 1.6, ry - 3.6), (rx + 2.2, ry - 1.6), (rx + 1.2, ry), (rx - 2, ry)], width: 1.6, red)
        canvas.line(rx - 0.2, ry, rx + 2.4, ry + 4, width: 1.6, red)
        canvas.outline(rgb(0x121218))
        // The searchlight, its beam sweeping.
        let (lx, ly) = s.point(5.5, 5.5, 9)
        let a = -Double.pi / 2 + 0.6 * sin(phase)
        canvas.polygon([(lx, ly), (lx + cos(a - 0.12) * 22, ly + sin(a - 0.12) * 22), (lx + cos(a + 0.12) * 22, ly + sin(a + 0.12) * 22)],
                       rgb(0xFFF4C0).mixed(with: .white, 0.3), shade: false)
        canvas.ball(lx, ly, 1.4, rgb(0xFFF4C0), gloss: 0.8)
    }

    /// A hideout's diorama, drawn once a team.
    @MainActor
    static func hideoutImage(_ team: VillainTeam) -> CGImage? {
        if let cached = hideoutCache[team] { return cached }
        var canvas = EggCanvas(size: 64)
        hideout(team)(0, &canvas)
        let image = canvas.image()
        hideoutCache[team] = image
        return image
    }

    @MainActor private static var hideoutCache: [VillainTeam: CGImage] = [:]

    /// A hideout's diorama cropped to what is drawn, for the menu bar.
    @MainActor
    static func trimmedHideoutImage(_ team: VillainTeam) -> CGImage? {
        if let cached = trimmedHideoutCache[team] { return cached }
        let trimmed = hideoutImage(team).flatMap(cropped)
        if let trimmed { trimmedHideoutCache[team] = trimmed }
        return trimmed
    }

    @MainActor private static var trimmedHideoutCache: [VillainTeam: CGImage] = [:]

    /// Seafoam Islands: the sea, two islands of ice, snow falling.
    static func seafoamIslands(_ t: Double, _ canvas: inout EggCanvas) {
        let phase = 2 * Double.pi * t
        var s = Scene()
        s.base = 36
        s.ground({ x, z in
            if (0...3).contains(x), (0...3).contains(z) { return 2 + max(0, 3 - abs(x - 1) - abs(z - 1)) }
            if (4...6).contains(x), (4...6).contains(z) { return 1 + max(0, 2 - abs(x - 5) - abs(z - 5)) }
            return 1
        }, top: { x, z, y in y == 0 ? water(x, z, phase, rgb(0x4F9BDB)) : rgb(0xF2FAFF) }, side: rgb(0xA9D8F5))
        s.draw(&canvas)
        canvas.outline(rgb(0x173A5E))
        for i in 0..<8 {
            let age = (t + h(i, 1, 47)).truncatingRemainder(dividingBy: 1)
            let x = 6 + h(i, 0, 47) * 52 + 2 * sin(age * 6 + Double(i)), y = 2 + age * 50
            if i % 3 == 0 { EggDesigns.star(&canvas, x, y, 1, .white, behind: true) } else { EggDesigns.light(&canvas, x, y, .white, behind: true) }
        }
    }

    /// Cerulean Cave: a blue rock, the cave's dark mouth, water glowing inside, psychic sparks.
    static func ceruleanCave(_ t: Double, _ canvas: inout EggCanvas) {
        let phase = 2 * Double.pi * t
        var s = Scene()
        s.base = 36
        s.ground({ x, z in
            if z >= 6 { return 1 }
            return 2 + max(0, 4 - abs(x - 3) / 2 - abs(z - 2))
        }, top: { x, z, y in y == 0 ? water(x, z, phase, rgb(0x3E78C8)) : rgb(0x7C8CB0).mixed(with: rgb(0x5E6C8E), h(x, z, 53)) },
                 side: rgb(0x55638A))
        for x in 2...4 { for y in 1...3 {
            let glow = rgb(0x5FD0FF).mixed(with: .white, 0.3 * max(0, sin(phase * 2 + Double(x))))
            s.add(x, y, 5, rgb(0x7C8CB0), left: y == 1 ? glow : rgb(0x0E1424))
        } }
        s.draw(&canvas)
        canvas.outline(rgb(0x141C34))
        for i in 0..<4 {
            let age = (t + Double(i) / 4).truncatingRemainder(dividingBy: 1)
            let (px, py) = s.point(3.5, 6.2, 2)
            let x = px - 8 + Double(i) * 5 + 2 * sin(age * 6), y = py - 2 - age * 18
            EggDesigns.star(&canvas, x, y, age > 0.3 && age < 0.7 ? 2 : 1, rgb(0xE0A8FF), behind: true)
        }
    }

    /// Mt. Coronet: the highest peak, snow from halfway up, the pillars at its top, clouds drifting past.
    static func mtCoronet(_ t: Double, _ canvas: inout EggCanvas) {
        var s = Scene()
        s.base = 44
        s.ground({ x, z in
            let d = ((Double(x) - 3.5) * (Double(x) - 3.5) + (Double(z) - 3.5) * (Double(z) - 3.5)).squareRoot()
            return max(1, Int((10.5 - d * 2.3).rounded()))
        }, top: { x, z, y in y >= 5 ? rgb(0xF4F7FF) : rgb(0x8A90A6).mixed(with: rgb(0x6E7488), h(x, z, 59)) }, side: rgb(0x6A7086))
        s.draw(&canvas)
        let (px, py) = s.point(4, 4, 10)
        for dx in [-3.0, 0, 3] { canvas.line(px + dx, py, px + dx, py - 5, width: 1.4, rgb(0xEDEFF7)) }
        canvas.line(px - 4, py - 5.5, px + 4, py - 5.5, width: 1.2, rgb(0xEDEFF7))
        canvas.outline(rgb(0x22263A))
        let drawn = canvas
        for k in 0..<2 {
            let x = -10 + ((t + Double(k) * 0.5).truncatingRemainder(dividingBy: 1)) * 84, y = 20 + Double(k) * 12
            for (dx, r) in [(-3.0, 2.5), (0, 3.4), (3.5, 2.6)] {
                canvas.fill(x + dx - r, y - r, x + dx + r, y + r) { px, py in
                    let d = ((px - x - dx) * (px - x - dx) + (py - y) * (py - y)).squareRoot()
                    return d < r && drawn.isEmpty(Int(px), Int(py)) ? rgb(0xE9EDF6) : nil
                }
            }
        }
    }

    /// Ruins of Alph: sand, broken columns, a block carved with an Unown; an Unown floats over the ruins.
    static func ruinsOfAlph(_ t: Double, _ canvas: inout EggCanvas) {
        let phase = 2 * Double.pi * t
        var s = Scene()
        s.ground({ _, _ in 1 }, top: { x, z, _ in (x + z).isMultiple(of: 3) ? rgb(0xE6D6A8) : rgb(0xDCC690).mixed(with: rgb(0xCDB57A), h(x, z, 61)) },
                 side: rgb(0xA8905C))
        let stone = rgb(0xCDBF9A)
        for (x, z, hgt) in [(1, 1, 5), (1, 5, 2), (5, 1, 3), (6, 4, 1)] { for y in 1...hgt { s.add(x, y, z, stone) } }
        s.box(3...4, 1...2, 4...4, stone.mixed(with: .white, 0.1))
        s.draw(&canvas)
        let (gx, gy) = s.point(3.6, 5, 2.2)
        canvas.fill(gx - 3, gy - 3, gx + 3, gy + 3) { x, y in
            let d = ((x - gx) * (x - gx) + (y - gy) * (y - gy)).squareRoot()
            return abs(d - 2) < 0.6 || d < 0.8 ? rgb(0x3A3326) : nil
        }
        canvas.outline(rgb(0x3A2E14))
        let ux = 40.0, uy = 12 + 2 * sin(phase)
        canvas.fill(ux - 5, uy - 5, ux + 5, uy + 9) { x, y in
            let d = ((x - ux) * (x - ux) + (y - uy) * (y - uy)).squareRoot()
            if abs(d - 3.6) < 0.9 { return rgb(0x23202A) }
            if d < 1.6 { return d < 0.8 ? rgb(0x23202A) : .white }
            if abs(x - ux) < 0.8, y > uy + 3.6, y < uy + 8 { return rgb(0x23202A) }
            return nil
        }
    }

    /// Hall of Origin: white marble trimmed with gold, stairs rising to a golden ring of light, sparks of gold.
    static func hallOfOrigin(_ t: Double, _ canvas: inout EggCanvas) {
        let phase = 2 * Double.pi * t
        var s = Scene()
        s.base = 40
        let marble = rgb(0xF4F1EA), gold = rgb(0xE6B422)
        s.ground({ _, _ in 1 }, top: { x, z, _ in x == 0 || z == 0 || x == 7 || z == 7 ? gold : marble.mixed(with: rgb(0xE2DCCD), h(x, z, 67)) },
                 side: rgb(0xD6D0C2))
        for z in 0...7 {
            let step = max(0, (7 - z) / 2)
            for x in 2...5 where step > 0 { for y in 1...step { s.add(x, y, z, y == step ? marble : rgb(0xE2DCCD)) } }
        }
        for (x, z) in [(0, 2), (7, 0), (0, 6)] {
            for y in 1...5 { s.add(x, y, z, marble) }
            s.add(x, 6, z, gold)
        }
        s.draw(&canvas)
        canvas.outline(rgb(0x5E4A12))
        let (rx, ry) = s.point(3.5, 0.5, 9)
        for step in 0..<90 {
            let a = Double(step) / 90 * 2 * .pi
            let bright = cos(a - phase) > 0.85
            EggDesigns.light(&canvas, rx + cos(a) * 9, ry + sin(a) * 3, bright ? .white : gold, behind: false)
            EggDesigns.light(&canvas, rx + cos(a) * 9, ry + sin(a) * 3 + 1, rgb(0xB8891A), behind: true)
        }
        for i in 0..<6 {
            let age = (t + h(i, 1, 71)).truncatingRemainder(dividingBy: 1)
            let x = 14 + h(i, 0, 71) * 36, y = 50 - age * 44
            EggDesigns.star(&canvas, x, y, age > 0.4 && age < 0.6 ? 2 : 1, rgb(0xFFE38A), behind: true)
        }
    }

    /// The moment each diorama is frozen at (they stay still, 2026-10-30): a Diglett out of its hole, the lava bright.
    static func still(_ id: DungeonID) -> Double {
        switch id {
        case .diglettsCave: 0.42
        case .mtEmber: 0.25
        case .dragonsDen: 0.2
        default: 0
        }
    }

    static func draw(_ id: DungeonID) -> (Double, inout EggCanvas) -> Void {
        switch id {
        case .viridianForest: viridianForest
        case .diglettsCave: diglettsCave
        case .mtMoon: mtMoon
        case .mtEmber: mtEmber
        case .victoryRoad: victoryRoad
        case .pokemonTower: pokemonTower
        case .dragonsDen: dragonsDen
        case .powerPlant: powerPlant
        case .seafoamIslands: seafoamIslands
        case .ceruleanCave: ceruleanCave
        case .mtCoronet: mtCoronet
        case .ruinsOfAlph: ruinsOfAlph
        case .hallOfOrigin: hallOfOrigin
        // Never seen while their boss is known: it stands in for them (`DungeonIcon`, the menu bar).
        case .daily: mtCoronet
        case .weekly: hallOfOrigin
        // The villains' hideout: a building, as the Power Plant's (its card shows the team's leader).
        case .hideout: powerPlant
        }
    }

    /// The dungeon's diorama on the eggs' 64-pixel canvas, drawn once.
    @MainActor
    static func image(_ id: DungeonID) -> CGImage? {
        if let cached = cache[id] { return cached }
        var canvas = EggCanvas(size: 64)
        draw(id)(still(id), &canvas)
        let image = canvas.image()
        cache[id] = image
        return image
    }

    @MainActor private static var cache: [DungeonID: CGImage] = [:]

    /// The diorama cropped to what is drawn: the menu bar fits its 20 points to it, not to the empty sky above.
    @MainActor private static var trimmedCache: [DungeonID: CGImage] = [:]

    /// Cropped once: the menu bar and the medals' icons asked at every redraw.
    @MainActor
    static func trimmedImage(_ id: DungeonID) -> CGImage? {
        if let cached = trimmedCache[id] { return cached }
        let trimmed = cropped(id)
        if let trimmed { trimmedCache[id] = trimmed }
        return trimmed
    }

    @MainActor
    private static func cropped(_ id: DungeonID) -> CGImage? {
        image(id).flatMap(cropped)
    }

    @MainActor
    private static func cropped(_ image: CGImage) -> CGImage? {
        let width = image.width, height = image.height
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
              let data = context.data else { return image }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        // The bitmap's first row is the image's top, as `cropping(to:)` counts.
        let pixels = data.bindMemory(to: UInt8.self, capacity: width * height * 4)
        var minX = width, minY = height, maxX = -1, maxY = -1
        for y in 0..<height {
            for x in 0..<width where pixels[(y * width + x) * 4 + 3] > 0 {
                minX = min(minX, x); maxX = max(maxX, x)
                minY = min(minY, y); maxY = max(maxY, y)
            }
        }
        guard maxX >= minX, maxY >= minY else { return image }
        return image.cropping(to: CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1))
    }
}

