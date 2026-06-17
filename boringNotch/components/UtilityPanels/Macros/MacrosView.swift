//
//  MacrosView.swift
//  boringNotch
//
//  Macros panel: a list of one-tap shell commands. Each row shows just a label
//  and a status dot (blank=idle, blue=running, green=done, amber=warning,
//  red=error) and expands to a live-streaming output pane. "+ Add Macro" adds
//  one inline; richer management (edit/reorder/delete) lives in Settings.
//

import AppKit
import SwiftUI

struct MacrosView: View {
    @ObservedObject private var vm = MacrosViewModel.shared

    @State private var expanded: Set<UUID> = []
    @State private var showingAdd = false
    @State private var draftLabel = ""
    @State private var draftCommand = ""
    @State private var draftDir = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            header

            if vm.macros.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(spacing: 4) {
                        ForEach(vm.macros) { macro in
                            row(for: macro)
                        }
                    }
                }
            }

            if showingAdd {
                addForm
            } else {
                addButton
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .onAppear { vm.markSeen() }
    }

    private var header: some View {
        HStack {
            Text("Macros").font(.headline)
            if !vm.macros.isEmpty {
                Text("\(vm.macros.count)")
                    .font(.caption2).foregroundStyle(.secondary)
                    .padding(.horizontal, 6).padding(.vertical, 1)
                    .background(Capsule().fill(Color.secondary.opacity(0.2)))
            }
            Spacer()
        }
    }

    private var emptyState: some View {
        VStack {
            Spacer(minLength: 0)
            Text("No macros yet").font(.caption).foregroundStyle(.secondary)
            Text("Add a shell command to run it from here.")
                .font(.caption2).foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
    }

    private func row(for macro: MacroItem) -> some View {
        let run = vm.runs[macro.id]
        let status = run?.status ?? .idle
        let hasOutput = !(run?.output ?? "").isEmpty
        let isOpen = expanded.contains(macro.id)

        return VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: macro.displayIcon)
                    .font(.callout).foregroundStyle(.secondary).frame(width: 18)

                Text(macro.displayLabel)
                    .font(.callout).lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)

                statusDot(status)

                if status == .running {
                    Button { vm.cancel(macro) } label: {
                        Image(systemName: "stop.fill").font(.caption2)
                    }
                    .buttonStyle(.plain).foregroundStyle(.secondary)
                    .help("Stop")
                } else {
                    Button {
                        vm.run(macro)
                        expanded.insert(macro.id)
                    } label: {
                        Image(systemName: "play.fill").font(.caption2)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(macro.hasRunnableCommand ? Color.accentColor : Color.secondary)
                    .disabled(!macro.hasRunnableCommand)
                    .help("Run")
                }

                Button {
                    if isOpen { expanded.remove(macro.id) } else { expanded.insert(macro.id) }
                } label: {
                    Image(systemName: isOpen ? "chevron.down" : "chevron.right")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .opacity(hasOutput ? 1 : 0.25)
                .disabled(!hasOutput)
            }
            .padding(.vertical, 5).padding(.horizontal, 8)

            if isOpen, let output = run?.output, !output.isEmpty {
                outputPane(output)
                    .padding(.horizontal, 8).padding(.bottom, 6)
            }
        }
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.06)))
    }

    private func statusDot(_ status: MacroRunStatus) -> some View {
        Circle()
            .fill(color(for: status))
            .frame(width: 9, height: 9)
            .overlay {
                if status == .idle {
                    Circle().strokeBorder(Color.white.opacity(0.25), lineWidth: 1)
                }
            }
            .help(helpText(for: status))
    }

    private func color(for status: MacroRunStatus) -> Color {
        switch status {
        case .idle: return .clear
        case .running: return .blue
        case .success: return .green
        case .warning: return .orange
        case .error: return .red
        }
    }

    private func helpText(for status: MacroRunStatus) -> String {
        switch status {
        case .idle: return "Idle"
        case .running: return "Running…"
        case .success: return "Completed"
        case .warning: return "Completed with warnings"
        case .error: return "Failed"
        }
    }

    private func outputPane(_ output: String) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text(output)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Color.clear.frame(height: 1).id(Self.outputBottomID)
                }
            }
            .frame(maxHeight: 140)
            .background(RoundedRectangle(cornerRadius: 6).fill(Color.black.opacity(0.25)))
            .onChange(of: output) { _, _ in
                proxy.scrollTo(Self.outputBottomID, anchor: .bottom)
            }
            .onAppear { proxy.scrollTo(Self.outputBottomID, anchor: .bottom) }
        }
    }

    private static let outputBottomID = "macro-output-bottom"

    // MARK: - Add

    private var addButton: some View {
        Button { showingAdd = true } label: {
            HStack(spacing: 4) {
                Image(systemName: "plus")
                Text("Add Macro")
            }
            .font(.callout)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.06)))
        }
        .buttonStyle(.plain)
    }

    private var addForm: some View {
        VStack(spacing: 6) {
            TextField("Label", text: $draftLabel)
                .textFieldStyle(.plain)
            TextField("Command (e.g. python3 pin_grab.py)", text: $draftCommand, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(.callout, design: .monospaced))
                .lineLimit(1...3)
            HStack(spacing: 6) {
                Button { chooseDir() } label: {
                    Image(systemName: "folder")
                    Text(draftDir.isEmpty ? "Working folder" : abbreviate(draftDir))
                        .lineLimit(1)
                }
                .buttonStyle(.plain).font(.caption).foregroundStyle(.secondary)
                if !draftDir.isEmpty {
                    Button { draftDir = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                    }
                    .buttonStyle(.plain).font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Cancel") { resetDraft() }
                    .buttonStyle(.plain).font(.caption).foregroundStyle(.secondary)
                Button("Add") { commitAdd() }
                    .buttonStyle(.plain).font(.caption.weight(.semibold))
                    .foregroundStyle(draftCommand.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.secondary : Color.accentColor)
                    .disabled(draftCommand.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.06)))
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
            draftDir = url.path
        }
    }

    private func commitAdd() {
        let command = draftCommand.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !command.isEmpty else { return }
        vm.add(MacroItem(label: draftLabel.trimmingCharacters(in: .whitespacesAndNewlines),
                         command: command,
                         workingDirectory: draftDir))
        resetDraft()
    }

    private func resetDraft() {
        draftLabel = ""
        draftCommand = ""
        draftDir = ""
        showingAdd = false
    }

    private func abbreviate(_ path: String) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let shortened = path.hasPrefix(home) ? "~" + path.dropFirst(home.count) : path
        return URL(fileURLWithPath: shortened).lastPathComponent.isEmpty ? shortened : (shortened as NSString).lastPathComponent
    }
}
