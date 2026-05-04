import SwiftUI
import Defaults

struct ScreenshotTrayView: View {
    @StateObject private var vm = ScreenshotTrayViewModel()
    @ObservedObject private var manager = ScreenshotManager.shared
    @StateObject private var quickLookService = QuickLookService()

    @Default(.screenshotTrayEnabled) private var enabled
    @Default(.screenshotsFolderBookmark) private var bookmarkData

    private var needsSetup: Bool { !enabled || bookmarkData == nil }

    var body: some View {
        Group {
            if needsSetup {
                onboardingView
            } else {
                mainContent
            }
        }
        .environmentObject(quickLookService)
        .quickLookPresenter(using: quickLookService)
    }

    private var mainContent: some View {
        HStack(spacing: 0) {
            stripPane
                .frame(maxWidth: .infinity)

            Divider()
                .background(Color.white.opacity(0.06))

            PinnedFolderGridView(onMoveCompleted: { result in
                vm.recordMove(result)
            })
        }
        .overlay(alignment: .bottom) {
            if vm.toastVisible, let result = vm.lastMoveResult {
                ScreenshotToastView(
                    folderName: result.folderName,
                    onUndo: { vm.undoLastMove() }
                )
                .padding(.bottom, 8)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
    }

    private var onboardingView: some View {
        VStack(spacing: 10) {
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(.secondary)

            Text("Pick a folder for screenshots")
                .font(.subheadline.weight(.medium))

            Text("The notch monitors this folder. Tell macOS to save screenshots here too: ⌘⇧5 → Options → Save to.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)

            Button("Choose folder…") {
                vm.runFirstRun()
            }
            .controlSize(.small)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var stripPane: some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 10) {
                    ForEach(vm.visibleItems) { item in
                        ScreenshotThumbView(screenshot: item)
                    }
                    if vm.hasMore {
                        Button {
                            vm.showMore()
                        } label: {
                            VStack(spacing: 3) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color.white.opacity(0.05))
                                    Image(systemName: "plus")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundStyle(.secondary)
                                }
                                .frame(width: 56, height: 56)
                                Text("+\(vm.hiddenCount)")
                                    .font(.system(size: 9))
                                    .foregroundStyle(.secondary)
                            }
                            .frame(width: 56)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
            }
            .background(
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.smooth(duration: 0.2)) {
                            vm.toggleOpenFolderAffordance()
                        }
                    }
            )

            if vm.showOpenFolderAffordance, let folder = manager.watchedFolderURL {
                Button {
                    openWatchedFolder(folder)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "folder")
                        Text("Open folder")
                    }
                    .font(.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Color.black.opacity(0.6)))
                    .overlay(
                        Capsule().stroke(Color.white.opacity(0.15), lineWidth: 0.5)
                    )
                    .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .padding(8)
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
        }
    }

    private func openWatchedFolder(_ folder: URL) {
        // The folder is security-scoped under the manager; NSWorkspace runs out-of-process
        // and doesn't need our scope to open Finder.
        NSWorkspace.shared.open(folder)
    }
}
