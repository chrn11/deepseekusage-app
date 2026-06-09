import Foundation

// MARK: - 平台 API 错误

enum PlatformError: LocalizedError {
    case invalidURL, invalidResponse, notLoggedIn, loginExpired, loginFailed
    case serverError(code: Int, body: String)
    var errorDescription: String? {
        switch self {
        case .notLoggedIn:             "请先在设置中登录 DeepSeek 平台"
        case .loginExpired:            "登录已过期，请重新登录"
        case .loginFailed:             "邮箱或密码错误"
        case .serverError(let code, _): "平台接口异常 (HTTP \(code))"
        default: nil
        }
    }
}

// MARK: - 登录请求/响应

struct LoginResult {
    let token: String; let email: String; let currency: String; let balance: String
}

struct LoginResponse: Codable {
    let data: LoginData?
    struct LoginData: Codable {
        let bizData: LoginBiz?
        enum CodingKeys: String, CodingKey { case bizData = "biz_data" }
        struct LoginBiz: Codable {
            let user: LoginUser?
            struct LoginUser: Codable {
                let token, email, currency: String?
                let normalWallets: [WalletInfo]?
                enum CodingKeys: String, CodingKey {
                    case token, email, currency
                    case normalWallets = "normal_wallets"
                }
            }
        }
    }
}

struct WalletInfo: Codable {
    let currency: String; let balance: String; let tokenEstimation: String?
    enum CodingKeys: String, CodingKey {
        case currency, balance
        case tokenEstimation = "token_estimation"
    }
}

// MARK: - 汇总响应

struct SummaryResponse: Codable {
    let data: SummaryWrap?
    struct SummaryWrap: Codable {
        let bizData: SummaryData?
        enum CodingKeys: String, CodingKey { case bizData = "biz_data" }
    }
}
struct SummaryData: Codable {
    let normalWallets: [WalletInfo]?
    let bonusWallets: [WalletInfo]?
    let monthlyCosts: [CostItem]?
    let monthlyTokenUsage: String?
    let monthlyUsage: String?
    let totalUsage: Int?
    let currentToken: Int?
    let totalAvailableTokenEstimation: String?

    enum CodingKeys: String, CodingKey {
        case normalWallets = "normal_wallets"
        case bonusWallets = "bonus_wallets"
        case monthlyCosts = "monthly_costs"
        case monthlyTokenUsage = "monthly_token_usage"
        case monthlyUsage = "monthly_usage"
        case totalUsage = "total_usage"
        case currentToken = "current_token"
        case totalAvailableTokenEstimation = "total_available_token_estimation"
    }

    var totalBalanceCNY: Double {
        (normalWallets?.first(where: { $0.currency == "CNY" })?.balance).flatMap(Double.init) ?? 0
    }
    var totalBalanceUSD: Double {
        (normalWallets?.first(where: { $0.currency == "USD" })?.balance).flatMap(Double.init) ?? 0
    }
    var costCNY: Double { (monthlyCosts?.first(where: { $0.currency == "CNY" })?.amount).flatMap(Double.init) ?? 0 }
    var costUSD: Double { (monthlyCosts?.first(where: { $0.currency == "USD" })?.amount).flatMap(Double.init) ?? 0 }
    var tokens: Int { (monthlyTokenUsage).flatMap(Int.init) ?? 0 }
}
struct CostItem: Codable {
    let currency: String; let amount: String?
}

// MARK: - 用量响应

struct UsageAmountResponse: Codable {
    let data: AmountWrap?
    struct AmountWrap: Codable {
        let bizData: UsageAmountData?
        enum CodingKeys: String, CodingKey { case bizData = "biz_data" }
    }
}
struct UsageAmountData: Codable {
    let total: [ModelUsage]?
    let days: [DayAmount]?
}
struct ModelUsage: Codable {
    let model: String?
    let usage: [UsageEntry]?
}
struct DayAmount: Codable {
    let date: String?
    let data: [ModelUsage]?
}
struct UsageEntry: Codable {
    let type: String?
    let amount: String?
}

// MARK: - 费用响应

struct UsageCostResponse: Codable {
    let data: CostWrap?
    struct CostWrap: Codable {
        // biz_data 是数组，每个元素按币种分组
        let bizData: [CostCurrencyGroup]?
        enum CodingKeys: String, CodingKey { case bizData = "biz_data" }
    }
}
/// 按币种分组的费用数据
struct CostCurrencyGroup: Codable {
    let total: [ModelUsage]?
    let days: [DayAmount]?
    let currency: String?
}
