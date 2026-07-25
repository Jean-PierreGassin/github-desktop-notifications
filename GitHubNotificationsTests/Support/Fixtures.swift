import Foundation

@testable import GitHubNotifications

enum Fixtures {
    static func repository(
        id: Int = 1,
        fullName: String = "acme/api",
        isPrivate: Bool = false,
    ) -> NotificationRepository {
        NotificationRepository(
            id: id,
            name: String(fullName.split(separator: "/").last ?? "api"),
            fullName: fullName,
            isPrivate: isPrivate,
            htmlURL: URL(string: "https://github.com/\(fullName)")!,
            owner: RepositoryOwner(login: String(fullName.split(separator: "/")[0]), avatarURL: nil),
        )
    }

    static func thread(
        id: String = "1",
        reason: NotificationReason = .subscribed,
        updatedAt: Date = Date(timeIntervalSince1970: 1_700_000_000),
        isUnread: Bool = true,
        title: String = "Fix token refresh",
        subjectType: NotificationSubjectType = .pullRequest,
        subjectAPIURL: String? = "https://api.github.com/repos/acme/api/pulls/412",
        latestCommentAPIURL: String? = nil,
        repository: NotificationRepository = Fixtures.repository(),
    ) -> NotificationThread {
        NotificationThread(
            id: id,
            isUnread: isUnread,
            reason: reason,
            updatedAt: updatedAt,
            subject: NotificationSubject(
                title: title,
                type: subjectType,
                apiURL: subjectAPIURL.flatMap(URL.init(string:)),
                latestCommentAPIURL: latestCommentAPIURL.flatMap(URL.init(string:)),
            ),
            repository: repository,
        )
    }

    /// A directory of its own per test, so ledgers never touch the real
    /// Application Support folder or each other.
    static func temporaryDirectory() -> URL {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)

        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        return directory
    }

    @MainActor
    static func readLedger() -> ReadThreadLedger {
        ReadThreadLedger(
            fileURL: temporaryDirectory().appending(path: "read-threads.json"),
            log: AppLog(subsystem: "tests"),
        )
    }

    @MainActor
    static func store(rowsPerRepository: Int = 5, readLedger: ReadThreadLedger? = nil) -> NotificationStore {
        NotificationStore(rowsPerRepository: rowsPerRepository, readLedger: readLedger ?? Fixtures.readLedger())
    }
}
