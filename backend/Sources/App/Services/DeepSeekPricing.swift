import Foundation

/// DeepSeek 官方定价配置
/// 价格单位: 元(CNY) / 百万 tokens
///
/// 数据来源: https://api-docs.deepseek.com/quick_start/pricing
/// 更新时间: 2026-06
enum DeepSeekPricing {

    // MARK: - 定价常量 (CNY per 1M tokens)

    /// deepseek-chat 模型定价
    enum Chat {
        /// 输入价格: ¥1 / 百万 tokens
        static let inputPrice: Decimal = 1.0
        /// 输出价格: ¥2 / 百万 tokens
        static let outputPrice: Decimal = 2.0

        // 缓存命中价格
        /// 缓存命中输入价格: ¥0.1 / 百万 tokens
        static let cacheHitInputPrice: Decimal = 0.1
    }

    /// deepseek-reasoner 模型定价
    enum Reasoner {
        /// 输入价格: ¥4 / 百万 tokens
        static let inputPrice: Decimal = 4.0
        /// 输出价格: ¥16 / 百万 tokens
        static let outputPrice: Decimal = 16.0

        // 缓存命中价格
        /// 缓存命中输入价格: ¥0.4 / 百万 tokens
        static let cacheHitInputPrice: Decimal = 0.4
    }

    // MARK: - 费用计算

    /// 计算一次 API 调用的预估费用（单位: 元 CNY）
    ///
    /// - Parameters:
    ///   - model: 模型名 (如 "deepseek-chat", "deepseek-reasoner")
    ///   - promptTokens: 输入 token 数
    ///   - completionTokens: 输出 token 数
    ///   - isCacheHit: 输入是否命中了缓存
    /// - Returns: 预估费用（CNY）
    static func calculateCost(
        model: String,
        promptTokens: Int,
        completionTokens: Int,
        isCacheHit: Bool = false
    ) -> Decimal {
        let promptMillions = Decimal(promptTokens) / 1_000_000
        let completionMillions = Decimal(completionTokens) / 1_000_000

        let inputPrice: Decimal
        let outputPrice: Decimal

        // 根据模型选择定价
        if model.contains("reasoner") {
            inputPrice = isCacheHit ? Reasoner.cacheHitInputPrice : Reasoner.inputPrice
            outputPrice = Reasoner.outputPrice
        } else {
            // 默认使用 deepseek-chat 定价（包括 deepseek-chat, deepseek-v3 等）
            inputPrice = isCacheHit ? Chat.cacheHitInputPrice : Chat.inputPrice
            outputPrice = Chat.outputPrice
        }

        let inputCost = promptMillions * inputPrice
        let outputCost = completionMillions * outputPrice

        return inputCost + outputCost
    }

    /// 格式化费用为字符串（保留 6 位小数）
    static func formatCost(_ cost: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 6
        formatter.maximumFractionDigits = 6
        return formatter.string(from: cost as NSDecimalNumber) ?? String(describing: cost)
    }
}
