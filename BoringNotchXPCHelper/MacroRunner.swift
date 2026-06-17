//
//  MacroRunner.swift
//  BoringNotchXPCHelper
//
//  Runs a macro's shell command as a child process (the helper is unsandboxed,
//  so it can exec scripts, read the user's home, drive other apps via Apple
//  Events, etc.) and streams stdout/stderr back to the app over XPC.
//

import Foundation
import os

final class MacroRunner {
    private static let log = Logger(subsystem: "theboringteam.boringnotch.BoringNotchXPCHelper",
                                    category: "MacroRunner")
    private static let maxCommandLength = 100_000

    private let lock = NSLock()
    /// runID -> live process, for cancellation.
    private var processes: [String: Process] = [:]

    /// Per-run completion bookkeeping, guarded by `lock`. We finish a run only
    /// once the process has exited AND both pipes have reported EOF, so no
    /// output is lost and the two reader queues never race the termination path.
    private final class RunState {
        var stdoutDone = false
        var stderrDone = false
        var exited = false
        var exitCode: Int32 = 0
        var finished = false
    }

    private enum RunEvent {
        case stdoutEOF
        case stderrEOF
        case exited(Int32)
    }

    func run(runID: String, command: String, workingDirectory: String,
             client: MacroRunnerClientProtocol) {
        guard command.count <= Self.maxCommandLength else {
            client.didFail(runID: runID, message: "Command is too long to run.")
            return
        }

        // Resolve the working directory (helper is unsandboxed → real user access).
        let trimmedDir = workingDirectory.trimmingCharacters(in: .whitespacesAndNewlines)
        let dirURL = trimmedDir.isEmpty
            ? FileManager.default.homeDirectoryForCurrentUser
            : URL(fileURLWithPath: (trimmedDir as NSString).expandingTildeInPath)
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: dirURL.path, isDirectory: &isDir), isDir.boolValue else {
            client.didFail(runID: runID, message: "Working folder not found: \(dirURL.path)")
            return
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        // -l: login shell so the user's PATH is present (python3 etc. resolve).
        // -c: run the command string; ~ and globs are expanded by zsh.
        process.arguments = ["-lc", command]
        process.currentDirectoryURL = dirURL

        // Audit trail without leaking the (possibly secret-bearing) command text.
        Self.log.info("run \(runID, privacy: .public): \(command.count, privacy: .public) chars in \(dirURL.path, privacy: .public)")

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        let state = RunState()

        stdoutPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if data.isEmpty {
                handle.readabilityHandler = nil
                self?.update(runID: runID, state: state, event: .stdoutEOF, client: client)
            } else {
                client.didReceiveOutput(runID: runID, chunk: data, isStderr: false)
            }
        }
        stderrPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if data.isEmpty {
                handle.readabilityHandler = nil
                self?.update(runID: runID, state: state, event: .stderrEOF, client: client)
            } else {
                client.didReceiveOutput(runID: runID, chunk: data, isStderr: true)
            }
        }

        process.terminationHandler = { [weak self] proc in
            self?.update(runID: runID, state: state, event: .exited(proc.terminationStatus), client: client)
        }

        lock.lock(); processes[runID] = process; lock.unlock()

        do {
            try process.run()
        } catch {
            stdoutPipe.fileHandleForReading.readabilityHandler = nil
            stderrPipe.fileHandleForReading.readabilityHandler = nil
            lock.lock(); processes[runID] = nil; lock.unlock()
            client.didFail(runID: runID, message: error.localizedDescription)
        }
    }

    func cancel(runID: String) {
        lock.lock(); let process = processes[runID]; lock.unlock()
        process?.terminate()
    }

    /// Terminate every running child — used when the app's connection drops so we
    /// don't leave orphaned processes running unsupervised.
    func cancelAll() {
        lock.lock(); let all = Array(processes.values); lock.unlock()
        for process in all { process.terminate() }
    }

    /// Records a lifecycle event and, once the process has exited and both pipes
    /// are drained, reports completion exactly once. `didFinish` is sent outside
    /// the lock.
    private func update(runID: String, state: RunState, event: RunEvent,
                        client: MacroRunnerClientProtocol) {
        lock.lock()
        switch event {
        case .stdoutEOF: state.stdoutDone = true
        case .stderrEOF: state.stderrDone = true
        case .exited(let code): state.exited = true; state.exitCode = code
        }
        let shouldFinish = state.exited && state.stdoutDone && state.stderrDone && !state.finished
        if shouldFinish {
            state.finished = true
            processes[runID] = nil
        }
        lock.unlock()

        if shouldFinish {
            client.didFinish(runID: runID, exitCode: Int(state.exitCode))
        }
    }
}
