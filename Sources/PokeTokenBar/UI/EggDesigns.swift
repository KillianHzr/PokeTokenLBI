import AppKit
import SwiftUI

/// Where the egg stands in one frame of its idle loop, and how to place things around it.
struct EggFrame {
    let phase: Double           // 0..<2π over the loop
    let yaw: Double
    let tilt: Double
    let lift: Int               // pixels up
    let cx: Double
    let cy: Double
    /// Egg units (its height is 2) per pixel.
    let unitsPerPixel: Double

    /// A point of the egg's frame (x right, y up, in egg units) in pixels.
    func pixel(_ ex: Double, _ ey: Double) -> (Double, Double) {
        let (s, c) = (sin(tilt), cos(tilt))
        let u = ex * c - ey * s, v = ex * s + ey * c
        return (cx + u / unitsPerPixel, cy - v / unitsPerPixel - Double(lift))
    }

    /// The egg's radius at height `ey`, in pixels.
    func radius(_ ey: Double) -> Double { EggProfile.radius(ey) / unitsPerPixel }

    /// The loop as 0..<1.
    var t: Double { phase / (2 * .pi) }
}

/// A point of the egg's surface: turned by the yaw for what is painted on it.
struct EggSurfacePoint {
    let x, y, z: Double
    /// Around the axis, 0 facing the viewer.
    let angle: Double
    /// The normal, in the image's frame (for the light).
    let normal: EggVector
    let px: Int, py: Int
    /// How far the egg has turned on itself in this frame.
    var yaw: Double = 0
    /// Where the frame is in the loop, 0..<2π.
    var phase: Double = 0
}

/// What the egg's own surface looks like in a design.
struct EggSurface {
    var albedo: (EggSurfacePoint) -> EggColor
    /// Bumps, facets.
    var normal: ((EggVector, EggSurfacePoint) -> EggVector)? = nil
    /// The silhouette's radius scale at a height, on a side (-1 left, 1 right).
    var silhouette: ((Double, Double) -> Double)? = nil
    /// False leaves the pixel empty (a ghost's tail, a dithered fade).
    var keep: ((EggSurfacePoint) -> Bool)? = nil
    var gloss: Double = 0.4
    var shininess: Double = 40
    /// A crack around the top, at a height for each angle around: the cap above it lifts by `gap` egg units.
    var cap: ((Double) -> Double)? = nil
    var capGap: (Double) -> Double = { _ in 0 }
    /// Glowing parts, unshaded: lava veins.
    var emission: ((EggSurfacePoint) -> EggColor?)? = nil
    /// A shape that is not an egg, in its own frame (it turns with the yaw): where a ray from a point along a direction
    /// enters it, and the outward normal there. Replaces the egg's profile and `silhouette`.
    var solid: ((EggVector, EggVector) -> (point: EggVector, normal: EggVector)?)? = nil
}

/// A custom egg: its surface, what is drawn behind and in front of it, its outline.
struct EggDesign {
    var surface: EggSurface
    var back: (inout EggCanvas, EggFrame) -> Void = { _, _ in }
    var front: (inout EggCanvas, EggFrame) -> Void = { _, _ in }
    var outline: EggColor
    /// Light drawn over the outline, so thin sparks keep their color.
    var glow: (inout EggCanvas, EggFrame) -> Void = { _, _ in }
    /// The egg's height against the others', and where it stands: smaller and higher leaves room for what hangs under
    /// it (the Friendship Egg's balloon basket).
    var scale = 1.0
    var center = 35.0
}

/// The custom eggs: a gem for each rarer guarantee, one per type and Type: Null's, each its own shape and things around
/// it, rendered like the plain egg (`EggRenderer`) on a wider canvas so flames, wings or a ring fit.
enum EggDesigns {
    /// Pixels across: the egg is 48 pixels tall in it, the rest is room for what surrounds it.
    static let pixels = 64
    static let eggHeight = 48.0

    /// One frame of a design's idle loop.
    static func render(_ design: EggDesign, phase: Double) -> CGImage? {
        var canvas = EggCanvas(size: pixels)
        let frame = EggFrame(phase: phase, yaw: 0.52 * sin(phase), tilt: 0.09 * cos(phase),
                             lift: Int((2 * sin(phase)).rounded()), cx: Double(pixels) / 2, cy: design.center,
                             unitsPerPixel: 2 / (eggHeight * design.scale))
        design.back(&canvas, frame)
        drawEgg(&canvas, frame, design.surface)
        design.front(&canvas, frame)
        canvas.outline(design.outline)
        design.glow(&canvas, frame)
        return canvas.image()
    }

    /// The egg itself: per pixel, its front surface, lit, its marks turned with the yaw.
    static func drawEgg(_ canvas: inout EggCanvas, _ f: EggFrame, _ surface: EggSurface) {
        let samples = [(-0.25, -0.25), (0.25, -0.25), (-0.25, 0.25), (0.25, 0.25)]
        let (sinT, cosT) = (sin(f.tilt), cos(f.tilt)), (sinY, cosY) = (sin(f.yaw), cos(f.yaw))
        let upp = f.unitsPerPixel
        // Hit the egg at a point of the image (u, v in egg units): its surface point, or nil.
        func hit(_ u: Double, _ v: Double, _ px: Int, _ py: Int) -> EggSurfacePoint? {
            let x = u * cosT + v * sinT, y = -u * sinT + v * cosT
            let scale = surface.silhouette?(y, x < 0 ? -1 : 1) ?? 1
            let r = EggProfile.radius(y) * scale
            guard r > 0, abs(x) < r else { return nil }
            let z = (r * r - x * x).squareRoot()
            let n0 = EggLight.normalize((x, -r * EggProfile.slope(y) * scale, z))
            let normal: EggVector = (n0.x * cosT - n0.y * sinT, n0.x * sinT + n0.y * cosT, n0.z)
            let tx = x * cosY + z * sinY, tz = -x * sinY + z * cosY
            return EggSurfacePoint(x: tx, y: y, z: tz, angle: atan2(tx, tz), normal: normal, px: px, py: py)
        }
        // A shape of its own: the ray toward the pixel, in the shape's frame; its normal back in the image's.
        func hitSolid(_ u: Double, _ v: Double, _ px: Int, _ py: Int,
                      _ solid: (EggVector, EggVector) -> (point: EggVector, normal: EggVector)?) -> EggSurfacePoint? {
            let x = u * cosT + v * sinT, y = -u * sinT + v * cosT, z = 2.0
            let origin: EggVector = (x * cosY + z * sinY, y, -x * sinY + z * cosY)
            guard let (o, n) = solid(origin, (-sinY, 0, -cosY)) else { return nil }
            let nx = n.x * cosY - n.z * sinY, nz = n.x * sinY + n.z * cosY
            let normal: EggVector = (nx * cosT - n.y * sinT, nx * sinT + n.y * cosT, nz)
            return EggSurfacePoint(x: o.x, y: o.y, z: o.z, angle: atan2(o.x, o.z), normal: normal, px: px, py: py)
        }
        for py in 0..<canvas.size {
            for px in 0..<canvas.size {
                var sum = (0.0, 0.0, 0.0), count = 0.0
                for (sx, sy) in samples {
                    let u = (Double(px) + 0.5 + sx - f.cx) * upp
                    let v = (f.cy - Double(py) - 0.5 - sy - Double(f.lift)) * upp
                    var point: EggSurfacePoint?
                    if let solid = surface.solid {
                        point = hitSolid(u, v, px, py, solid)
                    } else if let cap = surface.cap {
                        // The cap, lifted, over the crack; the rest below it.
                        let gap = surface.capGap(f.phase)
                        if let top = hit(u, v - gap, px, py), top.y >= cap(top.angle) { point = top }
                        else if let low = hit(u, v, px, py), low.y < cap(low.angle) { point = low }
                    } else {
                        point = hit(u, v, px, py)
                    }
                    guard var p = point, surface.keep?(p) ?? true else { continue }
                    p.yaw = f.yaw
                    p.phase = f.phase
                    let n = surface.normal?(p.normal, p) ?? p.normal
                    let occlusion = 0.88 + 0.12 * EggLight.smoothstep(-1, -0.2, p.y)
                    let c = surface.emission?(p) ?? EggLight.shade(surface.albedo(p), normal: n, gloss: surface.gloss,
                                                                   shininess: surface.shininess, occlusion: occlusion)
                    sum.0 += c.r; sum.1 += c.g; sum.2 += c.b
                    count += 1
                }
                guard count >= 2 else { continue }
                canvas.set(px, py, EggColor(sum.0 / count, sum.1 / count, sum.2 / count))
            }
        }
    }

    /// Where a ray enters a convex solid cut by planes (outward normal, distance from the center), and that plane's
    /// normal.
    static func enter(_ planes: [(n: EggVector, d: Double)], _ o: EggVector,
                      _ dir: EggVector) -> (point: EggVector, normal: EggVector)? {
        var near = -Double.infinity, far = Double.infinity, normal: EggVector = (0, 0, 1)
        for plane in planes {
            let along = plane.n.x * dir.x + plane.n.y * dir.y + plane.n.z * dir.z
            let gap = plane.d - (plane.n.x * o.x + plane.n.y * o.y + plane.n.z * o.z)
            if abs(along) < 1e-9 {
                if gap < 0 { return nil }
                continue
            }
            let t = gap / along
            if along < 0 {
                if t > near { near = t; normal = plane.n }
            } else {
                far = min(far, t)
            }
        }
        guard near > -.infinity, near <= far else { return nil }
        return ((o.x + dir.x * near, o.y + dir.y * near, o.z + dir.z * near), normal)
    }

    /// A deterministic value in 0..<1 for a lattice point.
    static func hash(_ i: Int, _ j: Int, _ k: Int, seed: Int) -> Double {
        var h = UInt64(bitPattern: Int64(i &* 374_761_393 &+ j &* 668_265_263 &+ k &* 1_440_662_683 &+ seed &* 1_013_904_223))
        h = (h ^ (h >> 13)) &* 1_274_126_177
        h ^= h >> 16
        return Double(h & 0xFFFF) / 65536
    }

