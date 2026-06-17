//
//  MacroItem.swift
//  boringNotch
//
//  A single user-defined macro: a labelled shell command run on demand from the
//  notch. The command is executed by the unsandboxed XPC helper (the app itself
//  is sandboxed and cannot spawn arbitrary scripts), in `workingDirectory`.
//

import Foundation

struct MacroItem: Identifiable, Codable, Equatable {
    let id: UUID
    var label: String
    /// SF Symbol name shown beside the label.
    var icon: String
    /// Shell command, run via `/bin/zsh -lc` in the helper.
    var command: String
    /// Directory the command runs in (may be empty or contain `~`; empty = home).
    var workingDirectory: String
    var createdAt: Date

    init(id: UUID = UUID(),
         label: String = "",
         icon: String = "terminal",
         command: String = "",
         workingDirectory: String = "",
         createdAt: Date = Date()) {
        self.id = id
        self.label = label
        self.icon = icon
        self.command = command
        self.workingDirectory = workingDirectory
        self.createdAt = createdAt
    }

    var displayLabel: String {
        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Untitled macro" : trimmed
    }

    var displayIcon: String {
        icon.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "terminal" : icon
    }

    var hasRunnableCommand: Bool {
        !command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private enum CodingKeys: String, CodingKey {
        case id, label, icon, command, workingDirectory, createdAt
    }

    // Tolerant decode so adding fields later never wipes saved macros.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        label = try c.decodeIfPresent(String.self, forKey: .label) ?? ""
        icon = try c.decodeIfPresent(String.self, forKey: .icon) ?? "terminal"
        command = try c.decodeIfPresent(String.self, forKey: .command) ?? ""
        workingDirectory = try c.decodeIfPresent(String.self, forKey: .workingDirectory) ?? ""
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
    }
}

/// Live status of a macro's most recent run. Drives the row's status dot.
enum MacroRunStatus: Equatable {
    case idle
    case running
    case success
    case warning
    case error
}

/// Transient (non-persisted) state for the most recent run of a macro.
struct MacroRun: Equatable {
    var runID: UUID
    var status: MacroRunStatus
    var output: String = ""
    var exitCode: Int? = nil
    /// Whether any bytes arrived on stderr (drives the amber "warning" status).
    var sawStderr: Bool = false
    /// Whether a finished (green) run has been shown to the user yet.
    var seen: Bool = false
    /// Set when the user hit Stop, so the result is shown as stopped rather than
    /// success/error (a SIGTERM'd process's exit code is unreliable).
    var cancelled: Bool = false
    /// Residual bytes from a UTF-8 sequence split across XPC chunk boundaries,
    /// held per stream until the next chunk completes the character.
    var stdoutPending: Data = Data()
    var stderrPending: Data = Data()
}
