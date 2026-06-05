import Foundation

/// DeepSeek 平台内部 API（platform.deepseek.com）
///
/// - 需要 Cookie 登录
/// - 接口路径存 UserDefaults，可通过 WebView 诊断自动更新
enum PlatformAPI {

    // MARK: - 可配路径（UserDefaults 存储，支持诊断更新）

    static var summaryPath: String {
        get { UserDefaults.standard.string(forKey: "papi_summary") ?? "/api/v0/users/get_user_summary" }
        set { UserDefaults.standard.set(newValue, forKey: "papi_summary") }
    }
    static var amountPath: String {
        get { UserDefaults.standard.string(forKey: "papi_amount") ?? "/api/v0/usage/amount" }
        set { UserDefaults.standard.set(newValue, forKey: "papi_amount") }
    }
    static var costPath: String {
        get { UserDefaults.standard.string(forKey: "papi_cost") ?? "/api/v0/usage/cost" }
        set { UserDefaults.standard.set(newValue, forKey: "papi_cost") }
    }

    private static let baseURL = "https://platform.deepseek.com"
    private static let session: URLSession = {
        let c = URLSessionConfiguration.default
        c.timeoutIntervalForRequest = 12
        c.timeoutIntervalForResource = 30
        return URLSession(configuration: c)
    }()
    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()

    // MARK: - 查询接口

    static func fetchUsageSummary() async throws -> UsageSummary {
        let data = try await get(summaryPath)
        return try decoder.decode(UsageSummary.self, from: data)
    }

    static func fetchDailyAmount() async throws -> [DailyAmount] {
        let data = try await get(amountPath)
        let resp = try decoder.decode(DailyAmountResponse.self, from: data)
        return resp.items
    }

    static func fetchDailyCost() async throws -> [DailyCost] {
        let data = try await get(costPath)
        let resp = try decoder.decode(DailyCostResponse.self, from: data)
        return resp.items
    }

    // MARK: - 诊断

    /// 返回平台页面中常用的 XHR 路径
    static func diagnoseEndpoints() -> [String] {
        return [
            summaryPath,
            amountPath,
            costPath
        ]
    }

    /// 重置为默认值
    static func resetEndpoints() {
        summaryPath = "/api/v0/users/get_user_summary"
        amountPath = "/api/v0/usage/amount"
        costPath = "/api/v0/usage/cost"
    }

    // MARK: - HTTP

    private static func get(_ path: String) async throws -> Data {
        guard let url = URL(string: "\(baseURL)\(path)") else {
            throw PlatformError.invalidURL
        }
        guard let cookie = KeychainManager.loadCookie(), !cookie.isEmpty else {
            throw PlatformError.notLoggedIn
        }
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue(cookie, forHTTPHeaderField: "Cookie")

        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw PlatformError.invalidResponse }
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
    case invalidURL, invalidResponse, notLoggedIn, loginExpired, rateLimited
    case serverError(code: Int, body: String)
    var errorDescription: String? {
        switch self {
        case .notLoggedIn:             "请先在设置中登录 DeepSeek 平台"
        case .loginExpired:            "登录已过期，请重新登录"
        case .rateLimited:             "请求太频繁，请稍后再试"
        case .serverError(let c, _):   "平台接口错误 (\(c))"
        default: nil
        }
    }
}

// MARK: - 数据模型

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

    var formattedSpent: String { String(format: "¥%.2f", totalSpentThisMonth ?? 0) }
    var formattedTokens: String {
        guard let t = totalTokensThisMonth, t > 0 else { return "0" }
        return t >= 1_000_000 ? String(format: "%.1fM", Double(t)/1_000_000)
             : t >= 1_000     ? String(format: "%.0fK", Double(t)/1_000)
             : "\(t)"
    }
}

struct DailyAmountResponse: Codable {
    let data: [DailyAmountRaw]
    var items: [DailyAmount] { data.map { DailyAmount(date: $0.date, inputTokens: $0.inputTokens, outputTokens: $0.outputTokens, model: $0.model) } }
}

struct DailyAmountRaw: Codable {
    let date, model: String
    let inputTokens, outputTokens: Int
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

    var formattedDate: String { date.count >= 10 ? String(date.suffix(5)) : date }
    var formattedTokens: String {
        let t = totalTokens
        return t >= 1_000_000 ? String(format: "%.1fM", Double(t)/1_000_000)
             : t >= 1_000     ? String(format: "%.0fK", Double(t)/1_000)
             : "\(t)"
    }

    var estimatedCost: Double {
        let inP: Double = model.contains("reasoner") ? 4.0 : 1.0
        let outP: Double = model.contains("reasoner") ? 16.0 : 2.0
        return (Double(inputTokens) * inP + Double(outputTokens) * outP) / 1_000_000
    }

    var formattedCost: String { String(format: "¥%.2f", estimatedCost) }
    var modelDisplayName: String { model.replacingOccurrences(of: "deepseek-", with: "") }
}

struct DailyCostResponse: Codable {
    let data: [DailyCostRaw]
    var items: [DailyCost] { data.map { DailyCost(date: $0.date, cost: $0.cost) } }
}

struct DailyCostRaw: Codable {
    let date: String
    let cost: Double
}

struct DailyCost: Identifiable {
    let id = UUID()
    let date: String
    let cost: Double
    var formattedDate: String { date.count >= 10 ? String(date.suffix(5)) : date }
    var formattedCost: String { String(format: "¥%.2f", cost) }
}
