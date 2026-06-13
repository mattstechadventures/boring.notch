//
//  FilesSettings.swift
//  boringNotch
//

import Defaults
import SwiftUI

struct FilesSettings: View {
    @ObservedObject private var vm = FilesViewModel.shared

    var body: some View {
        Form {
            Section {
                Defaults.Toggle(key: .enableFiles) {
                    Text("Enable Files panel")
                }
            } header: {
                Text("General")
            } footer: {
                Text("Pin folders to browse and open their contents from the notch, and drag files in or out. Access uses security-scoped bookmarks.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section {
                if vm.pins.isEmpty {
                    Text("No pinned folders").foregroundStyle(.secondary)
                } else {
                    ForEach(vm.pins) { pin in
                        HStack {
                            Image(systemName: "folder.fill").foregroundStyle(.secondary)
                            Text(pin.displayName)
                            Spacer()
                            Button("Remove", role: .destructive) { vm.remove(pin) }
                                .buttonStyle(.borderless)
                        }
                    }
                }
                Button("Pin a folder…") { vm.addPin() }
            } header: {
                Text("Pinned folders")
            }
        }
        .accentColor(.effectiveAccent)
        .navigationTitle("Files")
    }
}
