import SwiftUI

@main
struct CloudDropApp: App {
    @State private var appState = AppState()

    init() {
        NSApplication.shared.setActivationPolicy(.accessory)
    }

    var body: some Scene {
        MenuBarExtra("CloudDrop", systemImage: "icloud.and.arrow.up.fill") {
            ContentView()
                .environment(appState)
                .frame(width: 320, height: 500)
        }
        .menuBarExtraStyle(.window)
    }
}
