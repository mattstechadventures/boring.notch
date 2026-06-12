//
//  PomodoroView.swift
//  boringNotch
//
//  Expanded notch view for the Pomodoro timer + coffee break.
//

import Defaults
import SwiftUI

struct PomodoroView: View {
    @ObservedObject private var manager = PomodoroManager.shared

    private var isBreak: Bool { manager.phase == .breakTime }

    var body: some View {
        VStack(spacing: 14) {
            // Phase + countdown
            VStack(spacing: 2) {
                if isBreak {
                    GeometryReader { geo in
                        MarqueeText(
                            .constant("☕ \(manager.phaseLabel.uppercased())"),
                            font: .system(size: 13, weight: .semibold, design: .monospaced),
                            textColor: .orange,
                            minDuration: 4,
                            frameWidth: geo.size.width
                        )
                    }
                    .frame(height: 16)
                } else {
                    Text(manager.phaseLabel.uppercased())
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                        .tracking(2)
                }

                Text(manager.formattedTimeRemaining)
                    .font(.system(size: 40, weight: .medium, design: .monospaced))
                    .foregroundStyle(isBreak ? .orange : .white)
                    .contentTransition(.numericText())
            }

            // Controls
            HStack(spacing: 16) {
                CircleControl(
                    icon: manager.isRunning ? "pause.fill" : "play.fill",
                    tint: isBreak ? .orange : .accentColor
                ) {
                    manager.isRunning ? manager.pause() : manager.start()
                }

                CircleControl(icon: "stop.fill", tint: .secondary) {
                    manager.stop()
                }
                .disabled(manager.phase == .idle)

                CircleControl(icon: "forward.end.fill", tint: .secondary) {
                    manager.skip()
                }
                .disabled(manager.phase == .idle)

                CircleControl(icon: "cup.and.saucer.fill", tint: .orange) {
                    manager.startManualBreak()
                }
                .help("Take a coffee break now")
            }

            if manager.completedSessions > 0 {
                Text("Sessions completed: \(manager.completedSessions)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 8)
    }
}

private struct CircleControl: View {
    let icon: String
    var tint: Color = .accentColor
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(Color(nsColor: .secondarySystemFill))
                .frame(width: 42, height: 42)
                .overlay {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(tint)
                }
        }
        .buttonStyle(.plain)
    }
}
