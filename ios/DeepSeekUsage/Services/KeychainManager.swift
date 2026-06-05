import Foundation
import Security

/// 钥匙串管理器 — 安全存储 API Key 和平台 Cookie
enum KeychainManager {

    static let loginStatusChanged = Notification.Name("com.deepseekusage.loginStatusChanged")

    private static let service = "com.deepseekusage.app"

    // MARK: - 通用存储

    private static func save(data: Data, account: String) throws {
        try? delete(account: account)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.unableToSave(status: status)
        }
    }

    private static func load(account: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        guard status == errSecSuccess,
              let data = item as? Data else { return nil }
        return data
    }

    private static func delete(account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unableToDelete(status: status)
        }
    }

    // MARK: - API Key

    private static let apiKeyAccount = "deepseek_api_key"

    static func saveAPIKey(_ key: String) throws {
        guard !key.isEmpty else { try deleteAPIKey(); return }
        try save(data: key.data(using: .utf8)!, account: apiKeyAccount)
    }

    static func loadAPIKey() -> String? {
        guard let data = load(account: apiKeyAccount) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func deleteAPIKey() throws {
        try delete(account: apiKeyAccount)
    }

    static var hasAPIKey: Bool { loadAPIKey() != nil }

    // MARK: - 平台 Cookie

    private static let cookieAccount = "deepseek_platform_cookie"

    static func saveCookie(_ cookie: String) throws {
        guard !cookie.isEmpty else { try deleteCookie(); return }
        try save(data: cookie.data(using: .utf8)!, account: cookieAccount)
    }

    static func loadCookie() -> String? {
        guard let data = load(account: cookieAccount) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func deleteCookie() throws { try delete(account: cookieAccount) }
    static var hasCookie: Bool { loadCookie() != nil }

    // MARK: - Bearer Token（登录返回的 auth token）

    private static let tokenAccount = "deepseek_bearer_token"

    static func saveToken(_ token: String) throws {
        guard !token.isEmpty else { try deleteToken(); return }
        try save(data: token.data(using: .utf8)!, account: tokenAccount)
    }

    static func loadToken() -> String? {
        guard let data = load(account: tokenAccount) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func deleteToken() throws { try delete(account: tokenAccount) }
    static var hasToken: Bool { loadToken() != nil }

    // MARK: - 登录凭据一并清理

    static func logoutPlatform() {
        try? deleteCookie()
        try? deleteToken()
        NotificationCenter.default.post(name: loginStatusChanged, object: nil)
    }

    // 兼容旧方法名
    static func save(key: String) throws { try saveAPIKey(key) }
    static func load() -> String? { loadAPIKey() }
    static func delete() throws { try deleteAPIKey() }
    static var hasKey: Bool { hasAPIKey }
}

enum KeychainError: LocalizedError {
    case unableToSave(status: OSStatus)
    case unableToDelete(status: OSStatus)

    var errorDescription: String? {
        switch self {
        case .unableToSave(let s): return "保存失败 (OSStatus: \(s))"
        case .unableToDelete(let s): return "删除失败 (OSStatus: \(s))"
        }
    }
}
