import Foundation
import Security

protocol TokenStorage: Sendable {
    func readToken() -> String?

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
struct KeychainTokenStorage: TokenStorage {
    private static let account = "personal-access-token"

    private let service: String

    init(service: String = Bundle.main.bundleIdentifier ?? "GitHubNotifications") {
        self.service = service
    }

    func readToken() -> String? {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var storedItem: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &storedItem)

        guard status == errSecSuccess, let tokenData = storedItem as? Data else {
            return nil
        }

        return String(data: tokenData, encoding: .utf8)
    }

    func writeToken(_ token: String) throws {
        deleteToken()

        var query = baseQuery()
        query[kSecValueData as String] = Data(token.utf8)
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock

        let status = SecItemAdd(query as CFDictionary, nil)

        guard status == errSecSuccess else {
            throw KeychainError(status: status)
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
