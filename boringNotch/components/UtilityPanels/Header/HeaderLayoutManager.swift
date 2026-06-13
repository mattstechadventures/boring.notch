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
            MainActor.assumeIsolated { self?.recompute() }
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

    /// Clamp an ordered arrangement to the side's live capacity. Pinned items are
    /// always kept (they survive first); the remaining capacity is filled from the
    /// non-pinned items in priority (left-to-right) order. Original order preserved.
    func clamp(_ ids: [PanelID], side: PanelSide, screenUUID: String? = nil) -> [PanelID] {
        let cap = capacity(for: side, screenUUID: screenUUID)
        if ids.count <= cap { return ids }

        let registry = PanelRegistry.shared
        let pinned = ids.filter { registry.descriptor(for: $0)?.isPinnable == true }
        let rest = ids.filter { registry.descriptor(for: $0)?.isPinnable != true }
        let restBudget = max(0, cap - pinned.count)
        let kept = Set(pinned + rest.prefix(restBudget))
        // If even the pinned items overflow a tiny display, keep the first `cap`.
        let bounded = kept.count > cap ? Set(ids.filter { kept.contains($0) }.prefix(cap)) : kept
        return ids.filter { bounded.contains($0) }
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
