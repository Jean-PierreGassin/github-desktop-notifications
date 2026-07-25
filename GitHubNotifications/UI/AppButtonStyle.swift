import SwiftUI

/// One vocabulary of buttons for the whole app, so a control's look always says
/// what kind of thing it does.
enum AppButtonRole {
    /// The one action being pushed on this screen.
    case primary
    /// Everything else that is safe to press.
    case standard
    /// Actions that throw work away or end the session.
    case destructive
}

private struct AppButtonModifier: ViewModifier {
    let role: AppButtonRole
    let size: ControlSize

    @ViewBuilder
    func body(content: Content) -> some View {
        switch role {
        case .primary:
            content.buttonStyle(.borderedProminent).controlSize(size)
        case .standard:
            content.buttonStyle(.bordered).controlSize(size)
        case .destructive:
            content.buttonStyle(.bordered).controlSize(size).tint(.red)
        }
    }
}

extension View {
    func appButton(_ role: AppButtonRole, size: ControlSize = .regular) -> some View {
        modifier(AppButtonModifier(role: role, size: size))
    }
}
