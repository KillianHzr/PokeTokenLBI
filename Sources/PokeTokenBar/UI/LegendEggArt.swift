import AppKit

/// The eggs of the dungeons' legendary bosses (D5, chosen by the owner on 2026-10-30, refined and validated on
/// 2026-11-02): Articuno's tail spiraling up cut ice, Lugia's Aeroblast over the sea, Suicune's crystal over clear water,
/// Mewtwo's psychic aura, Dialga's Roar of Time, Palkia's Spacial Rend, Giratina's Distortion World, Arceus's divine
/// light. Any other boss's egg is drawn as its line's type egg (`EggKind.dungeonLook`).
enum LegendEggArt {
    typealias C = EggColor

    /// The egg a legendary boss leaves, by its species; nil for every other boss.
    static func design(_ speciesID: Int) -> EggDesign? {
        switch speciesID {
        case 144: return articuno
        case 249: return lugia
        case 245: return suicune
        case 150: return mewtwo
        case 483: return dialga
        case 484: return palkia
        case 487: return giratina
        case 493: return arceus
        default: return nil
        }
    }

    // MARK: Tools

    static func rgb(_ hex: Int) -> C {
        C(Double((hex >> 16) & 0xFF) / 255, Double((hex >> 8) & 0xFF) / 255, Double(hex & 0xFF) / 255)
    }

    private static func h(_ i: Int, _ j: Int, _ seed: Int) -> Double { EggDesigns.hash(i, j, 0, seed: seed) }

    /// Points around the egg's outline, closer together toward its ends, for distances to it.
    private static let outlinePoints: [(Double, Double)] = (0...96).flatMap { i -> [(Double, Double)] in
        let y = -cos(Double(i) / 96 * .pi)
        return [(EggProfile.radius(y), y), (-EggProfile.radius(y), y)]
    }

    /// A pixel in the egg's frame: (x, y) in egg units, and whether it is on the egg.
    private static func eggPoint(_ f: EggFrame, _ px: Double, _ py: Double) -> (x: Double, y: Double, inside: Bool) {
        let u = (px - f.cx) * f.unitsPerPixel, v = (f.cy - py - Double(f.lift)) * f.unitsPerPixel
        let x = u * cos(f.tilt) + v * sin(f.tilt), y = -u * sin(f.tilt) + v * cos(f.tilt)
        return (x, y, abs(y) < 1 && abs(x) < EggProfile.radius(y))
    }

    /// How far a pixel outside the egg is from its outline, in egg units, and where it is; nil on the egg.
    private static func outside(_ f: EggFrame, _ px: Double, _ py: Double, within: Double) -> (d: Double, x: Double, y: Double)? {
        let (x, y, inside) = eggPoint(f, px, py)
        guard !inside, abs(x) < 0.8 + within, abs(y) < 1 + within else { return nil }
        var nearest = 99.0
        for (ox, oy) in outlinePoints { nearest = min(nearest, (x - ox) * (x - ox) + (y - oy) * (y - oy)) }
        let d = nearest.squareRoot()
        return d < within ? (d, x, y) : nil
    }

    /// A point of the egg's outline at an angle (0 right, π/2 top), pushed out by `out` egg units, in pixels.
    private static func rim(_ f: EggFrame, _ angle: Double, out: Double) -> (Double, Double) {
        let y = sin(angle) * 0.96
        let x = cos(angle) * EggProfile.radius(y)
        let l = max(0.01, (x * x + y * y).squareRoot())
        return f.pixel(x + x / l * out, y + y / l * out)
    }

    /// A point around the egg (angle 0 facing the viewer, turning with the egg), `out` egg units off its surface, seen a
    /// little from above; whether it is on the near side.
    private static func around(_ f: EggFrame, _ angle: Double, _ y: Double, out: Double) -> (x: Double, y: Double, near: Bool) {
        let a = angle - f.yaw
        let r = EggProfile.radius(max(-0.97, min(0.97, y))) + out
        let ex = r * sin(a), ez = r * cos(a)
        let (px, py) = f.pixel(ex, y - ez * 0.14)
        return (px, py, ez > 0)
    }

    /// A ring around the egg at a height, seen a little from above: the pixel of an angle (sin > 0 is the near side).
    private static func ringPoint(_ f: EggFrame, _ a: Double, rx: Double, ry: Double, tilt: Double, at height: Double) -> (Double, Double) {
        let (cx, cy) = f.pixel(0, height)
        let x = cos(a) * rx, y = sin(a) * ry
        let (s, c) = (sin(tilt), cos(tilt))
        return (cx + x * c - y * s, cy + x * s + y * c)
    }

    /// Sparkles at points of the egg's frame, each flashing in its turn.
    private static func sparkles(_ canvas: inout EggCanvas, _ f: EggFrame, _ spots: [(Double, Double)], _ color: C) {
        for (i, (x, y)) in spots.enumerated() {
            let pulse = max(0, sin(f.phase * 2 + Double(i) * 2.4))
            guard pulse > 0.3 else { continue }
            let (px, py) = f.pixel(x, y)
            canvas.sparkle(px, py, 1.5 + 3 * pulse * pulse, color)
        }
    }