    /// Cellular noise: the distances to the nearest and the second nearest of points scattered one per unit cell.
    static func cells(_ x: Double, _ y: Double, _ z: Double) -> (near: Double, second: Double) {
        let xi = Int(x.rounded(.down)), yi = Int(y.rounded(.down)), zi = Int(z.rounded(.down))
        var near = 9.0, second = 9.0
        for i in xi - 1...xi + 1 {
            for j in yi - 1...yi + 1 {
                for k in zi - 1...zi + 1 {
                    let dx = Double(i) + hash(i, j, k, seed: 1) - x
                    let dy = Double(j) + hash(i, j, k, seed: 2) - y
                    let dz = Double(k) + hash(i, j, k, seed: 3) - z
                    let d = (dx * dx + dy * dy + dz * dz).squareRoot()
                    if d < near { second = near; near = d } else if d < second { second = d }
                }
            }
        }
        return (near, second)
    }

    // MARK: Surface helpers

    /// Spots at surface positions (angle around, height, radius): how much one covers a point.
    static func spots(_ p: EggSurfacePoint, _ list: [(Double, Double, Double)]) -> Double {
        var mask = 0.0
        for (theta, sy, radius) in list {
            let sr = EggProfile.radius(sy)
            let dx = p.x - sr * sin(theta), dy = p.y - sy, dz = p.z - sr * cos(theta)
            mask = max(mask, 1 - EggLight.smoothstep(radius * 0.86, radius, (dx * dx + dy * dy + dz * dz).squareRoot()))
        }
        return mask
    }

    /// A point's place on the surface's map around the front: (across, up), in egg units.
    static func front(_ p: EggSurfacePoint) -> (Double, Double) { (p.angle * EggProfile.radius(p.y), p.y) }

    static func color(_ type: PokemonType) -> EggColor { EggColor(type.color) }

    // MARK: The designs

    static func design(for kind: EggKind) -> EggDesign? {
        switch kind {
        case .type(let type): return design(for: type)
        case .typeNull: return typeNull
        case .birthday: return birthdaySurprise
        case .event(let event): return EventEggArt.design(event)
        case .fossil: return FossilEggArt.design
        case .dungeon(let species): return LegendEggArt.design(species) ?? design(for: EggKind.dungeonLook(species))
        case .tier(.uncommon): return emerald
        case .tier(.rare): return sapphire
        case .tier(.legendary): return legendary
        case .secret: return secret
        case .plain, .tier: return nil
        }
    }

    static func design(for type: PokemonType) -> EggDesign {
        switch type {
        case .normal: return normal
        case .fire: return fire
        case .water: return water
        case .electric: return electric
        case .grass: return grass
        case .ice: return ice
        case .fighting: return fighting
        case .poison: return poison
        case .ground: return ground
        case .flying: return flying
        case .psychic: return psychic
        case .bug: return bug
        case .rock: return rock
        case .ghost: return ghost
        case .dragon: return dragon
        case .dark: return dark
        case .steel: return steel
        case .fairy: return fairy
        }
    }

    /// Cracked around the top: the cap lifts off and settles back, about to hatch.
    static var normal: EggDesign {
        let shell = EggColor(0.93, 0.89, 0.80), spot = EggColor(0.66, 0.6, 0.52)
        let list: [(Double, Double, Double)] = [(-0.5, -0.2, 0.2), (0.55, -0.45, 0.17), (0.1, -0.7, 0.13), (-1.4, -0.5, 0.18)]
        var surface = EggSurface(albedo: { p in shell.mixed(with: spot, spots(p, list)) })
        // A zigzag crack a little above the middle.
        surface.cap = { angle in 0.28 + 0.08 * abs((angle / (2 * .pi) * 9).truncatingRemainder(dividingBy: 1) * 2 - 1) }
        surface.capGap = { phase in 0.04 + 0.1 * max(0, sin(phase)) }
        return EggDesign(surface: surface, outline: EggColor(0.36, 0.32, 0.27))
    }

    /// A shell of cooled lava, its cracks glowing; it sits in a fire rising all around it, embers flying off.
    static var fire: EggDesign {
        let crust = EggColor(0.2, 0.13, 0.13), ember = EggColor(0.58, 0.13, 0.07)
        func crack(_ p: EggSurfacePoint) -> (edge: Double, width: Double) {
            let c = cells(p.x * 2.4 + 7, p.y * 2.4, p.z * 2.4)
            let width = (0.05 + 0.08 * EggLight.smoothstep(0.7, -0.9, p.y)) * (0.92 + 0.12 * sin(p.phase * 2))
            return (c.second - c.near, width)
        }
        var surface = EggSurface(albedo: { p in
            let (edge, width) = crack(p)
            let glow = EggLight.smoothstep(width * 3.2, width, edge) * 0.8 + EggLight.smoothstep(0.1, -1, p.y) * 0.3
            return crust.mixed(with: ember, min(1, glow))
        }, gloss: 0.3, shininess: 30)
        surface.emission = { p in
            let (edge, width) = crack(p)
            guard edge < width else { return nil }
            return edge < width * 0.45 ? flame[3] : flame[2]
        }
        return EggDesign(surface: surface, back: { canvas, f in
            paintFire(&canvas, f, front: false)
            // Embers rising off the flames, cooling as they go; behind the egg, so never on its shell.
            for i in 0..<12 {
                let speed = Double(1 + i % 2)
                let age = (f.t * speed + Double(i) * 0.37).truncatingRemainder(dividingBy: 1)
                let side: Double = i.isMultiple(of: 2) ? -1 : 1
                let x0 = side * (0.8 + 0.3 * hash(i, 0, 0, seed: 9))
                let ex = x0 * (1 - age * 0.6) + 0.1 * sin(age * 10 + Double(i))
                let (px, py) = f.pixel(ex, -0.4 + age * 1.9)
                let color = age < 0.3 ? flame[4] : age < 0.6 ? flame[3] : flame[2]
                canvas.fill(px - 0.5, py - 0.5, px + 0.5, py + 0.5) { _, _ in color }
            }
        }, front: { canvas, f in
            paintFire(&canvas, f, front: true)
        }, outline: EggColor(0.28, 0.05, 0.03))
    }

    /// The fire's tones, from its cool edge to its white-hot heart.
    static let flame = [EggColor(0.62, 0.1, 0.05), EggColor(0.93, 0.28, 0.07), EggColor(1, 0.55, 0.1),
                        EggColor(1, 0.83, 0.28), EggColor(1, 0.96, 0.72)]

    /// Points around the egg's outline, closer together toward its ends, for distances to it.
    private static let outlinePoints: [(Double, Double)] = (0...96).flatMap { i -> [(Double, Double)] in
        let y = -cos(Double(i) / 96 * .pi)
        return [(EggProfile.radius(y), y), (-EggProfile.radius(y), y)]
    }

    /// The fire around the egg (or, in front, over its foot), in bands of its tones; lone pixels dropped.
    private static func paintFire(_ canvas: inout EggCanvas, _ f: EggFrame, front: Bool) {
        let size = canvas.size
        var heat = [Double](repeating: -1, count: size * size)
        if front {
            for py in 0..<size {
                for px in 0..<size { heat[py * size + px] = footFire(f, Double(px) + 0.5, Double(py) + 0.5) }
            }
        } else {
            // A skin of heat around the egg, hottest at its foot, carried straight up into tongues of a length that
            // changes from column to column and over the loop.
            var skin = [Double](repeating: 0, count: size * size)
            for py in 0..<size {
                for px in 0..<size { skin[py * size + px] = fireSkin(f, Double(px) + 0.5, Double(py) + 0.5) }
            }
            for px in 0..<size {
                let length = 4 + 16 * EggLight.noise(Double(px) * 0.3 + 5, f.t * 6, periodY: 6)
                for py in 0..<size {
                    var best = skin[py * size + px]
                    for k in 1..<22 where py + k < size {
                        best = max(best, skin[(py + k) * size + px] * (1 - Double(k) / length))
                    }
                    guard best > 0 else { continue }
                    let flicker = EggLight.noise(Double(px) * 0.5 + 9, Double(py) * 0.25 + f.t * 16, periodY: 16)
                    heat[py * size + px] = best * 1.1 - flicker * 0.35 + 0.05
                }
            }
        }
        func lit(_ x: Int, _ y: Int) -> Bool { x >= 0 && y >= 0 && x < size && y < size && heat[y * size + x] > 0 }
        for py in 0..<size {
            for px in 0..<size where heat[py * size + px] > 0 {
                let neighbors = [lit(px - 1, py), lit(px + 1, py), lit(px, py - 1), lit(px, py + 1)].filter { $0 }.count
                guard neighbors >= 2 else { continue }
                let h = heat[py * size + px]
                canvas.set(px, py, flame[h < 0.2 ? 0 : h < 0.42 ? 1 : h < 0.64 ? 2 : h < 0.84 ? 3 : 4])
            }
        }
    }

    /// A pixel in the egg's frame: (x, y) in egg units, and whether it is on the egg.
    private static func eggPoint(_ f: EggFrame, _ px: Double, _ py: Double) -> (x: Double, y: Double, inside: Bool) {
        let u = (px - f.cx) * f.unitsPerPixel, v = (f.cy - py - Double(f.lift)) * f.unitsPerPixel
        let x = u * cos(f.tilt) + v * sin(f.tilt), y = -u * sin(f.tilt) + v * cos(f.tilt)
        return (x, y, abs(y) < 1 && abs(x) < EggProfile.radius(y))
    }

    /// The heat in a thin skin around the egg: 1 against it, 0 a few pixels out; hotter toward its foot.
    private static func fireSkin(_ f: EggFrame, _ px: Double, _ py: Double) -> Double {
        let (x, y, inside) = eggPoint(f, px, py)
        guard !inside, abs(x) < 1.1, y > -1.25, y < 1.2 else { return inside ? 1 : 0 }
        var nearest = 9.0
        for (ox, oy) in outlinePoints { nearest = min(nearest, (x - ox) * (x - ox) + (y - oy) * (y - oy)) }
        let thickness = 0.14 + 0.1 * EggLight.smoothstep(0.3, -1, y)
        return max(0, 1 - nearest.squareRoot() / thickness) * (0.78 + 0.22 * EggLight.smoothstep(0.4, -0.9, y))
    }

