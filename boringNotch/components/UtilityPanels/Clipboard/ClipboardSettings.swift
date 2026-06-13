//
//  ClipboardSettings.swift
//  boringNotch
//

import Defaults
import SwiftUI

struct ClipboardSettings: View {
    @ObservedObject private var manager = ClipboardManager.shared
    @Default(.clipboardHistoryLimit) var historyLimit

    var body: some View {
        Form {
            Section {
                Defaults.Toggle(key: .enableClipboard) {
                    Text("Enable Clipboard history")
                }
            } header: {
                Text("General")
            } footer: {
                Text("Records what you copy so you can paste it again. Password-manager and transient items are ignored. Text and links are saved across launches; images are kept for the session only.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section {
                Stepper(value: $historyLimit, in: 5...200, step: 5) {
                    HStack {
                        Text("History limit")
                        Spacer()
                        Text("\(historyLimit) items").foregroundStyle(.secondary)
                    }
                }
                Button("Clear all", role: .destructive) { manager.clearAll() }
                    .disabled(manager.items.isEmpty)
            } header: {
                Text("History")
            }
        }
        .accentColor(.effectiveAccent)
        .navigationTitle("Clipboard")
    }
}
