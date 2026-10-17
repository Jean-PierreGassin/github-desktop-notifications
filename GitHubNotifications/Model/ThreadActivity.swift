import Foundation

/// Someone who did something on a thread.
struct GitHubActor: Sendable, Equatable, Codable {
    private static let botSuffix = "[bot]"

    let login: String
    let isBot: Bool

    /// A bot's login carries a `[bot]` suffix that reads as noise in a caption,
    /// so it is said in words instead: "coderabbitai (bot)" rather than
    /// "@coderabbitai[bot]".
    var displayName: String {
        guard isBot else {
            return "@\(login)"
        }

        let name = login.hasSuffix(Self.botSuffix) ? String(login.dropLast(Self.botSuffix.count)) : login

        return "\(name) (bot)"
    }

    init(login: String, isBot: Bool) {
        self.login = login
        self.isBot = isBot
    }

    init(_ user: TimelineUser) {
        login = user.login
        isBot = user.type == "Bot" || user.login.hasSuffix(Self.botSuffix)
    }

    func isSameAccount(as login: String?) -> Bool {
        guard let login else {
            return false
        }

        return self.login.caseInsensitiveCompare(login) == .orderedSame
    }
}

enum ReviewVerdict: String, Sendable, Codable {
    case approved
    case changesRequested = "changes_requested"
    case commented
}

/// Exactly what happened on a pull request or issue to put it back in the
/// inbox, and who did it.
///
/// GitHub's notification names a reason and nothing else, so the same "Review
/// requested from you" used to stand for a bot's comment, a colleague's
/// approval and the merge alike. The timeline of the subject is where the event
/// and its actor are actually recorded.
enum ThreadActivity: Sendable, Equatable, Codable {
    case commented(by: GitHubActor)
    case mentionedYou(by: GitHubActor)
    case reviewed(by: GitHubActor, verdict: ReviewVerdict)
    case reviewRequestedFromYou(by: GitHubActor)
    case reviewRequested(by: GitHubActor, from: String)
    case assignedYou(by: GitHubActor)
    case assigned(by: GitHubActor, assignee: String)
    case merged(by: GitHubActor)
    case closed(by: GitHubActor)
    case reopened(by: GitHubActor)
    case readyForReview(by: GitHubActor)
    case convertedToDraft(by: GitHubActor)
    case forcePushed(by: GitHubActor)
    case pushedCommits

    var description: String {
        switch self {
        case let .commented(actor): "\(actor.displayName) commented"
        case let .mentionedYou(actor): "\(actor.displayName) mentioned you"
        case let .reviewed(actor, .approved): "\(actor.displayName) approved"
        case let .reviewed(actor, .changesRequested): "\(actor.displayName) requested changes"
        case let .reviewed(actor, .commented): "\(actor.displayName) left a review"
        case let .reviewRequestedFromYou(actor): "\(actor.displayName) requested your review"
        case let .reviewRequested(actor, reviewer): "\(actor.displayName) requested a review from \(reviewer)"
        case let .assignedYou(actor): "\(actor.displayName) assigned you"
        case let .assigned(actor, assignee): "\(actor.displayName) assigned @\(assignee)"
        case let .merged(actor): "Merged by \(actor.displayName)"
        case let .closed(actor): "Closed by \(actor.displayName)"
        case let .reopened(actor): "Reopened by \(actor.displayName)"
        case let .readyForReview(actor): "\(actor.displayName) marked it ready for review"
        case let .convertedToDraft(actor): "\(actor.displayName) converted it to a draft"
        case let .forcePushed(actor): "\(actor.displayName) force-pushed"
        case .pushedCommits: "New commits pushed"
        }
    }

    /// The caption: why the thread is the user's, then what just happened on
    /// it. Where the event is the reason itself, the event says it better on its
    /// own: "@alice requested your review" rather than "Review requested from
    /// you · @alice requested your review".
    func caption(for reason: NotificationReason) -> String {
        guard !restates(reason) else {
            return description
        }

        return "\(reason.displayName) · \(description)"
    }

    private func restates(_ reason: NotificationReason) -> Bool {
        switch (self, reason) {
        case (.reviewRequestedFromYou, .reviewRequested), (.assignedYou, .assigned), (.mentionedYou, .mentioned):
            true
        default:
            false
        }
    }
}

extension ThreadActivity {
    /// How far before the notification's own timestamp an event may be and still
    /// be what caused it. GitHub stamps a thread moments after the event, so
    /// anything older is history rather than the news.
    static let causeWindow: TimeInterval = 15 * 60

    /// How far after it an event may be. Anything later happened after the
    /// notification, most often the user's own reply to it.
    static let clockSlack: TimeInterval = 60

    /// The newest event by someone other than the user that lands close enough
    /// to the thread's update to have caused it, or nothing when none does and
    /// the timeline cannot say what happened.
    ///
    /// The user's own events are skipped: GitHub never notifies anyone about
    /// what they did themselves.
    static func latest(
        in events: [TimelineEvent],
        for thread: NotificationThread,
        viewerLogin: String?,
    ) -> ThreadActivity? {
        let earliest = thread.updatedAt.addingTimeInterval(-causeWindow)
        let latest = thread.updatedAt.addingTimeInterval(clockSlack)

        let candidates = events.compactMap { event -> (occurredAt: Date, activity: ThreadActivity)? in
            guard let occurredAt = event.occurredAt, occurredAt >= earliest, occurredAt <= latest else {
                return nil
            }

            guard event.performer.map({ !$0.isSameAccount(as: viewerLogin) }) ?? true else {
                return nil
            }

            return activity(from: event, reason: thread.reason, viewerLogin: viewerLogin).map { (occurredAt, $0) }
        }

        return candidates.max { $0.occurredAt < $1.occurredAt }?.activity
    }

