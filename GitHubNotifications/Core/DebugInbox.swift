#if DEBUG
import Foundation

@MainActor
final class DebugInbox {
    private static let identifierPrefix = "debug-sample-"

    private(set) var threads: [NotificationThread]

    init(now: Date = Date()) {
        let desktopRepository = Self.repository(
            id: -1,
            fullName: "sample/desktop",
            isPrivate: false,
        )
        let apiRepository = Self.repository(
            id: -2,
            fullName: "sample/private-api",
            isPrivate: true,
        )

        threads = [
            Self.thread(
                id: "review",
                reason: .reviewRequested,
                updatedAt: now,
                title: "Review the notification actions",
                subjectType: .pullRequest,
                subjectAPIPath: "pulls/42",
                repository: desktopRepository,
            ),
            Self.thread(
                id: "mention",
                reason: .mentioned,
                updatedAt: now.addingTimeInterval(-300),
                title: "Check the menu bar confirmation",
                subjectType: .issue,
                subjectAPIPath: "issues/18",
                repository: desktopRepository,
            ),
            Self.thread(
                id: "assigned",
                reason: .assigned,
                updatedAt: now.addingTimeInterval(-900),
                isUnread: false,
                title: "Already-read row for dismissal",
                subjectType: .discussion,
                subjectAPIPath: "discussions/7",
                repository: apiRepository,
            ),
        ]
    }

    func contains(_ thread: NotificationThread) -> Bool {
        thread.id.hasPrefix(Self.identifierPrefix)
    }

    func merge(with fetchedThreads: [NotificationThread]) -> [NotificationThread] {
        fetchedThreads + threads
    }

    func apply(_ behaviour: ClickBehaviour, to thread: NotificationThread) {
        guard let index = threads.firstIndex(where: { $0.id == thread.id }) else {
            return
        }

        guard !behaviour.dismisses else {
            threads.remove(at: index)
            return
        }

        threads[index] = threads[index].markedRead()
    }

    func markAllRead() {
        threads = threads.map { $0.markedRead() }
    }

    private static func repository(
        id: Int,
        fullName: String,
        isPrivate: Bool,
    ) -> NotificationRepository {
        let pathParts = fullName.split(separator: "/")

        return NotificationRepository(
            id: id,
            name: String(pathParts.last ?? "sample"),
            fullName: fullName,
            isPrivate: isPrivate,
            htmlURL: URL(string: "https://github.com/\(fullName)")!,
            owner: RepositoryOwner(login: String(pathParts[0]), avatarURL: nil),
        )
    }

    private static func thread(
        id: String,
        reason: NotificationReason,
        updatedAt: Date,
        isUnread: Bool = true,
        title: String,
        subjectType: NotificationSubjectType,
        subjectAPIPath: String,
        repository: NotificationRepository,
    ) -> NotificationThread {
        NotificationThread(
            id: "\(identifierPrefix)\(id)",
            isUnread: isUnread,
            reason: reason,
            updatedAt: updatedAt,
            subject: NotificationSubject(
                title: title,
                type: subjectType,
                apiURL: URL(string: "https://api.github.com/repos/\(repository.fullName)/\(subjectAPIPath)"),
                latestCommentAPIURL: nil,
            ),
            repository: repository,
        )
    }
}
#endif
