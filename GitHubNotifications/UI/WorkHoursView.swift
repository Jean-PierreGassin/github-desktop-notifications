import SwiftUI

struct WorkHoursView: View {
    private static let weekdaySymbols = ["S", "M", "T", "W", "T", "F", "S"]
    private static let weekdayNames = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
    private static let dayNameWidth: CGFloat = 84

    let session: AppSession

    var body: some View {
        Form {
            hoursSection

            daysSection

            heldSection
        }
        .formStyle(.grouped)
        .font(.callout)
    }

    private var hours: WorkHours {
        session.workHoursPreferences.hours
    }

    private var hoursSection: some View {
        Section {
            Toggle("Only notify me during work hours", isOn: binding(\.isEnabled))

            Picker("Hours", selection: binding(\.usesSameHoursEveryDay)) {
                Text("Same hours every day").tag(true)
                Text("Different hours per day").tag(false)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .disabled(!hours.isEnabled)

            if hours.usesSameHoursEveryDay {
                HStack(spacing: 8) {
                    TimeField(label: "From", minutes: sharedBinding(\.startMinutes))
                        .disabled(!hours.isEnabled)

                    TimeField(label: "to", minutes: sharedBinding(\.endMinutes))
                        .disabled(!hours.isEnabled)

                    if let note = note(for: hours.sharedSchedule) {
                        warning(note)
                    }

                    Spacer(minLength: 0)
                }
            }
        } header: {
            SettingsSectionHeader(title: "Hours") { session.workHoursPreferences.resetHours() }
        } footer: {
            Text("Outside your hours nothing pops up. Notifications still collect in the menu bar panel, "
                + "so nothing is lost.")
                .foregroundStyle(.secondary)
        }
    }

    /// Only the controls are disabled while work hours are off, never the
    /// section's own reset.
    private var daysSection: some View {
        Section {
            Group {
                if hours.usesSameHoursEveryDay {
                    weekdayChips

                    if !hours.hasAnyEnabledDay {
                        warning("No days are selected, so every notification will be held back.")
                    }
                } else {
                    perDayHours
                }
            }
            .disabled(!hours.isEnabled)
        } header: {
            SettingsSectionHeader(title: "Days") { session.workHoursPreferences.resetDays() }
        }
    }

    private var weekdayChips: some View {
        HStack(spacing: 6) {
            ForEach(Array(Self.weekdaySymbols.enumerated()), id: \.offset) { index, symbol in
                weekdayChip(symbol: symbol, weekday: index + 1)
            }

            Spacer(minLength: 0)
        }
    }

    private var perDayHours: some View {
        ForEach(WorkHours.allDays, id: \.self) { weekday in
            HStack(spacing: 8) {
                Toggle(isOn: dayEnabledBinding(for: weekday)) {
                    Text(Self.weekdayNames[weekday - 1])
                        .frame(width: Self.dayNameWidth, alignment: .leading)
                }
                .toggleStyle(.checkbox)

                TimeField(label: nil, minutes: dayBinding(for: weekday, keyPath: \.startMinutes))
                    .disabled(!isDayEnabled(weekday))

                Text("to")
                    .foregroundStyle(.secondary)

                TimeField(label: nil, minutes: dayBinding(for: weekday, keyPath: \.endMinutes))
                    .disabled(!isDayEnabled(weekday))

                if isDayEnabled(weekday), let note = note(for: hours.schedule(for: weekday)) {
                    warning(note)
                }

                Spacer(minLength: 0)
            }
        }
    }

    private var heldSection: some View {
        Section {
            Group {
                Picker("Deliver held notifications", selection: binding(\.heldDelivery)) {
                    ForEach(HeldAlertDelivery.allCases, id: \.self) { option in
                        Text(option.displayName).tag(option)
                    }
                }
                .pickerStyle(.radioGroup)
                .labelsHidden()

                if hours.heldDelivery == .atSetTime {
                    TimeField(label: "Deliver at", minutes: binding(\.deliveryMinutes))

                    if !hours.isDeliveryTimeWithinHours {
                        warning("That time falls outside every working day you have set, so held notifications will "
                            + "arrive when your hours start instead.")
                    }
                }
            }
            .disabled(!hours.isEnabled)

            if !session.heldAlerts.isEmpty {
                LabeledContent("Waiting") {
                    Text("\(session.heldAlerts.heldAnnouncements.count) notifications")
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            SettingsSectionHeader(title: "Held notifications") { session.workHoursPreferences.resetHeldDelivery() }
        } footer: {
            Text(hours.heldDelivery.explanation)
                .foregroundStyle(.secondary)
        }
    }

    private func warning(_ message: String) -> some View {
        Text(message)
            .foregroundStyle(.orange)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// Ends-before-it-starts is valid but surprising, so it is spelled out
    /// rather than silently accepted.
    private func note(for daySchedule: DaySchedule) -> String? {
        if daySchedule.isRoundTheClock {
            return "Same start and end, so this runs all day."
        }

        guard daySchedule.runsPastMidnight else {
            return nil
        }

        return "Ends at \(TimeOfDay.format(daySchedule.endMinutes)) the next day."
    }

    private func weekdayChip(symbol: String, weekday: Int) -> some View {
        let isActive = hours.activeWeekdays.contains(weekday)

        return Button {
            toggleWeekday(weekday)
        } label: {
            Text(symbol)
                .fontWeight(.medium)
                .frame(width: 30, height: 28)
                .background(
                    isActive ? AnyShapeStyle(.tint) : AnyShapeStyle(.quaternary),
                    in: RoundedRectangle(cornerRadius: 6),
                )
                .foregroundStyle(isActive ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
        }
        .buttonStyle(.plain)
        .help(Self.weekdayNames[weekday - 1])
    }

    private func isDayEnabled(_ weekday: Int) -> Bool {
        hours.daySchedules[weekday]?.isEnabled ?? false
    }

    private func binding<Value>(_ keyPath: WritableKeyPath<WorkHours, Value>) -> Binding<Value> {
        Binding(
            get: { session.workHoursPreferences.hours[keyPath: keyPath] },
            set: { session.workHoursPreferences.hours[keyPath: keyPath] = $0 },
        )
    }

    private func sharedBinding(_ keyPath: WritableKeyPath<DaySchedule, Int>) -> Binding<Int> {
        Binding(
            get: { session.workHoursPreferences.hours.sharedSchedule[keyPath: keyPath] },
            set: { session.workHoursPreferences.hours.sharedSchedule[keyPath: keyPath] = $0 },
        )
    }

    private func dayBinding(for weekday: Int, keyPath: WritableKeyPath<DaySchedule, Int>) -> Binding<Int> {
        Binding(
            get: { session.workHoursPreferences.hours.daySchedules[weekday]?[keyPath: keyPath] ?? 0 },
            set: { newValue in
                var daySchedule = session.workHoursPreferences.hours.daySchedules[weekday] ?? .off
                daySchedule[keyPath: keyPath] = newValue
                session.workHoursPreferences.hours.daySchedules[weekday] = daySchedule
            },
        )
    }

    private func dayEnabledBinding(for weekday: Int) -> Binding<Bool> {
        Binding(
            get: { session.workHoursPreferences.hours.daySchedules[weekday]?.isEnabled ?? false },
            set: { newValue in
                var daySchedule = session.workHoursPreferences.hours.daySchedules[weekday] ?? .off
                daySchedule.isEnabled = newValue
                session.workHoursPreferences.hours.daySchedules[weekday] = daySchedule
            },
        )
    }

    private func toggleWeekday(_ weekday: Int) {
        var weekdays = hours.activeWeekdays

        if weekdays.contains(weekday) {
            weekdays.remove(weekday)
        } else {
            weekdays.insert(weekday)
        }

        session.workHoursPreferences.hours.activeWeekdays = weekdays
    }
}
