import Foundation

/// 代理调用记录
/// 对应后端 GET /api/proxy/calls 的响应
struct ProxyCallItem: Codable, Identifiable {
    let id: String
    let timestamp: String
    let model: String
    let promptTokens: Int
    let completionTokens: Int
    let estimatedCost: String

    enum CodingKeys: String, CodingKey {
        case id
        case timestamp
        case model
        case promptTokens = "prompt_tokens"
        case completionTokens = "completion_tokens"
        case estimatedCost = "estimated_cost"
    }

    /// 总 Token 数
    var totalTokens: Int {
        promptTokens + completionTokens
    }

    /// 格式化的总 Token 数
    var formattedTotalTokens: String {
        if totalTokens >= 1_000 {
            return String(format: "%.1fK", Double(totalTokens) / 1_000)
        }
        return "\(totalTokens)"
    }

    /// 格式化的费用
    var formattedCost: String {
        let value = Double(estimatedCost) ?? 0
        return String(format: "¥%.4f", value)
    }

    /// 解析后的时间
    var parsedDate: Date? {
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: timestamp)
    }

    /// 相对时间显示（如 "2 小时前"）
    var relativeTime: String {
        guard let date = parsedDate else { return timestamp }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    /// 具体时间显示
    var formattedTime: String {
        guard let date = parsedDate else { return timestamp }
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd HH:mm:ss"
        return formatter.string(from: date)
    }

    /// 模型显示名
    var modelDisplayName: String {
        switch model {
        case "deepseek-chat": return "DeepSeek Chat"
        case "deepseek-reasoner": return "DeepSeek Reasoner"
        default: return model
        }
    }

    /// 模型对应图标
    var modelIcon: String {
        model.contains("reasoner") ? "brain.head.profile" : "message"
    }

    /// 模型对应颜色
    var modelColor: String {
        model.contains("reasoner") ? "purple" : "blue"
    }
}

/// 分页响应
struct ProxyCallPage: Codable {
    let items: [ProxyCallItem]
    let total: Int
    let page: Int
    let per: Int
}
