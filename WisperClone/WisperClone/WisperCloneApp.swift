import AppKit
import SwiftUI

enum AppTheme {
    static let accent = Color(hex: 0x7C5CFF)
    static let accentSoft = Color(hex: 0xB8A7FF)
    static let accentTint = Color(hex: 0xEFEAFF)
    static let cardBorder = Color.white.opacity(0.5)
}

extension Color {
    init(hex: UInt, alpha: Double = 1.0) {
        let red = Double((hex >> 16) & 0xFF) / 255.0
        let green = Double((hex >> 8) & 0xFF) / 255.0
        let blue = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }
}

struct AppCardBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(AppTheme.cardBorder, lineWidth: 1),
                    ),
            )
    }
}

extension View {
    func appCard() -> some View {
        modifier(AppCardBackground())
    }
}

@main
struct WisperCloneApp: App {
    @StateObject private var appModel = AppModel()

    var body: some Scene {
        WindowGroup {
            DesktopRootView()
                .environmentObject(appModel)
                .frame(minWidth: 880, minHeight: 560)
                .tint(AppTheme.accent)
                .onAppear {
                    FloatingControlController.shared.attach(appModel: appModel)
                }
        }
        .defaultSize(width: 1000, height: 680)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}