    private static func snowflake(_ canvas: inout EggCanvas, _ x: Double, _ y: Double, _ r: Double, _ c: C, behind: Bool) {
        EggDesigns.light(&canvas, x, y, c, behind: behind)
        guard r >= 1.5 else { return }
        for k in 0..<6 {
            let a = Double(k) * .pi / 3
            for step in 1...Int(r) {
                EggDesigns.light(&canvas, x + cos(a) * Double(step), y + sin(a) * Double(step), c, behind: behind)
            }
        }
    }

    /// Particles falling over the loop, each its column and phase.
    private static func falling(_ canvas: inout EggCanvas, _ f: EggFrame, count: Int, seed: Int,
                                draw: (inout EggCanvas, Double, Double, Int) -> Void) {
        for i in 0..<count {
            let x0 = 3 + h(i, 0, seed) * 58
            let age = (f.t + h(i, 1, seed)).truncatingRemainder(dividingBy: 1)
            draw(&canvas, x0 + 2.5 * sin(age * 2 * .pi + Double(i)), -4 + age * 70, i)
        }
    }

    /// A tube following points (x, y, radius): a darker edge, then its body, lit like a rope.
    private static func tube(_ canvas: inout EggCanvas, _ points: [(Double, Double, Double)], _ body: C, edge: C) {
        for (x, y, r) in points { canvas.ball(x, y, r + 0.9, edge, gloss: 0) }
        for (x, y, r) in points { canvas.ball(x, y, r, body, gloss: 0.25) }
    }

    /// A tube in two colors by stretch (alternating every `chunk` points), one dark edge under all of it.
    private static func bandTube(_ canvas: inout EggCanvas, _ points: [(Double, Double, Double)], _ a: C, _ b: C, chunk: Int,
                                 edge: C) {
        for (x, y, r) in points { canvas.ball(x, y, r + 0.9, edge, gloss: 0) }
        for (i, (x, y, r)) in points.enumerated() { canvas.ball(x, y, r, (i / chunk).isMultiple(of: 2) ? a : b, gloss: 0.3) }
    }

    /// A glow around the egg's outline, `reach` egg units, in bands from the egg out.
    private static func aura(_ canvas: inout EggCanvas, _ f: EggFrame, reach: Double, _ bands: [C], wobble: Double = 0) {
        for py in 0..<canvas.size {
            for px in 0..<canvas.size {
                guard let o = outside(f, Double(px) + 0.5, Double(py) + 0.5, within: reach * 1.4) else { continue }
                let edge = reach * (1 + wobble * sin(atan2(o.y, o.x) * 6 + f.phase * 2))
                guard o.d < edge else { continue }
                canvas.set(px, py, bands[min(bands.count - 1, Int(o.d / edge * Double(bands.count)))])
            }
        }
    }

    /// The normal snapped to a coarse lattice: cut facets.
    private static func facets(_ n: EggVector, _ p: EggSurfacePoint) -> EggVector {
        EggLight.normalize(((n.x * 3).rounded() / 3, (n.y * 3).rounded() / 3, max(0.2, (n.z * 3).rounded() / 3)))
    }

    // A gem's cut: planes tangent to the egg, in rings.
    private static let surfacePoints: [EggVector] = (0...40).flatMap { i -> [EggVector] in
        let y = -cos(Double(i) / 40 * .pi), r = EggProfile.radius(y)
        return (0..<48).map { k in (r * sin(Double(k) / 48 * 2 * .pi), y, r * cos(Double(k) / 48 * 2 * .pi)) }
    }

    private static func touch(_ n: EggVector) -> Double { surfacePoints.map { n.x * $0.x + n.y * $0.y + n.z * $0.z }.max() ?? 1 }

    private static func cutEgg(rings: [(elevation: Double, count: Int)]) -> [(n: EggVector, d: Double)] {
        var planes: [(n: EggVector, d: Double)] = []
        for (r, ring) in rings.enumerated() {
            for k in 0..<ring.count {
                let a = (Double(k) + (r.isMultiple(of: 2) ? 0 : 0.5)) / Double(ring.count) * 2 * .pi
                let n: EggVector = (cos(ring.elevation) * sin(a), sin(ring.elevation), cos(ring.elevation) * cos(a))
                planes.append((n, touch(n)))
            }
        }
        planes.append(((0, 1, 0), touch((0, 1, 0)) * 0.96))
        planes.append(((0, -1, 0), 0.95))
        return planes
    }

    private static let crystalPlanes = cutEgg(rings: [(-1.0, 6), (-0.45, 6), (0.05, 6), (0.5, 6), (1.0, 6)])

    // MARK: Articuno

