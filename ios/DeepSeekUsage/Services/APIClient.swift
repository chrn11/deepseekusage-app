import Foundation

/// API 客户端 — 负责与 Vapor 后端通信
///
/// 所有网络请求都通过这个类发送到后端服务器。
/// 你可以在 SettingsView 中修改 backendURL，它会被自动持久化到 UserDefaults。
class APIClient: ObservableObject {
    static let shared = APIClient()

    /// 后端地址，默认 http://localhost:8080
    /// 修改此值需要调用 updateBaseURL() 生效
    @Published var configuredBaseURL: String {
        didSet {
            UserDefaults.standard.set(configuredBaseURL, forKey: "backend_base_url")
        }
    }

    private var baseURL: String {
        configuredBaseURL
    }

    private let session: URLSession
    private let decoder: JSONDecoder

    private init() {
        // 从 UserDefaults 读取已保存的后端地址
        self.configuredBaseURL = UserDefaults.standard.string(forKey: "backend_base_url") ?? "http://localhost:8080"

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)

        self.decoder = JSONDecoder()
    }

    // MARK: - 余额

    /// 获取实时余额（从 DeepSeek 官方 API 拉取）
    func fetchBalance() async throws -> BalanceInfo {
        let data = try await get("/api/balance")
        return try decoder.decode(BalanceInfo.self, from: data)
    }

    /// 手动触发一次余额抓取
    func triggerBalancePoll() async throws -> BalanceInfo {
        let data = try await post("/api/balance/poll", body: nil)
        return try decoder.decode(BalanceInfo.self, from: data)
    }

    // MARK: - 每日用量

    /// 获取指定日期范围的每日用量
    /// - Parameters:
    ///   - from: 开始日期
    ///   - to: 结束日期
    func fetchDailyUsage(from: Date, to: Date) async throws -> [DailyUsageItem] {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        let fromStr = formatter.string(from: from)
        let toStr = formatter.string(from: to)

        let data = try await get("/api/usage/daily?from=\(fromStr)&to=\(toStr)")
        return try decoder.decode([DailyUsageItem].self, from: data)
    }

    /// 获取最近 30 天的用量（用于图表显示）
    func fetchRecent30DaysUsage() async throws -> [DailyUsageItem] {
        let to = Date()
        let from = Calendar.current.date(byAdding: .day, value: -30, to: to) ?? to
        return try await fetchDailyUsage(from: from, to: to)
    }

    /// 获取今日用量
    func fetchTodayUsage() async throws -> DailyUsageItem {
        let data = try await get("/api/usage/today")
        return try decoder.decode(DailyUsageItem.self, from: data)
    }

    // MARK: - 代理调用记录

    /// 获取代理调用记录（分页）
    func fetchProxyCalls(page: Int = 1, per: Int = 20) async throws -> ProxyCallPage {
        let data = try await get("/api/proxy/calls?page=\(page)&per=\(per)")
        return try decoder.decode(ProxyCallPage.self, from: data)
    }

    // MARK: - HTTP 基础方法

    private func get(_ path: String) async throws -> Data {
        guard let url = URL(string: "\(baseURL)\(path)") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)
        try validateResponse(response, data: data)
        return data
    }

    private func post(_ path: String, body: Data?) async throws -> Data {
        guard let url = URL(string: "\(baseURL)\(path)") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = body

        let (data, response) = try await session.data(for: request)
        try validateResponse(response, data: data)
        return data
    }

    private func validateResponse(_ response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw APIError.serverError(statusCode: httpResponse.statusCode, body: body)
        }
    }
}

// MARK: - 错误类型

enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case serverError(statusCode: Int, body: String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "无效的 URL，请检查后端地址配置"
        case .invalidResponse:
            return "服务器返回了无效的响应"
        case .serverError(let code, let body):
            return "服务器错误 (\(code)): \(body)"
        }
    }
}
