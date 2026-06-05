import Foundation
import Security

/// 钥匙串管理器 — 安全存储 DeepSeek API Key
///
/// Keychain 是 iOS 系统级的安全存储，数据加密存储在设备上。
/// 即使 App 被删除重装（如果使用此访问组），数据也不会丢失。
enum KeychainManager {

    private static let service = "com.deepseekusage.app"
    private static let account = "deepseek_api_key"

    // MARK: - 保存

    static func save(key: String) throws {
        guard !key.isEmpty else {
            try delete()
            return
        }

        let data = key.data(using: .utf8)!

        // 先尝试删除旧的
        try? delete()

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

    // MARK: - 读取

    static func load() -> String? {
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
              let data = item as? Data,
              let key = String(data: data, encoding: .utf8) else {
            return nil
        }

        return key
    }

    // MARK: - 删除

    static func delete() throws {
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

    // MARK: - 是否存在

    static var hasKey: Bool {
        load() != nil
    }
}

enum KeychainError: LocalizedError {
    case unableToSave(status: OSStatus)
    case unableToDelete(status: OSStatus)

    var errorDescription: String? {
        switch self {
        case .unableToSave(let s): return "保存 API Key 失败 (OSStatus: \(s))"
        case .unableToDelete(let s): return "删除 API Key 失败 (OSStatus: \(s))"
        }
    }
}
