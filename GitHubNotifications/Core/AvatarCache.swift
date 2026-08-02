import AppKit
import Foundation

/// Fetches and keeps repository owner avatars.
///
/// Avatars are decoration: a slow or failed fetch must never hold up a row, so
/// every lookup answers immediately from memory and the network is a background
/// concern. Disk keeps them across launches, since an owner's avatar changes
/// about as often as their username.
@MainActor
@Observable
final class AvatarCache {
    /// Small enough that the whole panel's avatars cost less than one API
    /// response, and still sharp at 16pt on a Retina display.
    private static let requestedPixelSize = 64

    private let directory: URL
    private let session: URLSession
    private let log: AppLog

    private var images: [String: NSImage] = [:]
    private var inFlight: Set<String> = []

    init(directory: URL? = nil, session: URLSession = .shared, log: AppLog) {
        self.directory = directory ?? Self.defaultDirectory()
        self.session = session
        self.log = log
    }

    /// The avatar if it is already to hand, and a fetch started if it is not.
    func image(for owner: RepositoryOwner) -> NSImage? {
        if let image = images[owner.login] {
            return image
        }

        if let image = readFromDisk(login: owner.login) {
            images[owner.login] = image

            return image
        }

        fetch(owner)

        return nil
    }

    /// Whether every fetch started so far has landed.
    ///
    /// Nothing on screen has a use for this - a row asks and draws whatever is
    /// there. Tests wait on it rather than pausing for a fixed moment and hoping
    /// it was long enough, which is a bet on how busy the machine is.
    var hasSettled: Bool {
        inFlight.isEmpty
    }

    private func fetch(_ owner: RepositoryOwner) {
        guard let avatarURL = owner.avatarURL, !inFlight.contains(owner.login) else {
            return
        }

        inFlight.insert(owner.login)

        Task { [weak self] in
            defer { self?.inFlight.remove(owner.login) }

            guard let data = try? await self?.session.data(from: Self.sized(avatarURL)).0,
                  let image = NSImage(data: data)
            else {
                self?.log.debug("Couldn't load the avatar for \(owner.login).")
                return
            }

            self?.images[owner.login] = image
            self?.writeToDisk(data, login: owner.login)
        }
    }

    private static func sized(_ avatarURL: URL) -> URL {
        guard var components = URLComponents(url: avatarURL, resolvingAgainstBaseURL: false) else {
            return avatarURL
        }

        components.queryItems = [URLQueryItem(name: "s", value: String(requestedPixelSize))]

        return components.url ?? avatarURL
    }

    private func readFromDisk(login: String) -> NSImage? {
        guard let data = try? Data(contentsOf: fileURL(for: login)) else {
            return nil
        }

        return NSImage(data: data)
    }

    private func writeToDisk(_ data: Data, login: String) {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try data.write(to: fileURL(for: login), options: .atomic)
        } catch {
            log.debug("Couldn't cache the avatar for \(login): \(error.localizedDescription)")
        }
    }

    /// A login is the file name, so it is stripped of anything that would let it
    /// escape the cache directory.
    private func fileURL(for login: String) -> URL {
        let safeName = login.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ".", with: "-")

        return directory.appending(path: "\(safeName).png")
    }

    private static func defaultDirectory() -> URL {
        let applicationSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let bundleIdentifier = Bundle.main.bundleIdentifier ?? "GitHubNotifications"

        return applicationSupport
            .appending(path: bundleIdentifier)
            .appending(path: "avatars")
    }
}
