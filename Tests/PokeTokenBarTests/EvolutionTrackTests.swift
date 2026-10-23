import AppKit
import SwiftUI
import XCTest
@testable import PokeTokenBar

/// Lines straight from the evolution data, so the tests walk the same trees the app loads.
private struct TrackLineProvider: PokeProviding {
    func line(baseSpeciesID: Int) async throws -> EvoLine {
        func node(_ id: Int) -> EvoNode {
            EvoNode(speciesID: id, children: (PokemonEvolutionData.children[id] ?? []).map(node))
        }
        return EvoLine(baseID: baseSpeciesID, tree: node(baseSpeciesID), rarity: .common,
                       names: [4: ["en": "Charmander"], 5: ["en": "Charmeleon"], 6: ["en": "Charizard"]])
    }
    func baseSpeciesIndex() async throws -> [BaseSpecies] { [] }
    func baseSpecies(id: Int) async throws -> BaseSpecies? { nil }
}

/// Home's evolution track: the stages reached, the coming ones as silhouettes until caught, and where the line goes
/// several ways, every way to its end.
@MainActor
final class EvolutionTrackTests: XCTestCase {
    private func store(_ path: [Int], stage: Int, caught: [[Int]] = []) async throws -> CompanionStore {
        let suite = "Track-\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        addTeardownBlock { defaults.removePersistentDomain(forName: suite) }
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("\(suite).json")
        addTeardownBlock { try? FileManager.default.removeItem(at: file) }
        var state = CompanionState()
        state.language = .en
        state.installBaselineSet = true
        state.active = MonState(baseID: path[0], pathIDs: Array(path.prefix(stage + 1)), plannedPathIDs: path,
                                stageIndex: stage, usedAtStage: 0, rarity: .common, totalForms: path.count,
                                nature: .hardy)
        state.dex = caught.enumerated().map { index, chain in
            DexEntry(baseID: chain[0], finalID: chain.last!, chainOrder: chain, rarity: .common,
                     caughtAt: Date(timeIntervalSince1970: 1_790_000_000 + Double(index)))
        }
        try JSONEncoder().encode(state).write(to: file)
        let store = CompanionStore(provider: TrackLineProvider(), fileURL: file, defaults: defaults)
        store.update(todayTokensByProvider: [:], todayDate: "2026-10-22", monthTotal: 0, burnTier: .idle,
                     limitWarning: false, hasUsageData: true)
        for _ in 0..<300 where store.currentLine == nil { try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertNotNil(store.currentLine)
        return store
    }

    private func item(_ id: Int, _ caught: Bool) -> BranchEvolutionItem { BranchEvolutionItem(speciesID: id, isCollected: caught) }

    func testALinearLineHeadsForTheGraduationThroughItsComingStages() async throws {
        let charmander = try await store([4, 5, 6], stage: 0, caught: [[4, 5]])
        XCTAssertEqual(charmander.evolutionTrack, [.reached(4, isCurrent: true), .coming(5, isCaught: true),
                                                   .coming(6, isCaught: false), .graduation])
        let charizard = try await store([4, 5, 6], stage: 2)
        XCTAssertEqual(charizard.evolutionTrack, [.reached(4, isCurrent: false), .reached(5, isCurrent: false),
                                                  .reached(6, isCurrent: true), .graduation])
    }

    func testABranchShowsEveryWayToItsEnd() async throws {
        // Eevee: eight ways of one species each.
        let eevee = try await store([133, 197], stage: 0, caught: [[133, 134]])
        let track = eevee.evolutionTrack
        XCTAssertEqual(track.first, .reached(133, isCurrent: true))
        guard case .branch(let paths)? = track.last else { return XCTFail("\(track)") }
        XCTAssertEqual(track.count, 2, "the line stops where it goes several ways")
        XCTAssertEqual(paths.count, 8)
        XCTAssertTrue(paths.allSatisfy { $0.count == 1 })
        XCTAssertEqual(paths.flatMap { $0 }.filter(\.isCollected).map(\.speciesID), [134])

        // Wurmple: the third stage depends on the second.
        let wurmple = try await store([265, 266, 267], stage: 0, caught: [[265, 266, 267]])
        XCTAssertEqual(wurmple.evolutionTrack, [.reached(265, isCurrent: true),
                                                .branch([[item(266, true), item(267, true)],
                                                         [item(268, false), item(269, false)]])])

        // Applin: two ways of one species, one of two.
        let applin = try await store([840, 841], stage: 0)
        XCTAssertEqual(applin.evolutionTrack, [.reached(840, isCurrent: true),
                                               .branch([[item(841, false)], [item(842, false)],
                                                        [item(1011, false), item(1019, false)]])])

        // Ralts: a coming stage, then the branch.
        let ralts = try await store([280, 281, 282], stage: 0)
        XCTAssertEqual(ralts.evolutionTrack, [.reached(280, isCurrent: true), .coming(281, isCaught: false),
                                              .branch([[item(282, false)], [item(475, false)]])])
    }

    func testTheCaptionNamesTheNextStop() async throws {
        let l = L(.en)
        let charmander = try await store([4, 5, 6], stage: 0)
        let names = [5: "Charmeleon"]
        XCTAssertEqual(CompanionHeader.trackCaption(charmander.evolutionTrack, amount: "95M", percent: "24%",
                                                    names: names, l: l), "95M to Charmeleon · 24%")
        let charizard = try await store([4, 5, 6], stage: 2)
        XCTAssertEqual(CompanionHeader.trackCaption(charizard.evolutionTrack, amount: "127.5M", percent: "32%",
                                                    names: names, l: l), "\(l.toGraduation("127.5M")) · 32%")
        let eevee = try await store([133, 197], stage: 0)
        XCTAssertEqual(CompanionHeader.trackCaption(eevee.evolutionTrack, amount: "425M", percent: "32%",
                                                    names: names, l: l), "\(l.toNextEvolution("425M")) · 32%")
    }

    /// Vivillon's twenty patterns stood on one line wider than the card and pushed the popover off its edges. The ways
    /// get the width the stops leave and wrap within it.
    func testAWideBranchWrapsWithinTheTrack() async throws {
        let patterns = PokemonForm.forms(speciesID: 666).map {
            [BranchEvolutionItem(speciesID: 666, isCollected: false, form: $0)]
        }
        XCTAssertGreaterThan(patterns.count, 15)
        let stops: [CompanionStore.EvolutionTrackStop] = [.reached(664, isCurrent: true), .coming(665, isCaught: false),
                                                          .branch(patterns)]
        let measured = MeasuredSize()
        let width: CGFloat = 300
        let view = EvolutionTrackView(stops: stops, progress: 0.2, tint: .gray, remaining: "1M to Spewpa · 20%",
                                      amount: "1M", detail: "", l: L(.en))
            .background(GeometryReader { geo in
                Color.clear.onChange(of: geo.size, initial: true) { _, size in measured.size = size }
            })
            .frame(width: width)
        let host = NSHostingView(rootView: AnyView(view))
        host.frame = NSRect(x: 0, y: 0, width: width, height: 300)
        let window = NSWindow(contentRect: NSRect(x: -10000, y: -10000, width: width, height: 300),
                              styleMask: .borderless, backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = host
        window.orderFront(nil)
        defer { window.close() }
        try await Task.sleep(for: .milliseconds(200))
        host.layoutSubtreeIfNeeded()
        XCTAssertLessThanOrEqual(measured.size.width, width + 0.5, "the track stays within its width")
        XCTAssertGreaterThan(measured.size.height, EvolutionTrackView.stopSize + 30, "the patterns wrap onto more lines")
        // Eevee's eight still stand on one line.
        let eevee = (0..<8).map { [BranchEvolutionItem(speciesID: 134 + $0, isCollected: false)] }
        measured.size = .zero
        host.rootView = AnyView(EvolutionTrackView(stops: [.reached(133, isCurrent: true), .branch(eevee)], progress: 0.2,
                                                   tint: .gray, remaining: "1M · 20%", amount: "1M", detail: "", l: L(.en))
            .background(GeometryReader { geo in
                Color.clear.onChange(of: geo.size, initial: true) { _, size in measured.size = size }
            })
            .frame(width: width))
        try await Task.sleep(for: .milliseconds(200))
        host.layoutSubtreeIfNeeded()
        XCTAssertLessThan(measured.size.height, EvolutionTrackView.stopSize + 30, "one line for Eevee's eight")
    }

    /// A branch of two ways (Raichu, Alolan Raichu) took the eight ways' width and left it empty: the track stopped
    /// short of the card's edge. It reaches it, the stretches taking the rest.
    func testANarrowBranchLetsTheTrackReachItsEdge() async throws {
        let width: CGFloat = 300
        let stops: [CompanionStore.EvolutionTrackStop] = [
            .reached(172, isCurrent: false), .reached(25, isCurrent: true),
            .branch([[item(26, false)], [BranchEvolutionItem(speciesID: 26, isCollected: false, form: PokemonForm("alola"))]]),
        ]
        let view = EvolutionTrackView(stops: stops, progress: 0.5, tint: .gray, remaining: "1M", amount: "1M", detail: "",
                                      l: L(.en))
            .frame(width: width, alignment: .leading).background(Color.white)
        let host = NSHostingView(rootView: view)
        host.frame = NSRect(x: 0, y: 0, width: width, height: 80)
        let window = NSWindow(contentRect: NSRect(x: -10000, y: -10000, width: width, height: 80),
                              styleMask: .borderless, backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.appearance = NSAppearance(named: .aqua)
        window.contentView = host
        window.orderFront(nil)
        defer { window.close() }
        try await Task.sleep(for: .milliseconds(300))
        host.layoutSubtreeIfNeeded()
        let bitmap = try XCTUnwrap(NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(width * 2), pixelsHigh: 160,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
            bytesPerRow: 0, bitsPerPixel: 0))
        bitmap.size = host.bounds.size
        host.cacheDisplay(in: host.bounds, to: bitmap)
        // The rightmost drawn pixel of the stops' row (the last way's sprite, or its 🥚 while it loads).
        var rightmost = 0
        for y in 0..<Int(EvolutionTrackView.stopSize * 2) {
            for x in 0..<bitmap.pixelsWide {
                guard let c = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.sRGB),
                      min(c.redComponent, c.greenComponent, c.blueComponent) < 0.8 else { continue }
                rightmost = max(rightmost, x)
            }
        }
        XCTAssertGreaterThan(CGFloat(rightmost) / 2, width - 24, "the track reaches the edge (it ended at \(rightmost / 2))")
    }

    func testNoTrackForTheEgg() throws {
        let suite = "TrackEgg-\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("\(suite).json")
        defer { try? FileManager.default.removeItem(at: file) }
        var state = CompanionState()
        state.installBaselineSet = true
        try JSONEncoder().encode(state).write(to: file)
        let store = CompanionStore(provider: TrackLineProvider(), fileURL: file, defaults: defaults)
        XCTAssertTrue(store.evolutionTrack.isEmpty)
    }
}

@MainActor
private final class MeasuredSize {
    var size: CGSize = .zero
}
