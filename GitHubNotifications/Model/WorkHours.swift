import Foundation

enum HeldAlertDelivery: String, Sendable, Codable, CaseIterable {
    case whenHoursStart
    case atSetTime

    var displayName: String {
        switch self {
        case .whenHoursStart: "As soon as the next work day starts"
        case .atSetTime: "At a set time within the next work day"
        }
    }

    var explanation: String {
        switch self {
        case .whenHoursStart:
            "Anything held overnight or over a weekend arrives the moment your next working day opens."
        case .atSetTime:
            "Anything held waits until this time on your next working day, so you choose when to catch up."
        }
    }
}

/// One day's working window.
struct DaySchedule: Sendable, Equatable, Codable {
    var isEnabled: Bool
    var startMinutes: Int
    var endMinutes: Int

    static let standard = DaySchedule(isEnabled: true, startMinutes: 9 * 60, endMinutes: 17 * 60)
    static let off = DaySchedule(isEnabled: false, startMinutes: 9 * 60, endMinutes: 17 * 60)

    /// A window ending before it starts carries on into the following day, which
    /// is legitimate for night shifts but worth spelling out.
    var runsPastMidnight: Bool {
        startMinutes > endMinutes
    }

    var isRoundTheClock: Bool {
        startMinutes == endMinutes
    }

    var summary: String {
        if isRoundTheClock {
            return "All day"
        }

        let window = "\(TimeOfDay.format(startMinutes)) to \(TimeOfDay.format(endMinutes))"

        return runsPastMidnight ? "\(window) the next day" : window
    }
}

/// When the user is willing to be interrupted, and what happens to alerts that
/// arrive outside those hours.
///
/// Times are minutes past midnight so the whole thing stays a plain value that
/// is trivial to persist and to test. Windows that run past midnight are
/// supported: the weekday is matched against the day the window opened.
struct WorkHours: Sendable, Equatable, Codable {
    static let weekdays = [2, 3, 4, 5, 6]
    static let allDays = [1, 2, 3, 4, 5, 6, 7]

    var isEnabled = false
    var usesSameHoursEveryDay = true
    var sharedSchedule = DaySchedule.standard
    var activeWeekdays: Set<Int> = Set(WorkHours.weekdays)
    var daySchedules: [Int: DaySchedule] = Dictionary(
        uniqueKeysWithValues: WorkHours.allDays.map { weekday in
            (weekday, WorkHours.weekdays.contains(weekday) ? DaySchedule.standard : DaySchedule.off)
        },
    )
    var heldDelivery: HeldAlertDelivery = .whenHoursStart
    var deliveryMinutes = 9 * 60

    /// The window that applies on a given weekday, whichever mode is in use.
    func schedule(for weekday: Int) -> DaySchedule {
        guard usesSameHoursEveryDay else {
            return daySchedules[weekday] ?? .off
        }

        return DaySchedule(
            isEnabled: activeWeekdays.contains(weekday),
            startMinutes: sharedSchedule.startMinutes,
            endMinutes: sharedSchedule.endMinutes,
        )
    }

    /// Whether an alert arriving now is allowed through.
    func isWithinHours(_ date: Date, calendar: Calendar = .current) -> Bool {
        let minute = minuteOfDay(date, calendar: calendar)
        let weekday = calendar.component(.weekday, from: date)

        if isWithin(schedule(for: weekday), minute: minute, allowingWrap: false) {
            return true
        }

        return isWithin(schedule(for: previousWeekday(before: weekday)), minute: minute, allowingWrap: true)
    }

    /// Whether held alerts should be released now.
    func isHeldDeliveryDue(at date: Date, calendar: Calendar = .current) -> Bool {
        guard isWithinHours(date, calendar: calendar) else {
            return false
        }

        guard heldDelivery == .atSetTime else {
            return true
        }

        let weekday = calendar.component(.weekday, from: date)
        let today = schedule(for: weekday)
        let minute = minuteOfDay(date, calendar: calendar)

        guard isDeliveryTime(within: today) else {
            return true
        }

        return offset(of: minute, in: today) >= offset(of: deliveryMinutes, in: today)
    }

    /// A delivery time outside every window would never arrive, so the UI warns
    /// and the logic falls back to the start of the window.
    var isDeliveryTimeWithinHours: Bool {
        enabledSchedules.contains { isDeliveryTime(within: $0) }
    }

    var hasAnyEnabledDay: Bool {
        !enabledSchedules.isEmpty
    }

    private var enabledSchedules: [DaySchedule] {
        Self.allDays.map(schedule(for:)).filter(\.isEnabled)
    }

    private func isDeliveryTime(within daySchedule: DaySchedule) -> Bool {
        daySchedule.isEnabled && offset(of: deliveryMinutes, in: daySchedule) < length(of: daySchedule)
    }

    /// `allowingWrap` looks only at the part of an overnight window that spills
    /// past midnight, which belongs to the previous day.
    private func isWithin(_ daySchedule: DaySchedule, minute: Int, allowingWrap: Bool) -> Bool {
        guard daySchedule.isEnabled else {
            return false
        }

        let runsPastMidnight = daySchedule.startMinutes > daySchedule.endMinutes

        guard runsPastMidnight else {
            return !allowingWrap && minute >= daySchedule.startMinutes && minute < daySchedule.endMinutes
        }

        return allowingWrap ? minute < daySchedule.endMinutes : minute >= daySchedule.startMinutes
    }

    private func length(of daySchedule: DaySchedule) -> Int {
        let span = (daySchedule.endMinutes - daySchedule.startMinutes + TimeOfDay.minutesInADay) % TimeOfDay.minutesInADay

        return span == 0 ? TimeOfDay.minutesInADay : span
    }

    private func offset(of minute: Int, in daySchedule: DaySchedule) -> Int {
        (minute - daySchedule.startMinutes + TimeOfDay.minutesInADay) % TimeOfDay.minutesInADay
    }

    private func minuteOfDay(_ date: Date, calendar: Calendar) -> Int {
        let components = calendar.dateComponents([.hour, .minute], from: date)

        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }

    private func previousWeekday(before weekday: Int) -> Int {
        weekday == 1 ? 7 : weekday - 1
    }
}
