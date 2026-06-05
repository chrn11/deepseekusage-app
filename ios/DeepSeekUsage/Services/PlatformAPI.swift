import Foundation

/// DeepSeek 平台 API（platform.deepseek.com 真实接口）
///
/// 认证: Bearer Token（从登录接口获取）+ Cookie（URLSession 自动管理）
/// 接口: 从网页抓包确认，非官方公开 API
enum PlatformAPI {

    private static let baseURL = "https://platform.deepseek.com"
    private static let decoder = JSONDecoder()

    /// 共享 URLSession — ephemeral 配置不持久化 cookie，手动注入避免冲突
    private static let session: URLSession = {
        let c = URLSessionConfiguration.ephemeral
        c.timeoutIntervalForRequest = 15
        c.timeoutIntervalForResource = 30
        c.httpShouldSetCookies = false
        c.httpAdditionalHeaders = [
            "x-app-version": "1.0.0",
            "accept": "*/*",
            "accept-language": "zh-CN,zh;q=0.9",
        ]
        return URLSession(configuration: c)
    }()

    // MARK: - 登录

    /// POST /auth-api/v0/users/login（保留供 API 方式登录，当前主流程用 WebView）
    static func login(email: String, password: String, deviceId: String) async throws -> LoginResult {
        var req = URLRequest(url: URL(string: "\(baseURL)/auth-api/v0/users/login")!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        req.setValue("https://platform.deepseek.com", forHTTPHeaderField: "origin")
        req.setValue("https://platform.deepseek.com/sign_in", forHTTPHeaderField: "referer")

        let body: [String: String] = [
            "email": email, "mobile": "", "password": password,
            "area_code": "", "device_id": deviceId, "os": "ios"
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw PlatformError.invalidResponse }

        if http.statusCode == 200 {
            let decoded = try decoder.decode(LoginResponse.self, from: data)
            guard let user = decoded.data?.bizData?.user, let token = user.token else {
                throw PlatformError.serverError(code: http.statusCode, body: "token missing")
            }
            // 登录接口返回的 Set-Cookie 备份到 Keychain
            let cookies = HTTPCookie.cookies(
                withResponseHeaderFields: (http.allHeaderFields as? [String: String]) ?? [:],
                for: URL(string: baseURL)!
            )
            let cookieStr = cookies.map { "\($0.name)=\($0.value)" }.joined(separator: "; ")
            if !cookieStr.isEmpty {
                try? KeychainManager.saveCookie(cookieStr)
            }

            return LoginResult(
                token: token,
                email: user.email ?? "",
                currency: user.currency ?? "CNY",
                balance: user.normalWallets?.first?.balance ?? "0"
            )
        } else if http.statusCode == 401 {
            throw PlatformError.loginFailed
        } else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw PlatformError.serverError(code: http.statusCode, body: body)
        }
    }

    // MARK: - 余额 + 汇总

    /// GET /api/v0/users/get_user_summary
    static func fetchUsageSummary() async throws -> SummaryData {
        let data = try await authedGet("/api/v0/users/get_user_summary")
        do {
            let decoded = try decoder.decode(SummaryResponse.self, from: data)
            guard let biz = decoded.data?.bizData else {
                let body = String(data: data, encoding: .utf8) ?? "(empty)"
                print("[PlatformAPI] summary: bizData 为 nil，响应体: \(body.prefix(500))")
                throw PlatformError.invalidResponse
            }
            return biz
        } catch let decodeError as DecodingError {
            let body = String(data: data, encoding: .utf8) ?? "(无法解码)"
            print("[PlatformAPI] summary 解码失败: \(decodeError)，响应体: \(body.prefix(500))")
            throw PlatformError.serverError(code: 200, body: "解码失败: \(decodeError.localizedDescription)")
        }
    }

    // MARK: - 每日用量（Token + 请求数）

    /// GET /api/v0/usage/amount?month=6&year=2026
    static func fetchUsageAmount(month: Int, year: Int) async throws -> UsageAmountData {
        let data = try await authedGet("/api/v0/usage/amount?month=\(month)&year=\(year)")
        do {
            let decoded = try decoder.decode(UsageAmountResponse.self, from: data)
            guard let biz = decoded.data?.bizData else {
                let body = String(data: data, encoding: .utf8) ?? "(empty)"
                print("[PlatformAPI] amount: bizData 为 nil，响应体: \(body.prefix(500))")
                throw PlatformError.invalidResponse
            }
            return biz
        } catch let decodeError as DecodingError {
            let body = String(data: data, encoding: .utf8) ?? "(无法解码)"
            print("[PlatformAPI] amount 解码失败: \(decodeError)，响应体: \(body.prefix(500))")
            throw PlatformError.serverError(code: 200, body: "解码失败: \(decodeError.localizedDescription)")
        }
    }

    // MARK: - 每日费用

    /// GET /api/v0/usage/cost?month=6&year=2026
    static func fetchUsageCost(month: Int, year: Int) async throws -> UsageCostData {
        let data = try await authedGet("/api/v0/usage/cost?month=\(month)&year=\(year)")
        do {
            let decoded = try decoder.decode(UsageCostResponse.self, from: data)
            guard let biz = decoded.data?.bizData else {
                let body = String(data: data, encoding: .utf8) ?? "(empty)"
                print("[PlatformAPI] cost: bizData 为 nil，响应体: \(body.prefix(500))")
                throw PlatformError.invalidResponse
            }
            return biz
        } catch let decodeError as DecodingError {
            let body = String(data: data, encoding: .utf8) ?? "(无法解码)"
            print("[PlatformAPI] cost 解码失败: \(decodeError)，响应体: \(body.prefix(500))")
            throw PlatformError.serverError(code: 200, body: "解码失败: \(decodeError.localizedDescription)")
        }
    }

