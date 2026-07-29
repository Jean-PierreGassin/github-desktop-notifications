import AppKit
import SwiftUI

struct NotificationSettingsView: View {
    /// One indent for every control that only makes sense while the control
    /// above it is on, so subordination is never hand-tuned per site.
    private static let dependentIndent: CGFloat = 20

    private static let highlightDuration: Duration = .seconds(3)

    let session: AppSession

    /// The preview is pinned below the form rather than placed in it, so it
    /// stays in view while the settings that feed it are changed, however long
    /// this page grows.
    var body: some View {
        VStack(spacing: 0) {
            Form {
                alerts

                notificationTypes

                notificationContent

                behaviour
            }
            .formStyle(.grouped)

            Divider()

            preview
        }
        .font(.callout)
    }

    /// Three pickers because there are three decisions, and none of them can make
    /// another: which threads may interrupt at all, what has to happen on one
    /// before it interrupts again, and whose threads that second rule applies to.
    private var alerts: some View {
        Section {
            Picker("Notify me about", selection: presetBinding) {
                ForEach(AlertPreset.allCases, id: \.self) { preset in
                    Text(preset.displayName).tag(preset)
                }
            }

            Picker("After the first alert", selection: followUpBinding) {
                ForEach(FollowUpAlerts.allCases, id: \.self) { followUp in
                    Text(followUp.displayName).tag(followUp)
                }
            }

            Picker("Follow up on", selection: followUpThreadsBinding) {
                ForEach(FollowUpThreads.allCases, id: \.self) { threads in
                    Text(threads.displayName).tag(threads)
                }
            }
            .disabled(session.alertPreferences.followUpAlerts == .nothing)
            .padding(.leading, Self.dependentIndent)
        } header: {
            SettingsSectionHeader(title: "Alerts") { session.alertPreferences.resetToDefaults() }
        } footer: {
            Text("\(session.alertPreferences.preset.summary) "
                + "\(session.alertPreferences.followUpAlerts.summary) "
                + "\(session.alertPreferences.followUpThreads.summary) "
                + "Follow-up only decides what interrupts you: every change to a type you have switched on still "
                + "reaches its row in the menu bar panel, which says what last happened. "
                + "Reset restores all three, and the types below with them.")
                .foregroundStyle(.secondary)
        }
    }

    /// One section holding all fifteen, so they read as a single list rather
    /// than as three settings groups peer to Content and Behaviour. The group
    /// names are rows of their own, which keeps every checkbox on the form's
    /// own alignment instead of a nested stack's.
    private var notificationTypes: some View {
        Section {
            Picker("Menu bar panel shows", selection: panelContentsBinding) {
                ForEach(PanelContents.allCases, id: \.self) { contents in
                    Text(contents.displayName).tag(contents)
                }
            }

            ForEach(NotificationGroup.allCases, id: \.self) { group in
                Text(group.displayName)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                ForEach(session.alertPreferences.reasons(in: group), id: \.self) { reason in
                    Toggle(reason.displayName, isOn: reasonBinding(for: reason))
                        .toggleStyle(.checkbox)
                        .help(reason.explanation)
                }
            }
        } header: {
            SettingsSectionHeader(title: "Notification types") { session.alertPreferences.resetToDefaults() }
        } footer: {
            Text("These decide which notifications reach you at all. \(session.alertPreferences.panelContents.summary)")
                .foregroundStyle(.secondary)
        }
    }

    private var notificationContent: some View {
        Section {
            Toggle("Show the repository", isOn: contentBinding(\.showsRepository))

            Toggle("Include the owner in the repository name", isOn: contentBinding(\.showsFullRepositoryPath))
                .disabled(!session.notificationContentPreferences.settings.showsRepository)
                .padding(.leading, Self.dependentIndent)

            Toggle("Show the thread title", isOn: contentBinding(\.showsThreadTitle))

            Toggle("Show why it reached you and what changed", isOn: contentBinding(\.showsNotificationType))
        } header: {
            SettingsSectionHeader(title: "Notification content") {
                session.notificationContentPreferences.resetContent()
            }
        } footer: {
            Text("What each notification says when macOS shows it. Every notification names why the thread is yours, "
                + "and adds what has changed on it since, in the same words as the row in the menu bar panel.")
                .foregroundStyle(.secondary)
        }
    }

