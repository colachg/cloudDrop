import ServiceManagement
import SwiftUI

@main
struct CloudDropApp: App {
    @State private var appState = AppState()
    @State private var updateChecker = UpdateChecker()
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    init() {
        NSApplication.shared.setActivationPolicy(.accessory)
        _updateChecker.wrappedValue.start()
    }

    var body: some Scene {
        MenuBarExtra("CloudDrop", systemImage: "icloud.and.arrow.up.fill") {
            ContentView(updateChecker: updateChecker, launchAtLogin: $launchAtLogin)
                .environment(appState)
                .frame(width: 320, height: 500)
        }
        .menuBarExtraStyle(.window)
    }
}
