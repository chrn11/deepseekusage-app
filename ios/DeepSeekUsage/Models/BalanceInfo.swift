import Foundation

/// DeepSeek API 返回的余额结构
/// GET https://api.deepseek.com/user/balance
struct DeepSeekBalanceResponse: Codable {
    let isAvailable: Bool
    let balanceInfos: [BalanceInfo]

    enum CodingKeys: String, CodingKey {
        case isAvailable = "is_available"
        case balanceInfos = "balance_infos"
    }
}

/// 单币种的余额
struct BalanceInfo: Codable {
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

    /// 格式化总余额 "¥110.00"
    var formattedTotal: String {
        let symbol = currency == "CNY" ? "¥" : "$"
        return "\(symbol)\(totalBalance)"
    }

    /// 格式化充值余额
    var formattedToppedUp: String {
        let symbol = currency == "CNY" ? "¥" : "$"
        return "\(symbol)\(toppedUpBalance)"
    }

    /// 格式化赠送余额
    var formattedGranted: String {
        let symbol = currency == "CNY" ? "¥" : "$"
        return "\(symbol)\(grantedBalance)"
    }

    /// 转为 Double
    var totalBalanceValue: Double { Double(totalBalance) ?? 0 }
    var grantedBalanceValue: Double { Double(grantedBalance) ?? 0 }
    var toppedUpBalanceValue: Double { Double(toppedUpBalance) ?? 0 }
}