    /// Clicking is behaviour too, so it sits in this section rather than one of
    /// its own, kept apart by a rule because it answers a different question
    /// from the two rows above it.
    private var behaviour: some View {
        Section {
            Toggle("Stack notifications by repository", isOn: contentBinding(\.groupsByRepository))

            Toggle("Play a sound", isOn: contentBinding(\.playsSound))

            Picker("Sound", selection: soundBinding) {
                ForEach(NotificationSound.allCases, id: \.self) { sound in
                    Text(sound.displayName).tag(sound)
                }
            }
            .disabled(!session.notificationContentPreferences.settings.playsSound)
            .padding(.leading, Self.dependentIndent)

            Divider()

            clicks
        } header: {
            SettingsSectionHeader(title: "Behaviour", reset: resetBehaviour)
        } footer: {
            Text("Stacking keeps a busy repository to one banner. Choosing a sound plays it. The click setting drives "
                + "the button on a row and the one under the panel alike, and any single notification can still be "
                + "handled another way from its right-click menu.")
                .foregroundStyle(.secondary)
        }
    }

    private func resetBehaviour() {
        session.notificationContentPreferences.resetBehaviour()
        session.behaviourPreferences.resetToDefaults()
    }

    /// What a click does lives on this tab rather than in General: it belongs
    /// with the notifications it acts on, and General is about the app itself.
    private var clicks: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("When notifications are clicked, mark them as")

            ClickBehaviourPicker(selection: clickBehaviourBinding)
        }
        .padding(6)
        .background(
            isHighlighted ? AnyShapeStyle(.tint.opacity(0.15)) : AnyShapeStyle(.clear),
            in: RoundedRectangle(cornerRadius: 8),
        )
        .task(id: session.highlightedSettingsField == nil) { await fadeOutHighlight() }
    }

    private var isHighlighted: Bool {
        session.highlightedSettingsField == .clickBehaviour
    }

    /// The highlight exists to answer "where did that setting go", so it fades
    /// once it has been seen rather than staying on the page.
    private func fadeOutHighlight() async {
        guard isHighlighted else {
            return
        }

        try? await Task.sleep(for: Self.highlightDuration)

        withAnimation(.easeOut(duration: 0.6)) {
            session.clearSettingsHighlight()
        }
    }

    /// The preview holds no settings of its own, so it carries no reset.
    private var preview: some View {
        HStack(alignment: .bottom, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Preview")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                previewCard
            }

            Button("Send a test notification") {
                Task {
                    await session.notifier.sendTestNotification(
                        settings: session.notificationContentPreferences.settings,
                    )
                }
            }
            .appButton(.standard, size: .small)
            .disabled(session.notifier.needsPermission)
        }
        .padding(16)
        .background(.bar)
    }

    private var previewCard: some View {
        let preview = NotificationContentFormatter.make(
            for: SampleNotification.announcement,
            settings: session.notificationContentPreferences.settings,
        )

        return HStack(alignment: .top, spacing: 10) {
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .frame(width: 38, height: 38)

            VStack(alignment: .leading, spacing: 1) {
                Text(preview.title)
                    .fontWeight(.semibold)
                    .lineLimit(1)

                if !preview.subtitle.isEmpty {
                    Text(preview.subtitle)
                        .lineLimit(1)
                }

                Text(preview.body)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))
    }

    /// Choosing a sound plays it, so there is nothing extra to press.
    private var soundBinding: Binding<NotificationSound> {
        Binding(
            get: { session.notificationContentPreferences.settings.sound },
            set: { sound in
                session.notificationContentPreferences.settings.sound = sound
                sound.play()
            },
        )
    }

    private var clickBehaviourBinding: Binding<ClickBehaviour> {
        Binding(
            get: { session.behaviourPreferences.clickBehaviour },
            set: { session.behaviourPreferences.clickBehaviour = $0 },
        )
    }

    private var presetBinding: Binding<AlertPreset> {
        Binding(
            get: { session.alertPreferences.preset },
            set: { session.alertPreferences.select($0) },
        )
    }

    private var panelContentsBinding: Binding<PanelContents> {
        Binding(
            get: { session.alertPreferences.panelContents },
            set: { session.alertPreferences.panelContents = $0 },
        )
    }

    private var followUpBinding: Binding<FollowUpAlerts> {
        Binding(
            get: { session.alertPreferences.followUpAlerts },
            set: { session.alertPreferences.followUpAlerts = $0 },
        )
    }

    private var followUpThreadsBinding: Binding<FollowUpThreads> {
        Binding(
            get: { session.alertPreferences.followUpThreads },
            set: { session.alertPreferences.followUpThreads = $0 },
        )
    }

    private func reasonBinding(for reason: NotificationReason) -> Binding<Bool> {
        Binding(
            get: { session.alertPreferences.isEnabled(reason) },
            set: { session.alertPreferences.setEnabled($0, for: reason) },
        )
    }

    private func contentBinding(_ keyPath: WritableKeyPath<NotificationContentSettings, Bool>) -> Binding<Bool> {
        Binding(
            get: { session.notificationContentPreferences.settings[keyPath: keyPath] },
            set: { session.notificationContentPreferences.settings[keyPath: keyPath] = $0 },
        )
    }
}
