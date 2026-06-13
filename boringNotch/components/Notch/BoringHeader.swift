//
//  BoringHeader.swift
//  boringNotch
//
//  Created by Harsh Vardhan  Goswami  on 04/08/24.
//
//  Reworked to render both header clusters from the PanelRegistry +
//  HeaderLayoutManager. Each side renders only `resolvedOrder(for:)` — its saved
//  arrangement clamped to the live per-display capacity — so the header can
//  never overflow the notch panel (the bug that made Home disappear).
//

import Defaults
import SwiftUI

struct BoringHeader: View {
    @EnvironmentObject var vm: BoringViewModel
    @ObservedObject var coordinator = BoringViewCoordinator.shared
    @ObservedObject var layout = HeaderLayoutManager.shared

    // Observed so the header re-renders when the layout is edited.
    @Default(.headerLeftOrder) var leftOrder
    @Default(.headerRightOrder) var rightOrder
    @Default(.headerLeftElastic) var leftElastic
    @Default(.headerRightElastic) var rightElastic

    var body: some View {
        HStack(spacing: 0) {
            sideCluster(.left)
                .frame(maxWidth: .infinity, alignment: .leading)
                .opacity(vm.notchState == .closed ? 0 : 1)
                .blur(radius: vm.notchState == .closed ? 20 : 0)
                .zIndex(2)

            if vm.notchState == .open {
                Rectangle()
                    .fill(NSScreen.screen(withUUID: coordinator.selectedScreenUUID)?.safeAreaInsets.top ?? 0 > 0 ? .black : .clear)
                    .frame(width: vm.closedNotchSize.width)
                    .mask {
                        NotchShape()
                    }
            }

            rightCluster
                .font(.system(.headline, design: .rounded))
                .frame(maxWidth: .infinity, alignment: .trailing)
                .opacity(vm.notchState == .closed ? 0 : 1)
                .blur(radius: vm.notchState == .closed ? 20 : 0)
                .zIndex(2)
        }
        .foregroundColor(.gray)
        .environmentObject(vm)
    }

    /// One side's slot items, clamped to capacity, with elastic spacing.
    @ViewBuilder
    private func sideCluster(_ side: PanelSide) -> some View {
        if vm.notchState == .open {
            let ids = layout.resolvedOrder(for: side, screenUUID: coordinator.selectedScreenUUID)
            let elastic = side == .left ? leftElastic : rightElastic
            let spacing = layout.gap(for: ids.count, side: side, elastic: elastic,
                                     screenUUID: coordinator.selectedScreenUUID)
            HStack(spacing: spacing) {
                ForEach(ids) { id in
                    if let descriptor = PanelRegistry.shared.descriptor(for: id) {
                        HeaderSlotButton(descriptor: descriptor)
                    }
                }
            }
        }
    }

    /// The right cluster yields to the HUD (volume/brightness/etc.) when one is active.
    @ViewBuilder
    private var rightCluster: some View {
        if vm.notchState == .open {
            if isHUDType(coordinator.sneakPeek.type) && coordinator.sneakPeek.show && Defaults[.showOpenNotchHUD] {
                OpenNotchHUD(type: $coordinator.sneakPeek.type, value: $coordinator.sneakPeek.value, icon: $coordinator.sneakPeek.icon)
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
            } else {
                sideCluster(.right)
            }
        }
    }

    func isHUDType(_ type: SneakContentType) -> Bool {
        switch type {
        case .volume, .brightness, .backlight, .mic:
            return true
        default:
            return false
        }
    }
}

#Preview {
    BoringHeader().environmentObject(BoringViewModel())
}
