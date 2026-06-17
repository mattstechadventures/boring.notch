//
//  MacrosViewModel.swift
//  boringNotch
//
//  @MainActor singleton over a CodableFileStore<MacroItem>. Owns the persisted
//  macro list (order is significant — it's the user's arrangement) and the
//  transient per-macro run state fed by the XPC helper's streaming callbacks.
//

import SwiftUI

@MainActor
final class MacrosViewModel: ObservableObject {
    static let shared = MacrosViewModel()

    @Published private(set) var macros: [MacroItem] = []
    /// Most recent run per macro id. Absent = never run / cleared (idle).
    @Published private(set) var runs: [UUID: MacroRun] = [:]

    /// Cap on retained output per run so a chatty/never-ending command can't grow
    /// unbounded; we keep the most recent slice. `trimSlack` is hysteresis so a
    /// streaming command doesn't re-`suffix` the whole string on every chunk.
    private static let maxOutputChars = 100_000
    private static let trimSlack = 20_000

    /// runID -> macro id, so streamed callbacks can find their row.
    private var runIDToMacro: [UUID: UUID] = [:]

    private let store = CodableFileStore<MacroItem>(subdirectory: "Macros", filename: "macros.json")

    private init() {
        macros = store.load()
    }

    // MARK: - CRUD

    func add(_ macro: MacroItem) {
        macros.append(macro)
        persist()
    }

    func update(_ macro: MacroItem) {
        guard let idx = macros.firstIndex(where: { $0.id == macro.id }) else { return }
        macros[idx] = macro
        persist()
    }

    func delete(_ macro: MacroItem) {
        macros.removeAll { $0.id == macro.id }
        runs[macro.id] = nil
        runIDToMacro = runIDToMacro.filter { $0.value != macro.id }
        persist()
    }

    func delete(atOffsets offsets: IndexSet) {
        let ids = Set(offsets.map { macros[$0].id })
        for id in ids { runs[id] = nil }
        runIDToMacro = runIDToMacro.filter { !ids.contains($0.value) }
        macros.remove(atOffsets: offsets)
        persist()
    }

