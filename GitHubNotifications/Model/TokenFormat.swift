import Foundation

/// Tells apart the token types a user might paste, so the app can explain the
/// problem instead of failing with a generic error.
enum TokenFormat: Sendable, Equatable {
    case classic
    case fineGrained
    case unrecognised

    static func classify(_ candidate: String) -> TokenFormat {
        let trimmed = candidate.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.hasPrefix("github_pat_") {
            return .fineGrained
        }

        if trimmed.hasPrefix("ghp_") || isLegacyHexToken(trimmed) {
            return .classic
        }

        return .unrecognised
    }

    private static func isLegacyHexToken(_ candidate: String) -> Bool {
        candidate.count == 40 && candidate.allSatisfy(\.isHexDigit)
    }
}
