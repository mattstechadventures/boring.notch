//
//  PomodoroManager.swift
//  boringNotch
//
//  Drives the Pomodoro focus/break cycle. The break phase is the "coffee break".
//

import Combine
import Defaults
import Foundation

final class PomodoroManager: ObservableObject {
    static let shared = PomodoroManager()

    @Published private(set) var phase: PomodoroPhase = .idle
    /// Seconds remaining in the current phase.
    @Published private(set) var timeRemaining: TimeInterval = 0
    @Published private(set) var isRunning: Bool = false
    /// Number of focus sessions completed in the current long-break cycle.
    @Published private(set) var completedSessions: Int = 0

    private var timer: Timer?

    private init() {}

    // MARK: - Durations (read live from Defaults)

    private var focusDuration: TimeInterval { Defaults[.pomodoroFocusMinutes] * 60 }
    private var breakDuration: TimeInterval { Defaults[.pomodoroBreakMinutes] * 60 }
    private var longBreakDuration: TimeInterval { Defaults[.pomodoroLongBreakMinutes] * 60 }
    private var sessionsBeforeLongBreak: Int { max(1, Defaults[.pomodoroSessionsBeforeLongBreak]) }

    /// True when the upcoming break should be a long break.
    var isLongBreakNext: Bool {
        completedSessions > 0 && completedSessions % sessionsBeforeLongBreak == 0
    }

    // MARK: - Controls

    /// Starts a fresh focus session from idle, or resumes a paused one.
    func start() {
        if phase == .idle {
            beginPhase(.focus)
        } else {
            resume()
        }
    }

    func pause() {
        timer?.invalidate()
        timer = nil
        isRunning = false
    }

    func resume() {
        guard phase != .idle, !isRunning else { return }
        startTicking()
    }

    /// Stops and resets the whole cycle.
    func stop() {
        timer?.invalidate()
        timer = nil
        isRunning = false
        phase = .idle
        timeRemaining = 0
        completedSessions = 0
    }

    /// Skips to the end of the current phase, advancing the cycle.
    func skip() {
        guard phase != .idle else { return }
        advancePhase()
    }

    /// Manually begin a coffee break right now, regardless of the focus timer.
    func startManualBreak() {
        beginPhase(.breakTime)
    }

    // MARK: - Phase machine

    private func beginPhase(_ newPhase: PomodoroPhase) {
        phase = newPhase
        switch newPhase {
        case .focus:
            timeRemaining = focusDuration
        case .breakTime:
            timeRemaining = isLongBreakNext ? longBreakDuration : breakDuration
        case .idle:
            timeRemaining = 0
        }
        startTicking()
    }

    private func startTicking() {
        timer?.invalidate()
        isRunning = true
        let t = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        // Keep ticking while menus/tracking loops run.
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func tick() {
        guard timeRemaining > 0 else {
            advancePhase()
            return
        }
        timeRemaining -= 1
        if timeRemaining <= 0 {
            advancePhase()
        }
    }

    private func advancePhase() {
        switch phase {
        case .focus:
            completedSessions += 1
            beginPhaseOrPause(.breakTime)
        case .breakTime, .idle:
            beginPhaseOrPause(.focus)
        }
    }

    /// Starts the next phase, honoring the auto-start preference. When auto-start
    /// is off, we load the next phase but leave it paused for the user to start.
    private func beginPhaseOrPause(_ newPhase: PomodoroPhase) {
        if Defaults[.pomodoroAutoStartNext] {
            beginPhase(newPhase)
        } else {
            timer?.invalidate()
            timer = nil
            isRunning = false
            phase = newPhase
            switch newPhase {
            case .focus:
                timeRemaining = focusDuration
            case .breakTime:
                timeRemaining = isLongBreakNext ? longBreakDuration : breakDuration
            case .idle:
                timeRemaining = 0
            }
        }
    }

    // MARK: - Formatting

    var formattedTimeRemaining: String {
        let total = Int(timeRemaining.rounded())
        return String(format: "%02d:%02d", total / 60, total % 60)
    }

    var phaseLabel: String {
        switch phase {
        case .idle: return "Ready"
        case .focus: return "Focus"
        case .breakTime: return isLongBreakNext ? "Long Break" : "Coffee Break"
        }
    }
}
