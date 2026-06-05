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

    /// 1 USD 默认汇率（约数，会随市场变化，用户可后续定制）
    static let usdRate: Double = 7.25
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

    /// USD 换算值
    var totalUSD:    Double { totalBalanceValue / CurrencyDisplay.usdRate }
    var grantedUSD:  Double { grantedBalanceValue / CurrencyDisplay.usdRate }
    var toppedUpUSD: Double { toppedUpBalanceValue / CurrencyDisplay.usdRate }

    // MARK: - 格式化

    var formattedTotal: String {
        switch CurrencyDisplay.current {
        case .cny:  return "¥\(totalBalance)"
        case .usd:  return "$\(String(format: "%.2f", totalUSD))"
        case .both: return "¥\(totalBalance)  ·  $\(String(format: "%.2f", totalUSD))"
        }
    }

    var formattedToppedUp: String {
        switch CurrencyDisplay.current {
        case .cny:  return "¥\(toppedUpBalance)"
        case .usd:  return "$\(String(format: "%.2f", toppedUpUSD))"
        case .both: return "¥\(toppedUpBalance)  ·  $\(String(format: "%.2f", toppedUpUSD))"
        }
    }

    var formattedGranted: String {
        switch CurrencyDisplay.current {
        case .cny:  return "¥\(grantedBalance)"
        case .usd:  return "$\(String(format: "%.2f", grantedUSD))"
        case .both: return "¥\(grantedBalance)  ·  $\(String(format: "%.2f", grantedUSD))"
        }
    }
}
