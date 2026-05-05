import SwiftUI

struct PinnedFolderGridView: View {
    @ObservedObject private var store = PinnedFoldersStore.shared
    var onMoveCompleted: (ScreenshotMoveResult) -> Void = { _ in }

    private let cellSize: CGFloat = 36
    private let cellSpacing: CGFloat = 8
    private let columnsCount = 4

    private var columns: [GridItem] {
        Array(
            repeating: GridItem(.fixed(cellSize), spacing: cellSpacing),
            count: columnsCount
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: "pin.fill")
                Text("Pinned")
            }
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(.secondary)

            LazyVGrid(columns: columns, alignment: .leading, spacing: cellSpacing) {
                ForEach(store.folders) { folder in
                    PinnedFolderCellView(folder: folder, onMoveCompleted: onMoveCompleted)
                }
                AddPinCellView { store.addPin() }
            }
        }
        .padding(8)
        .frame(width: CGFloat(columnsCount) * cellSize + CGFloat(columnsCount - 1) * cellSpacing + 16)
    }
}
