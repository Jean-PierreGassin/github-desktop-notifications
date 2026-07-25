import SwiftUI

/// A section heading with the reset that belongs to it.
///
/// Reset sits on the header's trailing edge rather than among the section's own
/// controls: findable when it is wanted, and never in the way of the control
/// someone actually came for. Nothing here leaves the machine or is
/// unrecoverable, so it asks for no confirmation.
struct SettingsSectionHeader: View {
    let title: String
    let reset: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            Text(title)

            Spacer(minLength: 12)

            Button("Reset", action: reset)
                .buttonStyle(.borderless)
                .controlSize(.small)
                .foregroundStyle(.secondary)
                .help("Restore this section to its defaults")
                .accessibilityLabel("Reset \(title)")
        }
    }
}
