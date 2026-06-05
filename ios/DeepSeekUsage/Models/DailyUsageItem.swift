import Foundation

/// 每日用量统计
/// 对应后端 GET /api/usage/daily 的响应
struct DailyUsageItem: Codable, Identifiable {
    var id: String { date }
    let date: String
    let estimatedSpending: String
    let proxyTokenCount: Int
    let proxyCallCount: Int

    enum CodingKeys: String, CodingKey {
        case date
        case estimatedSpending = "estimated_spending"
        case proxyTokenCount = "proxy_token_count"
        case proxyCallCount = "proxy_call_count"
    }

    /// 格式化的消费金额
    var formattedSpending: String {
        let value = Double(estimatedSpending) ?? 0
        return String(format: "¥%.2f", value)
    }

    /// 格式化的 Token 数量（如 "120K"）
    var formattedTokens: String {
        if proxyTokenCount >= 1_000_000 {
            return String(format: "%.1fM", Double(proxyTokenCount) / 1_000_000)
        } else if proxyTokenCount >= 1_000 {
            return String(format: "%.1fK", Double(proxyTokenCount) / 1_000)
        }
        return "\(proxyTokenCount)"
    }

    /// 解析为 Date（用于图表横轴）
    var parsedDate: Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return formatter.date(from: date)
    }

    /// 日期的简短显示（如 "6/5"）
    var shortDate: String {
        guard let date = parsedDate else { return date }
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        return formatter.string(from: date)
    }
}
