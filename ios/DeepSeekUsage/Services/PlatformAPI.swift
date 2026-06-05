import Foundation

/// DeepSeek 平台内部 API（platform.deepseek.com）
///
/// 这些接口需要登录 Cookie，不是 API Key。
/// 在 App 设置里通过 WebView 登录一次后，Cookie 存钥匙串，后续自动使用。
/// 接口地址来自对 platform.deepseek.com 网页的网络抓包，非官方公开 API，随时可能变动。
enum PlatformAPI {

    private static let baseURL = "https://platform.deepseek.com"
    private static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 12
        config.timeoutIntervalForResource = 30
        return URLSession(configuration: config)
    }()

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()

    // MARK: - 用量汇总

    /// 获取当前月份的用量汇总（Token 数 + 费用）
    static func fetchUsageSummary() async throws -> UsageSummary {
        let data = try await get("/api/v0/users/get_user_summary")
        return try decoder.decode(UsageSummary.self, from: data)
    }

    /// 获取每日用量明细（Token 拆分）
    static func fetchDailyAmount() async throws -> [DailyAmount] {
        let data = try await get("/api/v0/usage/amount")
        let resp = try decoder.decode(DailyAmountResponse.self, from: data)
        return resp.items
    }

    /// 获取每日费用明细
    static func fetchDailyCost() async throws -> [DailyCost] {
        let data = try await get("/api/v0/usage/cost")
        let resp = try decoder.decode(DailyCostResponse.self, from: data)
        return resp.items
    }

    // MARK: - HTTP

    private static func get(_ path: String) async throws -> Data {
        guard let url = URL(string: "\(baseURL)\(path)") else {
            throw PlatformError.invalidURL
        }

        guard let cookie = KeychainManager.loadCookie(), !cookie.isEmpty else {
            throw PlatformError.notLoggedIn
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(cookie, forHTTPHeaderField: "Cookie")

        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw PlatformError.invalidResponse
        }

        switch http.statusCode {
        case 200: return data
        case 302, 401: throw PlatformError.loginExpired
        case 429: throw PlatformError.rateLimited
        default:
            let body = String(data: data, encoding: .utf8) ?? ""
            throw PlatformError.serverError(code: http.statusCode, body: body)
        }
    }
}

enum PlatformError: LocalizedError {
    case invalidURL
    case invalidResponse
    case notLoggedIn
    case loginExpired
    case rateLimited
    case serverError(code: Int, body: String)

    var errorDescription: String? {
        switch self {
        case .notLoggedIn:          return "请先在设置中登录 DeepSeek 平台"
        case .loginExpired:         return "登录已过期，请重新登录"
        case .rateLimited:          return "请求太频繁，请稍后再试"
        case .serverError(let c, _): return "平台接口错误 (\(c))"
        default: return nil
        }
    }
}

// MARK: - 数据模型

/// 账户用量汇总
struct UsageSummary: Codable {
    let data: UsageSummaryData?
    let code: Int
    let msg: String?
}

struct UsageSummaryData: Codable {
    let balance: Double?
    let totalSpentThisMonth: Double?
    let totalTokensThisMonth: Int?
    let totalCallsThisMonth: Int?

    var formattedSpent: String {
        String(format: "¥%.2f", totalSpentThisMonth ?? 0)
    }

    var formattedTokens: String {
        guard let t = totalTokensThisMonth, t > 0 else { return "0" }
        if t >= 1_000_000 { return String(format: "%.1fM", Double(t) / 1_000_000) }
        if t >= 1_000 { return String(format: "%.0fK", Double(t) / 1_000) }
        return "\(t)"
    }
}

/// 每日用量
struct DailyAmountResponse: Codable {
    let data: [DailyAmountRaw]
    var items: [DailyAmount] {
        data.map { DailyAmount(date: $0.date, inputTokens: $0.inputTokens, outputTokens: $0.outputTokens, model: $0.model) }
    }
}

struct DailyAmountRaw: Codable {
    let date: String
    let inputTokens: Int
    let outputTokens: Int
    let model: String

    enum CodingKeys: String, CodingKey {
        case date, model
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
    }
}

struct DailyAmount: Identifiable {
    let id = UUID()
    let date: String
    let inputTokens: Int
    let outputTokens: Int
    let model: String

    var totalTokens: Int { inputTokens + outputTokens }

    var formattedDate: String {
        guard date.count >= 10 else { return date }
        return String(date.suffix(5)) // "06-05"
    }

    var formattedTokens: String {
        let t = totalTokens
        if t >= 1_000_000 { return String(format: "%.1fM", Double(t) / 1_000_000) }
        if t >= 1_000 { return String(format: "%.0fK", Double(t) / 1_000) }
        return "\(t)"
    }

    /// token 费用估算
    /// deepseek-chat: input ¥1/M, output ¥2/M
    /// deepseek-reasoner: input ¥4/M, output ¥16/M
    var estimatedCost: Double {
        let inPrice: Double = model.contains("reasoner") ? 4.0 : 1.0
        let outPrice: Double = model.contains("reasoner") ? 16.0 : 2.0
        return (Double(inputTokens) * inPrice + Double(outputTokens) * outPrice) / 1_000_000
    }

    var formattedCost: String {
        String(format: "¥%.2f", estimatedCost)
    }
}

struct DailyCostResponse: Codable {
    let data: [DailyCostRaw]
    var items: [DailyCost] {
        data.map { DailyCost(date: $0.date, cost: $0.cost) }
    }
}

struct DailyCostRaw: Codable {
    let date: String
    let cost: Double
}

struct DailyCost: Identifiable {
    let id = UUID()
    let date: String
    let cost: Double

    var formattedDate: String {
        guard date.count >= 10 else { return date }
        return String(date.suffix(5))
    }

    var formattedCost: String {
        String(format: "¥%.2f", cost)
    }
}
