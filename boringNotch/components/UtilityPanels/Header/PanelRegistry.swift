//
//  PanelRegistry.swift
//  boringNotch
//
//  Single source of truth for every header entry point. Phase 1 registers the
//  existing legacy panels (tabs + right-cluster tools); the four utility panels
//  register their descriptors as they are built.
//

import Defaults
import SwiftUI

@MainActor
final class PanelRegistry: ObservableObject {
    static let shared = PanelRegistry()

    /// All known descriptors, keyed by id for O(1) lookup.
    private(set) var descriptors: [PanelID: PanelDescriptor] = [:]
    /// Registration order (used for stable iteration in settings, etc.).
    private(set) var order: [PanelID] = []

    private init() {
        registerLegacyPanels()
        registerUtilityPanels()
    }

    func register(_ descriptor: PanelDescriptor) {
        if descriptors[descriptor.id] == nil {
            order.append(descriptor.id)
        }
        descriptors[descriptor.id] = descriptor
    }

    func descriptor(for id: PanelID) -> PanelDescriptor? {
        descriptors[id]
    }

    var all: [PanelDescriptor] {
        order.compactMap { descriptors[$0] }
    }

    // MARK: - Legacy registrations

    private func registerLegacyPanels() {
        // Navigation tabs (left cluster today). enableKey is nil — they are
        // always-available nav (matching today's always-present tab bar); the
        // user removes a tab by un-placing it in the layout editor, not by a
        // feature toggle. (Home & Settings are additionally pinnable.)
        register(.init(id: .home, label: "Home", icon: "house.fill",
                       kind: .view(.home), defaultSide: .left, isPinnable: true))
        register(.init(id: .shelf, label: "Shelf", icon: "tray.fill",
                       kind: .view(.shelf), defaultSide: .left,
                       isActiveContext: { !ShelfStateViewModel.shared.isEmpty }))
        register(.init(id: .screenshots, label: "Screenshots", icon: "camera.fill",
                       kind: .view(.screenshots), defaultSide: .left))
        register(.init(id: .claudeCode, label: "Claude", icon: "terminal.fill",
                       kind: .view(.claudeCode), defaultSide: .left))

        // Right-cluster tools / indicators.
        register(.init(id: .pomodoro, label: "Pomodoro", icon: "timer",
                       kind: .view(.pomodoro), defaultSide: .right,
                       enableKey: .enablePomodoro))
        register(.init(id: .focusMusic, label: "Focus Music", icon: "music.note",
                       kind: .view(.focusMusic), defaultSide: .right,
                       enableKey: .enableFocusMusic,
                       isActiveContext: { FocusMusicManager.shared.isPlaying }))
        register(.init(id: .webcam, label: "Mirror", icon: "web.camera",
                       kind: .toggleWebcam, defaultSide: .right,
                       enableKey: .showMirror))
        register(.init(id: .settings, label: "Settings", icon: "gear",
                       kind: .openSettings, defaultSide: .right, isPinnable: true,
                       enableKey: .settingsIconInNotch))
        register(.init(id: .battery, label: "Battery", icon: "battery.100",
                       kind: .batteryIndicator, defaultSide: .right,
                       enableKey: .showBatteryIndicator))
    }

    // MARK: - Utility panel registrations

    private func registerUtilityPanels() {
        register(.init(id: .notes, label: "Notes", icon: "note.text",
                       kind: .view(.notes), defaultSide: .left,
                       enableKey: .enableNotes))
        register(.init(id: .tasks, label: "Tasks", icon: "checklist",
                       kind: .view(.tasks), defaultSide: .left,
                       enableKey: .enableTasks))
        register(.init(id: .clipboard, label: "Clipboard", icon: "doc.on.clipboard",
                       kind: .view(.clipboard), defaultSide: .right,
                       enableKey: .enableClipboard))
    }
}
