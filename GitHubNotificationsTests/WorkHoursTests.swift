import Foundation
import Testing

@testable import GitHubNotifications

struct WorkHoursTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!

        return calendar
    }()

    // 2026-07-20 is a Monday, 2026-07-25 a Saturday.
    private func date(day: Int, hour: Int, minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 7, day: day, hour: hour, minute: minute))!
    }

    private func makeSharedHours(start: Int = 9 * 60, end: Int = 17 * 60) -> WorkHours {
        var hours = WorkHours()
        hours.isEnabled = true
        hours.usesSameHoursEveryDay = true
        hours.sharedSchedule = DaySchedule(isEnabled: true, startMinutes: start, endMinutes: end)
        hours.activeWeekdays = Set(WorkHours.weekdays)

        return hours
    }

    @Test(arguments: [(9, true), (12, true), (16, true), (8, false), (17, false), (23, false)])
    func letsNotificationsThroughOnlyBetweenTheChosenHours(hour: Int, isWithin: Bool) {
        #expect(makeSharedHours().isWithinHours(date(day: 20, hour: hour), calendar: calendar) == isWithin)
    }

    @Test
    func holdsNotificationsOnDaysThatAreTurnedOff() {
        #expect(!makeSharedHours().isWithinHours(date(day: 25, hour: 12), calendar: calendar))
    }

    @Test
    func holdsEverythingWhenNoDaysAreSelected() {
        var hours = makeSharedHours()
        hours.activeWeekdays = []

        #expect(!hours.isWithinHours(date(day: 20, hour: 12), calendar: calendar))
        #expect(!hours.hasAnyEnabledDay)
    }

    @Test
    func handlesAWindowThatRunsPastMidnight() {
        let nightShift = makeSharedHours(start: 22 * 60, end: 6 * 60)

        #expect(nightShift.isWithinHours(date(day: 20, hour: 23), calendar: calendar))
        #expect(nightShift.isWithinHours(date(day: 21, hour: 2), calendar: calendar))
        #expect(!nightShift.isWithinHours(date(day: 21, hour: 7), calendar: calendar))
    }

    @Test
    func creditsAnAfterMidnightHourToTheDayTheWindowOpened() {
        var mondayNightsOnly = makeSharedHours(start: 22 * 60, end: 6 * 60)
        mondayNightsOnly.activeWeekdays = [2]

        #expect(mondayNightsOnly.isWithinHours(date(day: 21, hour: 2), calendar: calendar))
        #expect(!mondayNightsOnly.isWithinHours(date(day: 22, hour: 2), calendar: calendar))
    }

    @Test
    func usesEachDaysOwnHoursWhenTheyAreSetIndividually() {
        var hours = WorkHours()
        hours.isEnabled = true
        hours.usesSameHoursEveryDay = false
        hours.daySchedules[2] = DaySchedule(isEnabled: true, startMinutes: 7 * 60, endMinutes: 12 * 60)
        hours.daySchedules[3] = DaySchedule(isEnabled: true, startMinutes: 13 * 60, endMinutes: 18 * 60)

        #expect(hours.isWithinHours(date(day: 20, hour: 8), calendar: calendar))
        #expect(!hours.isWithinHours(date(day: 20, hour: 14), calendar: calendar))
        #expect(!hours.isWithinHours(date(day: 21, hour: 8), calendar: calendar))
        #expect(hours.isWithinHours(date(day: 21, hour: 14), calendar: calendar))
    }

    @Test
    func ignoresSharedDaySelectionWhenEachDayHasItsOwnHours() {
        var hours = makeSharedHours()
        hours.usesSameHoursEveryDay = false
        hours.activeWeekdays = []
        hours.daySchedules[2] = DaySchedule(isEnabled: true, startMinutes: 9 * 60, endMinutes: 17 * 60)

        #expect(hours.isWithinHours(date(day: 20, hour: 12), calendar: calendar))
    }

    @Test
    func releasesHeldNotificationsAsSoonAsHoursStart() {
        let hours = makeSharedHours()

        #expect(hours.isHeldDeliveryDue(at: date(day: 20, hour: 9), calendar: calendar))
        #expect(!hours.isHeldDeliveryDue(at: date(day: 20, hour: 8), calendar: calendar))
    }

    @Test
    func waitsForTheSetTimeBeforeReleasingHeldNotifications() {
        var hours = makeSharedHours()
        hours.heldDelivery = .atSetTime
        hours.deliveryMinutes = 11 * 60

        #expect(!hours.isHeldDeliveryDue(at: date(day: 20, hour: 10), calendar: calendar))
        #expect(hours.isHeldDeliveryDue(at: date(day: 20, hour: 11), calendar: calendar))
        #expect(hours.isHeldDeliveryDue(at: date(day: 20, hour: 15), calendar: calendar))
    }

    @Test
    func neverStrandsHeldNotificationsWhenTheSetTimeFallsOutsideTheHours() {
        var hours = makeSharedHours()
        hours.heldDelivery = .atSetTime
        hours.deliveryMinutes = 3 * 60

        #expect(!hours.isDeliveryTimeWithinHours)
        #expect(hours.isHeldDeliveryDue(at: date(day: 20, hour: 9), calendar: calendar))
    }

    @Test
    func neverReleasesHeldNotificationsOutsideTheHours() {
        var hours = makeSharedHours()
        hours.heldDelivery = .atSetTime
        hours.deliveryMinutes = 11 * 60

        #expect(!hours.isHeldDeliveryDue(at: date(day: 20, hour: 20), calendar: calendar))
        #expect(!hours.isHeldDeliveryDue(at: date(day: 25, hour: 12), calendar: calendar))
    }
}
