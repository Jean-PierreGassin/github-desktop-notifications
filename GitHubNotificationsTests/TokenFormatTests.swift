import Testing

@testable import GitHubNotifications

struct TokenFormatTests {
    @Test(arguments: [
        "ghp_1234567890abcdefghijklmnopqrstuvwxyz",
        "  ghp_1234567890abcdefghijklmnopqrstuvwxyz  ",
        "0123456789abcdef0123456789abcdef01234567",
    ])
    func recognisesClassicTokens(candidate: String) {
        #expect(TokenFormat.classify(candidate) == .classic)
    }

    @Test
    func recognisesFineGrainedTokensSoTheUserCanBeTold() {
        #expect(TokenFormat.classify("github_pat_11ABCDEFG0abcdefghijkl") == .fineGrained)
    }

    @Test(arguments: [
        "",
        "not a token",
        "0123456789abcdef",
        "0123456789abcdef0123456789abcdef0123456z",
    ])
    func treatsAnythingElseAsUnrecognised(candidate: String) {
        #expect(TokenFormat.classify(candidate) == .unrecognised)
    }
}
