import Foundation

// MARK: - 货币显示模式

enum CurrencyDisplay: String, CaseIterable {
    case cny = "仅人民币"
    case usd = "仅美元"
    case both = "双币种"

    static var current: CurrencyDisplay {
        get {
            if let raw = UserDefaults.standard.string(forKey: "currency_display"),
               let v = CurrencyDisplay(rawValue: raw) { return v }
            return .cny
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "currency_display") }
    }

    /// 币种显示目标：主显示用哪个货币
    var primaryCurrency: String {
        switch self {
        case .cny, .both: return "CNY"
        case .usd:         return "USD"
        }
    }
}

// MARK: - API 响应

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

    // MARK: - 币种判断

    var isCNY: Bool { currency == "CNY" }
    var isUSD: Bool { currency == "USD" }

    // MARK: - 格式化（直接用 API 原始数据，不做手动汇率换算）

    var formattedTotal: String {
        currency == "CNY"
            ? "¥\(totalBalance)"
            : "$\(totalBalance)"
    }

    var formattedToppedUp: String {
        currency == "CNY"
            ? "¥\(toppedUpBalance)"
            : "$\(toppedUpBalance)"
    }

    var formattedGranted: String {
        currency == "CNY"
            ? "¥\(grantedBalance)"
            : "$\(grantedBalance)"
    }
}

// MARK: - 余额数组辅助：根据显示设置选取币种

extension [BalanceInfo] {
    /// 按 CurrencyDisplay 设置选取主显示币种的余额
    var primary: BalanceInfo? {
        let preferred = CurrencyDisplay.current.primaryCurrency
        return first(where: { $0.currency == preferred })
            ?? first(where: { $0.currency == "CNY" })
            ?? first
    }

    var cny: BalanceInfo? { first(where: { $0.isCNY }) }
    var usd: BalanceInfo? { first(where: { $0.isUSD }) }

    /// 双币种显示格式：¥x.xx · $x.xx
    var formattedBoth: String {
        let c = cny, u = usd
        if let c, let u {
            return "¥\(c.totalBalance)  ·  $\(String(format: "%.2f", u.totalBalanceValue))"
        }
        return cny?.formattedTotal ?? usd?.formattedTotal ?? "--"
    }
}
