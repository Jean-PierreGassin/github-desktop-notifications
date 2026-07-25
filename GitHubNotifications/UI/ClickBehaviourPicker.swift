import SwiftUI

/// The three click behaviours as rows carrying their own explanation.
///
/// A plain picker would hide what each option does behind a menu, and the
/// difference between Dismissed and Read & Dismissed is exactly the kind of
/// thing someone should not have to find out by trying it on a real inbox.
struct ClickBehaviourPicker: View {
    @Binding var selection: ClickBehaviour

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(ClickBehaviour.allCases, id: \.self) { behaviour in
                option(behaviour)
            }
        }
    }

    private func option(_ behaviour: ClickBehaviour) -> some View {
        Button {
            selection = behaviour
        } label: {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: behaviour == selection ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(behaviour == selection ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))

                VStack(alignment: .leading, spacing: 2) {
                    Text(behaviour.displayName)
                        .fontWeight(.medium)

                    Text(behaviour.explanation)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(behaviour == selection ? [.isSelected, .isButton] : .isButton)
    }
}
