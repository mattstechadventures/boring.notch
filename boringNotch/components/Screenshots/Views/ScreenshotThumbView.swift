import SwiftUI

struct ScreenshotThumbView: View {
    let screenshot: Screenshot
    var size: CGFloat = 56

    @EnvironmentObject private var vm: BoringViewModel
    @EnvironmentObject private var quickLookService: QuickLookService
    @State private var image: NSImage?
    @State private var hovering: Bool = false

    var body: some View {
        VStack(spacing: 3) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.white.opacity(0.05))
                if let image {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    ProgressView().controlSize(.small)
                }

                if hovering {
                    Color.black.opacity(0.45)
                        .transition(.opacity)
                    HStack(spacing: 6) {
                        actionButton("photo.on.rectangle", help: "Copy image") { copyImage() }
                        actionButton("doc.on.doc", help: "Copy file") { copyFile() }
                        actionButton("magnifyingglass", help: "Reveal in Finder") { reveal() }
                    }
                    .transition(.opacity)
                }
            }
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
            )

            Text(Self.relativeShort(from: screenshot.addedAt))
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(width: size)
        .onHover { isOver in
            withAnimation(.smooth(duration: 0.12)) { hovering = isOver }
        }
        .onDrag {
            // Outgoing drag carries the file URL — Finder, Slack, Photos, etc. all accept this
            // and apply the standard macOS move/copy modifier convention themselves. Without
            // DragSessionTracker, the notch's hover-collapse fires when the cursor leaves the
            // notch area mid-drag and the drag aborts.
            DispatchQueue.main.async { DragSessionTracker.start(vm: vm) }
            return NSItemProvider(object: screenshot.url as NSURL)
        }
        .contextMenu {
            Button("Copy image") { copyImage() }
            Button("Copy file") { copyFile() }
            Button("Reveal in Finder") { reveal() }
            Divider()
            Button("Quick Look") { quickLook() }
            Divider()
            Button("Delete", role: .destructive) { delete() }
        }
        .task(id: screenshot.id) {
            let scale = NSScreen.main?.backingScaleFactor ?? 2
            image = await ThumbnailService.shared.thumbnail(
                for: screenshot.url,
                size: CGSize(width: size * scale, height: size * scale)
            )
        }
    }

    @ViewBuilder
    private func actionButton(_ systemName: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 18, height: 18)
                .background(Circle().fill(Color.white.opacity(0.18)))
        }
        .buttonStyle(.plain)
        .help(help)
    }

    // MARK: - Actions

    private func copyImage() { ScreenshotPasteboardService.copyImage(at: screenshot.url) }
    private func copyFile() { ScreenshotPasteboardService.copyFile(at: screenshot.url) }
    private func reveal() { NSWorkspace.shared.activateFileViewerSelecting([screenshot.url]) }
    private func quickLook() { quickLookService.show(urls: [screenshot.url], selectFirst: true) }
    private func delete() {
        do {
            try FileManager.default.trashItem(at: screenshot.url, resultingItemURL: nil)
        } catch {
            NSLog("ScreenshotThumbView: trash failed for \(screenshot.url.path): \(error.localizedDescription)")
        }
    }

    static func relativeShort(from date: Date, now: Date = Date()) -> String {
        let interval = now.timeIntervalSince(date)
        if interval < 60 { return "now" }
        if interval < 3600 { return "\(Int(interval / 60))m" }
        if interval < 86400 { return "\(Int(interval / 3600))h" }
        if interval < 86400 * 2 { return "yest." }
        let days = Int(interval / 86400)
        if days < 7 { return "\(days)d" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}
