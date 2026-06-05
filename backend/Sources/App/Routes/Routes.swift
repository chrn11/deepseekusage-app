import Vapor
import Fluent

func routes(_ app: Application) throws {
    // MARK: - 健康检查

    app.get { _ in
        "DeepSeek Usage Tracker API v1.0 🚀"
    }

    app.get("health") { _ in
        ["status": "ok", "timestamp": ISO8601DateFormatter().string(from: Date())]
    }

    // MARK: - 余额相关

    let balance = app.grouped("api", "balance")
    balance.get { req async throws -> DeepSeekBalanceResponse in
        guard let apiKey = req.application.storage[DeepSeekAPIKey.self] else {
            throw Abort(.internalServerError, reason: "DeepSeek API Key 未配置")
        }
        return try await BalancePollingService.shared.fetchBalance(apiKey: apiKey, client: req.client)
    }

    balance.post("poll") { req async throws -> BalanceRecord in
        try await BalancePollingService.shared.manualPoll(app: req.application)
    }

    // MARK: - 用量查询

    let usage = app.grouped("api", "usage")
    usage.get("daily") { req async throws -> [DailyUsageDTO] in
        let query = try req.query.decode(DailyUsageQuery.self)

        let from = query.from ?? Calendar.current.date(byAdding: .day, value: -30, to: Date())!
        let to = query.to ?? Date()

        let records = try await DailyUsage.query(on: req.db)
            .filter(\.$date >= Calendar.current.startOfDay(for: from))
            .filter(\.$date <= Calendar.current.startOfDay(for: to))
            .sort(\.$date, .ascending)
            .all()

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]

        return records.map { r in
            DailyUsageDTO(
                date: formatter.string(from: r.date),
                estimatedSpending: r.estimatedSpending,
                proxyTokenCount: r.proxyTokenCount,
                proxyCallCount: r.proxyCallCount
            )
        }
    }

    usage.get("today") { req async throws -> DailyUsageDTO in
        let today = Calendar.current.startOfDay(for: Date())
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]

        if let record = try await DailyUsage.query(on: req.db)
            .filter(\.$date == today)
            .first() {
            return DailyUsageDTO(
                date: formatter.string(from: record.date),
                estimatedSpending: record.estimatedSpending,
                proxyTokenCount: record.proxyTokenCount,
                proxyCallCount: record.proxyCallCount
            )
        } else {
            return DailyUsageDTO(
                date: formatter.string(from: today),
                estimatedSpending: "0.00",
                proxyTokenCount: 0,
                proxyCallCount: 0
            )
        }
    }

    // MARK: - 代理转发

    let proxy = app.grouped("api", "proxy")
    let proxyService = ProxyService()

    // 聊天补全代理
    proxy.post("chat", "completions") { req async throws -> Response in
        guard let apiKey = req.application.storage[DeepSeekAPIKey.self] else {
            throw Abort(.internalServerError, reason: "DeepSeek API Key 未配置")
        }
        return try await proxyService.proxyChatCompletion(req: req, apiKey: apiKey)
    }

    // 调用记录查询
    proxy.get("calls") { req async throws -> ProxyCallPageDTO in
        let query = try req.query.decode(CallHistoryQuery.self)
        let page = query.page ?? 1
        let per = min(query.per ?? 20, 100)

        let total = try await ProxyCallRecord.query(on: req.db).count()

        let items = try await ProxyCallRecord.query(on: req.db)
            .sort(\.$timestamp, .descending)
            .limit(per)
            .offset((page - 1) * per)
            .all()

        let iso = ISO8601DateFormatter()

        return ProxyCallPageDTO(
            items: items.map { r in
                ProxyCallItemDTO(
                    id: r.id,
                    timestamp: iso.string(from: r.timestamp),
                    model: r.model,
                    promptTokens: r.promptTokens,
                    completionTokens: r.completionTokens,
                    estimatedCost: r.estimatedCost
                )
            },
            total: total,
            page: page,
            per: per
        )
    }
}

// MARK: - 查询参数 DTO

struct DailyUsageQuery: Content {
    let from: Date?
    let to: Date?
}

struct CallHistoryQuery: Content {
    let page: Int?
    let per: Int?
}
