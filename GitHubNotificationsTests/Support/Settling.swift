import Foundation
import Testing

/// Waits for background work to land.
///
/// The caches answer from memory and fill in behind a fetch, so a test has to
/// wait for the fetch itself. Pausing for a fixed moment instead is a bet on how
/// busy the machine is, and CI is where that bet gets lost: the suite passed on
/// a laptop and failed on a loaded runner, three tests at a time.
///
/// The timeout is long because it is only ever reached when something is
/// genuinely stuck. Work that lands takes a few milliseconds and the wait ends
/// with it, so a generous ceiling costs the suite nothing.
@MainActor
func waitUntil(
    within timeout: Duration = .seconds(10),
    sourceLocation: SourceLocation = #_sourceLocation,
    _ isSatisfied: () -> Bool,
) async throws {
    let deadline = ContinuousClock.now + timeout

    while !isSatisfied() {
        guard ContinuousClock.now < deadline else {
            Issue.record("Timed out waiting for background work to land.", sourceLocation: sourceLocation)
            return
        }

        try await Task.sleep(for: .milliseconds(5))
    }
}
