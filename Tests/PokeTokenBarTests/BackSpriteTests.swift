import AppKit
import ImageIO
import UniformTypeIdentifiers
import XCTest
@testable import PokeTokenBar

private final class BackSpriteURLProtocol: URLProtocol, @unchecked Sendable {
    final class State: @unchecked Sendable {
        private let lock = NSLock()
        private var gif: Data?
        private var urls: [URL] = []
        func configure(gif: Data?) { lock.withLock { self.gif = gif; urls = [] } }
        func receive(_ url: URL) -> Data? { lock.withLock { urls.append(url); return gif } }
        var requests: [URL] { lock.withLock { urls } }
    }
    static let state = State()
    override class func canInit(with request: URLRequest) -> Bool {
        request.url?.host == "raw.githubusercontent.com" && request.url?.path.contains("/other/showdown/back/") == true
    }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        guard let url = request.url else { return }
        let gif = Self.state.receive(url)
        let response = HTTPURLResponse(url: url, statusCode: gif == nil ? 404 : 200, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        if let gif { client?.urlProtocol(self, didLoad: gif) }
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

/// The player's side of the arena seen from behind (the owner, 2026-11-09): Showdown's back renders, the front kept
/// for the eight forms without one.
@MainActor
final class BackSpriteTests: XCTestCase {
    override func setUp() {
        super.setUp()
        BackSpriteURLProtocol.state.configure(gif: nil)
        URLProtocol.registerClass(BackSpriteURLProtocol.self)
    }
    override func tearDown() {
        URLProtocol.unregisterClass(BackSpriteURLProtocol.self)
        BackSpriteURLProtocol.state.configure(gif: nil)
        super.tearDown()
    }

    private let base = "https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/showdown/back/"

    /// Showdown's names of the front, in its `back/` folder; never Black and White's pixel GIFs.
    func testTheBacksAreShowdownsBackRenders() {
        XCTAssertEqual(SpriteStore.backSpriteURLs(speciesID: 6, shiny: false).map(\.absoluteString), [base + "6.gif"])
        XCTAssertEqual(SpriteStore.backSpriteURLs(speciesID: 6, shiny: true).map(\.absoluteString), [base + "shiny/6.gif"])
        XCTAssertEqual(SpriteStore.backSpriteURLs(speciesID: 925, shiny: false).map(\.absoluteString), [base + "925-four.gif"],
                       "Maushold's Showdown name")
        for id in [1, 25, 150, 493, 649, 906] {
            XCTAssertTrue(SpriteStore.backSpriteURLs(speciesID: id, shiny: false)
                .allSatisfy { $0.absoluteString.hasPrefix(base) }, "\(id)")
        }
        XCTAssertEqual(SpriteStore.backKey(speciesID: 6, shiny: false), "6-b")
        XCTAssertEqual(SpriteStore.backKey(speciesID: 6, shiny: true), "6-shb")
        XCTAssertNotEqual(SpriteStore.backKey(speciesID: 6, shiny: false),
                          SpriteStore.cacheKey(speciesID: 6, animated: false, shiny: false), "apart from the front's still")
    }

    private func gif() throws -> Data {
        let context = try XCTUnwrap(CGContext(data: nil, width: 4, height: 4, bitsPerComponent: 8, bytesPerRow: 0,
                                              space: CGColorSpaceCreateDeviceRGB(),
                                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setFillColor(CGColor(red: 0, green: 0, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 4, height: 4))
        let data = NSMutableData()
        let destination = try XCTUnwrap(CGImageDestinationCreateWithData(data, UTType.gif.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, try XCTUnwrap(context.makeImage()), nil)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        return data as Data
    }

    /// The back downloaded once, its first frame kept on disk and shown at once afterwards.
    func testTheBackIsDownloadedOnceAndKept() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("back-\(UUID())")
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = SpriteStore(directory: directory)
        BackSpriteURLProtocol.state.configure(gif: try gif())
        XCTAssertNil(SpriteLoader.cachedBackImage(speciesID: 6, shiny: false, directory: directory))
        let image = await SpriteLoader.backImage(speciesID: 6, shiny: false, store: store)
        XCTAssertNotNil(image)
        XCTAssertTrue(FileManager.default.fileExists(atPath: directory.appendingPathComponent("6-b.png").path))
        XCTAssertNotNil(SpriteLoader.cachedBackImage(speciesID: 6, shiny: false, directory: directory))
        let before = BackSpriteURLProtocol.state.requests.count
        _ = await store.backStill(speciesID: 6, shiny: false)
        XCTAssertEqual(BackSpriteURLProtocol.state.requests.count, before, "kept, not downloaded again")
    }

    /// No back (Showdown answers 404, as for Gigantamax Venusaur): nil, so the arena keeps the front, and it is not
    /// asked again this session.
    func testAFormWithoutBackKeepsItsFront() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("back-\(UUID())")
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = SpriteStore(directory: directory)
        BackSpriteURLProtocol.state.configure(gif: nil)
        let image = await SpriteLoader.backImage(speciesID: 3, shiny: false, store: store)
        XCTAssertNil(image)
        let asked = BackSpriteURLProtocol.state.requests.count
        XCTAssertGreaterThan(asked, 0)
        _ = await store.backStill(speciesID: 3, shiny: false)
        XCTAssertEqual(BackSpriteURLProtocol.state.requests.count, asked, "a 404 is not asked again")
    }
}
