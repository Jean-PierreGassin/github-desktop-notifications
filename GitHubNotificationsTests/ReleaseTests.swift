import Foundation
import Testing

@testable import GitHubNotifications

struct ReleaseTests {
    @Test
    func readsTheVersionWithoutTheTagsLeadingV() {
        #expect(Release.decode(from: json())?.version == "1.3.0")
    }

    @Test
    func picksTheZipTheUpdaterCanUnpackRatherThanTheDmg() {
        let release = Release.decode(from: json())

        #expect(release?.downloadURL.lastPathComponent == "GitHubNotifications-1.3.0.zip")
    }

    @Test(arguments: ["draft", "prerelease"])
    func ignoresReleasesNotMeantForEveryone(flag: String) {
        let payload = String(decoding: json(), as: UTF8.self)
            .replacingOccurrences(of: "\"\(flag)\": false", with: "\"\(flag)\": true")

        #expect(Release.decode(from: Data(payload.utf8)) == nil)
    }

    @Test
    func ignoresAReleasePublishedWithoutTheZip() {
        let payload = json(assets: """
        [{ "name": "GitHubNotifications-1.3.0.dmg", "browser_download_url": "https://example.invalid/app.dmg" }]
        """)

        #expect(Release.decode(from: payload) == nil)
    }

    @Test
    func ignoresSomethingThatIsNotAReleaseAtAll() {
        #expect(Release.decode(from: Data("{}".utf8)) == nil)
    }

    private func json(assets: String = """
    [{ "name": "GitHubNotifications-1.3.0.zip",
       "browser_download_url": "https://example.invalid/GitHubNotifications-1.3.0.zip" }]
    """) -> Data {
        Data("""
        {
          "tag_name": "v1.3.0",
          "html_url": "https://github.com/example/example/releases/tag/v1.3.0",
          "published_at": "2026-07-25T04:00:00Z",
          "draft": false,
          "prerelease": false,
          "assets": \(assets)
        }
        """.utf8)
    }
}
