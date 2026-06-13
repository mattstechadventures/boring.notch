//
//  NotchSlotEditor.swift
//  boringNotch
//
//  Visual drag-to-slot arranger. Each side shows ghost slots up to the live
//  per-display capacity (plus any extra "overflow" slots styled to show they
//  won't fit on this display). Drag panels from the palette into slots, reorder,
//  move between sides, or drag back to the palette to remove. Pinned panels
//  (Home, Settings) can be moved but not removed.
//

import Defaults
import SwiftUI

struct NotchSlotEditor: View {
    @ObservedObject private var layout = HeaderLayoutManager.shared
    @Default(.headerLeftOrder) private var leftOrder
    @Default(.headerRightOrder) private var rightOrder

    private let slotSize: CGFloat = 46

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .center, spacing: 8) {
                    sideRow(.left)
                    notchSilhouette
                    sideRow(.right)
                }
                .padding(.vertical, 6)
            }

            Text("Available").font(.caption).foregroundStyle(.secondary)
            paletteView

            Text("Drag icons into the slots on either side of the notch. Faded slots won't fit on this display. Drag back to Available to remove (Home and Settings can be moved but not removed).")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    // MARK: Side row of slots

    @ViewBuilder
    private func sideRow(_ side: PanelSide) -> some View {
        let placed = layout.arranged(side)
        let capacity = layout.capacity(for: side)
        let slotCount = max(capacity, placed.count)

        HStack(spacing: 6) {
            ForEach(0..<max(slotCount, 1), id: \.self) { index in
                slot(side: side, index: index, placed: placed, capacity: capacity)
            }
        }
    }

    @ViewBuilder
    private func slot(side: PanelSide, index: Int, placed: [PanelID], capacity: Int) -> some View {
        let isOverflow = index >= capacity
        Group {
            if index < placed.count, let descriptor = PanelRegistry.shared.descriptor(for: placed[index]) {
                placedChip(descriptor, isOverflow: isOverflow)
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4]))
                    .foregroundStyle(.secondary.opacity(isOverflow ? 0.2 : 0.5))
                    .frame(width: slotSize, height: slotSize)
            }
        }
        .dropDestination(for: String.self) { items, _ in
            guard let raw = items.first, let id = PanelID(rawValue: raw) else { return false }
            layout.place(id, side: side, at: index)
            return true
        }
    }

    private func placedChip(_ descriptor: PanelDescriptor, isOverflow: Bool) -> some View {
        VStack(spacing: 2) {
            Image(systemName: descriptor.icon).imageScale(.medium)
            Text(descriptor.label).font(.system(size: 8)).lineLimit(1)
        }
        .frame(width: slotSize, height: slotSize)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.accentColor.opacity(isOverflow ? 0.12 : 0.3)))
        .overlay(alignment: .topTrailing) {
            if descriptor.isPinnable {
                Image(systemName: "pin.fill").font(.system(size: 7)).foregroundStyle(.secondary).padding(2)
            }
        }
        .opacity(isOverflow ? 0.55 : 1)
        .draggable(descriptor.id.rawValue)
        .help(isOverflow ? "\(descriptor.label) — hidden on this display (doesn't fit)" : descriptor.label)
    }

    // MARK: Palette

    @State private var paletteTargeted = false

    private var paletteView: some View {
        let columns = [GridItem(.adaptive(minimum: slotSize + 6), spacing: 6)]
        return Group {
            if layout.paletteIDs.isEmpty {
                Text("Drop an icon here to remove it from the notch")
                    .font(.caption).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: slotSize, alignment: .center)
            } else {
                LazyVGrid(columns: columns, alignment: .leading, spacing: 6) {
                    ForEach(layout.paletteIDs, id: \.self) { id in
                        if let descriptor = PanelRegistry.shared.descriptor(for: id) {
                            VStack(spacing: 2) {
                                Image(systemName: descriptor.icon).imageScale(.medium)
                                Text(descriptor.label).font(.system(size: 8)).lineLimit(1)
                            }
                            .frame(width: slotSize, height: slotSize)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.08)))
                            .draggable(descriptor.id.rawValue)
                        }
                    }
                }
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, minHeight: slotSize + 16, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.secondary.opacity(paletteTargeted ? 0.18 : 0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [5]))
                .foregroundStyle(.secondary.opacity(paletteTargeted ? 0.7 : 0.35))
        )
        .dropDestination(for: String.self) { items, _ in
            guard let raw = items.first, let id = PanelID(rawValue: raw) else { return false }
            layout.removeFromHeader(id)
            return true
        } isTargeted: { paletteTargeted = $0 }
    }

    // MARK: Mini notch

    private var notchSilhouette: some View {
        NotchShape()
            .fill(Color.black)
            .frame(width: 90, height: slotSize)
            .overlay(
                NotchShape().stroke(Color.secondary.opacity(0.4), lineWidth: 1)
            )
    }
}
