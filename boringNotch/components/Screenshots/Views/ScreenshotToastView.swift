import SwiftUI

struct ScreenshotToastView: View {
    let folderName: String
    let onUndo: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Text("Moved to \(folderName)")
                .font(.caption)
                .foregroundStyle(.white)
            Button(action: onUndo) {
                Text("Undo")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.blue)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Capsule().fill(Color.black.opacity(0.78)))
        .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 0.5))
    }
}
