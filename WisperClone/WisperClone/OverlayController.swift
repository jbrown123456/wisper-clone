import AppKit
import SwiftUI

@MainActor
final class OverlayViewModel: ObservableObject {
    @Published var nativeText = ""
    @Published var englishText = ""
    @Published var phase: SessionPhase = .idle
    @Published var errorBanner = ""
}

@MainActor
final class OverlayController {
    static let shared = OverlayController()

    private var panel: NSPanel?
    private var host: NSHostingController<OverlayRootView>?
    let model = OverlayViewModel()

    private init() {}

    func show() {
        if panel != nil { return }

        let root = OverlayRootView(model: model)
        let hc = NSHostingController(rootView: root)
        host = hc

        let p = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 160),
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
        p.hasShadow = true
        p.contentViewController = hc

        positionNearMouse(panel: p)
        p.orderFrontRegardless()
        panel = p
    }

    func hide() {
        panel?.orderOut(nil)
        panel = nil
        host = nil
    }

    func update(native: String, english: String, phase: SessionPhase, error: String? = nil) {
        model.nativeText = native
        model.englishText = english
        model.phase = phase
        model.errorBanner = error ?? ""
    }

    private func positionNearMouse(panel: NSPanel) {
        let mouse = NSEvent.mouseLocation
        var f = panel.frame
        f.origin = NSPoint(x: mouse.x + 12, y: mouse.y - f.height - 12)
        guard let screen = NSScreen.main?.visibleFrame else {
            panel.setFrame(f, display: true)
            return
        }
        if f.maxX > screen.maxX { f.origin.x = screen.maxX - f.width - 8 }
        if f.minX < screen.minX { f.origin.x = screen.minX + 8 }
        if f.maxY > screen.maxY { f.origin.y = screen.maxY - f.height - 8 }
        if f.minY < screen.minY { f.origin.y = screen.minY + 8 }
        panel.setFrame(f, display: true)
    }
}

struct OverlayRootView: View {
    @ObservedObject var model: OverlayViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: phaseIcon)
                Text(phaseTitle)
                    .font(.headline)
                Spacer()
            }
            if !model.nativeText.isEmpty {
                Text(model.nativeText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
            if !model.englishText.isEmpty {
                Text(model.englishText)
                    .font(.body.weight(.semibold))
                    .lineLimit(6)
            }
            if model.nativeText.isEmpty, model.englishText.isEmpty {
                Text("…")
                    .foregroundStyle(.tertiary)
            }
            if !model.errorBanner.isEmpty {
                Text(model.errorBanner)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .lineLimit(4)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(.white.opacity(0.12)))
    }

    private var phaseIcon: String {
        switch model.phase {
        case .idle: return "mic.slash"
        case .listening: return "mic.fill"
        case .processing: return "waveform"
        case .outputting: return "text.bubble"
        }
    }

    private var phaseTitle: String {
        switch model.phase {
        case .idle: return "Idle"
        case .listening: return "Listening…"
        case .processing: return "Processing…"
        case .outputting: return "Output"
        }
    }
}