    /// Events nobody is notified about, such as labels and cross-references,
    /// describe nothing and are left out.
    private static func activity(
        from event: TimelineEvent,
        reason: NotificationReason,
        viewerLogin: String?,
    ) -> ThreadActivity? {
        if event.event == "committed" {
            return .pushedCommits
        }

        guard let actor = event.performer else {
            return nil
        }

        switch event.event {
        case "commented":
            return commentActivity(by: actor, body: event.body, reason: reason, viewerLogin: viewerLogin)
        case "reviewed":
            return event.state.flatMap(ReviewVerdict.init(rawValue:)).map { .reviewed(by: actor, verdict: $0) }
        case "review_requested":
            return reviewRequestActivity(by: actor, event: event, viewerLogin: viewerLogin)
        case "assigned":
            return assignmentActivity(by: actor, assignee: event.assignee, viewerLogin: viewerLogin)
        case "merged":
            return .merged(by: actor)
        case "closed":
            return .closed(by: actor)
        case "reopened":
            return .reopened(by: actor)
        case "ready_for_review":
            return .readyForReview(by: actor)
        case "convert_to_draft":
            return .convertedToDraft(by: actor)
        case "head_ref_force_pushed":
            return .forcePushed(by: actor)
        default:
            return nil
        }
    }

    private static func commentActivity(
        by actor: GitHubActor,
        body: String?,
        reason: NotificationReason,
        viewerLogin: String?,
    ) -> ThreadActivity {
        guard reason == .mentioned, let viewerLogin, let body,
              body.localizedCaseInsensitiveContains("@\(viewerLogin)")
        else {
            return .commented(by: actor)
        }

        return .mentionedYou(by: actor)
    }

    private static func reviewRequestActivity(
        by actor: GitHubActor,
        event: TimelineEvent,
        viewerLogin: String?,
    ) -> ThreadActivity? {
        if let team = event.requestedTeam {
            return .reviewRequested(by: actor, from: team.name)
        }

        guard let reviewer = event.requestedReviewer else {
            return nil
        }

        guard !GitHubActor(reviewer).isSameAccount(as: viewerLogin) else {
            return .reviewRequestedFromYou(by: actor)
        }

        return .reviewRequested(by: actor, from: GitHubActor(reviewer).displayName)
    }

    private static func assignmentActivity(
        by actor: GitHubActor,
        assignee: TimelineUser?,
        viewerLogin: String?,
    ) -> ThreadActivity? {
        guard let assignee else {
            return nil
        }

        guard !GitHubActor(assignee).isSameAccount(as: viewerLogin) else {
            return .assignedYou(by: actor)
        }

        return .assigned(by: actor, assignee: assignee.login)
    }
}

struct TimelineUser: Sendable, Equatable, Decodable {
    let login: String
    let type: String?
}

struct TimelineTeam: Sendable, Equatable, Decodable {
    let name: String
}

struct TimelineCommitter: Sendable, Equatable, Decodable {
    let date: Date?
}

/// One entry of an issue or pull request timeline. Every field is optional
/// because the entries share nothing but a name, and one unexpected shape must
/// not cost the rest of the timeline.
struct TimelineEvent: Sendable, Equatable, Decodable {
    let event: String?
    let actor: TimelineUser?
    let user: TimelineUser?
    let createdAt: Date?
    let submittedAt: Date?
    let state: String?
    let body: String?
    let requestedReviewer: TimelineUser?
    let requestedTeam: TimelineTeam?
    let assignee: TimelineUser?
    let committer: TimelineCommitter?

    enum CodingKeys: String, CodingKey {
        case event
        case actor
        case user
        case createdAt = "created_at"
        case submittedAt = "submitted_at"
        case state
        case body
        case requestedReviewer = "requested_reviewer"
        case requestedTeam = "requested_team"
        case assignee
        case committer
    }

    /// A review carries its author as `user` rather than `actor`.
    var performer: GitHubActor? {
        (actor ?? user).map(GitHubActor.init)
    }

    /// Reviews and commits keep their time under names of their own.
    var occurredAt: Date? {
        createdAt ?? submittedAt ?? committer?.date
    }

    /// The timeline of a pull request lives under its issue, so both subject
    /// URLs lead to the same place. Anything else has no timeline.
    static func timelineURL(forSubjectAt subjectURL: URL) -> URL? {
        let pathSegments = subjectURL.pathComponents.filter { $0 != "/" }

        guard pathSegments.count == 5, pathSegments[0] == "repos",
              ["issues", "pulls"].contains(pathSegments[3])
        else {
            return nil
        }

        var components = URLComponents(url: subjectURL, resolvingAgainstBaseURL: false)
        components?.path = "/repos/\(pathSegments[1])/\(pathSegments[2])/issues/\(pathSegments[4])/timeline"

        return components?.url
    }
}
