import SwiftUI

struct PinnedFolderCellView: View {
    let folder: PinnedFolder
    var size: CGFloat = 36
    var onMoveCompleted: (ScreenshotMoveResult) -> Void = { _ in }

    @ObservedObject private var store = PinnedFoldersStore.shared
    @State private var hovering = false
    @State private var isDropTargeted = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(backgroundFill)
            Image(systemName: "folder.fill")
                .font(.system(size: size * 0.55))
                .foregroundStyle(isDropTargeted ? .green : .blue)
        }
        .frame(width: size, height: size)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isDropTargeted ? Color.green.opacity(0.85) : Color.clear, lineWidth: 1.5)
        )
        .dropDestination(for: URL.self) { urls, _ in
            let useCopy = NSEvent.modifierFlags.contains(.option)
            var anyMoved = false
            for url in urls where url.isFileURL {
                if let result = ScreenshotMoveService.perform(
                    sourceURL: url,
                    into: folder,
                    operation: useCopy ? .copy : .move
                ) {
                    onMoveCompleted(result)
                    if result.operation == .move { anyMoved = true }
                }
            }
            return anyMoved || !urls.isEmpty
        } isTargeted: { isOver in
            withAnimation(.smooth(duration: 0.12)) { isDropTargeted = isOver }
        }
        .overlay(alignment: .bottom) {
            if hovering {
                Text(folder.displayName)
                    .font(.system(size: 9))
                    .lineLimit(1)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.black.opacity(0.78)))
                    .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 0.5))
                    .foregroundStyle(.white)
                    .fixedSize()
                    .offset(y: 18)
                    .transition(.opacity)
                    .zIndex(2)
            }
        }
        .onHover { isOver in
            withAnimation(.smooth(duration: 0.12)) { hovering = isOver }
        }
        .contextMenu {
            Button("Open folder") {
                if let url = store.resolveURL(for: folder) {
                    NSWorkspace.shared.open(url)
                }
            }
            Divider()
            Button("Remove pin", role: .destructive) {
                store.remove(id: folder.id)
            }
        }
    }

    private var backgroundFill: Color {
        if isDropTargeted { return Color.green.opacity(0.18) }
        if hovering { return Color.white.opacity(0.14) }
        return Color.white.opacity(0.05)
    }
}

struct AddPinCellView: View {
    var size: CGFloat = 36
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(
                        Color.white.opacity(0.22),
                        style: StrokeStyle(lineWidth: 1, dash: [3, 3])
                    )
                Image(systemName: "plus")
                    .font(.system(size: size * 0.45))
                    .foregroundStyle(.secondary)
            }
            .frame(width: size, height: size)
        }
        .buttonStyle(.plain)
        .help("Pin a folder")
    }
}
