//
//  NotchLayoutSettings.swift
//  boringNotch
//
//  Manage which panels appear in the notch header and how the notch opens.
//  The visual drag-to-slot editor is added on top of these controls.
//

import Defaults
import SwiftUI

struct NotchLayoutSettings: View {
    @ObservedObject private var layout = HeaderLayoutManager.shared

    @Default(.defaultViewPolicy) private var policy
    @Default(.defaultViewFallback) private var fallback
    @Default(.headerLeftElastic) private var leftElastic
    @Default(.headerRightElastic) private var rightElastic
    @Default(.headerLeftMax) private var leftMax
    @Default(.headerRightMax) private var rightMax

    @State private var fixedSelection: PanelID = .home

    private enum DVMode: String, CaseIterable, Identifiable {
        case smart, lastViewed, fixed
        var id: String { rawValue }
        var label: String {
            switch self {
            case .smart: return "Smart"
            case .lastViewed: return "Last viewed"
            case .fixed: return "Specific panel"
            }
        }
    }

    private var viewPanels: [PanelDescriptor] {
        PanelRegistry.shared.all.filter { $0.destination != nil }
    }

    private var mode: Binding<DVMode> {
        Binding(
            get: {
                switch policy {
                case .smart: return .smart
                case .lastViewed: return .lastViewed
                case .fixed: return .fixed
                }
            },
            set: { newMode in
                switch newMode {
                case .smart: policy = .smart
                case .lastViewed: policy = .lastViewed
                case .fixed: policy = .fixed(fixedSelection)
                }
            }
        )
    }

    var body: some View {
        Form {
            Section {
                NotchSlotEditor()
                    .padding(.vertical, 4)
            } header: {
                Text("Arrangement")
            }

            Section {
                Picker("When the notch opens", selection: mode) {
                    ForEach(DVMode.allCases) { Text($0.label).tag($0) }
                }
                if case .fixed = policy {
                    Picker("Open panel", selection: $fixedSelection) {
                        ForEach(viewPanels) { Text($0.label).tag($0.id) }
                    }
                    .onChange(of: fixedSelection) { _, new in policy = .fixed(new) }
                }
                if case .smart = policy {
                    Picker("Fallback panel", selection: $fallback) {
                        ForEach(viewPanels) { Text($0.label).tag($0.id) }
                    }
                }
            } header: {
                Text("Default view")
            } footer: {
                Text("Smart opens Focus Music while it's playing, then Shelf when it has items, otherwise the fallback. Last viewed reopens the panel you closed on.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section {
                sideControls(title: "Left", elastic: $leftElastic, max: $leftMax,
                             capacity: layout.capacity(for: .left))
                sideControls(title: "Right", elastic: $rightElastic, max: $rightMax,
                             capacity: layout.capacity(for: .right))
            } header: {
                Text("Header sides")
            } footer: {
                Text("Elastic padding spreads icons out to fill a side. Max slots caps how many icons show (Auto uses everything that fits the notch on this display).")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .accentColor(.effectiveAccent)
        .navigationTitle("Notch Layout")
        .onAppear {
            if case let .fixed(id) = policy { fixedSelection = id }
        }
    }

    @ViewBuilder
    private func sideControls(title: String, elastic: Binding<Bool>, max: Binding<Int>, capacity: Int) -> some View {
        Toggle("\(title): elastic padding", isOn: elastic)
        Stepper(value: max, in: 0...12, step: 1) {
            HStack {
                Text("\(title): max slots")
                Spacer()
                Text(max.wrappedValue == 0 ? "Auto (fits \(capacity))" : "\(max.wrappedValue)")
                    .foregroundStyle(.secondary)
            }
        }
    }
}
