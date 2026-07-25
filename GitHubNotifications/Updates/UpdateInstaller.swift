import AppKit
import Foundation

enum UpdateFailure: Error, Equatable {
    case downloadFailed
    case archiveUnreadable
    case signedByAnotherIdentity
    case notWritable(String)
    case swapFailed(String)

    var description: String {
        switch self {
        case .downloadFailed:
            "The download didn't complete. Try again, or download it from the release page."
        case .archiveUnreadable:
            "The download couldn't be unpacked, so nothing was changed."
        case .signedByAnotherIdentity:
            "That download isn't signed by the same certificate as this app, so it was refused and deleted."
        case let .notWritable(path):
            "This copy of the app lives somewhere it can't update itself (\(path)). "
                + "Move it to Applications, or download the new version yourself."
        case let .swapFailed(reason):
            "The update couldn't be put in place, so the previous version was restored. \(reason)"
        }
    }
}

protocol UpdateInstalling: Sendable {
    /// Fetches the release and returns the unarchived bundle, having already
    /// proved it is signed the same way as the running app.
    ///
    /// - Throws: ``UpdateFailure`` for anything that leaves the app unchanged.
    func downloadAndVerify(_ release: Release) async throws -> URL

    /// Replaces the running app with the verified bundle, from outside this
    /// process, and quits.
    ///
    /// - Throws: ``UpdateFailure`` when the swap cannot even be started.
    func install(from bundleURL: URL, relaunching: Bool) throws
}

/// Downloads, verifies and swaps in a new copy of the app.
///
/// Verification is the whole security model here. Nothing is notarised and
/// there is no Apple in the loop, so proving the download satisfies the running
/// app's designated requirement is the only thing between a user and a swapped
/// binary. It happens before anything is moved.
struct UpdateInstaller: UpdateInstalling {
    private let session: URLSession
    private let installedBundleURL: URL

    init(session: URLSession = .shared, installedBundleURL: URL = Bundle.main.bundleURL) {
        self.session = session
        self.installedBundleURL = installedBundleURL
    }

    func downloadAndVerify(_ release: Release) async throws -> URL {
        let workingDirectory = FileManager.default.temporaryDirectory
            .appending(path: "update-\(UUID().uuidString)")

        try? FileManager.default.createDirectory(at: workingDirectory, withIntermediateDirectories: true)

        let archiveURL = workingDirectory.appending(path: "update.zip")

        guard let (downloadedURL, response) = try? await session.download(from: release.downloadURL),
              (response as? HTTPURLResponse)?.statusCode == 200,
              (try? FileManager.default.moveItem(at: downloadedURL, to: archiveURL)) != nil
        else {
            try? FileManager.default.removeItem(at: workingDirectory)
            throw UpdateFailure.downloadFailed
        }

        do {
            let bundleURL = try unarchive(archiveURL, into: workingDirectory)

            try CodeSignature.verify(bundleURL: bundleURL)

            return bundleURL
        } catch {
            try? FileManager.default.removeItem(at: workingDirectory)
            throw error
        }
    }

    /// `ditto` rather than `unzip`: it round-trips extended attributes and
    /// symlinks, and a bundle that loses either no longer validates.
    private func unarchive(_ archiveURL: URL, into directory: URL) throws -> URL {
        let unpacked = directory.appending(path: "unpacked")

        let ditto = Process()
        ditto.executableURL = URL(filePath: "/usr/bin/ditto")
        ditto.arguments = ["-x", "-k", archiveURL.path(), unpacked.path()]

        try? ditto.run()
        ditto.waitUntilExit()

        guard ditto.terminationStatus == 0,
              let bundleURL = try? FileManager.default
              .contentsOfDirectory(at: unpacked, includingPropertiesForKeys: nil)
              .first(where: { $0.pathExtension == "app" })
        else {
            throw UpdateFailure.archiveUnreadable
        }

        return bundleURL
    }

    /// A running bundle cannot overwrite itself, so the swap is handed to a
    /// short script that waits for this process to exit. It backs the old copy
    /// up with a rename, which is atomic within a volume, and puts it back if
    /// anything goes wrong.
    func install(from bundleURL: URL, relaunching: Bool) throws {
        let installedPath = installedBundleURL.path()

        guard FileManager.default.isWritableFile(atPath: installedBundleURL.deletingLastPathComponent().path()) else {
            throw UpdateFailure.notWritable(installedBundleURL.deletingLastPathComponent().path())
        }

        let scriptURL = FileManager.default.temporaryDirectory.appending(path: "install-\(UUID().uuidString).sh")
        let logURL = FileManager.default.temporaryDirectory.appending(path: "github-notifications-update.log")

        let script = """
        #!/bin/bash
        set -u
        exec >>"\(logURL.path())" 2>&1

        while kill -0 \(ProcessInfo.processInfo.processIdentifier) 2>/dev/null; do sleep 0.2; done

        BACKUP="\(installedPath).backup"
        rm -rf "$BACKUP"
        mv "\(installedPath)" "$BACKUP" || exit 1

        if ! ditto "\(bundleURL.path())" "\(installedPath)"; then
          rm -rf "\(installedPath)"
          mv "$BACKUP" "\(installedPath)"
          exit 1
        fi

        rm -rf "$BACKUP"
        \(relaunching ? "open \"\(installedPath)\"" : "")
        """

        do {
            try script.write(to: scriptURL, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path())

            let installation = Process()
            installation.executableURL = URL(filePath: "/bin/bash")
            installation.arguments = [scriptURL.path()]
            try installation.run()
        } catch {
            throw UpdateFailure.swapFailed(error.localizedDescription)
        }

        guard relaunching else {
            return
        }

        NSApplication.shared.terminate(nil)
    }
}

/// Proves a downloaded bundle is the same program as the running one, by the
/// only definition macOS recognises: the running app's designated requirement.
enum CodeSignature {
    static func verify(bundleURL: URL) throws {
        var runningCode: SecCode?
        var requirement: SecRequirement?
        var candidate: SecStaticCode?

        guard SecCodeCopySelf([], &runningCode) == errSecSuccess,
              let runningCode,
              SecCodeCopyDesignatedRequirement(
                  unsafeBitCast(runningCode, to: SecStaticCode.self),
                  [],
                  &requirement,
              ) == errSecSuccess,
              let requirement,
              SecStaticCodeCreateWithPath(bundleURL as CFURL, [], &candidate) == errSecSuccess,
              let candidate,
              SecStaticCodeCheckValidity(candidate, [], requirement) == errSecSuccess
        else {
            throw UpdateFailure.signedByAnotherIdentity
        }
    }
}
