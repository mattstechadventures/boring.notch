//
//  ClaudeProcessScanner.swift
//  boringNotch
//
//  Enumerates running `claude` binary processes via sysctl(KERN_PROC_ALL) and
//  per-pid libproc calls. Used to determine which sessions are alive (process
//  running) vs ended (process gone), independent of JSONL mtime activity.
//  Catches idle terminal sessions sitting at the prompt.
//
//  Note: proc_listpids() returns 0 in sandboxed apps. sysctl(KERN_PROC_ALL)
//  works because the existing isProcessRunning() check already uses sysctl
//  with KERN_PROC_PID, and the same path is permitted for KERN_PROC_ALL.
//

import Foundation
import Darwin

struct RunningClaudeProcess: Equatable {
    let pid: Int32
    let path: String
    let cwd: String
    let ideName: String
}

enum ClaudeProcessScanner {
    /// Enumerate every running `claude` process with its cwd + IDE label.
    static func runningClaudeProcesses() -> [RunningClaudeProcess] {
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0]
        var bufSize = 0
        guard sysctl(&mib, UInt32(mib.count), nil, &bufSize, nil, 0) == 0, bufSize > 0 else {
            return []
        }

        // Slight overshoot for race-safety — process list may grow between calls
        bufSize += MemoryLayout<kinfo_proc>.size * 32
        let bufCapacity = bufSize / MemoryLayout<kinfo_proc>.size
        var procs = [kinfo_proc](repeating: kinfo_proc(), count: bufCapacity)
        let result = procs.withUnsafeMutableBufferPointer { buf -> Int32 in
            sysctl(&mib, UInt32(mib.count), buf.baseAddress, &bufSize, nil, 0)
        }
        guard result == 0 else { return [] }
        let valid = bufSize / MemoryLayout<kinfo_proc>.size

        var results: [RunningClaudeProcess] = []
        for i in 0..<valid {
            let pid = procs[i].kp_proc.p_pid
            guard pid > 0 else { continue }

            // Cheap kernel-supplied "command name" (16-char max). Skip the 99% of
            // processes that aren't claude before doing more expensive lookups.
            let comm = withUnsafeBytes(of: &procs[i].kp_proc.p_comm) { raw -> String in
                guard let base = raw.bindMemory(to: CChar.self).baseAddress else { return "" }
                return String(cString: base)
            }
            // Match: comm is "claude" OR a version string like "2.1.126" (the user's
            // CLI install symlinks to a versioned binary, so comm shows the version).
            let isVersionLike = comm.first.map(\.isNumber) == true && comm.contains(".")
            guard comm == "claude" || isVersionLike else { continue }

            // Resolve full binary path (works in sandbox for individual pids)
            var pathBuf = [CChar](repeating: 0, count: Int(MAXPATHLEN))
            let pathLen = proc_pidpath(pid, &pathBuf, UInt32(MAXPATHLEN))
            let path = pathLen > 0 ? String(cString: pathBuf) : ""

            // Validate path if we have one. Accept by comm-match alone otherwise.
            if !path.isEmpty {
                // Skip Claude Desktop's bundled claude — different session model
                // (~/Library/Application Support/Claude/local-agent-mode-sessions),
                // not the ~/.claude/projects/ JSONLs we're tracking.
                let lower = path.lowercased()
                if lower.contains("/applications/claude.app/")
                    || lower.contains("/claude.app/contents/")
                    || lower.contains("/library/application support/claude/")
                {
                    continue
                }

                let lastComponent = (path as NSString).lastPathComponent
                let pathLooksLikeClaude = lastComponent == "claude"
                    || path.contains("/.local/share/claude/versions/")
                    || path.contains("/claude/versions/")
                guard pathLooksLikeClaude else { continue }
            }

            guard let cwd = currentDirectory(forPID: pid), !cwd.isEmpty else { continue }

            // Also skip Claude Desktop sessions caught only via cwd
            if cwd.contains("/Library/Application Support/Claude/local-agent-mode-sessions/") {
                continue
            }

            results.append(RunningClaudeProcess(
                pid: pid,
                path: path,
                cwd: cwd,
                ideName: inferIDE(from: path)
            ))
        }

        return results
    }

    private static func inferIDE(from path: String) -> String {
        if path.contains("/anthropic.claude-code-") || path.contains("/.antigravity/") {
            return "Antigravity"
        }
        if path.contains("/Cursor.app/") {
            return "Cursor"
        }
        if path.contains("/Visual Studio Code.app/") || path.contains("/Code.app/") {
            return "VSCode"
        }
        if path.contains("/Zed.app/") {
            return "Zed"
        }
        if path.contains("/Windsurf.app/") {
            return "Windsurf"
        }
        return "Terminal"
    }

    private static func currentDirectory(forPID pid: pid_t) -> String? {
        var info = proc_vnodepathinfo()
        let size = MemoryLayout<proc_vnodepathinfo>.size
        let bytes = withUnsafeMutablePointer(to: &info) { ptr -> Int32 in
            proc_pidinfo(pid, PROC_PIDVNODEPATHINFO, 0, ptr, Int32(size))
        }
        guard Int(bytes) == size else { return nil }

        return withUnsafeBytes(of: &info.pvi_cdir.vip_path) { raw -> String? in
            guard let base = raw.bindMemory(to: CChar.self).baseAddress else { return nil }
            return String(cString: base)
        }
    }
}
