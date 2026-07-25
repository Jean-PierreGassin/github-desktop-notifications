import AppKit
import SwiftUI

@main
struct GitHubNotificationsApp: App {
    static let settingsWindowIdentifier = "settings"

    @State private var session = AppSession()

    var body: some Scene {
        MenuBarExtra {
            InboxPanel(session: session)
        } label: {
            MenuBarLabel(session: session)
        }
        .menuBarExtraStyle(.window)

        Window("GitHub Notifications Settings", id: Self.settingsWindowIdentifier) {
            SettingsView(session: session)
        }
        .windowResizability(.contentSize)
    }
}
