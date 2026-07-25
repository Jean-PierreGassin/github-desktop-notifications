import SwiftUI

struct WorkHoursView: View {
    private static let weekdaySymbols = ["S", "M", "T", "W", "T", "F", "S"]
    private static let weekdayNames = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]

    let session: AppSession

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Work hours")
                    .font(.headline)

                Text("Outside your hours nothing pops up. Notifications still collect in the menu bar panel, "
                    + "so nothing is lost.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Toggle("Only notify me during work hours", isOn: binding(\.isEnabled))
                .toggleStyle(.switch)

            Group {
                hoursMode

                if hours.usesSameHoursEveryDay {
                    sharedHours
                } else {
                    perDayHours
                }

                Divider()

                heldDeliverySection
            }
            .disabled(!hours.isEnabled)
            .opacity(hours.isEnabled ? 1 : 0.5)

            Spacer(minLength: 0)
        }
    }

    private var hours: WorkHours {
        session.workHoursPreferences.hours
    }

    private var hoursMode: some View {
        Picker("Hours", selection: binding(\.usesSameHoursEveryDay)) {
            Text("Same hours every day").tag(true)
            Text("Different hours per day").tag(false)
        }
        .labelsHidden()
        .pickerStyle(.segmented)
    }

    private var sharedHours: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                TimeField(label: "From", minutes: sharedBinding(\.startMinutes))

                TimeField(label: "to", minutes: sharedBinding(\.endMinutes))

                Spacer(minLength: 0)
            }

            if let note = note(for: hours.sharedSchedule) {
                Text(note)
                    .font(.callout)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("On these days")
                    .font(.callout)

                HStack(spacing: 6) {
                    ForEach(Array(Self.weekdaySymbols.enumerated()), id: \.offset) { index, symbol in
                        weekdayChip(symbol: symbol, weekday: index + 1)
                    }
                }
            }

            if !hours.hasAnyEnabledDay {
                Text("No days are selected, so every notification will be held back.")
                    .font(.callout)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var perDayHours: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(WorkHours.allDays, id: \.self) { weekday in
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Toggle(isOn: dayEnabledBinding(for: weekday)) {
                            Text(Self.weekdayNames[weekday - 1])
                                .font(.callout)
                                .frame(width: 84, alignment: .leading)
                        }
                        .toggleStyle(.checkbox)

                        TimeField(label: nil, minutes: dayBinding(for: weekday, keyPath: \.startMinutes))
                            .disabled(!isDayEnabled(weekday))

                        Text("to")
                            .font(.callout)
                            .foregroundStyle(.secondary)

                        TimeField(label: nil, minutes: dayBinding(for: weekday, keyPath: \.endMinutes))
                            .disabled(!isDayEnabled(weekday))

                        Spacer(minLength: 0)
                    }

                    if isDayEnabled(weekday), let note = note(for: hours.schedule(for: weekday)) {
                        Text(note)
                            .font(.caption)
                            .foregroundStyle(.orange)
                            .padding(.leading, 104)
                    }
                }
            }
        }
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
                .font(.callout)
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

    private var heldDeliverySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("When notifications arrive outside work hours")
                .font(.callout)
                .fontWeight(.medium)

            Text("Notifications that arrive outside your hours are kept, then delivered together.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Picker("Deliver held notifications", selection: binding(\.heldDelivery)) {
                ForEach(HeldAlertDelivery.allCases, id: \.self) { option in
                    Text(option.displayName).tag(option)
                }
            }
            .labelsHidden()
            .pickerStyle(.radioGroup)

            Text(hours.heldDelivery.explanation)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if hours.heldDelivery == .atSetTime {
                TimeField(label: "Deliver at", minutes: binding(\.deliveryMinutes))

                if !hours.isDeliveryTimeWithinHours {
                    Text("That time falls outside every working day you have set, so held notifications will arrive "
                        + "when your hours start instead.")
                        .font(.callout)
                        .foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if !session.heldAlerts.isEmpty {
                Text("\(session.heldAlerts.heldThreads.count) waiting to be delivered.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
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
