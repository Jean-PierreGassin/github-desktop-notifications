import AppKit
import SwiftUI

struct NotificationSettingsView: View {
    private static let reasonColumns = [GridItem(.flexible(), alignment: .leading),
                                        GridItem(.flexible(), alignment: .leading)]
    private static let optionColumns = [GridItem(.flexible(), alignment: .leading),
                                        GridItem(.flexible(), alignment: .leading)]

    let session: AppSession

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .top, spacing: 28) {
                    alertTypes

                    Divider()

                    WorkHoursView(session: session)
                        .frame(width: 400, alignment: .leading)
                }

                Divider()

                notificationCustomisation
            }
            .padding(24)
        }
    }

    private var alertTypes: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("What interrupts you")
                    .font(.headline)

                Text("Every notification appears in the menu bar panel. These decide which ones also reach macOS.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            presetPicker

            Divider()

            reasonSections

            Spacer(minLength: 0)
        }
        .frame(width: 380, alignment: .leading)
    }

    private var presetPicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Picker("Notify me about", selection: presetBinding) {
                ForEach(AlertPreset.allCases, id: \.self) { preset in
                    Text(preset.displayName).tag(preset)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)

            Text(session.alertPreferences.preset.summary)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var reasonSections: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(NotificationGroup.allCases, id: \.self) { group in
                VStack(alignment: .leading, spacing: 4) {
                    Text(group.displayName)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)

                    LazyVGrid(columns: Self.reasonColumns, alignment: .leading, spacing: 6) {
                        ForEach(session.alertPreferences.reasons(in: group), id: \.self) { reason in
                            Toggle(reason.displayName, isOn: reasonBinding(for: reason))
                                .toggleStyle(.checkbox)
                                .font(.callout)
                                .lineLimit(1)
                                .help(reason.explanation)
                        }
                    }
                }
            }
        }
    }

    private var notificationCustomisation: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Notification customisation")
                    .font(.headline)

                Text("How each notification looks and sounds when macOS shows it. The menu bar panel is unaffected.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(alignment: .top, spacing: 28) {
                VStack(alignment: .leading, spacing: 8) {
                    LazyVGrid(columns: Self.optionColumns, alignment: .leading, spacing: 8) {
                        Toggle("Show the repository", isOn: contentBinding(\.showsRepository))

                        Toggle("Show the thread title", isOn: contentBinding(\.showsThreadTitle))

                        Toggle(
                            "Include the owner in the repository name",
                            isOn: contentBinding(\.showsFullRepositoryPath),
                        )
                        .disabled(!session.notificationContentPreferences.settings.showsRepository)

                        Toggle("Show why you were notified", isOn: contentBinding(\.showsNotificationType))

                        Toggle("Stack notifications by repository", isOn: contentBinding(\.groupsByRepository))

                        Toggle("Play a sound", isOn: contentBinding(\.playsSound))
                    }
                    .font(.callout)

                    soundPicker
                        .padding(.leading, 18)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 10) {
                    previewCard

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
                .frame(width: 320, alignment: .leading)
            }
        }
    }

    private var soundPicker: some View {
        HStack(spacing: 8) {
            Text("Sound")
                .font(.callout)

            Picker("Sound", selection: soundBinding) {
                ForEach(NotificationSound.allCases, id: \.self) { sound in
                    Text(sound.displayName).tag(sound)
                }
            }
            .labelsHidden()
            .frame(width: 140)
        }
        .disabled(!session.notificationContentPreferences.settings.playsSound)
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

    private var previewCard: some View {
        let preview = NotificationContentFormatter.make(
            for: SampleNotification.thread,
            settings: session.notificationContentPreferences.settings,
        )

        return VStack(alignment: .leading, spacing: 6) {
            Text("Preview")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            HStack(alignment: .top, spacing: 10) {
                Image(nsImage: NSApplication.shared.applicationIconImage)
                    .resizable()
                    .frame(width: 38, height: 38)

                VStack(alignment: .leading, spacing: 1) {
                    Text(preview.title)
                        .font(.callout)
                        .fontWeight(.semibold)
                        .lineLimit(1)

                    if !preview.subtitle.isEmpty {
                        Text(preview.subtitle)
                            .font(.callout)
                            .lineLimit(1)
                    }

                    Text(preview.body)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 0)
            }
            .padding(12)
            .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))
        }
    }

    private var presetBinding: Binding<AlertPreset> {
        Binding(
            get: { session.alertPreferences.preset },
            set: { session.alertPreferences.select($0) },
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
