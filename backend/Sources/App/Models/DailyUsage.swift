import Fluent
import Vapor

/// 每日用量统计 — 汇总每天的消费和调用数据
final class DailyUsage: Model, Content, @unchecked Sendable {
    static let schema = "daily_usages"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "date")
    var date: Date

    /// 通过余额差值估算的当日消费（CNY）
    @Field(key: "estimated_spending")
    var estimatedSpending: String

    /// 通过代理记录统计的 Token 总量
    @Field(key: "proxy_token_count")
    var proxyTokenCount: Int

    /// 通过代理记录统计的调用次数
    @Field(key: "proxy_call_count")
    var proxyCallCount: Int

    init() {}

    init(id: UUID? = nil,
         date: Date,
         estimatedSpending: String = "0.00",
         proxyTokenCount: Int = 0,
         proxyCallCount: Int = 0) {
        self.id = id
        self.date = date
        self.estimatedSpending = estimatedSpending
        self.proxyTokenCount = proxyTokenCount
        self.proxyCallCount = proxyCallCount
    }
}

/// iOS App 返回的每日用量 DTO
struct DailyUsageDTO: Content {
    let date: String
    let estimatedSpending: String
    let proxyTokenCount: Int
    let proxyCallCount: Int
}
