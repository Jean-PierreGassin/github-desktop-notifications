import Foundation

/// Turns a notification thread into the github.com page a human wants to land on.
///
/// The API only ever gives an `api.github.com` URL for the subject, and for some
/// subject types not even that, so the mapping is done locally rather than
/// spending a request per notification.
enum ThreadURL {
    private static let webHost = "https://github.com"

    static func derive(for thread: NotificationThread) -> URL {
        let pageURL = derivePageURL(for: thread)

        guard let anchor = commentAnchor(for: thread) else {
            return pageURL
        }

        return URL(string: pageURL.absoluteString + anchor) ?? pageURL
    }

    private static func derivePageURL(for thread: NotificationThread) -> URL {
        if let derivedFromSubject = deriveFromSubjectAPIURL(thread) {
            return derivedFromSubject
        }

        let section = repositorySection(for: thread.subject.type)

        guard !section.isEmpty else {
            return thread.repository.htmlURL
        }

        return thread.repository.htmlURL.appending(path: section)
    }

    private static func deriveFromSubjectAPIURL(_ thread: NotificationThread) -> URL? {
        guard let apiURL = thread.subject.apiURL else {
            return nil
        }

        let pathSegments = apiURL.pathComponents.filter { $0 != "/" }

        guard pathSegments.count >= 5, pathSegments[0] == "repos" else {
            return nil
        }

        let owner = pathSegments[1]
        let repository = pathSegments[2]
        let resource = pathSegments[3]
        let identifier = pathSegments[4]

        guard let webResource = webResourceName(for: resource) else {
            return nil
        }

        return URL(string: "\(webHost)/\(owner)/\(repository)/\(webResource)/\(identifier)")
    }

    private static func webResourceName(for apiResource: String) -> String? {
        switch apiResource {
        case "issues": "issues"
        case "pulls": "pull"
        case "commits": "commit"
        case "discussions": "discussions"
        default: nil
        }
    }

    /// Where to land when GitHub gives no subject URL at all.
    private static func repositorySection(for subjectType: NotificationSubjectType) -> String {
        switch subjectType {
        case .checkSuite: "actions"
        case .repositoryVulnerabilityAlert, .repositoryDependabotAlertsThread: "security/dependabot"
        case .repositoryInvitation: "invitations"
        case .discussion: "discussions"
        case .release: "releases"
        case .issue, .pullRequest, .commit, .unrecognised: ""
        }
    }

    private static func commentAnchor(for thread: NotificationThread) -> String? {
        guard let commentURL = thread.subject.latestCommentAPIURL?.absoluteString,
              let commentIdentifier = commentURL.split(separator: "/").last,
              Int(commentIdentifier) != nil
        else {
            return nil
        }

        if commentURL.contains("/issues/comments/") {
            return "#issuecomment-\(commentIdentifier)"
        }

        if commentURL.contains("/pulls/comments/") {
            return "#discussion_r\(commentIdentifier)"
        }

        return nil
    }
}
