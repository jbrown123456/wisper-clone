import AppKit
import SwiftUI

private enum FloatingControlDefaults {
    static let xKey = "floating_control_origin_x"
    static let yKey = "floating_control_origin_y"
    static let panelWidth: CGFloat = 132
    static let panelHeight: CGFloat = 44
}

// MARK: - AppKit helpers (push region + drag handle)

private final class FloaterDragHandleView: NSView {
    override func mouseDown(with event: NSEvent) {
        window?.performDrag(with: event)
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(bounds, cursor: .openHand)
    }
}

private final class FloaterPushRegionView: NSView {
    var onMouseDown: () -> Void = {}

    override func mouseDown(with event: NSEvent) {
        onMouseDown()
    }
}

private struct FloaterChromeNSView: NSViewRepresentable {
    let onPushBegan: () -> Void

    func makeNSView(context: Context) -> NSView {
        let root = NSView(frame: .zero)
        root.wantsLayer = true

        let drag = FloaterDragHandleView(frame: .zero)
        drag.translatesAutoresizingMaskIntoConstraints = false

        let push = FloaterPushRegionView(frame: .zero)
        push.translatesAutoresizingMaskIntoConstraints = false
        push.onMouseDown = onPushBegan

        root.addSubview(drag)
        root.addSubview(push)

        NSLayoutConstraint.activate([
            drag.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            drag.topAnchor.constraint(equalTo: root.topAnchor),
            drag.bottomAnchor.constraint(equalTo: root.bottomAnchor),
            drag.widthAnchor.constraint(equalToConstant: 18),

            push.leadingAnchor.constraint(equalTo: drag.trailingAnchor),
            push.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            push.topAnchor.constraint(equalTo: root.topAnchor),
            push.bottomAnchor.constraint(equalTo: root.bottomAnchor),
        ])

        return root
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let push = nsView.subviews.compactMap({ $0 as? FloaterPushRegionView }).first else { return }
        push.onMouseDown = onPushBegan
    }
}

// MARK: - SwiftUI chrome

private struct FloatingControlRootView: View {
    @ObservedObject var appModel: AppModel

    var body: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(.white.opacity(0.14)))

            HStack(spacing: 0) {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 18)
                    .accessibilityLabel("Drag to move")

                HStack(spacing: 8) {
                    Image(systemName: phaseSymbol)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(phaseTint)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(title)
                            .font(.caption.weight(.semibold))
                        Text(subtitle)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.trailing, 10)
            }
            .allowsHitTesting(false)

            FloaterChromeNSView {
                appModel.beginCaptureFromFloater()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: FloatingControlDefaults.panelWidth, height: FloatingControlDefaults.panelHeight)
        .shadow(color: .black.opacity(0.18), radius: 10, y: 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Dictation")
        .accessibilityHint("Hold mouse button to dictate; release to finish. Drag the left grip to move.")
    }

    private var title: String {
        if !appModel.isEnabled { return "Paused" }
        switch appModel.sessionPhase {
        case .idle: return "Flow"
        case .listening: return "Listening"
        case .processing: return "Processing"
        case .outputting: return "Writing"
        }
    }

    private var subtitle: String {
        if !appModel.isEnabled { return "Enable in Settings" }
        return "Hold to dictate"
    }

    private var phaseSymbol: String {
        switch appModel.sessionPhase {
        case .idle: return "mic.fill"
        case .listening: return "mic.fill"
        case .processing: return "waveform"
        case .outputting: return "text.bubble.fill"
        }
    }

    private var phaseTint: Color {
        switch appModel.sessionPhase {
        case .idle: return AppTheme.accent
        case .listening: return .red.opacity(0.9)
        case .processing: return AppTheme.accentSoft
        case .outputting: return AppTheme.accent
        }
    }
}

// MARK: - Window delegate (persist frame)

private final class FloatingPanelDelegate: NSObject, NSWindowDelegate {
    func windowDidMove(_ notification: Notification) {
        guard let win = notification.object as? NSWindow else { return }
        let o = win.frame.origin
        UserDefaults.standard.set(o.x, forKey: FloatingControlDefaults.xKey)
        UserDefaults.standard.set(o.y, forKey: FloatingControlDefaults.yKey)
    }

    func windowDidEndLiveResize(_ notification: Notification) {
        windowDidMove(notification)
    }
}

// MARK: - Controller

@MainActor
final class FloatingControlController {
    static let shared = FloatingControlController()

    private var panel: NSPanel?
    private var host: NSHostingController<FloatingControlRootView>?
    private weak var appModel: AppModel?
    private let panelDelegate = FloatingPanelDelegate()

    private init() {}

    func attach(appModel: AppModel) {
        self.appModel = appModel
        if appModel.settings.showFloatingControl {
            showPanel(appModel: appModel)
        }
    }

    func setFloatingControlVisible(_ visible: Bool, appModel: AppModel) {
        self.appModel = appModel
        if visible {
            showPanel(appModel: appModel)
        } else {
            hidePanel()
        }
    }

    private func showPanel(appModel: AppModel) {
        if panel != nil {
            panel?.orderFrontRegardless()
            return
        }

        let root = FloatingControlRootView(appModel: appModel)
        let hc = NSHostingController(rootView: root)
        host = hc

        let rect = NSRect(x: 0, y: 0, width: FloatingControlDefaults.panelWidth, height: FloatingControlDefaults.panelHeight)
        let p = NSPanel(
            contentRect: rect,
            styleMask: [.nonactivatingPanel, .borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false,
        )
        p.isFloatingPanel = true
        p.level = .floating
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        p.isReleasedWhenClosed = false
        p.titlebarAppearsTransparent = true
        p.titleVisibility = .hidden
        p.backgroundColor = .clear
        p.isOpaque = false
        p.hasShadow = false
        p.contentViewController = hc
        p.delegate = panelDelegate
        p.isMovableByWindowBackground = false

        restoreFrame(panel: p)
        p.orderFrontRegardless()
        panel = p
    }

    private func hidePanel() {
        panel?.orderOut(nil)
        panel = nil
        host = nil
    }

    private func restoreFrame(panel: NSPanel) {
        let d = UserDefaults.standard
        if d.object(forKey: FloatingControlDefaults.xKey) != nil,
           d.object(forKey: FloatingControlDefaults.yKey) != nil
        {
            let x = d.double(forKey: FloatingControlDefaults.xKey)
            let y = d.double(forKey: FloatingControlDefaults.yKey)
            var f = panel.frame
            f.origin = CGPoint(x: x, y: y)
            panel.setFrame(f, display: false)
            clampToVisible(panel: panel)
            return
        }

        guard let screen = NSScreen.main?.visibleFrame else { return }
        var f = panel.frame
        f.origin.x = screen.maxX - f.width - 24
        f.origin.y = screen.minY + 24
        panel.setFrame(f, display: false)
    }

    private func clampToVisible(panel: NSPanel) {
        guard let screen = NSScreen.main?.visibleFrame else { return }
        var f = panel.frame
        if f.maxX > screen.maxX { f.origin.x = screen.maxX - f.width - 8 }
        if f.minX < screen.minX { f.origin.x = screen.minX + 8 }
        if f.maxY > screen.maxY { f.origin.y = screen.maxY - f.height - 8 }
        if f.minY < screen.minY { f.origin.y = screen.minY + 8 }
        panel.setFrame(f, display: true)
    }
}
