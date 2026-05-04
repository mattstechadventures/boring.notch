import Foundation

final class ScreenshotFolderWatcher {
    private var stream: FSEventStreamRef?
    private let queue = DispatchQueue(label: "com.boringNotch.ScreenshotFolderWatcher")
    private var onChange: (@Sendable () -> Void)?

    deinit {
        stop()
    }

    func start(at url: URL, onChange: @escaping @Sendable () -> Void) {
        stop()
        self.onChange = onChange

        let pathsToWatch: CFArray = [url.path] as CFArray
        // passRetained + release callback: keep `self` alive for the stream's full lifetime
        // even if the dispatch queue dispatches a final callback after the manager has
        // dropped its reference. The release callback runs when the stream is destroyed.
        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passRetained(self).toOpaque(),
            retain: nil,
            release: { info in
                if let info {
                    Unmanaged<ScreenshotFolderWatcher>.fromOpaque(info).release()
                }
            },
            copyDescription: nil
        )
        let flags = UInt32(
            kFSEventStreamCreateFlagUseCFTypes
            | kFSEventStreamCreateFlagFileEvents
            | kFSEventStreamCreateFlagNoDefer
            | kFSEventStreamCreateFlagWatchRoot
        )

        let callback: FSEventStreamCallback = { _, contextInfo, numEvents, _, eventFlags, _ in
            guard let info = contextInfo else { return }
            let watcher = Unmanaged<ScreenshotFolderWatcher>.fromOpaque(info).takeUnretainedValue()
            // Inspect the root-changed flag so we can surface folder deletion / rename. The
            // manager's rescan handles the actual state transition; we just emit the signal.
            for i in 0..<numEvents {
                let f = eventFlags[i]
                if f & UInt32(kFSEventStreamEventFlagRootChanged) != 0 {
                    NSLog("ScreenshotFolderWatcher: root changed (folder moved/deleted)")
                }
            }
            watcher.onChange?()
        }

        let created = FSEventStreamCreate(
            kCFAllocatorDefault,
            callback,
            &context,
            pathsToWatch,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.1,
            flags
        )

        guard let created else {
            NSLog("ScreenshotFolderWatcher: FSEventStreamCreate failed for \(url.path)")
            return
        }
        stream = created
        FSEventStreamSetDispatchQueue(created, queue)
        FSEventStreamStart(created)
    }

    func stop() {
        if let stream {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
            self.stream = nil
        }
        onChange = nil
    }
}