    /// Cut ice under a cap of snow ending in icicles, Articuno's crest on top; its long feathered tail spirals up
    /// around it, waving; snow falls, diamond dust glints.
    static var articuno: EggDesign {
        let snow = rgb(0xF4FBFF), light = rgb(0xA9DCF7), mid = rgb(0x5FA8E6), deep = rgb(0x2B63B0)
        var surface = EggSurface(albedo: { (p: EggSurfacePoint) -> C in
            let icicle: Double = 0.56 + 0.05 * sin(p.angle * 7) - 0.08 * max(0, sin(p.angle * 13))
            if p.y > icicle { return snow }
            return light.mixed(with: mid, EggLight.smoothstep(0.5, -0.3, p.y)).mixed(with: deep, EggLight.smoothstep(-0.3, -1, p.y) * 0.8)
        }, gloss: 0.8, shininess: 80)
        surface.normal = facets
        func tail(_ canvas: inout EggCanvas, _ f: EggFrame, near: Bool) {
            var points: [(Double, Double, Double)] = []
            for step in 0..<90 {
                let s = Double(step) / 90
                let angle: Double = -2.6 + s * 5.6 + f.phase
                let y: Double = -0.9 + s * 1.55 + 0.06 * sin(s * 14 - f.phase * 2)
                let point = around(f, angle, y, out: 0.12 + 0.14 * s)
                guard point.near == near else { continue }
                points.append((point.x, point.y, 3.3 - 1.9 * s + 0.55 * max(0, sin(s * 38))))
            }
            tube(&canvas, points, near ? rgb(0xC4E9FC) : light.mixed(with: mid, 0.45), edge: deep)
            guard near else { return }
            for (x, y, r) in points where r > 1.8 { EggDesigns.light(&canvas, x - r * 0.3, y - r * 0.5, .white, behind: false) }
        }
        return EggDesign(surface: surface, back: { canvas, f in tail(&canvas, f, near: false) }, front: { canvas, f in
            tail(&canvas, f, near: true)
            let (tx, ty) = f.pixel(0, 0.93)
            for k in -1...1 {
                let angle = .pi / 2 + Double(k) * 0.45 + 0.13 * sin(f.phase + Double(k) * 0.9)
                let len: Double = k == 0 ? 15 : 11
                canvas.ellipse(tx + cos(angle) * len / 2, ty - sin(angle) * len / 2, len / 2, 2.2, angle: angle, deep, gloss: 0.4)
            }
            falling(&canvas, f, count: 6, seed: 811) { c, x, y, i in
                if i % 2 == 0 { snowflake(&c, x, y, 2, .white, behind: true) } else { EggDesigns.light(&c, x, y, .white, behind: true) }
            }
            sparkles(&canvas, f, [(-0.7, 0.45), (0.75, 0.15), (0.55, 0.8)], .white)
        }, outline: rgb(0x17325E))
    }

    // MARK: Lugia

    /// Silver, its blue belly ringed, the navy plates of its back over the top; Aeroblast's wind twists up around it
    /// while the sea foams at its foot.
    static var lugia: EggDesign {
        let top = rgb(0xFBFCFF), shade = rgb(0xA9B5D2), bellyBlue = rgb(0x7391D6), bellyEdge = rgb(0x3F5CA8), navy = rgb(0x2E3D78)
        let surface = EggSurface(albedo: { (p: EggSurfacePoint) -> C in
            let (a, y) = EggDesigns.front(p)
            let b: Double = (a / 0.5) * (a / 0.5) + ((y + 0.6) / 0.55) * ((y + 0.6) / 0.55)
            if b < 1 { return b > 0.8 ? bellyEdge : bellyBlue.mixed(with: .white, 0.25 * (1 - b)) }
            return top.mixed(with: shade, EggLight.smoothstep(0.5, -1, p.y) * 0.75)
        }, gloss: 0.55)
        func wind(_ canvas: inout EggCanvas, _ f: EggFrame, near: Bool) {
            for band in 0..<2 {
                var points: [(Double, Double, Double)] = []
                for step in 0..<90 {
                    let s = Double(step) / 90
                    let point = around(f, -f.phase * 1.5 + Double(band) * .pi + s * 6.2, -0.72 + s * 1.6, out: 0.13 + 0.2 * s)
                    guard point.near == near else { continue }
                    points.append((point.x, point.y, 1.2 + 0.9 * s))
                }
                bandTube(&canvas, points, .white, rgb(0xA9C2F2), chunk: 5, edge: near ? rgb(0x5376C4) : rgb(0x8EA4D8))
            }
        }
        return EggDesign(surface: surface, back: { canvas, f in
            for (k, angle) in [1.2, 1.57, 1.94].enumerated() {
                let (bx, by) = rim(f, angle, out: -0.08)
                let (tx, ty) = rim(f, angle, out: k == 1 ? 0.42 : 0.3)
                let nx = -(ty - by), ny = tx - bx, l = max(1, (nx * nx + ny * ny).squareRoot())
                canvas.polygon([(bx + nx / l * 4, by + ny / l * 4), (tx, ty), (bx - nx / l * 4, by - ny / l * 4)], navy)
            }
            wind(&canvas, f, near: false)
        }, front: { canvas, f in
            wind(&canvas, f, near: true)
            let (cx, by) = f.pixel(0, -0.92)
            canvas.fill(cx - 26, by - 6, cx + 26, by + 5) { x, y in
                let crest = by - 2 + 2 * sin((x - cx) * 0.42 + f.phase * 2)
                guard y > crest, abs(x - cx) < 26 - max(0, y - by) * 3 else { return nil }
                if y < crest + 1.5 { return .white }
                return y < by + 1.5 ? rgb(0x5A8BE0) : rgb(0x2F5BB0)
            }
        }, outline: rgb(0x22305E))
    }

