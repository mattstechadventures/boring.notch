//
//  HeaderLayoutManager.swift
//  boringNotch
//
//  Computes how many slot items physically fit on each side of the notch for
//  the current display, and clamps a saved arrangement to that capacity. This
//  is the structural guarantee that the header can never overflow the panel:
//  if the renderer is incapable of drawing more than `capacity(side)` items,
//  the "icons push past the borders / Home disappears" bug cannot recur.
//
//  Saved layout = intent; rendering always clamps to live geometry (D3).
//

import Combine
import Defaults
import SwiftUI

@MainActor
final class HeaderLayoutManager: ObservableObject {
    static let shared = HeaderLayoutManager()

    // Slot metrics — uniform across both sides (calibrated visually in Phase 2).
    static let iconWidth: CGFloat = 30
    static let minGap: CGFloat = 4
    /// Breathing room reserved at the rounded outer edge of each side region.
    static let outerMargin: CGFloat = 10
    /// Upper limit on the elastic inter-icon gap (the "comfortable full" spacing).
    static let maxGap: CGFloat = 18

    /// Published so views recompute when the active display changes.
    @Published private(set) var leftCapacity: Int = 0
    @Published private(set) var rightCapacity: Int = 0

    private init() {
        recompute()
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.recompute() }
        }
    }

    /// Usable width on one side of the notch, inside the 640pt open panel.
    func sideRegionWidth(screenUUID: String? = nil) -> CGFloat {
        let notchWidth = getClosedNotchSize(screenUUID: screenUUID).width
        return (openNotchSize.width - notchWidth) / 2 - Self.outerMargin
    }

    /// How many uniform slot items fit on one side for the given display.
    func capacity(for side: PanelSide, screenUUID: String? = nil) -> Int {
        let region = sideRegionWidth(screenUUID: screenUUID)
        guard region >= Self.iconWidth else { return 0 }
        // n icons + (n-1) gaps ≤ region  ⇒  n ≤ (region + minGap) / (iconWidth + minGap)
        let n = floor((region + Self.minGap) / (Self.iconWidth + Self.minGap))
        return max(0, Int(n))
    }

    func recompute(screenUUID: String? = nil) {
        let uuid = screenUUID ?? BoringViewCoordinator.shared.selectedScreenUUID
        leftCapacity = capacity(for: .left, screenUUID: uuid)
        rightCapacity = capacity(for: .right, screenUUID: uuid)
    }

    /// The final, render-ready ordered ids for one side: the saved arrangement,
    /// filtered to enabled panels, capped by the user's MAX (if any), then clamped
    /// to the live geometric capacity. This is the single resolution shared by the
    /// header renderer and the layout editor preview.
    func resolvedOrder(for side: PanelSide, screenUUID: String? = nil) -> [PanelID] {
        let registry = PanelRegistry.shared
        let order = side == .left ? Defaults[.headerLeftOrder] : Defaults[.headerRightOrder]
        let userMax = side == .left ? Defaults[.headerLeftMax] : Defaults[.headerRightMax]
        let enabled = order.filter { registry.descriptor(for: $0)?.isEnabled ?? false }
        let cap = capacity(for: side, screenUUID: screenUUID)
        let effectiveCap = userMax > 0 ? min(userMax, cap) : cap
        return clamp(enabled, toCount: effectiveCap)
    }

    /// Clamp to the side's live geometric capacity (pinned-aware). Convenience.
    func clamp(_ ids: [PanelID], side: PanelSide, screenUUID: String? = nil) -> [PanelID] {
        clamp(ids, toCount: capacity(for: side, screenUUID: screenUUID))
    }

    /// Clamp an ordered arrangement to `count` items. Pinned items are always kept
    /// (they survive first); the remaining budget is filled from the non-pinned
    /// items in priority (left-to-right) order. Original order is preserved.
    func clamp(_ ids: [PanelID], toCount count: Int) -> [PanelID] {
        if ids.count <= count { return ids }

        let registry = PanelRegistry.shared
        let pinned = ids.filter { registry.descriptor(for: $0)?.isPinnable == true }
        let rest = ids.filter { registry.descriptor(for: $0)?.isPinnable != true }
        let restBudget = max(0, count - pinned.count)
        let kept = Set(pinned + rest.prefix(restBudget))
        // If even the pinned items overflow a tiny display, keep the first `count`.
        let bounded = kept.count > count ? Set(ids.filter { kept.contains($0) }.prefix(count)) : kept
        return ids.filter { bounded.contains($0) }
    }

    // MARK: - Editor operations

    /// Enabled panels currently placed on a side, in order. Disabled panels stay
    /// in the persisted order arrays (just hidden from the editor) so disabling
    /// and re-enabling a panel preserves its slot position.
    func arranged(_ side: PanelSide) -> [PanelID] {
        let order = side == .left ? Defaults[.headerLeftOrder] : Defaults[.headerRightOrder]
        return order.filter { PanelRegistry.shared.descriptor(for: $0)?.isEnabled == true }
    }

    /// Raw insertion index in `order` corresponding to the `visibleIndex`-th
    /// enabled (editor-visible) slot, so placing preserves interleaved disabled ids.
    private func rawInsertIndex(in order: [PanelID], visibleIndex: Int) -> Int {
        var seen = 0
        for (i, id) in order.enumerated() {
            if seen == visibleIndex { return i }
            if PanelRegistry.shared.descriptor(for: id)?.isEnabled == true { seen += 1 }
        }
        return order.count
    }

    /// Enabled panels not currently placed on either side (the editor palette).
    var paletteIDs: [PanelID] {
        let placed = Set(arranged(.left) + arranged(.right))
        return PanelRegistry.shared.all
            .filter { $0.isEnabled && !placed.contains($0.id) }
            .map(\.id)
    }

    /// Place (or move/reorder) a panel into `side` at the given editor-visible
    /// `index`. Operates on the raw order arrays so interleaved disabled panels
    /// keep their positions.
    func place(_ id: PanelID, side: PanelSide, at index: Int) {
        var left = Defaults[.headerLeftOrder]
        var right = Defaults[.headerRightOrder]
        left.removeAll { $0 == id }
        right.removeAll { $0 == id }
        if side == .left {
            left.insert(id, at: rawInsertIndex(in: left, visibleIndex: index))
        } else {
            right.insert(id, at: rawInsertIndex(in: right, visibleIndex: index))
        }
        Defaults[.headerLeftOrder] = left
        Defaults[.headerRightOrder] = right
    }

    /// Remove a panel from the header (back to the palette). Pinned panels stay.
    func removeFromHeader(_ id: PanelID) {
        guard PanelRegistry.shared.descriptor(for: id)?.isPinnable != true else { return }
        var left = Defaults[.headerLeftOrder]
        var right = Defaults[.headerRightOrder]
        left.removeAll { $0 == id }
        right.removeAll { $0 == id }
        Defaults[.headerLeftOrder] = left
        Defaults[.headerRightOrder] = right
    }

    /// Elastic inter-icon gap for `count` items on `side`. When `elastic` is off,
    /// a fixed `minGap`; when on, slack is spread up to `maxGap`. The group is
    /// anchored to the outer edge by the caller (so slack sits next to the notch).
    func gap(for count: Int, side: PanelSide, elastic: Bool, screenUUID: String? = nil) -> CGFloat {
        guard elastic, count > 1 else { return Self.minGap }
        let region = sideRegionWidth(screenUUID: screenUUID)
        let slack = region - CGFloat(count) * Self.iconWidth
        guard slack > 0 else { return Self.minGap }
        return min(Self.maxGap, max(Self.minGap, slack / CGFloat(count - 1)))
    }
}
