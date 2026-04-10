import SwiftUI
import AppKit

// NSApp is nil during App.init(), so activation must be deferred to
// applicationDidFinishLaunching — the first safe point to call NSApp.
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}

@main
struct FlexDemoApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        WindowGroup("FlexLayout Demo") {
            ContentView()
                .frame(minWidth: 760, minHeight: 520)
        }
    }
}
