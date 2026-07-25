import SwiftUI

/// Asked once, right after signing in.
///
/// It is a sheet on Settings rather than an alert because it is a choice, not a
/// problem: alerts are for things that have gone wrong or cannot be undone.
struct ClickBehaviourPromptView: View {
    private static let sheetWidth: CGFloat = 460

    let session: AppSession

    @State private var selection = ClickBehaviour.default

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("What should clicking a notification do?")
                    .font(.title3)
                    .fontWeight(.semibold)

                Text("Opening a notification usually means you have dealt with it, but an inbox some people keep "
                    + "as a to-do list is not one to clear behind their back.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            ClickBehaviourPicker(selection: $selection)

            InfoBubble(symbolName: "gearshape") {
                Text("You can change this any time in Settings, under Notifications.")
                    .foregroundStyle(.secondary)
            }

            HStack {
                Spacer(minLength: 0)

                Button("Continue") { session.chooseClickBehaviour(selection) }
                    .appButton(.primary)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .font(.callout)
        .padding(24)
        .frame(width: Self.sheetWidth)
        .task { selection = session.behaviourPreferences.clickBehaviour }
    }
}
