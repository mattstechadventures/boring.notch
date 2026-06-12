//
//  PomodoroLiveActivity.swift
//  boringNotch
//
//  Compact closed-notch countdown shown while a Pomodoro session is running.
//

import SwiftUI

struct PomodoroLiveActivity: View {
    @EnvironmentObject var vm: BoringViewModel
    @ObservedObject private var manager = PomodoroManager.shared

    private var isBreak: Bool { manager.phase == .breakTime }
    private var accent: Color { isBreak ? .orange : .white }

    var body: some View {
        HStack(spacing: 0) {
            HStack {
                Image(systemName: isBreak ? "cup.and.saucer.fill" : "timer")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundStyle(accent)
                    .frame(width: vm.effectiveClosedNotchHeight - 14, height: vm.effectiveClosedNotchHeight - 14)
            }
            .frame(width: 80, alignment: .leading)
            .padding(.leading, 10)

            Rectangle()
                .fill(.black)
                .frame(width: vm.closedNotchSize.width + 10)

            HStack(spacing: 4) {
                Text(manager.formattedTimeRemaining)
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundStyle(accent)
                    .contentTransition(.numericText())
            }
            .frame(width: 90, alignment: .trailing)
            .padding(.trailing, 10)
        }
        .frame(height: vm.effectiveClosedNotchHeight, alignment: .center)
    }
}
