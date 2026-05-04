//
//  SessionListView.swift
//  boringNotch
//
//  Horizontal scrollable strip of session chips. Default landing on the Claude tab.
//

import SwiftUI

struct SessionListView: View {
    @ObservedObject var manager: ClaudeCodeManager
    let onSelect: (ClaudeSession) -> Void

    var body: some View {
        if manager.availableSessions.isEmpty {
            ClaudeCodeEmptyView(manager: manager)
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 14) {
                    ForEach(manager.availableSessions) { session in
                        SessionChip(session: session, manager: manager) {
                            onSelect(session)
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }
}

struct SessionChip: View {
    let session: ClaudeSession
    @ObservedObject var manager: ClaudeCodeManager
    let onTap: () -> Void

    private var statusColor: Color {
        guard let state = manager.sessionStates[session.id] else { return .gray }
        if state.needsPermission { return .orange }
        if state.isActive { return .green }
        return .gray
    }

    var body: some View {
        Button(action: onTap) {
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

                Text(session.displayName)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: 80)
            }
            .padding(.horizontal, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
