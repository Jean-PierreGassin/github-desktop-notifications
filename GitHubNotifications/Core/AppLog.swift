import Foundation
import os

enum LogLevel: String, Sendable {
    case debug
    case info
    case warning
    case error
}

struct LogEntry: Identifiable, Sendable {
    let id = UUID()
    let timestamp: Date
    let level: LogLevel
    let message: String
}

/// Records everything the app does to both the unified log and an in-memory ring
/// buffer, so the Logs pane can show recent activity without asking the user to
/// open Console.
@MainActor
@Observable
final class AppLog {
    static let shared = AppLog()

    private static let retainedEntryLimit = 300

    private let logger: Logger

    private(set) var entries: [LogEntry] = []

    init(subsystem: String = Bundle.main.bundleIdentifier ?? "GitHubNotifications") {
        logger = Logger(subsystem: subsystem, category: "app")
    }

    func debug(_ message: String) {
        logger.debug("\(message, privacy: .public)")
        record(level: .debug, message: message)
    }

    func info(_ message: String) {
        logger.info("\(message, privacy: .public)")
        record(level: .info, message: message)
    }

    func warning(_ message: String) {
        logger.warning("\(message, privacy: .public)")
        record(level: .warning, message: message)
    }

    func error(_ message: String) {
        logger.error("\(message, privacy: .public)")
        record(level: .error, message: message)
    }

    func exportAsText() -> String {
        let formatter = ISO8601DateFormatter()

        return entries
            .map { entry in "\(formatter.string(from: entry.timestamp)) [\(entry.level.rawValue)] \(entry.message)" }
            .joined(separator: "\n")
    }

    private func record(level: LogLevel, message: String) {
        entries.append(LogEntry(timestamp: Date(), level: level, message: message))

        if entries.count > Self.retainedEntryLimit {
            entries.removeFirst(entries.count - Self.retainedEntryLimit)
        }
    }
}
