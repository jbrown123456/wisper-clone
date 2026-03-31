import AppKit

/// Global push-to-hold: key down begins session, key up finalizes exactly once.
final class HotkeyMonitor {
    /// Right Option (⌥) — change in HotkeyMonitor if it conflicts with your layout.
    static let defaultPushToTalkKeyCode: UInt16 = 61

    private let keyCode: UInt16
    private var monitors: [Any] = []
    private var isKeyDown = false
    private var sessionActive = false

    var onSessionBegan: () -> Void = {}
    var onSessionFinalized: () -> Void = {}

    init(defaultKeyCode: UInt16) {
        self.keyCode = defaultKeyCode
    }

    func start() {
        guard monitors.isEmpty else { return }
        let maskDown: NSEvent.EventTypeMask = .keyDown
        let maskUp: NSEvent.EventTypeMask = .keyUp
        if let m = NSEvent.addGlobalMonitorForEvents(matching: maskDown, handler: { [weak self] e in
            self?.handleKeyDown(e)
        }) { monitors.append(m) }
        if let m = NSEvent.addGlobalMonitorForEvents(matching: maskUp, handler: { [weak self] e in
            self?.handleKeyUp(e)
        }) { monitors.append(m) }
        if let m = NSEvent.addLocalMonitorForEvents(matching: maskDown, handler: { [weak self] e in
            self?.handleKeyDown(e)
            return e
        }) { monitors.append(m) }
        if let m = NSEvent.addLocalMonitorForEvents(matching: maskUp, handler: { [weak self] e in
            self?.handleKeyUp(e)
            return e
        }) { monitors.append(m) }
    }

    func stop() {
        for m in monitors {
            NSEvent.removeMonitor(m)
        }
        monitors.removeAll()
        isKeyDown = false
        sessionActive = false
    }

    private func handleKeyDown(_ event: NSEvent) {
        guard event.keyCode == keyCode else { return }
        guard event.isARepeat == false else { return }
        guard isKeyDown == false else { return }
        isKeyDown = true
        sessionActive = true
        onSessionBegan()
    }

    private func handleKeyUp(_ event: NSEvent) {
        guard event.keyCode == keyCode else { return }
        isKeyDown = false
        guard sessionActive else { return }
        sessionActive = false
        onSessionFinalized()
    }
}
