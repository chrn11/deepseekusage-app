import Foundation

/// 账户余额信息
/// 对应后端 GET /api/balance 的响应
struct BalanceInfo: Codable, Identifiable {
    var id: String { currency }
    let isAvailable: Bool
    let balanceInfos: [BalanceDetail]

    enum CodingKeys: String, CodingKey {
        case isAvailable = "is_available"
        case balanceInfos = "balance_infos"
    }
}

/// 单种货币的余额详情
struct BalanceDetail: Codable {
    let currency: String
    let totalBalance: String
    let grantedBalance: String
    let toppedUpBalance: String

    enum CodingKeys: String, CodingKey {
        case currency
        case totalBalance = "total_balance"
        case grantedBalance = "granted_balance"
        case toppedUpBalance = "topped_up_balance"
    }

    /// 格式化的总余额（如 "¥110.00 CNY"）
    var formattedTotal: String {
        let symbol = currency == "CNY" ? "¥" : "$"
        return "\(symbol)\(totalBalance) \(currency)"
    }

    /// 格式化的充值余额
    var formattedToppedUp: String {
        let symbol = currency == "CNY" ? "¥" : "$"
        return "\(symbol)\(toppedUpBalance)"
    }

    /// 格式化的赠送余额
    var formattedGranted: String {
        let symbol = currency == "CNY" ? "¥" : "$"
        return "\(symbol)\(grantedBalance)"
    }
}
