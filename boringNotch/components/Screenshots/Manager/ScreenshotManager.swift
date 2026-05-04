import Foundation
import Combine
import Defaults

@MainActor
final class ScreenshotManager: ObservableObject {
    static let shared = ScreenshotManager()

    @Published private(set) var items: [Screenshot] = []
    @Published private(set) var watchedFolderURL: URL?

    private let watcher = ScreenshotFolderWatcher()
    private var scopedURL: URL?
    private var rescanTask: Task<Void, Never>?
    private var announcedURLs: Set<String> = []
    private var didSeed: Bool = false

    private static let imageExtensions: Set<String> = [
        "png", "jpg", "jpeg", "heic", "gif", "tiff", "tif", "webp", "bmp"
    ]

    private init() {}

    func start() {
        // Re-entrant: tear down any prior session before standing one back up.
        stop()

        guard Defaults[.screenshotTrayEnabled] else { return }
        guard let bookmarkData = Defaults[.screenshotsFolderBookmark] else {
            NSLog("ScreenshotManager: no folder bookmark stored — idle until first-run flow runs")
            return
        }

        let bookmark = Bookmark(data: bookmarkData)
        let (resolvedURL, refreshedData) = bookmark.resolve()
        guard let url = resolvedURL else {
            NSLog("ScreenshotManager: could not resolve folder bookmark")
            return
        }
        if let refreshedData {
            Defaults[.screenshotsFolderBookmark] = refreshedData
        }

        guard url.startAccessingSecurityScopedResource() else {
            NSLog("ScreenshotManager: failed to start security scope for \(url.path)")
            return
        }
        scopedURL = url
        watchedFolderURL = url

        watcher.start(at: url) { [weak self] in
            Task { @MainActor in
                self?.scheduleRescan()
            }
        }

        // Seed initial state.
        scheduleRescan()
    }

    func stop() {
        watcher.stop()
        rescanTask?.cancel()
        rescanTask = nil
        scopedURL?.stopAccessingSecurityScopedResource()
        scopedURL = nil
        watchedFolderURL = nil
        items = []
        announcedURLs = []
        didSeed = false
    }

    private func scheduleRescan() {
        rescanTask?.cancel()
        rescanTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 80_000_000) // 80ms additional debounce
            guard !Task.isCancelled else { return }
            self?.rescan()
        }
    }

    private func rescan() {
        guard let folder = scopedURL else { return }
        let fm = FileManager.default

        // Folder might have been deleted out from under us. Clear state but keep the watcher
        // running — FSEvents will fire root-changed events if the folder reappears.
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: folder.path, isDirectory: &isDir), isDir.boolValue else {
            if !items.isEmpty {
                NSLog("ScreenshotManager: watched folder is missing or no longer a directory: \(folder.path)")
                items = []
                announcedURLs = []
            }
            return
        }

        let resourceKeys: [URLResourceKey] = [.creationDateKey, .contentModificationDateKey, .fileSizeKey, .isRegularFileKey]
        guard let enumerator = fm.enumerator(
            at: folder,
            includingPropertiesForKeys: resourceKeys,
            options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants, .skipsPackageDescendants]
        ) else {
            NSLog("ScreenshotManager: enumerator failed for \(folder.path)")
            return
        }

        var scanned: [Screenshot] = []
        // uniquingKeysWith protects against duplicate paths in transient state (e.g. mid-rename).
        let existingByURL = Dictionary(items.map { ($0.url.standardizedFileURL.path, $0) },
                                        uniquingKeysWith: { first, _ in first })

        for case let url as URL in enumerator {
            let ext = url.pathExtension.lowercased()
            guard Self.imageExtensions.contains(ext) else { continue }

            guard let values = try? url.resourceValues(forKeys: Set(resourceKeys)),
                  values.isRegularFile == true else { continue }
            // Prefer creation date for screenshot ordering; fall back to mtime so a missing
            // creation date doesn't slot the file at "now" and reorder the tray.
            let date = values.creationDate ?? values.contentModificationDate ?? Date(timeIntervalSince1970: 0)
            let size = Int64(values.fileSize ?? 0)

            if let existing = existingByURL[url.standardizedFileURL.path] {
                scanned.append(existing)
            } else {
                scanned.append(Screenshot(url: url, addedAt: date, byteSize: size))
            }
        }

        scanned.sort { $0.addedAt > $1.addedAt }

        let oldKeys = Set(items.map { $0.url.standardizedFileURL.path })
        let newKeys = Set(scanned.map { $0.url.standardizedFileURL.path })
        let added = newKeys.subtracting(oldKeys)
        let removed = oldKeys.subtracting(newKeys)
        if !added.isEmpty || !removed.isEmpty {
            NSLog("ScreenshotManager: +\(added.count) -\(removed.count) (total \(scanned.count))")
        }

        items = scanned

        // First scan after start: mark all existing files as already announced so we don't
        // fire the capture animation for files that pre-existed on app launch.
        if !didSeed {
            announcedURLs = newKeys
            didSeed = true
            return
        }

        let unannounced = added.subtracting(announcedURLs)
        if !unannounced.isEmpty {
            announcedURLs.formUnion(unannounced)
            if Defaults[.screenshotCaptureAnimationEnabled] {
                BoringViewCoordinator.shared.toggleExpandingView(status: true, type: .screenshot)
            }
        }
        // Drop announcements for files that no longer exist.
        announcedURLs.subtract(removed)
    }
}
