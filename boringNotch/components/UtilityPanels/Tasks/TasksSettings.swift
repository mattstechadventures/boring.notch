//
//  TasksSettings.swift
//  boringNotch
//

import Defaults
import SwiftUI

struct TasksSettings: View {
    @ObservedObject private var vm = TasksViewModel.shared

    var body: some View {
        Form {
            Section {
                Defaults.Toggle(key: .enableTasks) {
                    Text("Enable Tasks panel")
                }
            } header: {
                Text("General")
            } footer: {
                Text("A plain local checklist — add, tick, clear done. Stored on this Mac only. Connectors (Todoist, Outlook, Scoro) are a future addition.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section {
                HStack {
                    Text("Open tasks")
                    Spacer()
                    Text("\(vm.openCount)").foregroundStyle(.secondary)
                }
                Button("Clear completed") { vm.clearCompleted() }
                    .disabled(!vm.hasCompleted)
            } header: {
                Text("Data")
            }
        }
        .accentColor(.effectiveAccent)
        .navigationTitle("Tasks")
    }
}
