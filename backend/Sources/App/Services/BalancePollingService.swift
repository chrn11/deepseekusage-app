import Vapor
import Fluent

/// 余额定时轮询服务
/// 每隔一段时间自动抓取 DeepSeek 账户余额，并通过差值计算每日消费
actor BalancePollingService {
    static let shared = BalancePollingService()

    private var task: Task<Void, Never>?
    private let pollingInterval: TimeInterval = 3600 // 1 小时

    private init() {}

    // MARK: - 启动定时轮询

    func start(on app: Application) {
        guard task == nil else { return }
        app.logger.info("⏰ 余额轮询服务启动，间隔: \(self.pollingInterval) 秒")

        task = Task {
            // 启动后立即执行一次
            await pollBalance(app: app)

            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(pollingInterval))
                if Task.isCancelled { break }
                await pollBalance(app: app)
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }

    // MARK: - 执行一次余额抓取

    func pollBalance(app: Application) async {
        app.logger.info("📊 正在抓取 DeepSeek 余额...")

        guard let apiKey = app.storage[DeepSeekAPIKey.self] else {
            app.logger.error("❌ DeepSeek API Key 未配置")
            return
        }

        do {
            let balance = try await fetchBalance(apiKey: apiKey, client: app.client)
            try await saveBalanceRecord(balance, on: app.db)
            try await updateDailyUsage(on: app.db)
            app.logger.info("✅ 余额抓取成功: \(balance.balanceInfos.first?.totalBalance ?? "?") \(balance.balanceInfos.first?.currency ?? "")")
        } catch {
            app.logger.error("❌ 余额抓取失败: \(error.localizedDescription)")
        }
    }

    // MARK: - 手动触发抓取（暴露给路由）

    func manualPoll(app: Application) async throws -> BalanceRecord {
        guard let apiKey = app.storage[DeepSeekAPIKey.self] else {
            throw Abort(.internalServerError, reason: "DeepSeek API Key 未配置")
        }

        let balance = try await fetchBalance(apiKey: apiKey, client: app.client)
        let record = try await saveBalanceRecord(balance, on: app.db)
        try await updateDailyUsage(on: app.db)
        return record
    }

    // MARK: - 调用 DeepSeek API

    func fetchBalance(apiKey: String, client: Client) async throws -> DeepSeekBalanceResponse {
        let uri = URI(string: "https://api.deepseek.com/user/balance")
        let response = try await client.get(uri) { req in
            req.headers.bearerAuthorization = BearerAuthorization(token: apiKey)
        }

        guard response.status == .ok else {
            let body = try? response.content.decode([String: String].self)
            throw Abort(.badRequest, reason: "DeepSeek API 返回错误: \(body ?? [:])")
        }

        return try response.content.decode(DeepSeekBalanceResponse.self)
    }

    // MARK: - 保存余额快照

    @discardableResult
    private func saveBalanceRecord(_ balance: DeepSeekBalanceResponse, on db: Database) async throws -> BalanceRecord {
        guard let info = balance.balanceInfos.first else {
            throw Abort(.badRequest, reason: "余额数据为空")
        }

        let record = BalanceRecord(
            timestamp: Date(),
            totalBalance: info.totalBalance,
            grantedBalance: info.grantedBalance,
            toppedUpBalance: info.toppedUpBalance,
            currency: info.currency
        )
        try await record.save(on: db)
        return record
    }

    // MARK: - 更新每日用量

    private func updateDailyUsage(on db: Database) async throws {
        let today = Calendar.current.startOfDay(for: Date())

        // 获取今天的第一次余额记录
        let firstToday = try await BalanceRecord.query(on: db)
            .filter(\.$timestamp >= today)
            .sort(\.$timestamp, .ascending)
            .first()

        // 获取今天的最后一次余额记录
        let lastToday = try await BalanceRecord.query(on: db)
            .filter(\.$timestamp >= today)
            .sort(\.$timestamp, .descending)
            .first()

        // 如果有两条记录，通过差值估算消费
        var estimatedSpending = "0.00"
        if let first = firstToday, let last = lastToday, first.id != last.id {
            let firstBalance = Decimal(string: first.totalBalance) ?? 0
            let lastBalance = Decimal(string: last.totalBalance) ?? 0
            let diff = firstBalance - lastBalance
            if diff > 0 {
                estimatedSpending = diff.formatted(.number.precision(.fractionLength(2)))
            }
        }

        // 查找或创建今日用量记录
        guard let todayDaily = try await DailyUsage.query(on: db)
                .filter(\.$date == today).first() else {
            let newDaily = DailyUsage(
                date: today,
                estimatedSpending: estimatedSpending
            )
            try await newDaily.save(on: db)
            return
        }

        todayDaily.estimatedSpending = estimatedSpending
        try await todayDaily.save(on: db)
    }
}
