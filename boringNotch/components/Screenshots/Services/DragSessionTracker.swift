import AppKit

/// Holds `vm.dragDetectorTargeting` true for the duration of an outgoing screenshot drag so
/// the notch's hover-collapse doesn't fire while the cursor is outside the drop zone.
/// Without this, dragging a thumb to Finder/Slack/Photos collapses the notch mid-flight and
/// the drag aborts.
@MainActor
enum DragSessionTracker {
    private static var monitor: Any?
    private static var keepAliveTask: Task<Void, Never>?
    private static weak var trackedVM: BoringViewModel?

    static func start(vm: BoringViewModel) {
        trackedVM = vm
        vm.dragDetectorTargeting = true

        // Re-assert every 80ms because the existing `.onDrop(isTargeted:)` bindings on the
        // notch flip the same flag to false whenever the cursor leaves their drop zone.
        keepAliveTask?.cancel()
        keepAliveTask = Task { @MainActor in
            while !Task.isCancelled {
                trackedVM?.dragDetectorTargeting = true
                try? await Task.sleep(for: .milliseconds(80))
            }
        }

        if monitor == nil {
            monitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseUp]) { _ in
                Task { @MainActor in stop() }
            }
        }
    }

    static func stop() {
        keepAliveTask?.cancel()
        keepAliveTask = nil
        trackedVM?.dragDetectorTargeting = false
        trackedVM = nil
        if let m = monitor {
            NSEvent.removeMonitor(m)
            monitor = nil
        }
    }
}
