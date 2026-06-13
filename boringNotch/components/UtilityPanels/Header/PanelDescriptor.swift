//
//  PanelDescriptor.swift
//  boringNotch
//
//  Declarative description of a header entry point. The registry holds one of
//  these per PanelID; the header renderer, the layout editor, the per-feature
//  settings list, and the default-view resolver are all data over these.
//

import Defaults
import SwiftUI

/// Which side of the notch a slot item lives on.
enum PanelSide: String, Codable, Defaults.Serializable {
    case left
    case right
}

/// What activating a slot item does. Keeps the descriptor free of any captured
/// view state (`vm`, environment) — the renderer maps a kind to behaviour where
/// it has the right context.
enum PanelKind {
    /// Opens a notch view (the common case: tabs + the four utility panels).
    case view(NotchViews)
    /// Toggles the webcam mirror (`vm.toggleCameraPreview()`).
    case toggleWebcam
    /// Opens the Settings window.
    case openSettings
    /// Display-only battery readout (still occupies a slot).
    case batteryIndicator
}

/// One header entry point.
struct PanelDescriptor: Identifiable {
    let id: PanelID
    let label: String
    /// SF Symbol name.
    let icon: String
    let kind: PanelKind
    /// Default side when the user has no saved arrangement.
    let defaultSide: PanelSide
    /// Pinnable items (Home, Settings) are default-on and cannot be removed in
    /// the editor — but can still be moved/reordered, and survive capacity
    /// clamping first.
    let isPinnable: Bool
    /// Per-panel on/off. `nil` means always available (e.g. Home).
    let enableKey: Defaults.Key<Bool>?
    /// True when this panel currently has "active context" — used by the
    /// `.smart` default-view policy (e.g. Focus Music while a track plays).
    let isActiveContext: @MainActor () -> Bool
    /// Tie-break among active-context panels under `.smart` (higher wins).
    let contextPriority: Int

    init(
        id: PanelID,
        label: String,
        icon: String,
        kind: PanelKind,
        defaultSide: PanelSide,
        isPinnable: Bool = false,
        enableKey: Defaults.Key<Bool>? = nil,
        isActiveContext: @escaping @MainActor () -> Bool = { false },
        contextPriority: Int = 0
    ) {
        self.id = id
        self.label = label
        self.icon = icon
        self.kind = kind
        self.defaultSide = defaultSide
        self.isPinnable = isPinnable
        self.enableKey = enableKey
        self.isActiveContext = isActiveContext
        self.contextPriority = contextPriority
    }

    /// The notch view this opens, if it's a `.view` kind.
    var destination: NotchViews? {
        if case let .view(view) = kind { return view }
        return nil
    }

    /// Whether the panel is currently enabled (its `enableKey` is on, or it has none).
    @MainActor var isEnabled: Bool {
        guard let key = enableKey else { return true }
        return Defaults[key]
    }
}
