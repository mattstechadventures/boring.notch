//
//  DefaultViewPolicy.swift
//  boringNotch
//
//  Unifies what view the notch shows when it opens. Replaces the scattered
//  focusMusicAutoOpenTab / openShelfByDefault / openLastTabByDefault behaviours
//  with one policy. The old toggles still apply — they gate the `.smart`
//  active-context checks — so there is no behaviour regression.
//

import Defaults
import Foundation

enum DefaultViewPolicy: Codable, Defaults.Serializable, Equatable {
    /// Always open a chosen panel.
    case fixed(PanelID)
    /// Restore whatever panel was open last.
    case lastViewed
    /// Open the highest-priority panel with active context (e.g. Focus Music
    /// while playing, Shelf when it has items), else the fallback panel.
    case smart
}

extension DefaultViewPolicy {
    /// The view to show on open, or nil to leave the current view unchanged.
    @MainActor
    func resolve() -> NotchViews? {
        let registry = PanelRegistry.shared
        switch self {
        case let .fixed(id):
            return registry.descriptor(for: id)?.destination

        case .lastViewed:
            return registry.descriptor(for: Defaults[.lastView])?.destination

        case .smart:
            let candidates = registry.all
                .filter { $0.isEnabled && $0.isActiveContext() }
                .sorted { $0.contextPriority > $1.contextPriority }
            if let view = candidates.first?.destination {
                return view
            }
            return registry.descriptor(for: Defaults[.defaultViewFallback])?.destination
        }
    }
}
