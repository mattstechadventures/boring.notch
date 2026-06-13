//
//  FilesView.swift
//  boringNotch
//
//  Files panel: pinned-folder chips + the selected folder's contents. Tap a
//  file to open, drag files out to Finder, drop external files in to import.
//

import SwiftUI
import UniformTypeIdentifiers

struct FilesView: View {
    @ObservedObject private var vm = FilesViewModel.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Files").font(.headline)
                Spacer()
                Button { vm.addPin() } label: {
                    Image(systemName: "plus").font(.caption)
                }
                .buttonStyle(.plain).foregroundStyle(.secondary)
                .help("Pin a folder")
            }

            if vm.pins.isEmpty {
                Spacer(minLength: 0)
                HStack {
                    Spacer()
                    VStack(spacing: 4) {
                        Text("No pinned folders").font(.caption).foregroundStyle(.secondary)
                        Button("Pin a folder…") { vm.addPin() }
                            .buttonStyle(.plain).font(.caption).foregroundStyle(Color.accentColor)
                    }
                    Spacer()
                }
                Spacer(minLength: 0)
            } else {
                chips
                contentsList
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private var chips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(vm.pins) { pin in
                    let selected = pin.id == vm.selectedPinID
                    HStack(spacing: 4) {
                        Image(systemName: "folder.fill").font(.caption2)
                        Text(pin.displayName).font(.caption).lineLimit(1)
                        Button { vm.remove(pin) } label: {
                            Image(systemName: "minus.circle.fill").font(.caption2)
                        }
                        .buttonStyle(.plain).foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Capsule().fill(selected ? Color.accentColor.opacity(0.35) : Color.white.opacity(0.08)))
                    .foregroundStyle(selected ? Color.white : Color.secondary)
                    .contentShape(Capsule())
                    .onTapGesture { vm.select(pin) }
                }
            }
        }
    }

    private var contentsList: some View {
        ScrollView {
            VStack(spacing: 3) {
                if vm.contents.isEmpty {
                    Text("Empty folder").font(.caption).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 8)
                } else {
                    ForEach(vm.contents, id: \.self) { url in
                        row(for: url)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(vm.isDropTargeted ? Color.orange : Color.clear, lineWidth: 1.5)
        )
        .onDrop(of: [UTType.fileURL], isTargeted: $vm.isDropTargeted) { providers in
            for provider in providers {
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    guard let url else { return }
                    Task { @MainActor in vm.importFiles([url]) }
                }
            }
            return true
        }
    }

    private func row(for url: URL) -> some View {
        HStack(spacing: 8) {
            Image(nsImage: vm.icon(for: url))
                .resizable().frame(width: 16, height: 16)
            Text(url.lastPathComponent)
                .font(.callout).lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 4).padding(.horizontal, 8)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.06)))
        .contentShape(Rectangle())
        .onTapGesture { vm.open(url) }
        .onDrag { NSItemProvider(object: url as NSURL) }
    }
}
