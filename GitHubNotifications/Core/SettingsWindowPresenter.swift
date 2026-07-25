import AppKit

/// A setting worth pointing at once, straight after the user has chosen it.
enum SettingsField: Sendable {
    case clickBehaviour
}

/// The app normally hides from the Dock and the app switcher. A settings window
/// that cannot be switched back to is a trap, so the app becomes a regular app
/// for as long as that window is open.
@MainActor
enum SettingsWindowPresenter {
    static func prepareForDisplay() {
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    static func returnToMenuBarOnly() {
        NSApplication.shared.setActivationPolicy(.accessory)
    }
}
