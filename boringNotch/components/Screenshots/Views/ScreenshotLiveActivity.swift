import SwiftUI

struct ScreenshotLiveActivity: View {
    @EnvironmentObject var vm: BoringViewModel
    @ObservedObject private var manager = ScreenshotManager.shared
    @State private var thumbnail: NSImage?

    var body: some View {
        HStack(spacing: 0) {
            HStack {
                Group {
                    if let thumbnail {
                        Image(nsImage: thumbnail)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } else {
                        Image(systemName: "camera.viewfinder")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .foregroundStyle(.white)
                            .padding(2)
                    }
                }
                .frame(width: vm.effectiveClosedNotchHeight - 8, height: vm.effectiveClosedNotchHeight - 8)
                .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            .frame(width: 80, alignment: .leading)
            .padding(.leading, 6)
            .task(id: manager.items.first?.id) {
                guard let item = manager.items.first else { thumbnail = nil; return }
                let scale = NSScreen.main?.backingScaleFactor ?? 2
                let side = vm.effectiveClosedNotchHeight
                thumbnail = await ThumbnailService.shared.thumbnail(
                    for: item.url,
                    size: CGSize(width: side * scale, height: side * scale)
                )
            }

            Rectangle()
                .fill(.black)
                .frame(width: vm.closedNotchSize.width + 10)

            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("Saved")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white)
            }
            .frame(width: 90, alignment: .trailing)
            .padding(.trailing, 6)
        }
        .frame(height: vm.effectiveClosedNotchHeight, alignment: .center)
    }
}