    // MARK: Suicune

    /// White diamonds in rows over the front.
    private static func diamonds(_ p: EggSurfacePoint) -> Bool {
        let (a, y) = EggDesigns.front(p)
        let cell = 0.3
        let j = (y / cell + 50).rounded(.down)
        let shift: Double = Int(j).isMultiple(of: 2) ? 0.5 : 0
        let i = (a / cell + 50 + shift).rounded(.down)
        let u = a - (i - 50 - shift + 0.5) * cell, v = y - (j - 50 + 0.5) * cell
        guard p.y < 0.55 else { return false }
        return abs(u) / 0.07 + abs(v) / 0.1 < 1
    }

    /// A crystal cut like a gem, a white diamond in each face; Suicune's mane flowing back off the top in four strands,
    /// its crystal in front of it; clear water rings out at its foot.
    static var suicune: EggDesign {
        let light = rgb(0xA8E2F8), deep = rgb(0x2463A8)
        let maneLight = rgb(0xB9A3EC), maneMid = rgb(0x8C6FD6), maneDark = rgb(0x4E3A9A)
        var surface = EggSurface(albedo: { (p: EggSurfacePoint) -> C in
            let tone = EggDesigns.hash(EggDesigns.face(crystalPlanes, p), 0, 0, seed: 77)
            let c = light.mixed(with: deep, 0.15 + tone * 0.55).mixed(with: deep, EggLight.smoothstep(-0.2, -1, p.y) * 0.35)
            return diamonds(p) ? c.mixed(with: .white, 0.85) : c
        }, gloss: 0.95, shininess: 75)
        surface.solid = { o, dir in EggDesigns.enter(crystalPlanes, o, dir) }
        return EggDesign(surface: surface, back: { canvas, f in
            let (cx, cy) = f.pixel(0, -0.97)
            canvas.ellipse(cx, cy + 1, 20, 4, rgb(0x3E86C8), flat: true)
            canvas.ellipse(cx, cy + 0.5, 16, 2.8, rgb(0x7CC4EC), flat: true)
            for k in 0..<2 {
                let t = (f.t + Double(k) * 0.5).truncatingRemainder(dividingBy: 1)
                let rx = 10 + t * 18, ry = 2.4 + t * 4
                for step in 0..<120 {
                    let a = Double(step) / 120 * 2 * .pi
                    EggDesigns.light(&canvas, cx + cos(a) * rx, cy + 1 + sin(a) * ry, t < 0.6 ? rgb(0xBDEBFA) : rgb(0x7CC4EC), behind: true)
                }
            }
        }, front: { canvas, f in
            let (tx, ty) = f.pixel(-0.05, 0.86)
            for k in 0..<4 {
                var points: [(Double, Double, Double)] = []
                for step in 0..<26 {
                    let s = Double(step) / 26
                    let x = tx - 4 + Double(k) * 2.2 + s * (17 + Double(k) * 2)
                    let y = ty - 2 + s * (3 + Double(k) * 2.4) + 1.8 * sin(s * 5 - f.phase * 2 - Double(k) * 0.7)
                    points.append((x, y, 2.7 - s * 1.7))
                }
                tube(&canvas, points, k.isMultiple(of: 2) ? maneMid : maneLight, edge: maneDark)
            }
            let hex: [(Double, Double)] = (0..<6).map { k in
                let a = Double(k) * .pi / 3 + .pi / 6
                return (tx - 3 + cos(a) * 3.6, ty - 3.5 + sin(a) * 4)
            }
            canvas.polygon(hex, rgb(0xF2FBFF))
            canvas.polygon(hex.map { (tx - 3 + ($0.0 - tx + 3) * 0.5, ty - 3.5 + ($0.1 - ty + 3.5) * 0.5) }, rgb(0x9FDDF7), shade: false)
            sparkles(&canvas, f, [(-0.75, 0.3), (0.8, -0.1), (0.1, -1.05), (-0.85, -0.55)], .white)
        }, outline: rgb(0x173F6E))
    }

    // MARK: Mewtwo