    /// The flames licking the egg's foot, over it.
    private static func footFire(_ f: EggFrame, _ px: Double, _ py: Double) -> Double {
        let (x, y, inside) = eggPoint(f, px, py)
        guard inside else { return -1 }
        let noise = 0.65 * EggLight.noise(x * 4.5 + 20, y * 2.5 - f.t * 8, periodY: 8)
            + 0.35 * EggLight.noise(x * 10 + 40, y * 5 - f.t * 16, periodY: 16)
        return EggLight.smoothstep(-0.5, -1, y) * 1.25 - noise * 0.75
    }

    /// A drop's pointed top, waves around it, bubbles rising beside it.
    static var water: EggDesign {
        let light = EggColor(0.62, 0.84, 0.98), deep = color(.water), foam = EggColor(0.93, 0.98, 1)
        var surface = EggSurface(albedo: { p in
            var c = light.mixed(with: deep, EggLight.smoothstep(0.7, -0.9, p.y) * 0.6)
            for (center, width) in [(-0.35, 0.07), (0.05, 0.05), (-0.7, 0.06)] {
                let wave = center + 0.06 * sin(p.angle * 4)
                if abs(p.y - wave) < width { c = deep.mixed(with: .black, 0.1) }
                if abs(p.y - wave - width - 0.02) < 0.018 { c = foam }
            }
            return c
        }, gloss: 0.6, shininess: 60)
        // Pointier at the top, like a drop.
        surface.silhouette = { y, _ in y > 0.35 ? 1 - (y - 0.35) * 0.45 : 1 }
        return EggDesign(surface: surface, front: { canvas, f in
            for i in 0..<5 {
                let t = (f.t + Double(i) / 5).truncatingRemainder(dividingBy: 1)
                let side = i.isMultiple(of: 2) ? -1.0 : 1.0
                let x = f.cx + side * (21 + 3 * sin(t * 9 + Double(i))), y = 60 - t * 50
                let r = 2 + Double(i % 3) * 0.8
                canvas.fill(x - r - 1, y - r - 1, x + r + 1, y + r + 1) { px, py in
                    let d = ((px - x) * (px - x) + (py - y) * (py - y)).squareRoot()
                    if d > r + 0.5 { return nil }
                    if px < x - r * 0.3, py < y - r * 0.3, d < r * 0.6 { return .white }
                    return d > r - 1.2 ? EggColor(0.55, 0.8, 1) : nil
                }
            }
        }, outline: EggColor(0.1, 0.25, 0.5))
    }

    /// Overcharged: a crackling aura around it, its jagged edge and its arcs redrawn every frame, bolts leaping off
    /// it; the shell flashes.
    static var electric: EggDesign {
        let yellow = color(.electric), deep = EggColor(0.92, 0.6, 0.05)
        let glow = EggColor(1, 0.84, 0.22), pale = EggColor(1, 0.95, 0.6), white = EggColor(1, 1, 0.94)
        let surface = EggSurface(albedo: { (p: EggSurfacePoint) -> EggColor in
            let base = yellow.mixed(with: deep, EggLight.smoothstep(0.4, -1, p.y) * 0.5)
            return loopFrame(p.phase / (2 * .pi)) % 6 == 0 ? base.mixed(with: .white, 0.4) : base
        }, gloss: 0.55)
        return EggDesign(surface: surface, back: { canvas, f in
            let frame = Double(loopFrame(f.t))
            for py in 0..<canvas.size {
                for px in 0..<canvas.size {
                    let (x, y, inside) = eggPoint(f, Double(px) + 0.5, Double(py) + 0.5)
                    guard !inside, abs(x) < 1.25, abs(y) < 1.38 else { continue }
                    var nearest = 9.0
                    for (ox, oy) in outlinePoints { nearest = min(nearest, (x - ox) * (x - ox) + (y - oy) * (y - oy)) }
                    // A jagged edge: spikes around it, changing every frame.
                    let spike = EggLight.noise(atan2(y + 0.05, x) * 7 + frame * 3.3, frame * 1.9)
                    let reach = 0.11 + 0.32 * spike * spike, d = nearest.squareRoot()
                    guard d < reach else { continue }
                    let crackle = abs(EggLight.noise(Double(px) * 0.3 + frame * 7.3, Double(py) * 0.3) - 0.5)
                    canvas.set(px, py, crackle < 0.035 ? white : d < reach * 0.45 ? pale : glow)
                }
            }
        }, front: { canvas, f in
            let frame = loopFrame(f.t)
            for k in 0..<2 {
                let angle = hash(frame, k, 0, seed: 43) * 2 * .pi
                lightning(&canvas, f, from: rim(f, angle, out: 0.02), to: rim(f, angle + 0.2, out: 0.6), seed: 50 + k)
            }
        }, outline: EggColor(0.45, 0.3, 0.02))
    }

    /// The frame of the loop at `t` (0..<1), the loop's end counting as its start.
    static func loopFrame(_ t: Double) -> Int {
        Int((t * Double(EggRenderer.frameCount)).rounded()) % EggRenderer.frameCount
    }

    /// A lightning arc between two points of the canvas: jagged, its kinks redrawn every frame, a white core in a
    /// yellow glow.
    static func lightning(_ canvas: inout EggCanvas, _ f: EggFrame, from a: (Double, Double), to b: (Double, Double),
                          seed: Int) {
        let frame = loopFrame(f.t), kinks = 5
        let dx = b.0 - a.0, dy = b.1 - a.1, length = max(1, (dx * dx + dy * dy).squareRoot())
        var points: [(Double, Double)] = [a]
        for k in 1..<kinks {
            let t = Double(k) / Double(kinks), offset = (hash(seed, frame, k, seed: 31) - 0.5) * 4.8
            points.append((a.0 + dx * t - dy / length * offset, a.1 + dy * t + dx / length * offset))
        }
        points.append(b)
        canvas.path(points, width: 2.8, EggColor(1, 0.86, 0.25))
        canvas.path(points, width: 1.4, EggColor(1, 1, 0.9))
    }

    /// A point of the egg's outline at an angle (0 right, π/2 top), pushed out by `out` egg units, in pixels.
    private static func rim(_ f: EggFrame, _ angle: Double, out: Double) -> (Double, Double) {
        let y = sin(angle) * 0.96
        let x = cos(angle) * EggProfile.radius(y)
        let l = max(0.01, (x * x + y * y).squareRoot())
        return f.pixel(x + x / l * out, y + y / l * out)
    }

    /// Leaf veins on the shell; two leaves sprout from the top and sway.
    static var grass: EggDesign {
        let green = color(.grass), dark = color(.grass).mixed(with: .black, 0.3), light = EggColor(0.8, 0.95, 0.62)
        let surface = EggSurface(albedo: { p in
            let base = light.mixed(with: green, EggLight.smoothstep(0.9, -0.6, p.y))
            let vein = abs(sin(p.angle * 3)) < 0.1 && p.y < 0.75
            return vein ? dark : base
        }, gloss: 0.3)
        return EggDesign(surface: surface, front: { canvas, f in
            let (tx, ty) = f.pixel(0, 0.95)
            for side in [-1.0, 1.0] {
                let sway = 0.18 * sin(f.phase + (side < 0 ? 0 : 1.2))
                let angle = .pi / 2 + side * 0.75 + sway
                let len = 13.0
                let cx = tx + cos(angle) * len / 2, cy = ty - sin(angle) * len / 2
                canvas.ellipse(cx, cy, len / 2, 3.3, angle: angle, green.mixed(with: .white, 0.12), gloss: 0.1)
                canvas.line(tx, ty, tx + cos(angle) * len * 0.85, ty - sin(angle) * len * 0.85, width: 0.9, dark)
            }
            canvas.line(tx, ty + 1, tx, ty - 3, width: 1.6, dark)
        }, outline: EggColor(0.12, 0.3, 0.1))
    }

    /// Crystal facets, a crown of ice on top, snowflakes drifting down.
    static var ice: EggDesign {
        let ice = EggColor(0.72, 0.9, 0.98), deep = color(.ice).mixed(with: EggColor(0.3, 0.5, 1), 0.15)
        var surface = EggSurface(albedo: { p in
            if p.y > 0.62 + 0.06 * sin(p.angle * 7) { return .white }
            return ice.mixed(with: deep, EggLight.smoothstep(0.5, -1, p.y) * 0.6)
        }, gloss: 0.7, shininess: 80)
        // Facets: the normal snapped to a coarse lattice.
        surface.normal = { n, _ in EggLight.normalize(((n.x * 3).rounded() / 3, (n.y * 3).rounded() / 3, max(0.2, (n.z * 3).rounded() / 3))) }
        return EggDesign(surface: surface, front: { canvas, f in
            let (tx, ty) = f.pixel(0, 0.9)
            for (dx, h) in [(-5.0, 6.0), (0.0, 10.0), (5.0, 7.0), (-9.0, 4.0), (9.0, 4.0)] {
                let base = ty + abs(dx) * 0.35 + 2
                canvas.polygon([(tx + dx - 2.2, base), (tx + dx + 2.2, base), (tx + dx, base - h)], EggColor(0.8, 0.95, 1))
            }
            for i in 0..<4 {
                let t = (f.t + Double(i) / 4).truncatingRemainder(dividingBy: 1)
                let x = f.cx + (i < 2 ? -1.0 : 1.0) * (18 + Double(i % 2) * 6) + 2 * sin(t * 6), y = 6 + t * 50
                canvas.sparkle(x, y, 1.6, .white)
            }
        }, outline: EggColor(0.2, 0.4, 0.55))
    }

