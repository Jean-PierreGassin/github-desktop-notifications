import Testing

@testable import GitHubNotifications

struct TimeOfDayTests {
    @Test(arguments: [
        ("9", 9 * 60),
        ("09", 9 * 60),
        ("930", 9 * 60 + 30),
        ("9:30", 9 * 60 + 30),
        ("0930", 9 * 60 + 30),
        ("230am", 2 * 60 + 30),
        ("2:30 AM", 2 * 60 + 30),
        ("230pm", 14 * 60 + 30),
        ("9pm", 21 * 60),
        ("12am", 0),
        ("12pm", 12 * 60),
        ("1430", 14 * 60 + 30),
        ("14:30", 14 * 60 + 30),
        ("  17:05  ", 17 * 60 + 5),
    ])
    func acceptsTheWaysPeopleActuallyTypeATime(input: String, expectedMinutes: Int) {
        #expect(TimeOfDay.parse(input) == expectedMinutes)
    }

    @Test(arguments: ["", "abc", "99:99", "970", "25:00", "13am", "123456"])
    func rejectsInputItCannotReadAsATime(input: String) {
        #expect(TimeOfDay.parse(input) == nil)
    }

    @Test
    func roundTripsAFormattedTime() {
        let formatted = TimeOfDay.format(14 * 60 + 30)

        #expect(TimeOfDay.parse(formatted) == 14 * 60 + 30)
    }
}
