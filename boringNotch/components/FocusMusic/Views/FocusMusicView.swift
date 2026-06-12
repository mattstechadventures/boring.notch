//
//  FocusMusicView.swift
//  boringNotch
//
//  Expanded notch view: a row of YouTube-backed focus tracks (thumbnail covers),
//  tap to play in-app, plus a now-playing strip.
//

import Defaults
import SwiftUI

struct FocusMusicView: View {
    @ObservedObject private var manager = FocusMusicManager.shared
    @Default(.focusTracks) private var tracks

    var body: some View {
        VStack(spacing: 10) {
            if tracks.isEmpty {
                emptyState
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(tracks) { track in
                            TrackCover(
                                track: track,
                                isCurrent: manager.isCurrent(track),
                                isPlaying: manager.isCurrent(track) && manager.isPlaying
                            ) {
                                if manager.isCurrent(track) {
                                    manager.togglePlayPause()
                                } else {
                                    manager.play(track)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                }

                if manager.currentTrack != nil {
                    FocusNowPlaying(manager: manager)
                }

                if manager.loadFailed {
                    HStack(spacing: 8) {
                        Text("This video's owner blocked embedding.")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                        Button("Open on YouTube") {
                            manager.openCurrentOnYouTube()
                        }
                        .buttonStyle(.borderless)
                        .controlSize(.small)
                        .font(.caption2)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 8)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "music.note.list")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
            Text("No focus tracks yet")
                .font(.headline)
                .foregroundStyle(.white)
            Text("Add YouTube links in Settings → Focus Music")
                .font(.caption)
                .foregroundStyle(.secondary)
            Button("Open Settings") {
                SettingsWindowController.shared.showWindow()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

}

/// Rich now-playing block mirroring the Spotify player: cover art, animated pulse,
/// a draggable seek bar, and transport controls.
private struct FocusNowPlaying: View {
    @ObservedObject var manager: FocusMusicManager

    @State private var sliderValue: Double = 0
    @State private var dragging: Bool = false
    @State private var lastDragged: Date = .distantPast

    var body: some View {
        HStack(spacing: 12) {
            // Cover art
            AsyncImage(url: manager.currentTrack?.thumbnailURL) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().aspectRatio(contentMode: .fill)
                default:
                    Rectangle()
                        .fill(Color(nsColor: .secondarySystemFill))
                        .overlay { Image(systemName: "music.note").foregroundStyle(.secondary) }
                }
            }
            .frame(width: 64, height: 64)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(manager.currentTrack?.label ?? "")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    AudioSpectrumView(isPlaying: .constant(manager.isPlaying))
                        .frame(width: 16, height: 12)
                        .opacity(manager.isPlaying ? 1 : 0.3)
                    Spacer(minLength: 0)
                }

                // Seek bar
                CustomSlider(
                    value: $sliderValue,
                    range: 0...max(1, manager.duration),
                    color: .white,
                    dragging: $dragging,
                    lastDragged: $lastDragged,
                    onValueChange: { manager.seek(to: $0) }
                )
                .frame(height: 10)

                HStack {
                    Text(timeString(sliderValue))
                    Spacer()
                    Text(timeString(manager.duration))
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }

            // Transport
            Button { manager.togglePlayPause() } label: {
                Image(systemName: manager.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)

            Button { manager.stop() } label: {
                Image(systemName: "stop.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        // Track the live position unless the user is actively scrubbing.
        .onChange(of: manager.currentTime) { _, newValue in
            guard !dragging, lastDragged.timeIntervalSinceNow < -1 else { return }
            sliderValue = newValue
        }
        // Reset the bar deterministically when a different track starts.
        .onChange(of: manager.currentTrack?.id) { _, _ in
            sliderValue = 0
            lastDragged = .distantPast
        }
    }

    private func timeString(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0:00" }
        let total = Int(seconds)
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

private struct TrackCover: View {
    let track: FocusTrack
    let isCurrent: Bool
    let isPlaying: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .bottomLeading) {
                AsyncImage(url: track.thumbnailURL) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().aspectRatio(contentMode: .fill)
                    default:
                        Rectangle()
                            .fill(Color(nsColor: .secondarySystemFill))
                            .overlay {
                                Image(systemName: "music.note")
                                    .foregroundStyle(.secondary)
                            }
                    }
                }
                .frame(width: 120, height: 72)
                .clipped()

                // Darkening gradient for label legibility.
                LinearGradient(
                    colors: [.black.opacity(0.0), .black.opacity(0.7)],
                    startPoint: .top, endPoint: .bottom
                )

                HStack {
                    Text(track.label)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    if isCurrent {
                        Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .foregroundStyle(.white)
                    }
                }
                .padding(.horizontal, 6)
                .padding(.bottom, 5)
            }
            .frame(width: 120, height: 72)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(isCurrent ? Color.accentColor : .clear, lineWidth: 2)
            }
        }
        .buttonStyle(.plain)
    }
}
