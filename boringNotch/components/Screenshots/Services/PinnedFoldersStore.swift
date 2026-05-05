import Foundation
import AppKit
import Combine
import Defaults

@MainActor
final class PinnedFoldersStore: ObservableObject {
    static let shared = PinnedFoldersStore()

    @Published var folders: [PinnedFolder]

    private var persistCancellable: AnyCancellable?

    private init() {
        folders = Defaults[.screenshotPinnedFolders]
        persistCancellable = $folders
            .dropFirst()
            .sink { newValue in Defaults[.screenshotPinnedFolders] = newValue }
    }

    func addPin() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.title = "Pin a folder"
        panel.prompt = "Pin"

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let bookmark = try Bookmark(url: url)
            let pin = PinnedFolder(displayName: url.lastPathComponent, bookmark: bookmark.data)
            folders.append(pin)
        } catch {
            NSLog("PinnedFoldersStore: failed to bookmark \(url.path): \(error.localizedDescription)")
        }
    }

    func remove(id: UUID) {
        folders.removeAll { $0.id == id }
    }

    func resolveURL(for pin: PinnedFolder) -> URL? {
        Bookmark(data: pin.bookmark).resolveURL()
    }
}