    /// A red headband knotted on the side, its tails flapping.
    static var fighting: EggDesign {
        let shell = EggColor(0.95, 0.9, 0.82), band = EggColor(0.86, 0.17, 0.15)
        let surface = EggSurface(albedo: { p in
            let edge = 0.38 + 0.02 * sin(p.angle * 2)
            return abs(p.y - edge) < 0.1 ? band : shell
        }, gloss: 0.3)
        return EggDesign(surface: surface, front: { canvas, f in
            // The knot on the right, where the band leaves the egg, and two tails waving away.
            let (kx, ky) = f.pixel(EggProfile.radius(0.38) * 0.93, 0.38)
            for (i, spread) in [-0.35, 0.3].enumerated() {
                let wave = 2 * sin(f.phase * 2 + Double(i))
                let tipX = kx + 13, tipY = ky + spread * 16 + wave
                canvas.polygon([(kx, ky - 1.8), (tipX, tipY - 2), (tipX - 1.5, tipY + 2), (kx, ky + 1.8)], band)
            }
            canvas.ball(kx, ky, 3, band)
        }, outline: EggColor(0.34, 0.08, 0.07))
    }

    /// Toxic bubbles on the shell; drops of goo gather under it and fall.
    static var poison: EggDesign {
        let purple = color(.poison), dark = color(.poison).mixed(with: .black, 0.4), goo = EggColor(0.75, 0.45, 0.85)
        let list: [(Double, Double, Double)] = [(-0.5, 0.2, 0.2), (0.45, -0.25, 0.24), (0.0, 0.6, 0.13),
                                                (-0.3, -0.6, 0.16), (1.3, 0.3, 0.18), (-1.4, -0.3, 0.2)]
        let surface = EggSurface(albedo: { p in
            let m = spots(p, list)
            return purple.mixed(with: dark, m).mixed(with: goo, m > 0.2 && m < 0.6 ? 0.6 : 0)
        }, gloss: 0.55, shininess: 50)
        return EggDesign(surface: surface, front: { canvas, f in
            for (i, sx) in [-0.35, 0.3].enumerated() {
                let t = (f.t + Double(i) * 0.5).truncatingRemainder(dividingBy: 1)
                let (bx, by) = f.pixel(sx, -0.9)
                let stretch = min(t, 0.6) / 0.6
                canvas.ellipse(bx, by + 1 + stretch * 2, 1.8, 1.5 + stretch * 2.2, goo, gloss: 0.4)
                if t > 0.6 { canvas.ball(bx, by + 5 + (t - 0.6) * 25, 1.6, goo, gloss: 0.5) }
            }
            for i in 0..<2 {
                let t = (f.t * 2 + Double(i) * 0.5).truncatingRemainder(dividingBy: 1)
                if t < 0.8 { canvas.ball(f.cx + (i == 0 ? -8 : 7), 10 - t * 6, 1 + t * 1.6, goo, gloss: 0.6) }
            }
        }, outline: EggColor(0.25, 0.08, 0.3))
    }

    /// Sandstone rippled by the wind, a sand tomb whirling around it.
    static var ground: EggDesign {
        let sand = EggColor(0.9, 0.76, 0.5), ripple = EggColor(0.74, 0.56, 0.32)
        let surface = EggSurface(albedo: { p in
            let (a, y) = front(p)
            let wave = ((y + 0.05 * sin(a * 7) + 2) * 7).truncatingRemainder(dividingBy: 1)
            return wave < 0.2 ? ripple : sand.mixed(with: ripple, EggLight.smoothstep(0.4, -1, p.y) * 0.35)
        }, gloss: 0.15)
        return EggDesign(surface: surface, back: { canvas, f in sandstorm(&canvas, f, behind: true) },
                         front: { canvas, f in sandstorm(&canvas, f, behind: false) },
                         outline: EggColor(0.36, 0.24, 0.1))
    }

    /// Three bands of sand spiraling up around the egg, each turning once over the loop, and loose grains; seen a
    /// little from above, so the far side is higher. Only the side asked for: behind the egg or in front of it.
    private static func sandstorm(_ canvas: inout EggCanvas, _ f: EggFrame, behind: Bool) {
        let tones = [EggColor(0.96, 0.86, 0.62), EggColor(0.86, 0.69, 0.42), EggColor(0.72, 0.54, 0.32)]
        func place(_ angle: Double, _ y: Double) -> (x: Double, y: Double, near: Bool) {
            let r = 0.92 + 0.22 * (y + 1) / 2
            let ex = r * cos(angle), ez = r * sin(angle)
            let (px, py) = f.pixel(ex, y - ez * 0.22)
            return (px, py, ez > 0)
        }
        for band in 0..<3 {
            for step in 0..<70 {
                let s = Double(step) / 70
                let angle = f.phase + Double(band) * 2.1 + s * 3.6
                let point = place(angle, -0.8 + Double(band) * 0.62 + s * 0.3)
                guard point.near != behind else { continue }
                let tone = point.near ? tones[band % 2] : tones[2]
                canvas.ball(point.x, point.y, 0.8 + 1.3 * sin(s * .pi), tone, gloss: 0)
            }
        }
        for i in 0..<24 {
            let speed = Double(1 + i % 2)
            let angle = f.phase * speed + hash(i, 0, 0, seed: 7) * 2 * .pi
            let point = place(angle, -1 + 2.1 * hash(i, 1, 0, seed: 7))
            guard point.near != behind else { continue }
            canvas.set(Int(point.x), Int(point.y), tones[i % 3])
        }
    }

    /// Two feathered wings at its sides, beating.
    static var flying: EggDesign {
        let sky = EggColor(0.75, 0.86, 1), white = EggColor(0.98, 0.99, 1), feather = EggColor(0.93, 0.95, 1)
        let surface = EggSurface(albedo: { p in
            sky.mixed(with: white, EggLight.smoothstep(-0.6, 0.7, p.y) * 0.7 + spots(p, [(-0.5, -0.4, 0.2), (0.6, 0.1, 0.16), (0.1, -0.75, 0.13)]) * 0.5)
        }, gloss: 0.35)
        return EggDesign(surface: surface, back: { canvas, f in
            let beat = sin(f.phase * 2)
            for side in [-1.0, 1.0] {
                let (rx, ry) = f.pixel(side * EggProfile.radius(0.2) * 0.92, 0.2)
                // Feathers fanned from up and out to straight out, rising and falling with the beat.
                for k in 0..<4 {
                    let spread = 1.0 - Double(k) * 0.3 + beat * 0.3
                    let angle = side > 0 ? spread : .pi - spread
                    let len = 18.0 - Double(k) * 1.5
                    canvas.ellipse(rx + cos(angle) * len / 2, ry - sin(angle) * len / 2, len / 2, 3.2, angle: angle,
                                   k.isMultiple(of: 2) ? feather : white, gloss: 0.1)
                }
            }
        }, outline: EggColor(0.35, 0.45, 0.65))
    }

    /// A hypnotic spiral turning on its front; a ring orbits it.
    static var psychic: EggDesign {
        let pink = color(.psychic).mixed(with: .white, 0.25), magenta = color(.psychic).mixed(with: .black, 0.1)
        return EggDesign(surface: EggSurface(albedo: { p in
            let (a, y) = front(p)
            let dx = a, dy = y - 0.05
            let r = (dx * dx + dy * dy).squareRoot()
            guard r < 0.42 else { return pink }
            // Rotates with the loop: four turns from the middle out.
            let spin = (atan2(dy, dx) / (2 * .pi) + r * 2.6 - 0 + 10).truncatingRemainder(dividingBy: 1)
            return spin < 0.5 ? magenta : pink.mixed(with: .white, 0.3)
        }, gloss: 0.45), back: { canvas, f in ring(&canvas, f, behind: true, magenta) },
        front: { canvas, f in ring(&canvas, f, behind: false, magenta) },
        outline: EggColor(0.4, 0.1, 0.25))
    }

    /// The psychic ring: its back half behind the egg, its front half over it, three orbs going round.
    private static func ring(_ canvas: inout EggCanvas, _ f: EggFrame, behind: Bool, _ color: EggColor) {
        let cx = f.cx, cy = f.cy + 2 - Double(f.lift)
        let rx = 28.0, ry = 7.0, tilt = -0.18
        let (s, c) = (sin(tilt), cos(tilt))
        func point(_ a: Double) -> (Double, Double) {
            let x = cos(a) * rx, y = sin(a) * ry
            return (cx + x * c - y * s, cy + x * s + y * c)
        }
        // sin(a) > 0 is the near side.
        for step in 0..<160 {
            let a = Double(step) / 160 * 2 * .pi
            guard (sin(a) > 0) != behind else { continue }
            let (x, y) = point(a)
            canvas.ball(x, y, 1.1, EggColor(0.85, 0.7, 1), gloss: 0)
        }
        for k in 0..<3 {
            let a = f.phase + Double(k) * 2 * .pi / 3
            guard (sin(a) > 0) != behind else { continue }
            let (x, y) = point(a)
            canvas.ball(x, y, 2.2, color.mixed(with: .white, 0.3), gloss: 0.5)
        }
    }

    /// Segments like a larva's; two antennae bobbing on top.
    static var bug: EggDesign {
        let lime = color(.bug).mixed(with: .white, 0.15), band = color(.bug).mixed(with: .black, 0.3)
        let surface = EggSurface(albedo: { p in
            let seg = ((p.y + 1) * 3.2).truncatingRemainder(dividingBy: 1)
            if seg < 0.14 { return band }
            return lime.mixed(with: band, spots(p, [(-0.45, 0.2, 0.08), (0.45, 0.2, 0.08)]))
        }, gloss: 0.35)
        return EggDesign(surface: surface, front: { canvas, f in
            let (tx, ty) = f.pixel(0, 0.97)
            for side in [-1.0, 1.0] {
                let bob = 1.5 * sin(f.phase * 2 + side)
                let mid = (tx + side * 4, ty - 7 + bob * 0.5), tip = (tx + side * 9, ty - 11 + bob)
                canvas.path([(tx + side * 1.5, ty + 1), mid, tip], width: 1.3, band)
                canvas.ball(tip.0, tip.1, 2, band.mixed(with: .white, 0.2))
            }
        }, outline: EggColor(0.22, 0.3, 0.05))
    }

