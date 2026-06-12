//
//  PomodoroSettings.swift
//  boringNotch
//

import Defaults
import SwiftUI

struct PomodoroSettings: View {
    @Default(.enablePomodoro) var enablePomodoro
    @Default(.pomodoroFocusMinutes) var focusMinutes
    @Default(.pomodoroBreakMinutes) var breakMinutes
    @Default(.pomodoroLongBreakMinutes) var longBreakMinutes
    @Default(.pomodoroSessionsBeforeLongBreak) var sessionsBeforeLongBreak
    @Default(.pomodoroAutoStartNext) var autoStartNext
    @Default(.showPomodoroInClosedNotch) var showInClosedNotch

    var body: some View {
        Form {
            Section {
                Defaults.Toggle(key: .enablePomodoro) {
                    Text("Show Pomodoro icon in notch")
                }
            } header: {
                Text("General")
            } footer: {
                Text("Adds a timer icon to the right of the notch that opens the Pomodoro view.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                Stepper(value: $focusMinutes, in: 1...90, step: 1) {
                    HStack {
                        Text("Focus session")
                        Spacer()
                        Text("\(Int(focusMinutes)) min")
                            .foregroundStyle(.secondary)
                    }
                }
                Stepper(value: $breakMinutes, in: 1...30, step: 1) {
                    HStack {
                        Text("Coffee break")
                        Spacer()
                        Text("\(Int(breakMinutes)) min")
                            .foregroundStyle(.secondary)
                    }
                }
                Stepper(value: $longBreakMinutes, in: 1...60, step: 1) {
                    HStack {
                        Text("Long break")
                        Spacer()
                        Text("\(Int(longBreakMinutes)) min")
                            .foregroundStyle(.secondary)
                    }
                }
                Stepper(value: $sessionsBeforeLongBreak, in: 1...10, step: 1) {
                    HStack {
                        Text("Sessions before long break")
                        Spacer()
                        Text("\(sessionsBeforeLongBreak)")
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Durations")
            } footer: {
                Text("After a focus session the timer flips to a coffee break automatically. Every \(sessionsBeforeLongBreak) sessions you get a long break instead.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                Defaults.Toggle(key: .pomodoroAutoStartNext) {
                    Text("Auto-start next phase")
                }
                Defaults.Toggle(key: .showPomodoroInClosedNotch) {
                    Text("Show countdown in closed notch")
                }
            } header: {
                Text("Behaviour")
            } footer: {
                Text("When auto-start is off, the next focus or break is loaded but waits for you to press play.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .accentColor(.effectiveAccent)
        .navigationTitle("Pomodoro")
    }
}
