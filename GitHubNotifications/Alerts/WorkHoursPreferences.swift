import Foundation

/// Persists the work hours settings.
@MainActor
@Observable
final class WorkHoursPreferences {
    private static let storageKey = "workHours"

    private let defaults: UserDefaults

    var hours: WorkHours {
        didSet { save() }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        guard let stored = defaults.data(forKey: Self.storageKey),
              let decoded = try? JSONDecoder().decode(WorkHours.self, from: stored)
        else {
            hours = WorkHours()
            return
        }

        hours = decoded
    }

    /// Settings resets a section at a time, so the three below restore only the
    /// fields their section owns. Each reads a fresh ``WorkHours`` rather than
    /// repeating what the defaults are.
    func resetHours() {
        let defaults = WorkHours()

        hours.isEnabled = defaults.isEnabled
        hours.usesSameHoursEveryDay = defaults.usesSameHoursEveryDay
        hours.sharedSchedule = defaults.sharedSchedule
    }

    func resetDays() {
        let defaults = WorkHours()

        hours.activeWeekdays = defaults.activeWeekdays
        hours.daySchedules = defaults.daySchedules
    }

    func resetHeldDelivery() {
        let defaults = WorkHours()

        hours.heldDelivery = defaults.heldDelivery
        hours.deliveryMinutes = defaults.deliveryMinutes
    }

    private func save() {
        guard let encoded = try? JSONEncoder().encode(hours) else {
            return
        }

        defaults.set(encoded, forKey: Self.storageKey)
    }
}
