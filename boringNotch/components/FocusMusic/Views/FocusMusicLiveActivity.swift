//
//  FocusMusicLiveActivity.swift
//  boringNotch
//
//  Closed-notch live activity for in-app YouTube focus music: cover art on the
//  left, animated pulse on the right — mirroring the Spotify MusicLiveActivity
//  layout (and matching its computedChinWidth reservation).
//

import SwiftUI

struct FocusMusicLiveActivity: View {
    @EnvironmentObject var vm: BoringViewModel
    @ObservedObject private var manager = FocusMusicManager.shared

    private var artSide: CGFloat { max(0, vm.effectiveClosedNotchHeight - 12) }

    var body: some View {
        HStack {
            // Cover art (left) — same square size the music live activity uses.
            AsyncImage(url: manager.currentTrack?.thumbnailURL) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().aspectRatio(contentMode: .fill)
                default:
                    Rectangle()
                        .fill(Color(nsColor: .secondarySystemFill))
                        .overlay { Image(systemName: "music.note").foregroundStyle(.white) }
                }
            }
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: MusicPlayerImageSizes.cornerRadiusInset.closed))
            .frame(width: artSide, height: artSide)

            // Center spacer matching the physical notch cutout.
            Rectangle()
                .fill(.black)
                .frame(width: vm.closedNotchSize.width)

            // Pulse (right) — masked spectrum, same treatment as MusicLiveActivity.
            HStack {
                Rectangle()
                    .fill(Color.gray.gradient)
                    .frame(width: 50, alignment: .center)
                    .mask {
                        AudioSpectrumView(isPlaying: .constant(manager.isPlaying))
                            .frame(width: 16, height: 12)
                    }
            }
        }
        .frame(height: vm.effectiveClosedNotchHeight, alignment: .center)
    }
}