    /// An egg of stone, chiseled flat all around, speckled, a quartz vein through it.
    static var rock: EggDesign {
        let stone = EggColor(0.66, 0.6, 0.5), dark = EggColor(0.44, 0.39, 0.33), light = EggColor(0.82, 0.77, 0.68)
        let quartz = EggColor(0.95, 0.94, 0.9), vein = EggLight.normalize((0.5, 0.8, 0.3))
        var surface = EggSurface(albedo: { p in
            let patch = 0.5 * EggLight.noise(p.x * 3 + 11, p.y * 3) + 0.5 * EggLight.noise(p.z * 3 + 3, p.y * 3 + 7)
            var c = stone.mixed(with: dark, EggLight.smoothstep(0.45, 0.7, patch) * 0.55)
            let grain = EggLight.noise((p.x + p.z) * 13 + 5, p.y * 13)
            if grain > 0.8 { c = c.mixed(with: .black, 0.22) } else if grain < 0.12 { c = c.mixed(with: light, 0.6) }
            // A quartz vein through the stone: a slab, so it wraps around it as it turns.
            let across = vein.x * p.x + vein.y * p.y + vein.z * p.z - 0.05 + 0.04 * (EggLight.noise(p.x * 6, p.z * 6) - 0.5)
            if abs(across) < 0.045 { return quartz.mixed(with: stone, EggLight.noise(p.x * 20, p.y * 20) * 0.3) }
            return c
        }, gloss: 0.15, shininess: 20)
        surface.solid = { o, dir in enter(rockPlanes, o, dir) }
        return EggDesign(surface: surface, outline: EggColor(0.24, 0.22, 0.19))
    }

    /// Points of the egg's surface, for the planes that touch it.
    private static let eggSurfacePoints: [EggVector] = (0...40).flatMap { i -> [EggVector] in
        let y = -cos(Double(i) / 40 * .pi), r = EggProfile.radius(y)
        return (0..<48).map { k in (r * sin(Double(k) / 48 * 2 * .pi), y, r * cos(Double(k) / 48 * 2 * .pi)) }
    }

    /// The stone egg's faces: planes touching the egg from directions spread all around, each pushed in by up to
    /// `depth`, and a flat foot.
    private static let rockPlanes = chiseledEgg(faces: 40, depth: 0.06)

    /// How far the egg reaches in a direction: where a plane facing it touches the egg.
    private static func touch(_ n: EggVector) -> Double {
        eggSurfacePoints.map { n.x * $0.x + n.y * $0.y + n.z * $0.z }.max() ?? 1
    }

    /// The face of a cut solid a point lies on: the plane it is closest to.
    static func face(_ planes: [(n: EggVector, d: Double)], _ p: EggSurfacePoint) -> Int {
        var best = 0, gap = Double.infinity
        for (i, plane) in planes.enumerated() {
            let g = abs(plane.n.x * p.x + plane.n.y * p.y + plane.n.z * p.z - plane.d)
            if g < gap { gap = g; best = i }
        }
        return best
    }

    /// A jeweler's cut of the egg: rings of faces around it, each ring's faces between the last ring's, a table on top
    /// and a flat foot.
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

    private static func chiseledEgg(faces: Int, depth: Double) -> [(n: EggVector, d: Double)] {
        var planes: [(n: EggVector, d: Double)] = (0..<faces).map { i in
            let y = 1 - 2 * (Double(i) + 0.5) / Double(faces), ring = (1 - y * y).squareRoot()
            let a = Double(i) * 2.399963 + hash(i, 1, 0, seed: 5) * 0.6
            let n = EggLight.normalize((ring * sin(a) + (hash(i, 2, 0, seed: 5) - 0.5) * 0.3,
                                        y + (hash(i, 3, 0, seed: 5) - 0.5) * 0.3, ring * cos(a)))
            return (n, touch(n) * (1 - depth * hash(i, 4, 0, seed: 5)))
        }
        planes.append(((0, -1, 0), 0.95))
        return planes
    }

    /// Its bottom melts into a wavy ghost's tail, fading out; it watches you; wisps drift around.
    static var ghost: EggDesign {
        let purple = color(.ghost).mixed(with: .white, 0.15), eye = EggColor(0.12, 0.05, 0.18)
        var surface = EggSurface(albedo: { p in
            let (a, y) = front(p)
            for side in [-1.0, 1.0] {
                let dx = (a - side * 0.17) / 0.075, dy = (y - 0.28) / 0.12
                if dx * dx + dy * dy < 1 { return eye }
            }
            return purple.mixed(with: .white, EggLight.smoothstep(0, 0.9, y) * 0.2)
        }, gloss: 0.5)
        surface.keep = { p in
            // A wavy tail, and the lower part checkered out like a fade.
            let edge = -0.72 + 0.12 * sin(Double(p.px) * 0.7 + Double(p.py) * 0)
            if p.y < edge { return false }
            if p.y < -0.35 { return (p.px + p.py).isMultiple(of: 2) || p.y > -0.45 }
            return true
        }
        return EggDesign(surface: surface, back: { canvas, f in
            for i in 0..<2 {
                let t = (f.t + Double(i) * 0.5).truncatingRemainder(dividingBy: 1)
                let x = f.cx + (i == 0 ? -22.0 : 21) + 2 * sin(t * 2 * .pi * 2), y = 48 - t * 36
                canvas.flame(baseX: x, baseY: y, height: 7, width: 2.4, lean: 0.2 * sin(t * 6),
                             outer: purple.mixed(with: .black, 0.2), middle: purple, core: EggColor(0.95, 0.85, 1))
            }
        }, outline: EggColor(0.22, 0.12, 0.3))
    }

    /// Large overlapping scales, indigo darkening down, lit in their middle; a cream belly of plates like Dragonite's;
    /// two bat wings beating behind it, golden horns, golden embers rising (the owner chose it on 2026-11-10 over two
    /// others, the old one with its small scales and fins looked "affreux").
    static var dragon: EggDesign {
        let indigo = EggColor(0.17, 0.14, 0.47), violet = EggColor(0.42, 0.34, 0.88), lilac = EggColor(0.66, 0.61, 1)
        let cream = EggColor(0.96, 0.89, 0.71), creamD = EggColor(0.8, 0.66, 0.39)
        let gold = EggColor(0.95, 0.8, 0.39), goldD = EggColor(0.69, 0.51, 0.16)
        func frac(_ x: Double) -> Double { x - x.rounded(.down) }
        // How far inside its scale a point is (0 at its middle, 1 on its edge), the scales hanging like roof tiles.
        func scale(_ a: Double, _ y: Double) -> (inside: Double, rim: Bool) {
            let rowH = 0.3, colW = 0.38
            let row = ((y + 1.2) / rowH).rounded(.down)
            let fy = (y + 1.2) / rowH - row
            let shift = row.truncatingRemainder(dividingBy: 2) == 0 ? 0.0 : 0.5
            let fx = frac(a / colW + shift) - 0.5
            let d = (fx * fx * 1.1 + (1 - fy) * (1 - fy) * 0.55).squareRoot() / 0.62
            return (min(1, d), d > 0.82)
        }
        func onBelly(_ a: Double, _ y: Double) -> Bool { abs(a) < 0.28 - max(0, y - 0.3) * 0.5 && y < 0.66 && y > -0.9 }
        var surface = EggSurface(albedo: { p in
            let (a, y) = front(p)
            if onBelly(a, y) {
                let half = 0.28 - max(0, y - 0.3) * 0.5
                let band = frac((y + 1) / 0.21)
                if band < 0.14 || abs(a) > half - 0.035 { return creamD }
                return cream.mixed(with: .white, max(0, 0.25 - abs(a) * 0.8)).mixed(with: creamD, band * 0.25)
            }
            let s = scale(a, y)
            let body = indigo.mixed(with: violet, 0.35 + (y + 1) / 2 * 0.55)
            if s.rim { return body.mixed(with: .black, 0.45) }
            // Lit in its middle, a pale edge along its lower rim.
            return body.mixed(with: lilac, max(0, 0.6 - s.inside * 0.62) + (s.inside > 0.66 ? 0.22 : 0))
        }, gloss: 0.55, shininess: 55)
        surface.normal = { n, p in
            let (a, y) = front(p)
            guard !onBelly(a, y) else { return n }
            return EggLight.normalize((n.x, n.y - scale(a, y).inside * 0.35, n.z))
        }
        return EggDesign(surface: surface, back: { canvas, f in
            // Two bat wings, beating slowly: four fingers, the membrane sagging between them, a claw at the top.
            for side in [-1.0, 1.0] {
                let beat = sin(f.phase * 2) * 0.18
                let (sx, sy) = f.pixel(side * 0.55, 0.25)
                func finger(_ angle: Double, _ length: Double) -> (Double, Double) {
                    let a = angle + side * beat
                    return (sx + side * cos(a) * length, sy - sin(a) * length)
                }
                let tips = [finger(1.15, 25), finger(0.72, 27), finger(0.32, 23), finger(-0.05, 17)]
                var membrane: [(Double, Double)] = [(sx, sy - 2)]
                for (i, tip) in tips.enumerated() {
                    membrane.append(tip)
                    guard i < tips.count - 1 else { continue }
                    let next = tips[i + 1]
                    membrane.append(((tip.0 + next.0) / 2 - side * 2.5, (tip.1 + next.1) / 2 + 3))
                }
                membrane.append((sx + side * 6, sy + 12))
                canvas.polygon(membrane, lilac.mixed(with: violet, 0.35))
                for tip in tips { canvas.line(sx, sy, tip.0, tip.1, width: 1.6, indigo) }
                canvas.ball(sx, sy - 1, 2.2, indigo, gloss: 0.2)
                let claw = tips[0]
                canvas.polygon([(claw.0 - 1, claw.1 + 1), (claw.0 + side * 3, claw.1 - 3), (claw.0 + 1, claw.1 + 1)], gold)
            }
        }, front: { canvas, f in
            // Two horns curving back, a small crest between them.
            for side in [-1.0, 1.0] {
                let (bx, by) = f.pixel(side * 0.3, 0.86)
                canvas.polygon([(bx - 2.6, by + 2), (bx + 2.6, by + 2), (bx + side * 5, by - 6), (bx + side * 9.5, by - 12),
                                (bx + side * 3, by - 5.5)], gold)
                canvas.line(bx + side * 1, by + 1, bx + side * 7, by - 9, width: 0.8, goldD)
            }
            let (tx, ty) = f.pixel(0, 0.97)
            canvas.polygon([(tx - 2, ty + 1), (tx, ty - 5), (tx + 2, ty + 1)], violet)
        }, outline: EggColor(0.08, 0.06, 0.27), glow: { canvas, f in
            // Golden embers rising past it.
            for i in 0..<6 {
                let t = frac(f.t + Double(i) / 6)
                guard t < 0.9 else { continue }
                let x = 6 + Double(i) * 10.5 + 2 * sin(t * 7 + Double(i)), y = 62 - t * 58
                light(&canvas, x, y, i.isMultiple(of: 2) ? gold : EggColor(1, 0.95, 0.72), behind: true)
                if t < 0.5 { light(&canvas, x, y + 1, goldD, behind: true) }
            }
        })
    }

