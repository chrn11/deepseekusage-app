import Fluent
import Vapor

/// 余额快照记录 — 每次从 DeepSeek API 拉取的余额快照
final class BalanceRecord: Model, Content, @unchecked Sendable {
    static let schema = "balance_records"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "timestamp")
    var timestamp: Date

    @Field(key: "total_balance")
    var totalBalance: String

    @Field(key: "granted_balance")
    var grantedBalance: String

    @Field(key: "topped_up_balance")
    var toppedUpBalance: String

    @Field(key: "currency")
    var currency: String

    init() {}

    init(id: UUID? = nil,
         timestamp: Date,
         totalBalance: String,
         grantedBalance: String,
         toppedUpBalance: String,
         currency: String) {
        self.id = id
        self.timestamp = timestamp
        self.totalBalance = totalBalance
        self.grantedBalance = grantedBalance
        self.toppedUpBalance = toppedUpBalance
        self.currency = currency
    }
}

/// DeepSeek API 返回的余额结构
struct DeepSeekBalanceResponse: Content {
    let isAvailable: Bool
    let balanceInfos: [BalanceInfo]

    struct BalanceInfo: Content {
        let currency: String
        let totalBalance: String
        let grantedBalance: String
        let toppedUpBalance: String
    }

    enum CodingKeys: String, CodingKey {
        case isAvailable = "is_available"
        case balanceInfos = "balance_infos"
    }
}
