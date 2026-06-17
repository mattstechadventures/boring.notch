//
//  MacrosSettings.swift
//  boringNotch
//

import AppKit
import Defaults
import SwiftUI

struct MacrosSettings: View {
    @ObservedObject private var vm = MacrosViewModel.shared
    @State private var editing: MacroItem?
    @State private var editingIsNew = false

    var body: some View {
        Form {
            Section {
                Defaults.Toggle(key: .enableMacros) {
                    Text("Enable Macros panel")
                }
            } header: {
                Text("General")
            } footer: {
                Text("Run your own shell commands from the notch. Commands run through a local helper outside the app sandbox, with your user's permissions, in the working folder you choose — so only add commands you trust. The first command that controls another app (e.g. Safari) will trigger a one-time macOS Automation prompt.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section {
                List {
                    ForEach(vm.macros) { macro in
                        Button {
                            editingIsNew = false
                            editing = macro
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: macro.displayIcon)
                                    .foregroundStyle(.secondary).frame(width: 18)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(macro.displayLabel)
                                    Text(macro.command.isEmpty ? "No command" : macro.command)
                                        .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                                }
                                Spacer(minLength: 0)
                                Image(systemName: "pencil").foregroundStyle(.secondary)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    .onMove { vm.move(fromOffsets: $0, toOffset: $1) }
                    .onDelete { vm.delete(atOffsets: $0) }
                }
                .frame(minHeight: 120)
                .overlay {
                    if vm.macros.isEmpty {
                        Text("No macros")
                            .foregroundStyle(Color(.secondaryLabelColor))
                    }
                }

                Button {
                    editingIsNew = true
                    editing = MacroItem()
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "plus")
                        Text("Add macro")
                    }
                    .foregroundStyle(.secondary)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            } header: {
                HStack(spacing: 0) {
                    Text("Macros")
                    if !vm.macros.isEmpty {
                        Text(" – \(vm.macros.count)").foregroundStyle(.secondary)
                    }
                }
            } footer: {
                Text("Tap a macro to edit its label, icon, command and working folder. Drag to reorder; swipe to delete.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .accentColor(.effectiveAccent)
        .navigationTitle("Macros")
        .sheet(item: $editing) { macro in
            MacroEditSheet(macro: macro, isNew: editingIsNew) { result in
                if editingIsNew { vm.add(result) } else { vm.update(result) }
            }
        }
    }
}

private struct MacroEditSheet: View {
    @State var macro: MacroItem
    let isNew: Bool
    let onSave: (MacroItem) -> Void
    @Environment(\.dismiss) private var dismiss

    private var canSave: Bool {
        !macro.command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(isNew ? "Add macro" : "Edit macro")
                .font(.largeTitle.bold())

            TextField("Label (e.g. Grab Pinterest pins)", text: $macro.label)

            HStack {
                Image(systemName: macro.displayIcon)
                    .frame(width: 22)
                    .foregroundStyle(.secondary)
                TextField("SF Symbol name (e.g. terminal)", text: $macro.icon)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Command").font(.caption).foregroundStyle(.secondary)
                TextEditor(text: $macro.command)
                    .font(.system(.body, design: .monospaced))
                    .frame(height: 80)
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.secondary.opacity(0.3)))
                Text("Runs via /bin/zsh in the working folder below.")
                    .font(.caption2).foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                Button("Choose folder…") { chooseDir() }
                Text(macro.workingDirectory.isEmpty ? "Home folder" : macro.workingDirectory)
                    .font(.caption2).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                if !macro.workingDirectory.isEmpty {
                    Button { macro.workingDirectory = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                    }
                    .buttonStyle(.plain).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }

            HStack {
                Button("Cancel") { dismiss() }
                    .frame(maxWidth: .infinity)
                Button(isNew ? "Add" : "Save") {
                    onSave(macro)
                    dismiss()
                }
                .frame(maxWidth: .infinity)
                .buttonStyle(.borderedProminent)
                .disabled(!canSave)
            }
            .padding(.top, 4)
        }
        .textFieldStyle(.roundedBorder)
        .padding()
        .frame(width: 440)
    }

    private func chooseDir() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.title = "Choose working folder"
        panel.prompt = "Choose"
        if panel.runModal() == .OK, let url = panel.url {
            macro.workingDirectory = url.path
        }
    }
}
