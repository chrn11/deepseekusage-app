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
    /// 返回按币种分组的费用数据数组
    static func fetchUsageCost(month: Int, year: Int) async throws -> [CostCurrencyGroup] {
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


