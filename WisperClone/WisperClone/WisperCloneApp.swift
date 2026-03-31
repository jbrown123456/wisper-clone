import AppKit
import SwiftUI

@main
struct WisperCloneApp: App {
    @StateObject private var appModel = AppModel()

    var body: some Scene {
        WindowGroup {
            DesktopRootView()
                .environmentObject(appModel)
                .frame(minWidth: 880, minHeight: 560)
        }
        .defaultSize(width: 1000, height: 680)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}