    /// A shell like the night, a crescent moon glowing on it; dark smoke drifts around.
    static var dark: EggDesign {
        let night = EggColor(0.22, 0.2, 0.28), moon = EggColor(1, 0.86, 0.45)
        let surface = EggSurface(albedo: { p in
            let (a, y) = front(p)
            let d1 = ((a - 0.02) * (a - 0.02) + (y - 0.2) * (y - 0.2)).squareRoot()
            let d2 = ((a - 0.12) * (a - 0.12) + (y - 0.27) * (y - 0.27)).squareRoot()
            if d1 < 0.26 && d2 > 0.22 { return moon }
            let star = EggLight.noise(p.angle * 14, p.y * 14) > 0.9
            return star ? EggColor(0.7, 0.7, 0.85) : night
        }, gloss: 0.5, shininess: 60)
        return EggDesign(surface: surface, back: { canvas, f in
            for i in 0..<5 {
                let t = (f.t + Double(i) / 5).truncatingRemainder(dividingBy: 1)
                let a = Double(i) * 1.3 + t * 2
                let x = f.cx + cos(a) * 22, y = 52 - t * 30
                canvas.ball(x, y, 3.5 - t * 2, EggColor(0.32, 0.26, 0.4).mixed(with: .black, t * 0.3), gloss: 0)
            }
        }, outline: EggColor(0.08, 0.06, 0.12))
    }

    /// Chrome reflecting a sky and a horizon; a toothed gear rim around its middle.
    static var steel: EggDesign {
        let sky = EggColor(0.86, 0.9, 0.95), ground = EggColor(0.36, 0.38, 0.44), bolt = EggColor(0.55, 0.57, 0.62)
        let step = Double.pi / 6
        func onBolt(_ angle: Double) -> Bool {
            let offset: Double = (angle + 20 * .pi).truncatingRemainder(dividingBy: step)
            return offset < 0.08 || offset > step - 0.08
        }
        var surface = EggSurface(albedo: { p in
            if abs(p.y) < 0.09 { return onBolt(p.angle) ? bolt.mixed(with: .white, 0.3) : bolt }
            // The reflected view's height: the sky above the horizon, the ground under it, a bright line between.
            let ry: Double = 2 * p.normal.z * p.normal.y
            if abs(ry - 0.05) < 0.06 { return .white }
            return ry > 0.05 ? sky.mixed(with: EggColor(0.6, 0.7, 0.85), ry * 0.6) : ground
        }, gloss: 0.8, shininess: 90)
        // Teeth stand out of the outline around the middle.
        surface.silhouette = { y, _ in
            guard abs(y) < 0.09 else { return 1 }
            let tooth: Int = Int(((y + 0.09) * 40).rounded(.down))
            return tooth.isMultiple(of: 2) ? 1.11 : 1.07
        }
        return EggDesign(surface: surface, outline: EggColor(0.15, 0.16, 0.2))
    }

    /// Hearts on a pastel shell, a bow on top, sparkles twinkling around.
    static var fairy: EggDesign {
        let pastel = EggColor(1, 0.9, 0.95), pink = color(.fairy), bow = EggColor(0.98, 0.5, 0.72)
        let hearts: [(Double, Double)] = [(-0.45, 0.1), (0.45, -0.35), (0.05, -0.6), (0.2, 0.45), (-1.4, -0.3), (1.5, 0.2)]
        let surface = EggSurface(albedo: { p in
            for (theta, hy) in hearts {
                var da = p.angle - theta
                if da > .pi { da -= 2 * .pi }; if da < -.pi { da += 2 * .pi }
                let x = da * EggProfile.radius(p.y) / 0.13, y = (p.y - hy) / 0.13
                // The heart curve: (x² + y² - 1)³ - x² y³ < 0.
                let q = x * x + y * y - 1
                if q * q * q - x * x * y * y * y < 0 { return pink }
            }
            return pastel
        }, gloss: 0.45)
        return EggDesign(surface: surface, back: { canvas, f in
            for i in 0..<4 {
                let a = Double(i) * .pi / 2 + 0.7
                let twinkle = max(0, sin(f.phase * 2 + Double(i) * 1.6))
                if twinkle > 0.1 { canvas.sparkle(f.cx + cos(a) * 25, f.cy + sin(a) * 22, 1 + twinkle * 2.4, EggColor(1, 0.95, 0.6)) }
            }
        }, front: { canvas, f in
            let (bx, by) = f.pixel(0, 0.93)
            let flap = 0.8 * sin(f.phase * 2)
            canvas.polygon([(bx, by), (bx - 9, by - 5 - flap), (bx - 8, by + 4)], bow)
            canvas.polygon([(bx, by), (bx + 9, by - 5 + flap), (bx + 8, by + 4)], bow)
            canvas.ball(bx, by, 2.4, bow.mixed(with: .white, 0.2))
        }, outline: EggColor(0.45, 0.15, 0.3))
    }

    /// Type: Null's: riveted steel plates, a knight's helm over the top with a visor and a crest.
    static var typeNull: EggDesign {
        let plate = EggColor(0.62, 0.64, 0.68), seam = EggColor(0.22, 0.23, 0.27), rivet = EggColor(0.86, 0.85, 0.8)
        let helm = EggColor(0.4, 0.42, 0.47), visor = EggColor(0.1, 0.11, 0.14), glow = EggColor(0.4, 0.9, 0.85)
        func helmRim(_ angle: Double) -> Double { 0.05 + 0.05 * cos(angle) }
        var surface = EggSurface(albedo: { p in
            let (a, y) = front(p)
            if y > helmRim(p.angle) {
                if y < helmRim(p.angle) + 0.04 { return seam }
                if abs(y - 0.36) < 0.05 && abs(a) < 0.45 {
                    return abs(abs(a) - 0.16) < 0.06 ? glow : visor
                }
                if abs(a) < 0.06 && y > 0.4 { return helm.mixed(with: .white, 0.35) }
                return helm
            }
            if abs(a) < 0.035 || abs(y + 0.4) < 0.02 { return seam }
            for k in -4...4 where abs(a - 0.11) < 0.04 && abs(y - (-0.4 + Double(k) * 0.18)) < 0.04 { return rivet }
            for k in -4...4 where abs(a + 0.11) < 0.04 && abs(y - (-0.4 + Double(k) * 0.18)) < 0.04 { return rivet }
            return plate
        }, gloss: 0.6, shininess: 70)
        // The helm is a little wider than the egg below it.
        surface.silhouette = { y, _ in y > 0.08 ? 1.07 : 1 }
        return EggDesign(surface: surface, back: { canvas, f in
            // The crest: a plume of blades over the helm, swaying.
            let (tx, ty) = f.pixel(0, 0.98)
            for k in -3...3 {
                let sway = 0.08 * sin(f.phase + Double(k))
                let angle = .pi / 2 - Double(k) * 0.3 + sway
                let len = 19.0 - Double(abs(k)) * 2.6
                canvas.polygon([(tx - 2.4, ty + 3), (tx + 2.4, ty + 3),
                                (tx + cos(angle) * len, ty - sin(angle) * len)],
                               k.isMultiple(of: 2) ? EggColor(0.32, 0.34, 0.38) : EggColor(0.24, 0.5, 0.52))
            }
        }, outline: EggColor(0.12, 0.13, 0.16))
    }

    // MARK: Rarity eggs

    private static let gemPlanes = cutEgg(rings: [(-1.0, 8), (-0.5, 8), (0, 8), (0.45, 8), (0.9, 8), (1.25, 6)])

    /// A gem cut from the egg: each face its own shade of the stone's color, glossy, so faces flash as it turns.
    private static func gemSurface(_ color: EggColor) -> EggSurface {
        var surface = EggSurface(albedo: { p in
            let tone = hash(face(gemPlanes, p), 0, 0, seed: 21)
            return tone < 0.5 ? color.mixed(with: .black, (0.5 - tone) * 0.7) : color.mixed(with: .white, (tone - 0.5) * 0.7)
        }, gloss: 0.9, shininess: 70)
        surface.solid = { o, dir in enter(gemPlanes, o, dir) }
        return surface
    }

    /// Sparkles flashing in turn, at points of the egg's frame.
    private static func sparkles(_ canvas: inout EggCanvas, _ f: EggFrame, _ spots: [(Double, Double)],
                                 _ color: EggColor) {
        for (i, (x, y)) in spots.enumerated() {
            let pulse = max(0, sin(f.phase * 2 + Double(i) * 2.4))
            guard pulse > 0.3 else { continue }
            let (px, py) = f.pixel(x, y)
            canvas.sparkle(px, py, 1.5 + 3 * pulse * pulse, color)
        }
    }

