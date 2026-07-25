import SwiftUI

/// A plain text field for a time of day.
///
/// The stock date picker makes you tab between hour and minute segments, which
/// is painful for something typed as often as "230am". This accepts whatever
/// shape the user types and tidies it up once they commit.
struct TimeField: View {
    let label: String?

    @Binding var minutes: Int

    @State private var text = ""

    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 6) {
            if let label {
                Text(label)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            TextField("", text: $text)
                .textFieldStyle(.roundedBorder)
                .font(.callout)
                .frame(width: 88)
                .multilineTextAlignment(.center)
                .focused($isFocused)
                .onSubmit(commit)
                .onChange(of: isFocused) { _, hasFocus in
                    if !hasFocus {
                        commit()
                    }
                }
                .onChange(of: minutes) { _, newMinutes in
                    text = TimeOfDay.format(newMinutes)
                }
                .task { text = TimeOfDay.format(minutes) }
                .help("Type a time such as 9, 9:30, 930am or 21:15")
        }
    }

    /// Unreadable input snaps back rather than silently storing something the
    /// user did not intend.
    private func commit() {
        guard let parsed = TimeOfDay.parse(text) else {
            text = TimeOfDay.format(minutes)
            return
        }

        minutes = parsed
        text = TimeOfDay.format(parsed)
    }
}
