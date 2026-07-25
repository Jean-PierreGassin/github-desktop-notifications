import Foundation

/// Reads and writes times of day as minutes past midnight, forgiving about how
/// they are typed: `230`, `2:30`, `2:30 am`, `14:30` and `9pm` all work.
enum TimeOfDay {
    static let minutesInADay = 24 * 60

    static func parse(_ input: String) -> Int? {
        let cleaned = input.lowercased().trimmingCharacters(in: .whitespaces)

        guard !cleaned.isEmpty else {
            return nil
        }

        let meridiem = detectMeridiem(in: cleaned)
        let digits = cleaned.filter(\.isNumber)

        guard let (hour, minute) = splitDigits(digits) else {
            return nil
        }

        return combine(hour: hour, minute: minute, meridiem: meridiem)
    }

    static func format(_ minutes: Int) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none

        let components = DateComponents(
            year: 2000,
            month: 1,
            day: 1,
            hour: minutes / 60,
            minute: minutes % 60,
        )

        guard let date = Calendar.current.date(from: components) else {
            return "\(minutes / 60):\(minutes % 60)"
        }

        return formatter.string(from: date)
    }

    private enum Meridiem {
        case morning
        case afternoon
        case unspecified
    }

    private static func detectMeridiem(in input: String) -> Meridiem {
        if input.contains("pm") {
            return .afternoon
        }

        return input.contains("am") ? .morning : .unspecified
    }

    private static func splitDigits(_ digits: String) -> (hour: Int, minute: Int)? {
        switch digits.count {
        case 1, 2:
            return Int(digits).map { ($0, 0) }
        case 3:
            return (Int(digits.prefix(1))!, Int(digits.suffix(2))!)
        case 4:
            return (Int(digits.prefix(2))!, Int(digits.suffix(2))!)
        default:
            return nil
        }
    }

    private static func combine(hour: Int, minute: Int, meridiem: Meridiem) -> Int? {
        guard minute < 60 else {
            return nil
        }

        switch meridiem {
        case .morning:
            guard (1 ... 12).contains(hour) else { return nil }
            return (hour % 12) * 60 + minute
        case .afternoon:
            guard (1 ... 12).contains(hour) else { return nil }
            return (hour % 12 + 12) * 60 + minute
        case .unspecified:
            guard hour < 24 else { return nil }
            return hour * 60 + minute
        }
    }
}
