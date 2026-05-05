import SwiftUI
import Combine
import Defaults

@MainActor
final class ScreenshotTrayViewModel: ObservableObject {
    @Published private(set) var allItems: [Screenshot] = []
    @Published var visibleCap: Int
    @Published var showOpenFolderAffordance: Bool = false
    @Published private(set) var dragInProgress: Bool = false
    @Published private(set) var lastMoveResult: ScreenshotMoveResult?
    @Published var toastVisible: Bool = false

    private var cancellable: AnyCancellable?
    private var toastTask: Task<Void, Never>?

    init() {
        let initialCap = Defaults[.screenshotTrayMaxVisible]
        visibleCap = initialCap
        let manager = ScreenshotManager.shared
        allItems = manager.items
        cancellable = manager.$items
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.allItems = $0 }
    }

    var visibleItems: [Screenshot] {
        Array(allItems.prefix(visibleCap))
    }

    var hiddenCount: Int {
        max(0, allItems.count - visibleCap)
    }

    var hasMore: Bool { hiddenCount > 0 }

    func showMore() {
        visibleCap += max(1, Defaults[.screenshotTrayMaxVisible])
    }

    func toggleOpenFolderAffordance() {
        showOpenFolderAffordance.toggle()
    }

    func setDragInProgress(_ flag: Bool) {
        dragInProgress = flag
        if flag { showOpenFolderAffordance = false }
    }

    func recordMove(_ result: ScreenshotMoveResult) {
        // Copies stay in the tray and don't need a confirmation toast — only moves are
        // potentially-destructive enough to warrant an undo.
        guard result.operation == .move else { return }
        lastMoveResult = result
        toastTask?.cancel()
        withAnimation(.smooth(duration: 0.18)) { toastVisible = true }
        toastTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            withAnimation(.smooth(duration: 0.18)) { self?.toastVisible = false }
        }
    }

    func undoLastMove() {
        guard let result = lastMoveResult else { return }
        if ScreenshotMoveService.undo(result) {
            lastMoveResult = nil
            toastTask?.cancel()
            withAnimation(.smooth(duration: 0.18)) { toastVisible = false }
        }
    }

    func runFirstRun() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.title = "Choose your screenshots folder"
        panel.message = "Pick a folder for the notch to monitor.\nMake sure macOS saves screenshots here too — set it via ⌘⇧5 → Options → Save to."
        panel.prompt = "Use folder"

        let suggested = FileManager.default
            .urls(for: .picturesDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("Notchdock Screenshots", isDirectory: true)
        if let suggested {
            panel.directoryURL = suggested.deletingLastPathComponent()
            panel.nameFieldStringValue = suggested.lastPathComponent
        }

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let bookmark = try Bookmark(url: url)
            Defaults[.screenshotsFolderBookmark] = bookmark.data
            Defaults[.screenshotTrayEnabled] = true
            ScreenshotManager.shared.stop()
            ScreenshotManager.shared.start()
        } catch {
            NSLog("ScreenshotTrayViewModel: bookmark failed for \(url.path): \(error)")
        }
    }
}
