//
//  SessionListView.swift
//  boringNotch
//
//  Horizontal scrollable strip of session chips. Default landing on the Claude tab.
//

import SwiftUI
import Defaults

struct SessionListView: View {
    @ObservedObject var manager: ClaudeCodeManager
    let onSelect: (ClaudeSession) -> Void

    @Default(.claudeActiveThresholdMinutes) private var activeMin
    @Default(.claudeRecentThresholdMinutes) private var recentMin
    @Default(.showActiveClaudeSessions) private var showActive
    @Default(.showRecentClaudeSessions) private var showRecent
    @Default(.showIdleClaudeSessions) private var showIdle
    @Default(.claudeSessionGrouping) private var grouping

    @State private var hoveredSessionId: String?

    private var visibleSessions: [ClaudeSession] {
        let now = Date()
        let filtered = manager.availableSessions.filter { session in
            switch session.freshness(now: now,
                                     activeWithin: activeMin * 60,
                                     recentWithin: recentMin * 60) {
            case .active:  return showActive
            case .recent:  return showRecent
            case .idle:    return showIdle
            case .unknown: return showActive
            }
        }

        switch grouping {
        case .byProcess:
            return filtered.sorted { ($0.lastActivity ?? .distantPast) > ($1.lastActivity ?? .distantPast) }
        case .byProject:
            // Keep the freshest session per workspace (so the chip's color reflects
            // the most-active tab in that project)
            var seen: [String: ClaudeSession] = [:]
            for s in filtered {
                let key = s.workspaceKey
                if let existing = seen[key],
                   (existing.lastActivity ?? .distantPast) >= (s.lastActivity ?? .distantPast) {
                    continue
                }
                seen[key] = s
            }
            return Array(seen.values).sorted { ($0.lastActivity ?? .distantPast) > ($1.lastActivity ?? .distantPast) }
        }
    }

    private var hoveredMessage: String? {
        guard let id = hoveredSessionId,
              let msg = manager.sessionStates[id]?.lastMessage,
              !msg.isEmpty else {
            return nil
        }
        return msg
    }

    var body: some View {
        if visibleSessions.isEmpty {
            ClaudeCodeEmptyView(manager: manager)
        } else {
            VStack(spacing: 8) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 14) {
                        ForEach(visibleSessions) { session in
                            SessionChip(session: session,
                                        manager: manager,
                                        activeMin: activeMin,
                                        recentMin: recentMin) {
                                onSelect(session)
                            }
                            .onHover { inside in
                                hoveredSessionId = inside ? session.id : (hoveredSessionId == session.id ? nil : hoveredSessionId)
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                }

                // Preview area: shows hovered session's last message, or a placeholder.
                // Always visible (placeholder when nothing hovered) so layout doesn't shift.
                Group {
                    if let msg = hoveredMessage {
                        Text(msg)
                            .font(.caption)
                            .foregroundColor(.primary.opacity(0.85))
                            .lineLimit(3)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .transition(.opacity)
                    } else {
                        Text(hoveredSessionId == nil
                             ? "Hover a chip to preview"
                             : "No messages yet")
                            .font(.caption2)
                            .foregroundColor(.secondary.opacity(0.6))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .transition(.opacity)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.12))
                )
                .padding(.horizontal, 8)
                .frame(height: 64, alignment: .topLeading)
                .animation(.easeInOut(duration: 0.15), value: hoveredSessionId)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }
}

struct SessionChip: View {
    let session: ClaudeSession
    @ObservedObject var manager: ClaudeCodeManager
    let activeMin: Double
    let recentMin: Double
    let onTap: () -> Void

    private var statusColor: Color {
        // Permission needed always wins
        if manager.sessionStates[session.id]?.needsPermission == true {
            return .orange
        }
        // Currently running tools = green regardless of mtime
        if manager.sessionStates[session.id]?.isActive == true {
            return .green
        }
        // Fall back to JSONL-mtime freshness
        switch session.freshness(now: Date(),
                                 activeWithin: activeMin * 60,
                                 recentWithin: recentMin * 60) {
        case .active:  return .green
        case .recent:  return .yellow
        case .idle:    return .red
        case .unknown: return .gray
        }
    }

    var body: some View {
        VStack(spacing: 6) {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.gray.opacity(0.22))
                    .frame(width: 48, height: 48)
                    .overlay(
                        Image(systemName: ideIcon(for: session.ideName))
                            .font(.system(size: 20))
                            .foregroundColor(.white.opacity(0.9))
                    )

                Circle()
                    .fill(statusColor)
                    .frame(width: 10, height: 10)
                    .overlay(Circle().stroke(Color.black, lineWidth: 1.5))
                    .offset(x: 4, y: -4)
            }
            .contentShape(Rectangle())
            .onTapGesture { onTap() }

            HStack(spacing: 3) {
                Text(session.displayName)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Button {
                    manager.focusSession(session)
                } label: {
                    Image(systemName: "arrow.up.right.circle.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Open this session's terminal/IDE")
            }
            .frame(maxWidth: 96)
        }
        .padding(.horizontal, 4)
    }

    private func ideIcon(for ideName: String) -> String {
        switch ideName.lowercased() {
        case "cursor": return "cursorarrow.rays"
        case "vscode", "visual studio code": return "chevron.left.forwardslash.chevron.right"
        case "xcode": return "hammer.fill"
        case "terminal": return "terminal"
        case "zed": return "z.square"
        case "windsurf": return "wind"
        default: return "laptopcomputer"
        }
    }
}

struct ClaudeCodeEmptyView: View {
    @ObservedObject var manager: ClaudeCodeManager

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "terminal")
                .font(.title3)
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text("No active sessions")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("Start Claude Code to begin")
                    .font(.caption2)
                    .foregroundColor(.secondary.opacity(0.7))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
}

#Preview {
    SessionListView(manager: ClaudeCodeManager.shared) { _ in }
        .frame(width: 600, height: 120)
        .background(Color.black.opacity(0.9))
}