    /// Lavender darkening to purple, its tail coiled at its foot and the tube down its neck; a psychic aura breathes
    /// around it, three glowing orbs circle it.
    static var mewtwo: EggDesign {
        let top = rgb(0xEDE3F6), low = rgb(0x9A78C6), coil = rgb(0x7E46B0), coilLight = rgb(0xB284E2), coilDark = rgb(0x45206E)
        let surface = EggSurface(albedo: { (p: EggSurfacePoint) -> C in
            let (a, y) = EggDesigns.front(p)
            let d = p.y - (-0.5 + 0.22 * sin(p.angle - 0.8))
            if abs(d) < 0.15 { return abs(d) > 0.12 ? coilDark : d > 0.05 ? coilLight : coil }
            if abs(a - (0.28 + 0.25 * (y - 0.35))) < 0.05, y > 0.3, y < 0.88 { return low }
            return top.mixed(with: low, EggLight.smoothstep(0.35, -1, p.y) * 0.85)
        }, gloss: 0.5)
        func orbs(_ canvas: inout EggCanvas, _ f: EggFrame, near: Bool) {
            for k in 0..<3 {
                let a = f.phase + Double(k) * 2 * .pi / 3
                guard (sin(a) > 0) == near else { continue }
                let (x, y) = ringPoint(f, a, rx: 28, ry: 8, tilt: -0.2, at: 0.05)
                canvas.ball(x, y, 4.4, rgb(0xE2D2FF), gloss: 0)
                canvas.ball(x, y, 3.2, near ? rgb(0x7B5CF5) : rgb(0x5B43C2), gloss: 0.9)
            }
        }
        return EggDesign(surface: surface, back: { canvas, f in
            aura(&canvas, f, reach: 0.24 + 0.05 * sin(f.phase * 2),
                 [rgb(0xF2E2FF), rgb(0xCDA4FF), rgb(0xA06CEE), rgb(0x7443CF), rgb(0x55299E)], wobble: 0.32)
            orbs(&canvas, f, near: false)
        }, front: { canvas, f in orbs(&canvas, f, near: true) }, outline: rgb(0x351A52))
    }

    // MARK: Dialga

    static let timeCyan = rgb(0x8AF3FF), timeTeal = rgb(0x2FB8E0)
    private static let dSteel = rgb(0x5873B5), dLight = rgb(0xC3D3EF), gem = rgb(0x8FE6FF)

    /// The diamond of its chest, glowing with a pulse.
    private static func chestDiamond(_ p: EggSurfacePoint, pulse: Double) -> C? {
        let (a, y) = EggDesigns.front(p)
        let d = abs(a) / 0.15 + abs(y - 0.02) / 0.22
        guard d < 1 else { return nil }
        let facet = a > 0 ? 0.0 : 0.25
        return gem.mixed(with: .white, (d < 0.5 ? 0.45 : 0.1) + facet * 0.4 + pulse * 0.3)
    }

    /// Dialga's fins, fanned behind its top: steel plates edged with a line of cyan.
    private static func dialgaFins(_ canvas: inout EggCanvas, _ f: EggFrame) {
        for (k, angle) in [0.95, 1.35, 1.8, 2.2].enumerated() {
            let (bx, by) = rim(f, angle, out: -0.1)
            let (tx, ty) = rim(f, angle, out: k == 1 || k == 2 ? 0.46 : 0.34)
            let nx = -(ty - by), ny = tx - bx, l = max(1, (nx * nx + ny * ny).squareRoot())
            let sway = 0.6 * sin(f.phase + Double(k))
            canvas.polygon([(bx + nx / l * 4.5, by + ny / l * 4.5), (tx + sway, ty), (bx - nx / l * 4.5, by - ny / l * 4.5)],
                           k.isMultiple(of: 2) ? dLight : dSteel.mixed(with: dLight, 0.4))
            canvas.line(bx, by, tx + sway, ty, width: 0.9, timeCyan)
        }
    }

    /// Roar of Time: blue steel reflecting a sky, lines of cyan light running out from its diamond in waves, its fins
    /// behind, double shock rings spreading and fraying.
    static var dialga: EggDesign {
        let skyC = rgb(0xD8E5F8), steel = rgb(0x4C6BB8), deepS = rgb(0x1F3570)
        var surface = EggSurface(albedo: { (p: EggSurfacePoint) -> C in
            let ry: Double = 2 * p.normal.z * p.normal.y
            let sky = skyC.mixed(with: steel, max(0, 0.6 - ry * 0.55))
            let ground = steel.mixed(with: deepS, EggLight.smoothstep(0, -0.8, ry))
            return ry > 0.02 ? sky : ground.mixed(with: sky, EggLight.smoothstep(-0.2, 0.02, ry))
        }, gloss: 0.85, shininess: 85)
        surface.emission = { (p: EggSurfacePoint) -> C? in
            if let diamond = chestDiamond(p, pulse: max(0, sin(p.phase * 2))) { return diamond }
            let (a, y) = EggDesigns.front(p)
            guard y < 0.72, y > -0.85 else { return nil }
            var vein = false
            for c in [-0.42, -0.2, 0.2, 0.42] where abs(a - c * (1 - 0.35 * y * y) - 0.04 * sin(y * 5 + c * 9)) < 0.03 { vein = true }
            if abs(y - (0.42 - abs(a) * 0.6)) < 0.028, abs(a) < 0.5 { vein = true }
            guard vein else { return nil }
            let wave = 0.5 + 0.5 * sin(y * 10 - p.phase * 3)
            return timeTeal.mixed(with: timeCyan, wave).mixed(with: .white, wave > 0.85 ? 0.5 : 0)
        }
        return EggDesign(surface: surface, back: { canvas, f in dialgaFins(&canvas, f) }, outline: rgb(0x12204A), glow: { canvas, f in
            let (cx, cy) = f.pixel(0, 0)
            for k in 0..<2 {
                let t = (f.t + Double(k) * 0.5).truncatingRemainder(dividingBy: 1)
                let rx = 19 + t * 12, ry = 25 + t * 8
                for step in 0..<200 {
                    if t > 0.6, (step / 4).isMultiple(of: 2) { continue }
                    let a = Double(step) / 200 * 2 * .pi
                    let c = t < 0.3 ? timeCyan.mixed(with: .white, 0.3) : t < 0.6 ? timeCyan : timeTeal
                    EggDesigns.light(&canvas, cx + cos(a) * rx, cy + sin(a) * ry, c, behind: true)
                    EggDesigns.light(&canvas, cx + cos(a) * (rx + 1), cy + sin(a) * (ry + 1), timeTeal, behind: true)
                }
            }
        })
    }

