import Foundation
import Testing

@testable import GitHubNotifications

@MainActor
struct WorkHoursPreferencesTests {
    @Test
    func resettingHoursRestoresTheWindowWithoutTouchingTheDays() {
        let preferences = makePreferences()
        preferences.hours.isEnabled = true
        preferences.hours.sharedSchedule.startMinutes = 3 * 60
        preferences.hours.activeWeekdays = [1]

        preferences.resetHours()

        #expect(preferences.hours.sharedSchedule == DaySchedule.standard)
        #expect(!preferences.hours.isEnabled)
        #expect(preferences.hours.activeWeekdays == [1])
    }

    @Test
    func resettingDaysRestoresTheWeekWithoutTouchingTheWindow() {
        let preferences = makePreferences()
        preferences.hours.sharedSchedule.startMinutes = 3 * 60
        preferences.hours.activeWeekdays = [1]
        preferences.hours.daySchedules[2] = .off

        preferences.resetDays()

        #expect(preferences.hours.activeWeekdays == Set(WorkHours.weekdays))
        #expect(preferences.hours.daySchedules[2] == DaySchedule.standard)
        #expect(preferences.hours.sharedSchedule.startMinutes == 3 * 60)
    }

    @Test
    func resettingHeldDeliveryRestoresBothTheModeAndTheTime() {
        let preferences = makePreferences()
        preferences.hours.heldDelivery = .atSetTime
        preferences.hours.deliveryMinutes = 23 * 60

        preferences.resetHeldDelivery()

        #expect(preferences.hours.heldDelivery == .whenHoursStart)
        #expect(preferences.hours.deliveryMinutes == WorkHours().deliveryMinutes)
    }

    @Test
    func aResetSurvivesTheNextLaunch() {
        let defaults = makeDefaults()
        let preferences = WorkHoursPreferences(defaults: defaults)
        preferences.hours.isEnabled = true

        preferences.resetHours()

        #expect(!WorkHoursPreferences(defaults: defaults).hours.isEnabled)
    }

    private func makePreferences() -> WorkHoursPreferences {
        WorkHoursPreferences(defaults: makeDefaults())
    }

    private func makeDefaults() -> UserDefaults {
        UserDefaults(suiteName: "work-hours-preferences-tests-\(UUID().uuidString)")!
    }
}
