import Foundation
import Testing

@testable import GitHubNotifications

struct AppVersionTests {
    @Test(arguments: [
        ("1.10.0", "1.9.0"),
        ("1.0.1", "1.0.0"),
        ("2.0.0", "1.99.99"),
        ("1.0.0", "0.9"),
        ("1.0.1", "1.0"),
    ])
    func ordersTheNewerVersionAbove(newer: String, older: String) {
        #expect(AppVersion.compare(newer, older) == .orderedDescending)
        #expect(AppVersion.compare(older, newer) == .orderedAscending)
    }

    @Test(arguments: [
        ("1.2.3", "1.2.3"),
        ("1.2.0", "1.2"),
        ("1.0", "1.0.0.0"),
    ])
    func treatsMissingComponentsAsZero(one: String, other: String) {
        #expect(AppVersion.compare(one, other) == .orderedSame)
    }

    @Test
    func comparesReleaseTagNamesAgainstBundleVersions() {
        #expect(AppVersion.compare("v1.4.0", "1.3.0") == .orderedDescending)
        #expect(AppVersion.compare("v1.3.0", "1.3.0") == .orderedSame)
    }

    @Test
    func ignoresSurroundingWhitespace() {
        #expect(AppVersion.compare(" 1.2.0 ", "1.2.0") == .orderedSame)
    }

    @Test
    func sortsAPreReleaseBelowTheReleaseItPrecedes() {
        #expect(AppVersion.compare("1.2.0-beta.1", "1.2.0") == .orderedAscending)
        #expect(AppVersion.compare("1.2.0-beta.1", "1.2.0-beta.2") == .orderedAscending)
        #expect(AppVersion.compare("1.2.0-beta.1", "1.1.9") == .orderedDescending)
    }

    @Test
    func sortsAnUnreadableVersionBelowEveryRelease() {
        #expect(AppVersion.compare(AppVersion.unknown, "0.0.1") == .orderedAscending)
        #expect(AppVersion.compare("not a version", "0.0.1") == .orderedAscending)
    }

    @Test
    func readsTheRunningVersionFromTheBundle() {
        #expect(AppVersion.compare(AppVersion.current, AppVersion.unknown) == .orderedDescending)
        #expect(AppVersion.compare(AppVersion.build, AppVersion.unknown) == .orderedDescending)
    }
}
