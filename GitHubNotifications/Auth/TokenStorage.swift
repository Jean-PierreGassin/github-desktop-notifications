import Foundation
import Security

protocol TokenStorage: Sendable {
    /// Returns the stored token, or `nil` when there is none or macOS refused
    /// access to it.
    func readToken() -> String?

    /// Whether the last read failed because access was refused rather than
    /// because nothing was stored.
    var wasLastReadRefused: Bool { get }

    /// - Throws: ``KeychainError`` when the keychain refuses the write.
    func writeToken(_ token: String) throws

    func deleteToken()
}

struct KeychainError: Error, Sendable {
    let status: OSStatus

    var localizedDescription: String {
        SecCopyErrorMessageString(status, nil) as String? ?? "Keychain error \(status)"
    }
}

/// Stores the personal access token in the login keychain, which is the only
/// place it ever lives on disk.
final class KeychainTokenStorage: TokenStorage, @unchecked Sendable {
    private static let account = "personal-access-token"

    private let service: String

    private(set) var wasLastReadRefused = false

    init(service: String = Bundle.main.bundleIdentifier ?? "GitHubNotifications") {
        self.service = service
    }

    func readToken() -> String? {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var storedItem: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &storedItem)

        wasLastReadRefused = [errSecAuthFailed, errSecUserCanceled, errSecInteractionNotAllowed].contains(status)

        guard status == errSecSuccess, let tokenData = storedItem as? Data else {
            return nil
        }

        return String(data: tokenData, encoding: .utf8)
    }

    /// Updates the existing entry rather than replacing it.
    ///
    /// Deleting first fails whenever macOS will not grant this build access to
    /// the old entry, which then made the add fail as a duplicate and left the
    /// user unable to sign in at all.
    func writeToken(_ token: String) throws {
        var query = baseQuery()
        query[kSecValueData as String] = Data(token.utf8)
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock

        let addStatus = SecItemAdd(query as CFDictionary, nil)

        guard addStatus == errSecDuplicateItem else {
            guard addStatus == errSecSuccess else {
                throw KeychainError(status: addStatus)
            }

            return
        }

        let updateStatus = SecItemUpdate(
            baseQuery() as CFDictionary,
            [kSecValueData as String: Data(token.utf8)] as CFDictionary,
        )

        guard updateStatus == errSecSuccess else {
            throw KeychainError(status: updateStatus)
        }
    }

    func deleteToken() {
        SecItemDelete(baseQuery() as CFDictionary)
    }

    private func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: Self.account,
        ]
    }
}
