import Foundation

/// DeepSeek API 客户端
///
/// 直接调用 DeepSeek 官方 API，不走任何中间服务器。
/// API Key 从 Keychain 读取，在 App 设置页中由用户输入。
enum DeepSeekAPI {

    private static let baseURL = "https://api.deepseek.com"
    private static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 12
        config.timeoutIntervalForResource = 30
        return URLSession(configuration: config)
    }()
    private static let decoder = JSONDecoder()

    // MARK: - 查余额

    /// 查询账户余额
    /// - Returns: 余额信息（包含各币种详情）
    static func fetchBalance() async throws -> DeepSeekBalanceResponse {
        guard let apiKey = KeychainManager.load(), !apiKey.isEmpty else {
            throw DeepSeekError.noAPIKey
        }

        let data = try await get("/user/balance", apiKey: apiKey)
        return try decoder.decode(DeepSeekBalanceResponse.self, from: data)
    }

    // MARK: - 测试 API Key 是否有效

    /// 验证 API Key 是否有效
    /// - Parameter key: 待测试的 Key
    /// - Returns: 有效返回余额信息，无效抛出错误
    static func validateKey(_ key: String) async throws -> DeepSeekBalanceResponse {
        let data = try await get("/user/balance", apiKey: key)
        return try decoder.decode(DeepSeekBalanceResponse.self, from: data)
    }

    // MARK: - HTTP

    private static func get(_ path: String, apiKey: String) async throws -> Data {
        guard let url = URL(string: "\(baseURL)\(path)") else {
            throw DeepSeekError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw DeepSeekError.invalidResponse
        }

        switch http.statusCode {
        case 200:
            return data
        case 401:
            throw DeepSeekError.unauthorized
        case 429:
            throw DeepSeekError.rateLimited
        default:
            let body = String(data: data, encoding: .utf8) ?? ""
            throw DeepSeekError.serverError(code: http.statusCode, body: body)
        }
    }
}

// MARK: - 错误

enum DeepSeekError: LocalizedError {
    case noAPIKey
    case invalidURL
    case invalidResponse
    case unauthorized
    case rateLimited
    case serverError(code: Int, body: String)

    var errorDescription: String? {
        switch self {
        case .noAPIKey:         return "请先在设置中填入 DeepSeek API Key"
        case .invalidURL:       return "无效的 API 地址"
        case .invalidResponse:  return "服务器返回异常"
        case .unauthorized:     return "API Key 无效，请检查后重试"
        case .rateLimited:      return "请求太频繁，请稍后再试"
        case .serverError(let c, let b): return "服务器错误(\(c)): \(b)"
        }
    }
}
