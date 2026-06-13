//
//  NotesSettings.swift
//  boringNotch
//

import Defaults
import SwiftUI

struct NotesSettings: View {
    @ObservedObject private var vm = NotesViewModel.shared

    var body: some View {
        Form {
            Section {
                Defaults.Toggle(key: .enableNotes) {
                    Text("Enable Notes panel")
                }
            } header: {
                Text("General")
            } footer: {
                Text("A quick local scratchpad. Titles are taken from the first line and can be renamed. Stored on this Mac only.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section {
                HStack {
                    Text("Saved notes")
                    Spacer()
                    Text("\(vm.notes.count)").foregroundStyle(.secondary)
                }
                Button("Delete all notes", role: .destructive) { vm.deleteAll() }
                    .disabled(vm.notes.isEmpty)
            } header: {
                Text("Data")
            }
        }
        .accentColor(.effectiveAccent)
        .navigationTitle("Notes")
    }
}
