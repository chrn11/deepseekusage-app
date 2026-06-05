import Foundation

struct DeepSeekBalanceResponse: Codable {
    let isAvailable: Bool
    let balanceInfos: [BalanceInfo]
    enum CodingKeys: String, CodingKey {
        case isAvailable = "is_available"
        case balanceInfos = "balance_infos"
    }
}

struct BalanceInfo: Codable {
    let currency: String
    let totalBalance: String
    let grantedBalance: String
    let toppedUpBalance: String
    enum CodingKeys: String, CodingKey {
        case currency, totalBalance = "total_balance",
             grantedBalance = "granted_balance", toppedUpBalance = "topped_up_balance"
    }

    var totalBalanceValue: Double { Double(totalBalance) ?? 0 }
    var grantedBalanceValue: Double { Double(grantedBalance) ?? 0 }
    var toppedUpBalanceValue: Double { Double(toppedUpBalance) ?? 0 }

    // MARK: - 货币转换

    /// UserDefaults: "currency_rate" — 1 USD = ? CNY（如 7.2 表示 $1 = ¥7.2）
    static var rate: Double {
        get { UserDefaults.standard.double(forKey: "currency_rate") }
        set { UserDefaults.standard.set(newValue, forKey: "currency_rate") }
    }
    static var rateEnabled: Bool { rate > 0 }

    private var symbol: String { currency == "CNY" ? "¥" : "$" }
    private var convSymbol: String { currency == "CNY" ? "$" : "¥" }

    func fmt(_ val: String) -> String {
        let d = Double(val) ?? 0
        guard BalanceInfo.rateEnabled, currency == "CNY" else { return "\(symbol)\(val)" }
        let usd = d / BalanceInfo.rate
        return "¥\(val) ≈ $\(String(format: "%.2f", usd))"
    }

    func fmtCompact(_ val: String) -> String {
        let d = Double(val) ?? 0
        guard BalanceInfo.rateEnabled, currency == "CNY" else { return "\(symbol)\(val)" }
        return "$\(String(format: "%.2f", d / BalanceInfo.rate))"
    }

    var formattedTotal:    String { fmt(totalBalance) }
    var formattedToppedUp: String { fmtCompact(toppedUpBalance) }
    var formattedGranted:  String { fmtCompact(grantedBalance) }
}
