import SwiftUI

/// The update line under the panel's Quit button.
///
/// The installed version is always on show: knowing what you are running should
/// not require opening a window, and it is half of what an update prompt is
/// answering anyway.
struct UpdateStatusView: View {
    let session: AppSession

    var body: some View {
        HStack(spacing: 8) {
            Text(statusText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            action
        }
    }

    private var updates: UpdateChecker {
        session.updates
    }

    private var statusText: String {
        switch updates.state {
        case .idle:
            "Version \(updates.installedVersion)"
        case .checking:
            "Version \(updates.installedVersion) · checking"
        case .upToDate:
            "Version \(updates.installedVersion) · up to date"
        case let .available(release):
            "Version \(release.version) available"
        case .downloading:
            "Downloading"
        case let .readyToInstall(release):
            "Version \(release.version) is ready"
        case let .installsOnQuit(release):
            "Version \(release.version) installs when you quit"
        case let .failed(reason):
            reason
        }
    }

    @ViewBuilder
    private var action: some View {
        switch updates.state {
        case .idle, .upToDate:
            Button("Check for Updates") { check() }
                .appButton(.standard, size: .small)
        case .checking, .downloading:
            ProgressView()
                .controlSize(.small)
        case let .available(release):
            HStack(spacing: 8) {
                Link("Release notes", destination: release.pageURL)
                    .font(.caption)

                Button("Install Update") {
                    Task { await updates.download(release) }
                }
                .appButton(.primary, size: .small)
            }
        case let .readyToInstall(release):
            installChoice(for: release)
        case let .installsOnQuit(release):
            Button("Install Now") { updates.installAndRestart(release) }
                .appButton(.standard, size: .small)
        case .failed:
            Button("Try Again") { check() }
                .appButton(.standard, size: .small)
        }
    }

    /// Nothing is replaced without being asked for, which is why a verified
    /// download stops here rather than installing itself.
    private func installChoice(for release: Release) -> some View {
        HStack(spacing: 8) {
            Button("Install on Quit") { updates.installOnQuit(release) }
                .appButton(.standard, size: .small)

            Button("Install and Restart") { updates.installAndRestart(release) }
                .appButton(.primary, size: .small)
        }
    }

    private func check() {
        Task { await updates.check(usingToken: session.auth.activeToken, isManual: true) }
    }
}
