import Foundation

// MARK: - 图表与统计数据模型

/// 模型占比（Token 分布饼图/列表）
struct ModelShare: Identifiable {
    let id = UUID()
    let model: String; let tokens: Int; let cost: Double; let fraction: Double
    var pct: String { String(format: "%.0f%%", fraction * 100) }
    var formattedTokens: String {
        tokens >= 1_000_000 ? String(format: "%.1fM", Double(tokens)/1_000_000)
        : tokens >= 1_000   ? String(format: "%.0fK", Double(tokens)/1_000) : "\(tokens)"
    }
    var formattedCost: String { String(format: "¥%.2f", cost) }
}

/// 模型费用明细（按类型分组）
struct ModelCostDetail: Identifiable {
    let id = UUID()
    let model: String
    let totalCost: Double
    let details: [CostDetail]
}

/// 单项费用明细（PROMPT_TOKEN / CACHE_HIT / CACHE_MISS / RESPONSE_TOKEN / REQUEST）
struct CostDetail: Identifiable {
    let id = UUID()
    let type: String
    let amount: Double
}

/// 每日费用
struct DailyCost: Identifiable {
    let id = UUID(); let date: String; let cost: Double
    var formattedDate: String { date.count >= 10 ? String(date.suffix(5)) : date }
    var formattedCostCNY: String { String(format: "¥%.2f", cost) }
    var formattedCostUSD: String { String(format: "$%.2f", cost) }
}

/// 每日输入/输出 Token 对
struct IOPair: Identifiable {
    let id = UUID(); let date: String; let input: Int; let output: Int
    var shortDate: String { date.count >= 10 ? String(date.suffix(5)) : date }
}

// MARK: - 按模型每日数据

/// 每日数值数据
struct DayValue: Identifiable {
    let id = UUID()
    let date: String
    let value: Int
    var shortDate: String { date.count >= 10 ? String(date.suffix(5)) : date }
}

/// 模型每日数据
struct ModelDayData: Identifiable {
    let id = UUID()
    let model: String
    let days: [DayValue]
    var total: Int { days.map(\.value).reduce(0, +) }
}

/// 按模型聚合的请求+Token 图表数据
struct ModelChartData: Identifiable {
    let id = UUID()
    let model: String
    let requestDays: [DayValue]
    let tokenDays: [DayValue]
    var totalRequests: Int { requestDays.map(\.value).reduce(0, +) }
    var totalTokens: Int { tokenDays.map(\.value).reduce(0, +) }
}

// MARK: - YearMonth

struct YearMonth: Equatable, Hashable, Comparable {
    let year, month: Int
    static var current: YearMonth {
        let c = Calendar.current.dateComponents([.year, .month], from: Date())
        return YearMonth(year: c.year ?? 2026, month: c.month ?? 1)
    }
    init(year: Int, month: Int) { self.year = year; self.month = month }

    var label: String {
        let names = ["1月","2月","3月","4月","5月","6月","7月","8月","9月","10月","11月","12月"]
        return "\(year)年 \(names[month - 1])"
    }

    func previous() -> YearMonth {
        month > 1 ? YearMonth(year: year, month: month - 1)
                  : YearMonth(year: year - 1, month: 12)
    }
    static func < (l: YearMonth, r: YearMonth) -> Bool {
        l.year < r.year || (l.year == r.year && l.month < r.month)
    }
}
