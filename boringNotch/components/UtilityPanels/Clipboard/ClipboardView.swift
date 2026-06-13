//
//  ClipboardView.swift
//  boringNotch
//
//  Clipboard history: newest first. Tap a row to copy it back (brief "Copied!"
//  feedback); per-row delete; Clear All.
//

import SwiftUI

struct ClipboardView: View {
    @ObservedObject private var manager = ClipboardManager.shared
    @State private var copiedID: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Clipboard").font(.headline)
                Spacer()
                if !manager.items.isEmpty {
                    Button { manager.clearAll() } label: {
                        Text("Clear All").font(.caption)
                    }
                    .buttonStyle(.plain).foregroundStyle(.red)
                }
            }

            if manager.items.isEmpty {
                Spacer(minLength: 0)
                HStack {
                    Spacer()
                    Text("Nothing copied yet").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                }
                Spacer(minLength: 0)
            } else {
                ScrollView {
                    VStack(spacing: 4) {
                        ForEach(manager.items) { item in
                            row(for: item)
                        }
                    }
                }
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private func row(for item: ClipboardItem) -> some View {
        Button { copy(item) } label: {
            HStack(spacing: 8) {
                icon(for: item)
                if copiedID == item.id {
                    Text("Copied!").font(.callout).foregroundStyle(Color.accentColor)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else if let image = item.image, item.kind == .image {
                    Image(nsImage: image)
                        .resizable().scaledToFit()
                        .frame(height: 18)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Text(item.preview)
                        .font(.callout).lineLimit(1)
                        .foregroundStyle(item.kind == .link ? Color.accentColor : Color.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                Button { manager.delete(item) } label: {
                    Image(systemName: "xmark").font(.caption2)
                }
                .buttonStyle(.plain).foregroundStyle(.secondary)
            }
            .padding(.vertical, 5).padding(.horizontal, 8)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.06)))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func icon(for item: ClipboardItem) -> some View {
        let name: String = {
            switch item.kind {
            case .text: return "text.alignleft"
            case .link: return "link"
            case .image: return "photo"
            }
        }()
        Image(systemName: name).font(.caption).foregroundStyle(.secondary).frame(width: 14)
    }

    private func copy(_ item: ClipboardItem) {
        manager.copyToPasteboard(item)
        copiedID = item.id
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            if copiedID == item.id { copiedID = nil }
        }
    }
}
