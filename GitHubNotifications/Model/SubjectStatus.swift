import Foundation

/// Where a pull request or issue currently stands.
///
/// The notifications endpoint does not carry this. It says what a thread is and
/// what it is called, never whether the pull request underneath it is still open,
/// so a merged pull request and one waiting on you read identically in the panel.
/// Reading it costs a request against the subject itself, which is why it is
/// fetched for rows on screen rather than for the whole inbox.
enum SubjectStatus: String, Sendable, Equatable, Codable {
    case open
    case draft
    case merged
    case closed

    /// Sits beside the reason icon rather than replacing it. The reason is why
    /// the thread reached the user and does not stop being true when a pull
    /// request merges, so the two say different things and both are worth a
    /// glyph.
    var symbolName: String {
        switch self {
        case .open: "circle"
        case .draft: "circle.dashed"
        case .merged: "arrow.triangle.merge"
        case .closed: "xmark.circle"
        }
    }

    var displayName: String {
        switch self {
        case .open: "Open"
        case .draft: "Draft"
        case .merged: "Merged"
        case .closed: "Closed"
        }
    }

    /// Open is the ordinary case and the one most rows are in. Badging it would
    /// put a glyph on nearly every row to say nothing, which is the noise this
    /// panel is meant to be free of, so only the states worth reacting to show.
    var isWorthShowing: Bool {
        self != .open
    }
}

/// The parts of a pull request or issue that say where it stands.
///
/// GitHub answers with different shapes for the two: a pull request carries
/// `draft` and `merged`, an issue carries neither, and both carry `state`.
/// Decoding them as one optional-tolerant shape keeps a single request path for
/// both rather than branching on the subject type before the response is even in.
struct SubjectStatusResponse: Sendable, Equatable, Codable {
    let state: String
    let draft: Bool?
    let merged: Bool?

    /// Merged is checked before closed because GitHub reports a merged pull
    /// request as `closed` as well, and "merged" is the more useful of the two.
    var status: SubjectStatus {
        if merged == true {
            return .merged
        }

        if state == "closed" {
            return .closed
        }

        return draft == true ? .draft : .open
    }
}
