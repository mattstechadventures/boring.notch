//
//  PanelID.swift
//  boringNotch
//
//  Stable identity for every header entry point (tab or right-cluster icon).
//  Used as the persisted key for slot arrangements (see Defaults header* keys)
//  and to look up a PanelDescriptor in the PanelRegistry.
//

import Defaults
import Foundation

/// One identifier per header slot item. Raw values are the persisted form, so
/// **do not rename** existing cases without a migration.
enum PanelID: String, Codable, CaseIterable, Identifiable, Defaults.Serializable {
    // Legacy navigation tabs (left cluster today)
    case home
    case shelf
    case screenshots
    case claudeCode

    // New local utility panels
    case notes
    case clipboard
    case tasks
    case files
    case macros

    // Legacy right-cluster tools / indicators
    case pomodoro
    case focusMusic
    case webcam
    case settings
    case battery

    var id: String { rawValue }
}
