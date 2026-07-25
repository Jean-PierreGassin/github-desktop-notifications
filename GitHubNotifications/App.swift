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

        // Deliberately a Window rather than the standard Settings scene. The app
        // hides from the Dock, so opening settings has to flip the activation
        // policy to .regular and back when the window closes. A Window can be
        // addressed by id from the panel and hands SettingsView an onDisappear
        // to flip it back; the Settings scene offers neither hook.
        Window("GitHub Notifications Settings", id: Self.settingsWindowIdentifier) {
            SettingsView(session: session)
        }
        .windowResizability(.contentSize)
    }
}