    // MARK: Palkia

    private static let pearl = rgb(0xF8F0F7), pearlShade = rgb(0xDCC5DB), pinkS = rgb(0xE07AB2), pinkD = rgb(0xB24C8E)

    /// Pearl, iridescent as it turns, Palkia's pink lines across it and its two pearls at the shoulders.
    private static func palkiaShell(_ p: EggSurfacePoint) -> C {
        let (a, y) = EggDesigns.front(p)
        for side in [-1.0, 1.0] {
            let dx = a - side * 0.4, dy = y - 0.2
            let d = (dx * dx + dy * dy).squareRoot()
            if d < 0.13 {
                if d > 0.105 { return pinkD }
                let light = max(0, 1 - ((dx + 0.04) * (dx + 0.04) + (dy - 0.04) * (dy - 0.04)).squareRoot() / 0.08)
                return rgb(0xF4C6E2).mixed(with: .white, 0.15 + light * 0.75)
            }
        }
        for (height, bend) in [(0.18, 0.12), (-0.35, 0.1)] {
            let d = abs(y - (height + bend * cos(a * 2.4)))
            if d < 0.055 { return d < 0.03 ? pinkS : pinkD }
        }
        let tint = EggDesigns.hue(0.83 + p.normal.x * 0.18 + p.yaw * 0.08).mixed(with: .white, 0.84)
        return pearl.mixed(with: tint, 0.6).mixed(with: pearlShade, EggLight.smoothstep(0.2, -1, p.y) * 0.5)
    }

    /// Spacial Rend: space bends in a grid behind it, its shoulder pearls glow, two slashes of light tear the air.
    static var palkia: EggDesign {
        let surface = EggSurface(albedo: palkiaShell, gloss: 0.85, shininess: 70)
        return EggDesign(surface: surface, back: { canvas, f in
            let (cx, cy) = f.pixel(0, 0.05)
            for py in 0..<canvas.size {
                for px in 0..<canvas.size {
                    let x = Double(px) + 0.5 - cx, y = Double(py) + 0.5 - cy
                    let a = atan2(y, x), d = (x * x / (29 * 29) + y * y / (27 * 27)).squareRoot()
                    let edge = 1 + 0.06 * sin(a * 7 + f.phase * 2)
                    guard d < edge else { continue }
                    if d > edge - 0.06 { canvas.set(px, py, rgb(0xF2A8D8)); continue }
                    if d > edge - 0.11 { canvas.set(px, py, rgb(0xA77CE8)); continue }
                    var c = rgb(0x5A47B8).mixed(with: rgb(0x1E1648), 1 - d * 0.7)
                    let gx = x + 2.6 * sin(y * 0.2 + f.phase), gy = y + 2.6 * sin(x * 0.2 - f.phase)
                    let mx = (gx + 72).truncatingRemainder(dividingBy: 6), my = (gy + 72).truncatingRemainder(dividingBy: 6)
                    if mx < 1 || my < 1 { c = c.mixed(with: rgb(0xC9B4FF), 0.6) }
                    let star = EggDesigns.hash(px, py, 0, seed: 71)
                    if star > 0.97 { c = star > 0.985 && sin(f.phase * 2 + star * 40) > 0 ? .white : rgb(0xD8CCFF) }
                    canvas.set(px, py, c)
                }
            }
        }, front: { canvas, f in
            for side in [-1.0, 1.0] {
                let (x, y) = f.pixel(side * EggProfile.radius(-0.1) * 0.98, -0.1)
                let glow = 0.5 + 0.5 * sin(f.phase * 2 + side)
                canvas.ball(x, y, 4.8, pinkD, gloss: 0.3)
                canvas.ball(x, y, 3.8, rgb(0xF6D0E8).mixed(with: .white, glow * 0.45), gloss: 0.9)
            }
            for k in 0..<2 {
                let t = (f.t * 2 + Double(k) * 0.5).truncatingRemainder(dividingBy: 1)
                guard t < 0.5 else { continue }
                let grow = min(1, t / 0.18)
                let (x0, y0): (Double, Double) = k == 0 ? (7, 12) : (57, 16)
                let (x1, y1): (Double, Double) = k == 0 ? (25, 56) : (39, 59)
                let xe = x0 + (x1 - x0) * grow, ye = y0 + (y1 - y0) * grow
                if t <= 0.35 { canvas.line(x0, y0, xe, ye, width: 3.2, rgb(0xF07CC0)) }
                canvas.line(x0, y0, xe, ye, width: 1.8, rgb(0xFFD3EC))
                canvas.line(x0, y0, xe, ye, width: 0.8, .white)
            }
        }, outline: rgb(0x5E2450))
    }

