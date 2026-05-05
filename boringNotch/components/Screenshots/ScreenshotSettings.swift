import AppKit
import Defaults
import SwiftUI

struct ScreenshotSettings: View {
    @Default(.screenshotTrayEnabled) private var enabled
    @Default(.screenshotsFolderBookmark) private var bookmarkData
    @Default(.screenshotCaptureAnimationEnabled) private var captureAnimation
    @Default(.screenshotTrayMaxVisible) private var maxVisible

    @ObservedObject private var pins = PinnedFoldersStore.shared

    @State private var watchedFolderPath: String = ""

    var body: some View {
        Form {
            Section {
                Defaults.Toggle(key: .screenshotTrayEnabled) {
                    Text("Enable screenshot tray")
                }
            } footer: {
                Text("When enabled, the notch monitors a folder and surfaces newly-saved screenshots in a dedicated tab.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Watched folder")
                        Text(watchedFolderPath.isEmpty ? "No folder chosen" : watchedFolderPath)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    Spacer()
                    Button(watchedFolderPath.isEmpty ? "Choose…" : "Change…") {
                        chooseFolder()
                    }
                }
            } header: {
                Text("Folder")
            } footer: {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Tell macOS to save screenshots here too:")
                    Text("⌘⇧5 → Options → Save to → \(watchedFolderPath.isEmpty ? "(this folder)" : (watchedFolderPath as NSString).lastPathComponent)")
                        .font(.caption.monospaced())
                        .foregroundStyle(.primary)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .disabled(!enabled)

            Section {
                if pins.folders.isEmpty {
                    Text("No pinned folders. Use the ＋ button in the screenshot tray to pin a folder.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    List {
                        ForEach(pins.folders) { folder in
                            HStack {
                                Image(systemName: "folder.fill").foregroundStyle(.blue)
                                Text(folder.displayName)
                                Spacer()
                                Button(role: .destructive) {
                                    pins.remove(id: folder.id)
                                } label: {
                                    Image(systemName: "minus.circle")
                                        .foregroundStyle(.red)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .onMove { indices, newOffset in
                            pins.folders.move(fromOffsets: indices, toOffset: newOffset)
                        }
                    }
                    .frame(minHeight: 80, maxHeight: 200)
                }
                HStack {
                    Spacer()
                    Button("Add pin…") { pins.addPin() }
                }
            } header: {
                Text("Pinned folders")
            } footer: {
                Text("Drag a screenshot onto a pin to move it (Option-drag to copy).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .disabled(!enabled)

            Section {
                Defaults.Toggle(key: .screenshotCaptureAnimationEnabled) {
                    Text("Show capture animation")
                }
                Stepper(value: $maxVisible, in: 4...60, step: 4) {
                    HStack {
                        Text("Items visible at once")
                        Spacer()
                        Text("\(maxVisible)")
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Display")
            }
            .disabled(!enabled)
        }
        .accentColor(.effectiveAccent)
        .navigationTitle("Screenshots")
        .onAppear { refreshWatchedFolderPath() }
        .onChange(of: bookmarkData) { _, _ in refreshWatchedFolderPath() }
    }

    private func refreshWatchedFolderPath() {
        guard let data = bookmarkData else {
            watchedFolderPath = ""
            return
        }
        watchedFolderPath = Bookmark(data: data).resolveURL()?.path ?? ""
    }

    private func chooseFolder() {
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
            if !enabled { Defaults[.screenshotTrayEnabled] = true }
            ScreenshotManager.shared.stop()
            ScreenshotManager.shared.start()
            refreshWatchedFolderPath()
        } catch {
            NSLog("ScreenshotSettings: bookmark failed for \(url.path): \(error)")
        }
    }
}