    /// The Uncommon-or-better egg: an emerald cut from the egg, glinting.
    static var emerald: EggDesign {
        let emerald = EggColor(rarityColor(.uncommon)).mixed(with: .black, 0.2)
        return EggDesign(surface: gemSurface(emerald), front: { canvas, f in
            sparkles(&canvas, f, [(-0.55, 0.55), (0.6, -0.1), (0.05, -0.75)], EggColor(0.92, 1, 0.94))
        }, outline: emerald.mixed(with: .black, 0.7))
    }

    /// The Rare-or-better egg: a sapphire cut from the egg, set in gold claws, glinting more.
    static var sapphire: EggDesign {
        let sapphire = EggColor(rarityColor(.rare)).mixed(with: .black, 0.25), gold = EggColor(0.98, 0.78, 0.3)
        var surface = gemSurface(sapphire)
        let stone = surface.albedo
        surface.albedo = { p in
            let r = (p.x * p.x + p.z * p.z).squareRoot()
            // The cup, its rim scalloped, and four claws up the sides, each ending in a bead.
            if p.y < -0.74 + 0.04 * abs(sin(p.angle * 4)) { return gold }
            for k in 0..<4 {
                let clawAngle = (Double(k) + 0.5) * .pi / 2
                var d = abs(p.angle - clawAngle).truncatingRemainder(dividingBy: 2 * .pi)
                if d > .pi { d = 2 * .pi - d }
                if p.y < -0.12, d * r < 0.05 + 0.08 * (1 - EggLight.smoothstep(-0.74, -0.12, p.y)) { return gold }
                let tipR = EggProfile.radius(-0.08)
                let dx = p.x - tipR * sin(clawAngle), dy = p.y + 0.08, dz = p.z - tipR * cos(clawAngle)
                if dx * dx + dy * dy + dz * dz < 0.085 * 0.085 { return gold.mixed(with: .white, 0.25) }
            }
            return stone(p)
        }
        return EggDesign(surface: surface, front: { canvas, f in
            sparkles(&canvas, f, [(-0.6, 0.6), (0.62, 0.1), (0.1, 0.95), (-0.75, -0.25), (0.5, -0.55)],
                     EggColor(0.9, 0.95, 1))
        }, outline: sapphire.mixed(with: .black, 0.7))
    }

    // MARK: Legendary egg

    /// A saturated color around the hue circle (0..<1).
    static func hue(_ h: Double) -> EggColor {
        let h6: Double = (h - h.rounded(.down)) * 6
        let x: Double = 1 - abs(h6.truncatingRemainder(dividingBy: 2) - 1)
        switch Int(h6) {
        case 0: return EggColor(1, x, 0)
        case 1: return EggColor(x, 1, 0)
        case 2: return EggColor(0, 1, x)
        case 3: return EggColor(0, x, 1)
        case 4: return EggColor(x, 0, 1)
        default: return EggColor(1, 0, x)
        }
    }

    private static let gold = EggColor(0.98, 0.78, 0.3)

    /// The Legendary Egg: a brilliant-cut diamond, clear faces, some flashing the rainbow as it turns, set in gold,
    /// crowned.
    static var legendary: EggDesign {
        let ice = EggColor(0.86, 0.92, 0.98)
        var surface = EggSurface(albedo: { (p: EggSurfacePoint) -> EggColor in
            let k = face(gemPlanes, p)
            let tone: Double = hash(k, 0, 0, seed: 21)
            if p.y < -0.74 + 0.04 * abs(sin(p.angle * 4)) { return gold }
            if tone > 0.88 { return hue(tone * 5 + p.yaw * 0.6).mixed(with: .white, 0.62) }
            return tone < 0.35 ? ice.mixed(with: EggColor(0.6, 0.68, 0.8), (0.35 - tone) * 1.6) : ice.mixed(with: .white, (tone - 0.35) * 1.4)
        }, gloss: 0.95, shininess: 80)
        surface.solid = { o, dir in enter(gemPlanes, o, dir) }
        return EggDesign(surface: surface, front: { canvas, f in
            let (cx, top) = f.pixel(0, 0.98)
            let crown: [(Double, Double)] = [(cx - 8, top + 2), (cx - 8, top - 5), (cx - 4.5, top - 1.5), (cx, top - 7),
                                             (cx + 4.5, top - 1.5), (cx + 8, top - 5), (cx + 8, top + 2)]
            canvas.polygon(crown, gold)
            canvas.ball(cx, top - 7, 1.4, EggColor(0.9, 0.15, 0.25), gloss: 0.6)
            sparkles(&canvas, f, [(-0.62, 0.5), (0.65, 0.15), (-0.2, -0.6), (0.4, 0.75), (-0.8, -0.2), (0.75, -0.55)],
                     .white)
        }, outline: EggColor(0.3, 0.32, 0.4))
    }

    // MARK: Secret Egg

    /// The Secret Egg, every secret boss's (the owner, 2026-11-10): a black egg over a hidden sun, its rim lit, the
    /// corona's rays turning behind.
    static var secret: EggDesign {
        let black = EggColor(0.06, 0.05, 0.09), rim = EggColor(1, 0.86, 0.5)
        var surface = EggSurface(albedo: { p in
            let star = EggLight.noise(p.angle * 16 + 11, p.y * 16) > 0.94
            return star ? EggColor(0.4, 0.36, 0.5) : black
        }, gloss: 0.35, shininess: 50)
        surface.emission = { p in
            // Light only on the edge, as the hidden sun shows round the moon.
            let edge = 1 - p.normal.z
            return edge > 0.8 ? rim.mixed(with: .white, (edge - 0.8) * 2) : nil
        }
        // The sun's corona round the egg's own shape, a little wider: points of the egg's edge pushed out.
        func halo(_ f: EggFrame, out: Double) -> [(Double, Double)] {
            (0..<48).map { i in
                let y = -0.98 + 1.96 * Double(i) / 47
                let (x, py) = f.pixel(EggProfile.radius(y) + out, y)
                return (x, py)
            } + (0..<48).reversed().map { i in
                let y = -0.98 + 1.96 * Double(i) / 47
                let (x, py) = f.pixel(-EggProfile.radius(y) - out, y)
                return (x, py)
            }
        }
        return EggDesign(surface: surface, back: { canvas, f in
            canvas.polygon(halo(f, out: 0.16), EggColor(0.95, 0.55, 0.12), shade: false)
            canvas.polygon(halo(f, out: 0.08), EggColor(1, 0.86, 0.5), shade: false)
        }, outline: EggColor(0.03, 0.02, 0.05), glow: { canvas, f in
            // The corona's rays, turning slowly, drawn after the outline: light has no border.
            let (cx, cy) = f.pixel(0, 0)
            for i in 0..<14 {
                let a = Double(i) / 14 * 2 * .pi + f.t * 2 * .pi / 7
                let (rx, ry) = (f.radius(0) + 4, 24.0 + 4)
                let long = i.isMultiple(of: 2) ? 5.0 : 3.0
                canvas.line(cx + cos(a) * rx, cy + sin(a) * ry, cx + cos(a) * (rx + long), cy + sin(a) * (ry + long),
                            width: 1, EggColor(1, 0.82, 0.45))
            }
            for (i, (ex, ey)) in [(-0.95, 0.8), (0.95, -0.5), (0.25, 1.2)].enumerated() {
                let on = (f.t * 3 + Double(i) / 3).truncatingRemainder(dividingBy: 1) < 0.4
                guard on else { continue }
                let (x, y) = f.pixel(ex, ey)
                canvas.sparkle(x, y, 2, .white)
            }
        })
    }

    // MARK: Birthday egg

    /// Sprinkles: little sticks scattered over the surface's map, each its own color and slant.
    static func jimmy(_ p: EggSurfacePoint, _ colors: [EggColor], density: Double, seed: Int) -> EggColor? {
        let cell = 0.15
        let a: Double = p.angle * EggProfile.radius(p.y) / cell + 50, y: Double = p.y / cell + 50
        let i0 = Int(a.rounded(.down)), j0 = Int(y.rounded(.down))
        for i in i0 - 1...i0 + 1 {
            for j in j0 - 1...j0 + 1 where hash(i, j, 0, seed: seed) < density {
                let dx: Double = a - Double(i) - 0.2 - 0.6 * hash(i, j, 1, seed: seed)
                let dy: Double = y - Double(j) - 0.2 - 0.6 * hash(i, j, 2, seed: seed)
                let slant: Double = hash(i, j, 3, seed: seed) * .pi
                let along: Double = dx * cos(slant) + dy * sin(slant), across: Double = -dx * sin(slant) + dy * cos(slant)
                if abs(along) < 0.42, abs(across) < 0.17 {
                    return colors[Int(hash(i, j, 4, seed: seed) * Double(colors.count)) % colors.count]
                }
            }
        }
        return nil
    }

    /// A ring of round puffs around the egg at a height: the point's offset from the nearest one's center, across and
    /// up, in its radius, when it lies on one.
    static func puff(_ p: EggSurfacePoint, count: Int, at height: Double, radius: Double,
                     offset: Double = 0) -> (dx: Double, dy: Double)? {
        let dy: Double = (p.y - height) / radius
        guard abs(dy) < 1 else { return nil }
        let step = 2 * Double.pi / Double(count)
        let slot: Double = (p.angle / step - offset).rounded() + offset
        let dx: Double = (p.angle - slot * step) * EggProfile.radius(height) / radius
        return dx * dx + dy * dy < 1 ? (dx, dy) : nil
    }

    /// The normal of a puff's dome: tilted away from its center.
    static func bulge(_ n: EggVector, _ offset: (dx: Double, dy: Double)?) -> EggVector {
        guard let (dx, dy) = offset else { return n }
        return EggLight.normalize((n.x + dx, n.y + dy, n.z))
    }