    // MARK: Giratina

    /// The Distortion World: shadow gray to black with gold ribs and red stripes, its foot dissolving; rocks drift
    /// around it, lit on an edge, over a red rift that pulses, dark flames rising from it.
    static var giratina: EggDesign {
        let gray = rgb(0x84838F), black = rgb(0x1A1820), gold = rgb(0xF2C858), goldDark = rgb(0xA97F1E), red = rgb(0xD22F3C)
        var surface = EggSurface(albedo: { (p: EggSurfacePoint) -> C in
            let (a, y) = EggDesigns.front(p)
            for height in [0.34, -0.02] {
                let d = y - (height + 0.05 * abs(sin(a * 7)))
                if abs(d) < 0.075 { return d > 0.035 ? gold.mixed(with: .white, 0.35) : d > -0.03 ? gold : goldDark }
                if d < -0.075, d > -0.13 { return red }
            }
            return gray.mixed(with: black, EggLight.smoothstep(0.6, -0.7, p.y))
        }, gloss: 0.55)
        surface.keep = { p in
            let edge = -0.74 + 0.1 * sin(Double(p.px) * 0.8)
            if p.y < edge { return false }
            if p.y < -0.44 { return (p.px + p.py).isMultiple(of: 2) || p.y > -0.52 }
            return true
        }
        func rocks(_ canvas: inout EggCanvas, _ f: EggFrame, near: Bool) {
            for i in 0..<5 {
                // A whole turn a loop, so its end meets its start.
                let point = around(f, f.phase + Double(i) * 1.26, -0.6 + 0.3 * Double(i % 3) + 0.08 * sin(f.phase + Double(i)),
                                   out: 0.32)
                guard point.near == near else { continue }
                let s = 2.3 + Double(i % 2)
                let shape = [(point.x - s, point.y), (point.x - s * 0.3, point.y - s), (point.x + s, point.y - s * 0.4),
                             (point.x + s * 0.6, point.y + s * 0.8)]
                canvas.polygon(shape, i.isMultiple(of: 2) ? rgb(0x6E6B7C) : rgb(0x4A4758))
                canvas.line(shape[0].0, shape[0].1, shape[1].0, shape[1].1, width: 0.9, rgb(0xB4B0C4))
            }
        }
        return EggDesign(surface: surface, back: { canvas, f in
            let (cx, cy) = f.pixel(0, -0.95)
            // By the loop's frame: the phase's last frame reads its first exactly, rounding and all.
            let pulse = 0.5 + 0.5 * sin(Double(EggDesigns.loopFrame(f.t)) / Double(EggRenderer.frameCount) * 4 * .pi)
            canvas.ellipse(cx, cy + 1, 23, 5, black, flat: true)
            canvas.ellipse(cx, cy + 1, 17, 3.4, rgb(0x4A1636), flat: true)
            canvas.ellipse(cx, cy + 1, 10, 1.8, rgb(0x9A2448).mixed(with: rgb(0xE0506E), pulse * 0.6), flat: true)
            for i in 0..<4 {
                let t = (f.t + Double(i) / 4).truncatingRemainder(dividingBy: 1)
                canvas.flame(baseX: cx - 16 + Double(i) * 10.5, baseY: cy - t * 30, height: 8, width: 2.6, lean: 0.25 * sin(t * 6 + Double(i)),
                             outer: black, middle: rgb(0x3A2440), core: rgb(0x8A3A68))
            }
            rocks(&canvas, f, near: false)
        }, front: { canvas, f in rocks(&canvas, f, near: true) }, outline: rgb(0x0B0A0F))
    }

    // MARK: Arceus

    private static func goldMetal(_ p: EggSurfacePoint) -> C {
        let ry: Double = 2 * p.normal.z * p.normal.y
        let light = rgb(0xFFF0B5), mid = rgb(0xF0BF3C), deep = rgb(0xA06C14)
        return ry > 0.05 ? light.mixed(with: mid, max(0, 0.65 - ry * 0.6)) : mid.mixed(with: deep, EggLight.smoothstep(0.05, -0.8, ry))
    }