    // MARK: - HTTP

    private static func authedGet(_ path: String) async throws -> Data {
        guard let url = URL(string: "\(baseURL)\(path)") else {
            throw PlatformError.invalidURL
        }
        guard let token = KeychainManager.loadToken(), !token.isEmpty else {
            throw PlatformError.notLoggedIn
        }

        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "authorization")

        // 从 Keychain 恢复 cookie（WebView 非持久化 cookie 不会自动同步到 URLSession）
        if let cookieStr = KeychainManager.loadCookie(), !cookieStr.isEmpty {
            req.setValue(cookieStr, forHTTPHeaderField: "Cookie")
        }

        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw PlatformError.invalidResponse }

        let statusCode = http.statusCode
        print("[PlatformAPI] \(path) → \(statusCode)")
        if statusCode != 200 {
            let body = String(data: data, encoding: .utf8) ?? ""
            print("[PlatformAPI] 错误响应体: \(body.prefix(300))")
        }

        switch statusCode {
        case 200: return data
        case 401: throw PlatformError.loginExpired
        default:
            let body = String(data: data, encoding: .utf8) ?? ""
            throw PlatformError.serverError(code: statusCode, body: body)
        }
    }
}

// MARK: - 错误

enum PlatformError: LocalizedError {
    case invalidURL, invalidResponse, notLoggedIn, loginExpired, loginFailed
    case serverError(code: Int, body: String)
    var errorDescription: String? {
        switch self {
        case .notLoggedIn:             "请先在设置中登录 DeepSeek 平台"
        case .loginExpired:            "登录已过期，请重新登录"
        case .loginFailed:             "邮箱或密码错误"
        case .serverError(let code, _): "平台接口异常 (HTTP \(code))"
        default: nil
        }
    }
}

// MARK: - 登录请求/响应

struct LoginResult {
    let token: String; let email: String; let currency: String; let balance: String
}

struct LoginResponse: Codable {
    let data: LoginData?
    struct LoginData: Codable {
        let bizData: LoginBiz?
        enum CodingKeys: String, CodingKey { case bizData = "biz_data" }
        struct LoginBiz: Codable {
            let user: LoginUser?
            struct LoginUser: Codable {
                let token, email, currency: String?
                let normalWallets: [WalletInfo]?
                enum CodingKeys: String, CodingKey {
                    case token, email, currency
                    case normalWallets = "normal_wallets"
                }
            }
        }
    }
}

struct WalletInfo: Codable {
    let currency: String; let balance: String
}

// MARK: - 汇总响应

struct SummaryResponse: Codable {
    let data: SummaryWrap?
    struct SummaryWrap: Codable {
        let bizData: SummaryData?
        enum CodingKeys: String, CodingKey { case bizData = "biz_data" }
    }
}
struct SummaryData: Codable {
    let normalWallets: [WalletInfo]?
    let bonusWallets: [WalletInfo]?
    let monthlyCosts: [CostItem]?
    let monthlyTokenUsage: String?
    let monthlyUsage: String?
    let totalUsage: Int?

    enum CodingKeys: String, CodingKey {
        case normalWallets = "normal_wallets"
        case bonusWallets = "bonus_wallets"
        case monthlyCosts = "monthly_costs"
        case monthlyTokenUsage = "monthly_token_usage"
        case monthlyUsage = "monthly_usage"
        case totalUsage = "total_usage"
    }

    var totalBalanceCNY: Double {
        (normalWallets?.first(where: { $0.currency == "CNY" })?.balance).flatMap(Double.init) ?? 0
    }
    var totalBalanceUSD: Double {
        (normalWallets?.first(where: { $0.currency == "USD" })?.balance).flatMap(Double.init) ?? 0
    }
    var costCNY: Double { (monthlyCosts?.first(where: { $0.currency == "CNY" })?.amount).flatMap(Double.init) ?? 0 }
    var costUSD: Double { (monthlyCosts?.first(where: { $0.currency == "USD" })?.amount).flatMap(Double.init) ?? 0 }
    var tokens: Int { (monthlyTokenUsage).flatMap(Int.init) ?? 0 }
}
struct CostItem: Codable {
    let currency: String; let amount: String?
}

// MARK: - 用量响应

struct UsageAmountResponse: Codable {
    let data: AmountWrap?
    struct AmountWrap: Codable {
        let bizData: UsageAmountData?
        enum CodingKeys: String, CodingKey { case bizData = "biz_data" }
    }
}
struct UsageAmountData: Codable {
    let total: [ModelUsage]?
    let days: [DayAmount]?
}
struct ModelUsage: Codable {
    let model: String?
    let usage: [UsageEntry]?
}
struct DayAmount: Codable {
    let date: String?
    let data: [ModelUsage]?
}
struct UsageEntry: Codable {
    let type: String?
    let amount: String?
}

// MARK: - 费用响应

struct UsageCostResponse: Codable {
    let data: CostWrap?
    struct CostWrap: Codable {
        let bizData: UsageCostData?
        enum CodingKeys: String, CodingKey { case bizData = "biz_data" }
    }
}
struct UsageCostData: Codable {
    let total: [ModelUsage]?
    let days: [DayAmount]?
}