    /// Where a point of the egg's top (angle around, height) shows in this frame, and whether it faces the viewer.
    static func onTop(_ f: EggFrame, _ angle: Double, _ height: Double,
                      rise: Double = 0) -> (x: Double, y: Double, facing: Bool) {
        let turned = angle - f.yaw
        let (x, y) = f.pixel(EggProfile.radius(height) * sin(turned), height + rise)
        return (x, y, cos(turned) >= 0)
    }

    /// Striped candles standing in the top at angles around it, their flames flickering: those behind the egg in
    /// `back`, the others in `front`.
    static func candles(_ canvas: inout EggCanvas, _ f: EggFrame, _ list: [(angle: Double, color: EggColor)],
                        at height: Double, tall: Double, front: Bool, rise: Double = 0,
                        fire: [EggColor] = [flame[2], flame[3], flame[4]]) {
        for (k, candle) in list.enumerated() {
            let (bx, by, facing) = onTop(f, candle.angle, height, rise: rise)
            guard facing == front else { continue }
            let top = by - tall
            canvas.fill(bx - 2.5, top, bx + 2.5, by) { (x: Double, y: Double) -> EggColor? in
                guard abs(x - bx) <= 2, y >= top else { return nil }
                let stripe = (y - x + 60).truncatingRemainder(dividingBy: 4) < 2
                return (stripe ? EggColor(1, 1, 1) : candle.color).mixed(with: .black, x > bx + 1 ? 0.2 : 0)
            }
            let flicker: Double = 0.85 + 0.15 * sin(f.phase * 5 + Double(k) * 1.7)
            canvas.flame(baseX: bx, baseY: top - 1, height: 7 * flicker, width: 2.6, lean: 0.15 * sin(f.phase * 3 + Double(k)),
                         outer: fire[0], middle: fire[1], core: fire[2])
        }
    }

    /// A cake stand under the egg.
    static func cakeStand(_ canvas: inout EggCanvas, _ f: EggFrame, _ color: EggColor) {
        let (cx, by) = f.pixel(0, -0.94)
        canvas.ellipse(cx, by + 1, 19, 3.4, color, gloss: 0.7)
    }

    /// Sets a pixel, or only where nothing is drawn yet when `behind`: light shining around the egg, drawn over its
    /// outline so it keeps its color.
    static func light(_ canvas: inout EggCanvas, _ x: Double, _ y: Double, _ color: EggColor, behind: Bool) {
        let px = Int(x.rounded(.down)), py = Int(y.rounded(.down))
        if !behind || canvas.isEmpty(px, py) { canvas.set(px, py, color) }
    }

    /// A one-pixel streak of light between two points (`light`).
    static func streak(_ canvas: inout EggCanvas, from a: (Double, Double), to b: (Double, Double), _ color: EggColor,
                       behind: Bool) {
        let steps = max(1, Int((max(abs(b.0 - a.0), abs(b.1 - a.1)) * 2).rounded(.up)))
        for s in 0...steps {
            let t = Double(s) / Double(steps)
            light(&canvas, a.0 + (b.0 - a.0) * t, a.1 + (b.1 - a.1) * t, color, behind: behind)
        }
    }

    /// A small four-point star of light.
    static func star(_ canvas: inout EggCanvas, _ x: Double, _ y: Double, _ r: Int, _ color: EggColor, behind: Bool) {
        light(&canvas, x, y, .white, behind: behind)
        for step in 1...max(1, r) {
            let c = step == r ? color : color.mixed(with: .white, 0.5), d = Double(step)
            for (dx, dy) in [(d, 0.0), (-d, 0), (0, d), (0, -d)] { light(&canvas, x + dx, y + dy, c, behind: behind) }
        }
    }

    /// The Birthday Egg, a surprise cake: a pink cake whose lid of sprinkled cream, candles and all, rattles, then pops
    /// open: light pours out of it in rays, stars and confetti burst up, and the lid settles back.
    static var birthdaySurprise: EggDesign {
        let pink = EggColor(1, 0.66, 0.8), white = EggColor(1, 0.98, 0.95), gold = EggColor(1, 0.8, 0.3)
        let sprinkles = [EggColor(0.3, 0.7, 1), EggColor(1, 0.86, 0.2), EggColor(0.45, 0.9, 0.5), EggColor(1, 0.45, 0.6),
                         EggColor(0.7, 0.45, 1)]
        let crack: (Double) -> Double = { angle in 0.3 + 0.03 * abs(sin(angle * 8)) }
        // Open over the first half of the loop, rattling shut over the second.
        let gap: (Double) -> Double = { phase in
            sin(phase) > 0 ? 0.02 + 0.28 * pow(sin(phase), 1.5) : 0.02 + 0.025 * abs(sin(phase * 6))
        }
        func pearls(_ p: EggSurfacePoint) -> (dx: Double, dy: Double)? {
            puff(p, count: 22, at: -0.3, radius: 0.05) ?? puff(p, count: 14, at: -0.84, radius: 0.075)
        }
        var surface = EggSurface(albedo: { (p: EggSurfacePoint) -> EggColor in
            if p.y >= crack(p.angle) {
                if p.y < crack(p.angle) + 0.09 { return gold }
                return jimmy(p, sprinkles, density: 0.55, seed: 109) ?? white
            }
            if pearls(p) != nil { return white }
            if abs(p.y + 0.3) < 0.07 { return gold.mixed(with: .black, 0.08) }
            return abs(sin(p.angle * 9)) < 0.16 ? pink.mixed(with: .white, 0.45) : pink
        }, gloss: 0.6)
        surface.normal = { (n: EggVector, p: EggSurfacePoint) -> EggVector in bulge(n, pearls(p)) }
        surface.cap = crack
        surface.capGap = gap
        let list: [(angle: Double, color: EggColor)] = [(0, EggColor(0.4, 0.7, 1)), (2.1, EggColor(1, 0.5, 0.65)),
                                                        (-2.1, EggColor(0.5, 0.85, 0.5))]
        return EggDesign(surface: surface, back: { canvas, f in
            cakeStand(&canvas, f, gold)
            // The light inside, showing through the gap.
            let (cx, cy) = f.pixel(0, 0.31 + gap(f.phase) / 2)
            let rx = f.radius(0.31) + 1, ry = gap(f.phase) / f.unitsPerPixel / 2 + 2
            canvas.ellipse(cx, cy, rx, ry, EggColor(1, 0.95, 0.7), flat: true)
            canvas.ellipse(cx, cy, rx * 0.6, ry * 0.6, EggColor(1, 1, 0.95), flat: true)
            candles(&canvas, f, list, at: 0.82, tall: 6, front: false, rise: gap(f.phase))
        }, front: { canvas, f in
            candles(&canvas, f, list, at: 0.82, tall: 6, front: true, rise: gap(f.phase))
        }, outline: EggColor(0.42, 0.2, 0.28), glow: { canvas, f in
            let open = max(0, sin(f.phase))
            guard open > 0.05 else { return }
            let (cx, cy) = f.pixel(0, 0.31 + gap(f.phase) / 2)
            for k in 0..<13 {
                let a: Double = .pi + Double(k) / 12 * .pi + 0.08 * sin(f.phase * 3 + Double(k))
                let length: Double = (8 + 26 * open) * (k.isMultiple(of: 2) ? 1 : 0.6)
                streak(&canvas, from: (cx, cy), to: (cx + cos(a) * length * 1.2, cy + sin(a) * length),
                       EggColor(1, 0.95, 0.6).mixed(with: .white, k.isMultiple(of: 2) ? 0.4 : 0), behind: true)
            }
            // Stars and confetti shooting up out of the cake while it is open, falling back as it closes.
            let flight: Double = min(1, f.t / 0.48)
            for i in 0..<12 {
                let vx: Double = (hash(i, 0, 0, seed: 110) - 0.5) * 2.4, vy: Double = 0.7 + 0.5 * hash(i, 1, 0, seed: 110)
                let x = cx + vx * flight * 28, y = cy - vy * flight * 40 + flight * flight * 30
                if i % 2 == 0 {
                    star(&canvas, x, y, 2 + i % 4 / 2, EggColor(1, 0.88, 0.35), behind: false)
                } else {
                    let color = sprinkles[i % sprinkles.count]
                    for (dx, dy) in [(0.0, 0.0), (1, 0), (0, 1), (1, 1)] { light(&canvas, x + dx, y + dy, color, behind: false) }
                }
            }
        })
    }

    // MARK: Frames

    @MainActor private static var stillCache: [EggKind: NSImage] = [:]
    @MainActor private static var loopCache: [EggKind: [(image: NSImage, delay: TimeInterval)]] = [:]

    /// The kind a render is kept under: a dungeon egg without a design of its own is its type's egg, drawn and kept once
    /// for every species of that type, not once per species (about 400 KB each, on the main thread).
    @MainActor
    static func renderKey(_ kind: EggKind) -> EggKind {
        if case .dungeon(let species) = kind, LegendEggArt.design(species) == nil { return EggKind.dungeonLook(species) }
        return kind
    }

    @MainActor
    static func still(_ kind: EggKind) -> NSImage? {
        let kind = renderKey(kind)
        if let cached = stillCache[kind] { return cached }
        guard let design = design(for: kind), let image = render(design, phase: 0) else { return nil }
        let still = NSImage(cgImage: image, size: NSSize(width: pixels, height: pixels))
        stillCache[kind] = still
        return still
    }

    @MainActor
    static func idleFrames(_ kind: EggKind) -> [(image: NSImage, delay: TimeInterval)]? {
        let kind = renderKey(kind)
        if let cached = loopCache[kind] { return cached }
        guard let design = design(for: kind) else { return nil }
        let frames = (0..<EggRenderer.frameCount).compactMap { i -> (image: NSImage, delay: TimeInterval)? in
            let phase = 2 * Double.pi * Double(i) / Double(EggRenderer.frameCount)
            return render(design, phase: phase).map {
                (NSImage(cgImage: $0, size: NSSize(width: pixels, height: pixels)), EggRenderer.frameDelay)
            }
        }
        loopCache[kind] = frames
        return frames
    }
}