    /// The gold band at its waist, between its white top and its gray underside.
    private static func goldBand(_ p: EggSurfacePoint) -> Bool {
        abs(p.y - (-0.5 + 0.035 * abs(sin(p.angle * 8)))) < 0.035
    }

    /// Arceus's golden wheel around its middle, thin, four jewels set at its quarters, turning slowly.
    private static func goldenWheel(_ canvas: inout EggCanvas, _ f: EggFrame, near: Bool, jewels: (Int, Double) -> C) {
        for step in 0..<240 {
            let a = Double(step) / 240 * 2 * .pi
            guard (sin(a) > 0) == near else { continue }
            let (x, y) = ringPoint(f, a, rx: 27, ry: 7.5, tilt: -0.1, at: -0.08)
            canvas.ball(x, y, 1.5, near ? rgb(0xF6CB45) : rgb(0xB8891A), gloss: 0.7)
        }
        for k in 0..<4 {
            let a = f.phase / 4 + Double(k) * .pi / 2
            guard (sin(a) > 0) == near else { continue }
            let (x, y) = ringPoint(f, a, rx: 27, ry: 7.5, tilt: -0.1, at: -0.08)
            canvas.polygon([(x, y - 5), (x + 3, y), (x, y + 4), (x - 3, y)], rgb(0xF6CB45))
            canvas.ball(x, y - 0.5, 2, jewels(k, f.t), gloss: 0.9)
        }
    }

    /// Divine light: iridescent porcelain over its gray underside, the gold band catching a gleam that sweeps across
    /// it, its golden wheel and four changing jewels, a halo, golden rays turning behind.
    static var arceus: EggDesign {
        let white = rgb(0xFCFAF2), cream = rgb(0xEDE4C8), gray = rgb(0xA7A190), grayDark = rgb(0x77715F)
        var surface = EggSurface(albedo: { (p: EggSurfacePoint) -> C in
            if goldBand(p) { return goldMetal(p) }
            if p.y < -0.5 + 0.035 * abs(sin(p.angle * 8)) { return gray.mixed(with: grayDark, EggLight.smoothstep(-0.55, -1, p.y) * 0.7) }
            let sheen = EggDesigns.hue(p.angle * 0.25 + p.y * 0.35 + p.yaw * 0.6).mixed(with: .white, 0.82)
            return white.mixed(with: sheen, 0.45).mixed(with: cream, EggLight.smoothstep(0.4, -0.5, p.y) * 0.6)
        }, gloss: 0.7, shininess: 70)
        surface.emission = { (p: EggSurfacePoint) -> C? in
            guard goldBand(p) else { return nil }
            let sweep = (p.angle - p.phase + 20 * .pi).truncatingRemainder(dividingBy: 2 * .pi)
            return sweep < 0.25 ? rgb(0xFFFBE6) : nil
        }
        // The wheel turns a quarter a loop, each jewel taking the next one's place: its hue a quarter on, plus a full
        // turn of the rainbow, so the loop's end meets its start.
        let rainbow: (Int, Double) -> C = { k, t in EggDesigns.hue(Double(k) / 4 + 1.25 * t).mixed(with: .white, 0.2) }
        return EggDesign(surface: surface, back: { canvas, f in
            aura(&canvas, f, reach: 0.09, [rgb(0xFFF3C4), rgb(0xFFD866)], wobble: 0.15)
            goldenWheel(&canvas, f, near: false, jewels: rainbow)
        }, front: { canvas, f in
            goldenWheel(&canvas, f, near: true, jewels: rainbow)
            let (hx, hy) = f.pixel(0, 1.13)
            for step in 0..<90 {
                let a = Double(step) / 90 * 2 * .pi
                canvas.ball(hx + cos(a) * 10, hy + sin(a) * 2.8 + sin(f.phase) * 0.8, 1.3, sin(a) > 0 ? rgb(0xFFD24A) : rgb(0xC8901E), gloss: 0)
            }
            sparkles(&canvas, f, [(-0.85, 0.55), (0.9, 0.2), (-0.6, -0.95), (0.7, -0.75)], rgb(0xFFF3C4))
        }, outline: rgb(0x5E4410), glow: { canvas, f in
            let (cx, cy) = f.pixel(0, 0.05)
            for k in 0..<16 {
                let a = Double(k) / 16 * 2 * .pi + f.phase / 8
                let long: Double = k.isMultiple(of: 2) ? 32 : 27
                let c = k.isMultiple(of: 2) ? rgb(0xFFCF3A) : rgb(0xFFEFAE)
                EggDesigns.streak(&canvas, from: (cx + cos(a) * 21, cy + sin(a) * 26), to: (cx + cos(a) * long, cy + sin(a) * (long + 3)),
                                  c, behind: true)
                if k.isMultiple(of: 2) {
                    EggDesigns.streak(&canvas, from: (cx + cos(a + 0.03) * 22, cy + sin(a + 0.03) * 27),
                                      to: (cx + cos(a + 0.03) * (long - 2), cy + sin(a + 0.03) * (long + 1)), c, behind: true)
                }
            }
        })
    }
}
