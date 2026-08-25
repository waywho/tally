import Foundation
import Security

/// Persists session cookies in the iOS Keychain so login survives app restarts.
enum SessionStore {

    private static let service = "quest.tally"
    private static let account = "session.cookies"

    /// Save an array of HTTPCookie to the Keychain.
    static func save(cookies: [HTTPCookie]) {
        let properties = cookies.compactMap { $0.properties }
        guard let data = try? NSKeyedArchiver.archivedData(
            withRootObject: properties,
            requiringSecureCoding: false
        ) else { return }

        // Delete any existing entry first
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]
        SecItemAdd(addQuery as CFDictionary, nil)
    }

    /// Load previously saved cookies from the Keychain.
    static func loadCookies() -> [HTTPCookie]? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }

        guard let properties = try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data)
                as? [[HTTPCookiePropertyKey: Any]] else { return nil }

        let cookies = properties.compactMap { HTTPCookie(properties: $0) }
        return cookies.isEmpty ? nil : cookies
    }

    /// Delete saved cookies from the Keychain.
    static func clear() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
