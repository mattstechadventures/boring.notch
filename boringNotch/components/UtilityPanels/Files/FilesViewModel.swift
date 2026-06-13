//
//  FilesViewModel.swift
//  boringNotch
//
//  Pinned folders (security-scoped) with browse/open/import. Reuses the
//  Screenshots PinnedFolder model + Bookmark; persists to its own
//  Defaults[.filesPinnedFolders] via Combine autosave (mirrors PinnedFoldersStore).
//

import AppKit
import Combine
import Defaults
import Foundation

@MainActor
final class FilesViewModel: ObservableObject {
    static let shared = FilesViewModel()

    @Published var pins: [PinnedFolder]
    @Published private(set) var selectedPinID: UUID?
    @Published private(set) var contents: [URL] = []
    @Published var isDropTargeted = false

    private var persistCancellable: AnyCancellable?

    private init() {
        pins = Defaults[.filesPinnedFolders]
        persistCancellable = $pins
            .dropFirst()
            .sink { Defaults[.filesPinnedFolders] = $0 }
        selectedPinID = pins.first?.id
        reloadContents()
    }

    var selectedPin: PinnedFolder? {
        pins.first { $0.id == selectedPinID }
    }

    // MARK: Pinning

    func addPin() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.title = "Pin a folder"
        panel.prompt = "Pin"

        guard panel.runModal() == .OK, let url = panel.url else { return }
        addPin(url: url)
    }

    func addPin(url: URL) {
        // Dedupe by resolved path.
        let alreadyPinned = pins.contains { Bookmark(data: $0.bookmark).resolveURL()?.standardizedFileURL == url.standardizedFileURL }
        guard !alreadyPinned else { return }
        do {
            let bookmark = try Bookmark(url: url)
            let pin = PinnedFolder(displayName: url.lastPathComponent, bookmark: bookmark.data)
            pins.append(pin)
            selectedPinID = pin.id
            reloadContents()
        } catch {
            NSLog("FilesViewModel: failed to bookmark \(url.path): \(error.localizedDescription)")
        }
    }

    func remove(_ pin: PinnedFolder) {
        pins.removeAll { $0.id == pin.id }
        if selectedPinID == pin.id {
            selectedPinID = pins.first?.id
        }
        reloadContents()
    }

    func select(_ pin: PinnedFolder) {
        selectedPinID = pin.id
        reloadContents()
    }

    // MARK: Contents

    func reloadContents() {
        guard let pin = selectedPin else { contents = []; return }
        let listed: [URL]? = Bookmark(data: pin.bookmark).withAccess { dir in
            (try? FileManager.default.contentsOfDirectory(
                at: dir,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )) ?? []
        }
        contents = (listed ?? []).sorted {
            $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending
        }
    }

    func open(_ url: URL) {
        guard let pin = selectedPin else { return }
        _ = Bookmark(data: pin.bookmark).withAccess { _ in
            if isDirectory(url) {
                NSWorkspace.shared.activateFileViewerSelecting([url])
            } else {
                NSWorkspace.shared.open(url)
            }
        }
    }

    func importFiles(_ urls: [URL]) {
        guard let pin = selectedPin else { return }
        _ = Bookmark(data: pin.bookmark).withAccess { dir in
            for src in urls {
                let target = dir.appendingPathComponent(src.lastPathComponent)
                try? FileManager.default.copyItem(at: src, to: target)
            }
        }
        reloadContents()
    }

    func icon(for url: URL) -> NSImage {
        NSWorkspace.shared.icon(forFile: url.path)
    }

    func isDirectory(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
    }
}
