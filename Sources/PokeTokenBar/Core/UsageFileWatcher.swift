import CoreServices
import Foundation

/// Tells when files change under some folders, through FSEvents: macOS calls back when a file is written, the app polls
/// nothing. The usage logs grow by a line at each step of an agent's work (each API call), so their sources are read
/// again within seconds instead of at the next timer tick (`UsageStore.liveFilesChanged`).
///
/// The callbacks run on a private serial queue; `stop()` tears the stream down on that queue, so no callback can still
/// be running once it returns. The handler gets the changed paths, canonical (`realpath`) as FSEvents reports them.
final class UsageFileWatcher: @unchecked Sendable {
    /// Holds the handler for the C callback; the stream retains it through the context, until it is released.
    private final class Box {
        let handler: @Sendable ([String]) -> Void
        init(_ handler: @escaping @Sendable ([String]) -> Void) { self.handler = handler }
    }

    private let queue = DispatchQueue(label: "PokeTokenBar.usage-watcher")
    private var stream: FSEventStreamRef?
    let paths: [String]

    /// Nil when there is nothing to watch or FSEvents refuses the stream.
    init?(paths: [String], latency: TimeInterval = 0.5, handler: @escaping @Sendable ([String]) -> Void) {
        self.paths = paths
        guard !paths.isEmpty else { return nil }
        let box = Box(handler)
        var context = FSEventStreamContext(
            version: 0, info: Unmanaged.passUnretained(box).toOpaque(),
            retain: { info in
                guard let info else { return nil }
                _ = Unmanaged<Box>.fromOpaque(info).retain()
                return info
            },
            release: { info in
                guard let info else { return }
                Unmanaged<Box>.fromOpaque(info).release()
            },
            copyDescription: nil)
        let callback: FSEventStreamCallback = { _, info, _, eventPaths, _, _ in
            guard let info else { return }
            let box = Unmanaged<Box>.fromOpaque(info).takeUnretainedValue()
            let changed = Unmanaged<CFArray>.fromOpaque(eventPaths).takeUnretainedValue() as? [String] ?? []
            if !changed.isEmpty { box.handler(changed) }
        }
        let flags = FSEventStreamCreateFlags(kFSEventStreamCreateFlagUseCFTypes | kFSEventStreamCreateFlagFileEvents)
        guard let stream = FSEventStreamCreate(kCFAllocatorDefault, callback, &context, paths as CFArray,
                                               FSEventStreamEventId(kFSEventStreamEventIdSinceNow), latency, flags)
        else { return nil }
        FSEventStreamSetDispatchQueue(stream, queue)
        guard FSEventStreamStart(stream) else {
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
            return nil
        }
        self.stream = stream
    }

    func stop() {
        queue.sync {
            guard let stream else { return }
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
            self.stream = nil
        }
    }

    deinit { stop() }

    /// The path FSEvents reports for a folder: symbolic links resolved (`/var` is `/private/var`), or the path as given
    /// when it does not exist.
    static func canonicalPath(_ path: String) -> String {
        guard let resolved = realpath(path, nil) else { return path }
        defer { free(resolved) }
        return String(cString: resolved)
    }

    /// Whether `path` is `root` or lies under it.
    static func path(_ path: String, isUnder root: String) -> Bool {
        path == root || path.hasPrefix(root.hasSuffix("/") ? root : root + "/")
    }
}
