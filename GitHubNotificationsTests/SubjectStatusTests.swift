import Foundation
import Testing

@testable import GitHubNotifications

struct SubjectStatusTests {
    /// GitHub reports a merged pull request as closed as well, so the order the
    /// two are checked in is the whole decision.
    @Test
    func readsAMergedPullRequestAsMergedRatherThanClosed() {
        let response = SubjectStatusResponse(state: "closed", draft: false, merged: true)

        #expect(response.status == .merged)
    }

    @Test(arguments: [
        (SubjectStatusResponse(state: "closed", draft: false, merged: false), SubjectStatus.closed),
        (SubjectStatusResponse(state: "open", draft: true, merged: false), .draft),
        (SubjectStatusResponse(state: "open", draft: false, merged: false), .open),
    ])
    func readsThePullRequestStatesGitHubReports(response: SubjectStatusResponse, expected: SubjectStatus) {
        #expect(response.status == expected)
    }

    /// An issue carries neither `draft` nor `merged`, and must not be read as a
    /// draft just because the field is missing.
    @Test(arguments: [("open", SubjectStatus.open), ("closed", .closed)])
    func readsAnIssueThatCarriesNeitherDraftNorMerged(state: String, expected: SubjectStatus) {
        let response = SubjectStatusResponse(state: state, draft: nil, merged: nil)

        #expect(response.status == expected)
    }

    /// Open is the state most rows are in, and badging it would put a glyph on
    /// nearly every row to say nothing.
    @Test
    func badgesOnlyTheStatesWorthReactingTo() {
        #expect(!SubjectStatus.open.isWorthShowing)
        #expect(SubjectStatus.draft.isWorthShowing)
        #expect(SubjectStatus.merged.isWorthShowing)
        #expect(SubjectStatus.closed.isWorthShowing)
    }
}
