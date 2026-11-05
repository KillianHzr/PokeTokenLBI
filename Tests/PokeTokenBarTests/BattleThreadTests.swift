import XCTest
@testable import PokeTokenBar

/// A replay run with `Task.detached` crashed on `___chkstk_darwin` (2026-11-04): a battle's deepest call needed more
/// than a secondary thread's 512 KB in a debug build. Battles away from the main thread go through
/// `BattleEngine.offMain`, on a thread of 16 MB.
final class BattleThreadTests: XCTestCase {
    func testABattleOffTheMainThreadRunsOnABigStackAndMatches() async throws {
        let lax = try XCTUnwrap(BattlerSpec.make(id: "lax", speciesID: 143, level: 100, moves: ["body-slam", "rest"]))
        let gengar = try XCTUnwrap(BattlerSpec.make(id: "gengar", speciesID: 94, level: 100, moves: ["shadow-ball", "hypnosis"]))
        let setup = BattleSetup(sides: [BattleSideSpec(battlers: [lax], active: 1), BattleSideSpec(battlers: [gengar], active: 1)],
                                seed: 7)
        let stack = await BattleEngine.offMain { Thread.current.stackSize }
        XCTAssertGreaterThanOrEqual(stack, 8 << 20, "at least a main thread's stack")
        let off = await BattleEngine.offMain { BattleEngine.run(setup) }
        XCTAssertEqual(off, BattleEngine.run(setup))
    }

    /// No screen runs the engine in a detached task again: its thread's stack is too small.
    func testNoEngineRunInADetachedTask() throws {
        let sources = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().appendingPathComponent("Sources")
        let files = try XCTUnwrap(FileManager.default.enumerator(at: sources, includingPropertiesForKeys: nil))
            .compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" }
        XCTAssertFalse(files.isEmpty)
        let pattern = try NSRegularExpression(pattern: #"Task\.detached[^\n]*\{[^}]*(BattleEngine\.run|estimate\.run|ExpeditionEngine\.)"#)
        for file in files {
            let text = try String(contentsOf: file, encoding: .utf8)
            let found = pattern.firstMatch(in: text, range: NSRange(text.startIndex..., in: text))
            XCTAssertNil(found, "\(file.lastPathComponent): run the engine with BattleEngine.offMain")
        }
    }
}
