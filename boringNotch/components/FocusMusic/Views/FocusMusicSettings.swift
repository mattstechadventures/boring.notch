//
//  FocusMusicSettings.swift
//  boringNotch
//

import Defaults
import SwiftUI

struct FocusMusicSettings: View {
    @Default(.enableFocusMusic) var enableFocusMusic
    @Default(.focusTracks) var focusTracks
    @Default(.focusMusicPauseOtherMedia) var pauseOtherMedia

    @State private var selectedTrack: FocusTrack?
    @State private var isPresented: Bool = false
    @State private var label: String = ""
    @State private var url: String = ""

    var body: some View {
        Form {
            Section {
                Defaults.Toggle(key: .enableFocusMusic) {
                    Text("Show Focus Music icon in notch")
                }
                Defaults.Toggle(key: .focusMusicPauseOtherMedia) {
                    Text("Pause other media when a focus track starts")
                }
            } header: {
                Text("General")
            } footer: {
                Text("Tracks play inside notchdock via a hidden player, so there's no browser tab to lose and audio keeps going when the notch is closed.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                List {
                    ForEach(focusTracks) { track in
                        HStack {
                            AsyncImage(url: track.thumbnailURL) { phase in
                                switch phase {
                                case .success(let image):
                                    image.resizable().aspectRatio(contentMode: .fill)
                                default:
                                    Rectangle()
                                        .fill(Color(nsColor: .secondarySystemFill))
                                        .overlay { Image(systemName: "music.note").foregroundStyle(.secondary) }
                                }
                            }
                            .frame(width: 56, height: 34)
                            .clipShape(RoundedRectangle(cornerRadius: 4))

                            VStack(alignment: .leading, spacing: 1) {
                                Text(track.label)
                                if !track.isValid {
                                    Text("Invalid YouTube link")
                                        .font(.caption2)
                                        .foregroundStyle(.orange)
                                }
                            }
                            Spacer(minLength: 0)
                        }
                        .contentShape(Rectangle())
                        .padding(.vertical, 2)
                        .background(
                            selectedTrack == track ? Color.effectiveAccent.opacity(0.25) : Color.clear,
                            in: RoundedRectangle(cornerRadius: 5)
                        )
                        .onTapGesture {
                            selectedTrack = (selectedTrack == track) ? nil : track
                        }
                    }
                }
                .frame(minHeight: 120)
                .actionBar {
                    HStack(spacing: 5) {
                        Button {
                            label = ""
                            url = ""
                            isPresented.toggle()
                        } label: {
                            Image(systemName: "plus")
                                .foregroundStyle(.secondary)
                                .contentShape(Rectangle())
                        }
                        Divider()
                        Button {
                            if let track = selectedTrack,
                               let idx = focusTracks.firstIndex(of: track) {
                                focusTracks.remove(at: idx)
                                selectedTrack = nil
                            }
                        } label: {
                            Image(systemName: "minus")
                                .foregroundStyle(.secondary)
                                .contentShape(Rectangle())
                        }
                    }
                }
                .controlSize(.small)
                .buttonStyle(PlainButtonStyle())
                .overlay {
                    if focusTracks.isEmpty {
                        Text("No focus tracks")
                            .foregroundStyle(Color(.secondaryLabelColor))
                            .padding(.bottom, 22)
                    }
                }
                .sheet(isPresented: $isPresented) {
                    addTrackSheet
                }
            } header: {
                HStack(spacing: 0) {
                    Text("YouTube tracks")
                    if !focusTracks.isEmpty {
                        Text(" – \(focusTracks.count)")
                            .foregroundStyle(.secondary)
                    }
                }
            } footer: {
                Text("Paste a YouTube link (watch, youtu.be, or embed). The video thumbnail becomes the cover.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .accentColor(.effectiveAccent)
        .navigationTitle("Focus Music")
    }

    private var addTrackSheet: some View {
        VStack(alignment: .leading) {
            Text("Add focus track")
                .font(.largeTitle.bold())
                .padding(.vertical)
            TextField("Label (e.g. Lo-Fi)", text: $label)
            TextField("YouTube URL", text: $url)

            if !url.isEmpty, let preview = FocusTrack(label: label, youtubeURL: url).thumbnailURL {
                AsyncImage(url: preview) { phase in
                    if case .success(let image) = phase {
                        image.resizable().aspectRatio(contentMode: .fit)
                    } else {
                        EmptyView()
                    }
                }
                .frame(maxHeight: 90)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .padding(.top, 8)
            }

            HStack {
                Button {
                    isPresented = false
                } label: {
                    Text("Cancel").frame(maxWidth: .infinity, alignment: .center)
                }

                Button {
                    let track = FocusTrack(label: label.isEmpty ? "Untitled" : label, youtubeURL: url)
                    focusTracks.append(track)
                    isPresented = false
                } label: {
                    Text("Add").frame(maxWidth: .infinity, alignment: .center)
                }
                .buttonStyle(BorderedProminentButtonStyle())
                .disabled(!FocusTrack(label: label, youtubeURL: url).isValid)
            }
            .padding(.top)
        }
        .textFieldStyle(RoundedBorderTextFieldStyle())
        .controlSize(.extraLarge)
        .padding()
        .frame(width: 380)
    }
}
