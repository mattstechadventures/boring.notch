//
//  HeaderSlotButton.swift
//  boringNotch
//
//  Renders one header slot item from its PanelDescriptor. Uniform 30×30 style
//  across both clusters, with a selection highlight for the active view and a
//  kind-based activation action. The battery indicator renders its own view.
//

import Defaults
import SwiftUI

struct HeaderSlotButton: View {
    let descriptor: PanelDescriptor

    @EnvironmentObject var vm: BoringViewModel
    @ObservedObject var coordinator = BoringViewCoordinator.shared
    @ObservedObject var batteryModel = BatteryStatusViewModel.shared

    private var isSelected: Bool {
        guard let destination = descriptor.destination else { return false }
        return coordinator.currentView == destination
    }

    var body: some View {
        switch descriptor.kind {
        case .batteryIndicator:
            BoringBatteryView(
                batteryWidth: 30,
                isCharging: batteryModel.isCharging,
                isInLowPowerMode: batteryModel.isInLowPowerMode,
                isPluggedIn: batteryModel.isPluggedIn,
                levelBattery: batteryModel.levelBattery,
                maxCapacity: batteryModel.maxCapacity,
                timeToFullCharge: batteryModel.timeToFullCharge,
                isForNotification: false
            )
        default:
            Button(action: activate) {
                ZStack {
                    if isSelected {
                        Capsule().fill(Color(nsColor: .secondarySystemFill))
                    }
                    Image(systemName: descriptor.icon)
                        .foregroundColor(isSelected ? .white : .gray)
                        .imageScale(.medium)
                }
                .frame(width: 30, height: 30)
                .contentShape(Capsule())
            }
            .buttonStyle(PlainButtonStyle())
            .help(descriptor.label)
        }
    }

    private func activate() {
        switch descriptor.kind {
        case let .view(view):
            withAnimation(.smooth) { coordinator.currentView = view }
        case .toggleWebcam:
            vm.toggleCameraPreview()
        case .openSettings:
            DispatchQueue.main.async { SettingsWindowController.shared.showWindow() }
        case .batteryIndicator:
            break
        }
    }
}
