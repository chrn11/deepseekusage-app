import Fluent
import Vapor

/// 代理调用记录 — 每次通过代理转发 API 调用的详细记录
final class ProxyCallRecord: Model, Content, @unchecked Sendable {
    static let schema = "proxy_call_records"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "timestamp")
    var timestamp: Date

    /// 使用的模型名，如 deepseek-chat, deepseek-reasoner
    @Field(key: "model")
    var model: String

    /// 输入 Token 数
    @Field(key: "prompt_tokens")
    var promptTokens: Int

    /// 输出 Token 数
    @Field(key: "completion_tokens")
    var completionTokens: Int

    /// 估算费用（基于 DeepSeek 官方定价计算）
    @Field(key: "estimated_cost")
    var estimatedCost: String

    /// 请求内容的 SHA256 哈希（用于去重）
    @Field(key: "request_hash")
    var requestHash: String

    init() {}

    init(id: UUID? = nil,
         timestamp: Date,
         model: String,
         promptTokens: Int,
         completionTokens: Int,
         estimatedCost: String,
         requestHash: String) {
        self.id = id
        self.timestamp = timestamp
        self.model = model
        self.promptTokens = promptTokens
        self.completionTokens = completionTokens
        self.estimatedCost = estimatedCost
        self.requestHash = requestHash
    }
}

/// 调用记录分页 DTO
struct ProxyCallPageDTO: Content {
    let items: [ProxyCallItemDTO]
    let total: Int
    let page: Int
    let per: Int
}

/// 单条调用记录 DTO
struct ProxyCallItemDTO: Content {
    let id: UUID?
    let timestamp: String
    let model: String
    let promptTokens: Int
    let completionTokens: Int
    let estimatedCost: String
}
