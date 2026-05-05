import Foundation

enum ScreenshotMoveOperation {
    case move
    case copy
}

struct ScreenshotMoveResult: Equatable {
    let from: URL
    let to: URL
    let operation: ScreenshotMoveOperation
    let folderName: String
    /// The destination pinned folder's bookmark — undo needs this to re-acquire the security
    /// scope of the destination folder so it can move the file back out.
    let folderBookmark: Data
}

@MainActor
enum ScreenshotMoveService {
    static func perform(
        sourceURL: URL,
        into folder: PinnedFolder,
        operation: ScreenshotMoveOperation
    ) -> ScreenshotMoveResult? {
        let bookmark = Bookmark(data: folder.bookmark)
        let (resolvedURL, _) = bookmark.resolve()
        guard let folderURL = resolvedURL else {
            NSLog("ScreenshotMoveService: cannot resolve folder bookmark for \(folder.displayName)")
            return nil
        }

        let didStart = folderURL.startAccessingSecurityScopedResource()
        defer { if didStart { folderURL.stopAccessingSecurityScopedResource() } }

        let dest = uniqueDestination(for: sourceURL, in: folderURL)
        do {
            switch operation {
            case .move: try FileManager.default.moveItem(at: sourceURL, to: dest)
            case .copy: try FileManager.default.copyItem(at: sourceURL, to: dest)
            }
            return ScreenshotMoveResult(
                from: sourceURL,
                to: dest,
                operation: operation,
                folderName: folder.displayName,
                folderBookmark: folder.bookmark
            )
        } catch {
            NSLog("ScreenshotMoveService: \(operation) failed (\(sourceURL.path) → \(dest.path)): \(error.localizedDescription)")
            return nil
        }
    }

    /// Reverses a move. Re-resolves the pinned folder's security-scoped bookmark so the file
    /// at the destination is reachable for the move-back. The watched-folder scope is held by
    /// ScreenshotManager, so the source-folder write half is already reachable.
    static func undo(_ result: ScreenshotMoveResult) -> Bool {
        guard result.operation == .move else { return false }

        let bookmark = Bookmark(data: result.folderBookmark)
        let (resolvedURL, _) = bookmark.resolve()
        guard let destFolder = resolvedURL else {
            NSLog("ScreenshotMoveService: undo cannot resolve destination folder bookmark")
            return false
        }
        let didStart = destFolder.startAccessingSecurityScopedResource()
        defer { if didStart { destFolder.stopAccessingSecurityScopedResource() } }

        do {
            try FileManager.default.moveItem(at: result.to, to: result.from)
            return true
        } catch {
            NSLog("ScreenshotMoveService: undo failed: \(error.localizedDescription)")
            return false
        }
    }

    private static func uniqueDestination(for sourceURL: URL, in folder: URL) -> URL {
        let stem = sourceURL.deletingPathExtension().lastPathComponent
        let ext = sourceURL.pathExtension
        var candidate = folder.appendingPathComponent(sourceURL.lastPathComponent)
        var n = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            let name = ext.isEmpty ? "\(stem) (\(n))" : "\(stem) (\(n)).\(ext)"
            candidate = folder.appendingPathComponent(name)
            n += 1
        }
        return candidate
    }
}