    func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        macros.move(fromOffsets: source, toOffset: destination)
        persist()
    }

    private func persist() {
        store.save(macros)
    }

    // MARK: - Running

    func run(_ macro: MacroItem) {
        guard macro.hasRunnableCommand else { return }
        // Drop any prior run mapping for this macro so a fresh run is the only
        // one its id resolves to.
        runIDToMacro = runIDToMacro.filter { $0.value != macro.id }
        let runID = UUID()
        runIDToMacro[runID] = macro.id
        runs[macro.id] = MacroRun(runID: runID, status: .running)
        XPCHelperClient.shared.runMacro(runID: runID.uuidString,
                                        command: macro.command,
                                        workingDirectory: macro.workingDirectory)
    }

    func cancel(_ macro: MacroItem) {
        guard var run = runs[macro.id], run.status == .running else { return }
        run.cancelled = true
        runs[macro.id] = run
        XPCHelperClient.shared.cancelMacro(runID: run.runID.uuidString)
    }

    func isRunning(_ macro: MacroItem) -> Bool {
        runs[macro.id]?.status == .running
    }

    // MARK: - Streaming callbacks (invoked on the main actor by MacroRunnerClient)

    func appendOutput(runID rawRunID: String, data: Data, isStderr: Bool) {
        guard let (macroID, _) = liveRun(for: rawRunID) else { return }
        var run = runs[macroID]!
        let text = isStderr
            ? Self.decodeIncremental(&run.stderrPending, appending: data)
            : Self.decodeIncremental(&run.stdoutPending, appending: data)
        if isStderr && !data.isEmpty { run.sawStderr = true }
        if !text.isEmpty {
            run.output += text
            if run.output.count > Self.maxOutputChars + Self.trimSlack {
                run.output = "…" + String(run.output.suffix(Self.maxOutputChars))
            }
        }
        runs[macroID] = run
    }

    func finish(runID rawRunID: String, exitCode: Int) {
        guard let (macroID, _) = liveRun(for: rawRunID) else { return }
        var run = runs[macroID]!
        run.output += Self.flush(&run.stdoutPending) + Self.flush(&run.stderrPending)
        run.exitCode = exitCode
        if run.cancelled {
            run.status = .idle
            run.output += (run.output.isEmpty ? "" : "\n") + "■ Stopped"
        } else if exitCode != 0 {
            run.status = .error
        } else if run.sawStderr {
            run.status = .warning
        } else {
            run.status = .success
        }
        run.seen = false
        runs[macroID] = run
    }

    func fail(runID rawRunID: String, message: String) {
        guard let (macroID, _) = liveRun(for: rawRunID) else { return }
        var run = runs[macroID]!
        run.output += Self.flush(&run.stdoutPending) + Self.flush(&run.stderrPending)
        if run.cancelled {
            run.status = .idle
            run.output += (run.output.isEmpty ? "" : "\n") + "■ Stopped"
        } else {
            run.output += (run.output.isEmpty ? "" : "\n") + "⚠︎ " + message
            run.status = .error
        }
        runs[macroID] = run
    }

    /// The XPC connection dropped — any still-"running" macros will never report
    /// back, so surface that rather than leaving rows stuck on blue.
    func markRunningAsDisconnected() {
        for (macroID, var run) in runs where run.status == .running {
            run.output += (run.output.isEmpty ? "" : "\n") + "⚠︎ helper disconnected"
            run.status = .error
            runs[macroID] = run
        }
        runIDToMacro.removeAll()
    }

    /// Called when the Macros panel appears: a completed (green) run, once seen,
    /// fades its status back to blank after a moment. Output is retained.
    func markSeen() {
        for (macroID, var run) in runs where run.status == .success && !run.seen {
            run.seen = true
            runs[macroID] = run
            let seenRunID = run.runID
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(2))
                guard var current = self.runs[macroID],
                      current.runID == seenRunID,
                      current.status == .success else { return }
                current.status = .idle
                self.runs[macroID] = current
            }
        }
    }

    /// Resolve a raw runID to its macro, but only while that run is still the
    /// macro's current one — drops stale callbacks from a superseded run.
    private func liveRun(for rawRunID: String) -> (macroID: UUID, runID: UUID)? {
        guard let runID = UUID(uuidString: rawRunID),
              let macroID = runIDToMacro[runID],
              let run = runs[macroID], run.runID == runID else { return nil }
        return (macroID, runID)
    }

    /// Append `chunk` to `pending` and return the longest validly-decodable UTF-8
    /// prefix, leaving any trailing bytes of an incomplete character in `pending`
    /// for the next chunk. Falls back to a lossy decode if the data is malformed
    /// beyond a simple boundary split (keeps `pending` bounded).
    private static func decodeIncremental(_ pending: inout Data, appending chunk: Data) -> String {
        if !chunk.isEmpty { pending.append(chunk) }
        guard !pending.isEmpty else { return "" }
        // A UTF-8 character is at most 4 bytes, so trimming up to 3 trailing bytes
        // recovers any boundary split.
        for drop in 0...min(3, pending.count) {
            let end = pending.count - drop
            if let s = String(data: pending.prefix(end), encoding: .utf8) {
                pending = Data(pending.suffix(from: end))
                return s
            }
        }
        let s = String(decoding: pending, as: UTF8.self)
        pending.removeAll(keepingCapacity: true)
        return s
    }

    /// Lossily decode and clear whatever residual bytes remain at end of stream.
    private static func flush(_ pending: inout Data) -> String {
        guard !pending.isEmpty else { return "" }
        let s = String(decoding: pending, as: UTF8.self)
        pending.removeAll(keepingCapacity: true)
        return s
    }
}
