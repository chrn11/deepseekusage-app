import Vapor
import Fluent
import Crypto

/// 代理转发服务
/// 负责将客户端的聊天请求转发到 DeepSeek API，并自动记录 Token 消耗
struct ProxyService {

    /// 代理转发 /chat/completions 请求
    ///
    /// 流程：
    /// 1. 接收客户端的原始请求体
    /// 2. 转发到 https://api.deepseek.com/chat/completions
    /// 3. 从 DeepSeek 响应中提取 usage 信息（prompt_tokens, completion_tokens）
    /// 4. 计算费用并存入 proxy_call_records 表
    /// 5. 更新 daily_usages 表的代理统计
    /// 6. 把 DeepSeek 的响应原样返回给客户端
    func proxyChatCompletion(req: Request, apiKey: String) async throws -> Response {
        // ---- 步骤 1: 读取客户端请求体 ----
        guard let body = req.body.data,
              let bodyData = body.getData(at: 0, length: body.readableBytes) else {
            throw Abort(.badRequest, reason: "请求体为空")
        }

        // ---- 步骤 2: 计算请求哈希（用于去重） ----
        let requestHash = SHA256.hash(data: bodyData).hexEncodedString()

        // ---- 步骤 3: 转发到 DeepSeek API ----
        let deepseekURI = URI(string: "https://api.deepseek.com/chat/completions")
        let deepseekResponse = try await req.client.post(deepseekURI) { clientReq in
            clientReq.headers.bearerAuthorization = BearerAuthorization(token: apiKey)
            clientReq.headers.contentType = .json
            clientReq.body = .init(data: bodyData)
        }

        // ---- 步骤 4: 提取响应体 ----
        guard let responseBody = deepseekResponse.body,
              let responseData = responseBody.getData(at: 0, length: responseBody.readableBytes) else {
            throw Abort(.badGateway, reason: "DeepSeek 返回空响应")
        }

        // ---- 步骤 5: 解析 usage 并记录到数据库 ----
        do {
            let usageInfo = try JSONDecoder().decode(DeepSeekChatResponse.self, from: responseData)
            if let usage = usageInfo.usage {
                // 计算费用
                let model = usageInfo.model ?? "unknown"
                let cost = DeepSeekPricing.calculateCost(
                    model: model,
                    promptTokens: usage.promptTokens,
                    completionTokens: usage.completionTokens
                )

                // 保存调用记录
                let callRecord = ProxyCallRecord(
                    timestamp: Date(),
                    model: model,
                    promptTokens: usage.promptTokens,
                    completionTokens: usage.completionTokens,
                    estimatedCost: String(format: "%.6f", cost),
                    requestHash: requestHash
                )
                try await callRecord.save(on: req.db)

                // 更新今日用量统计
                try await updateTodayProxyStats(
                    on: req.db,
                    tokenCount: usage.totalTokens,
                    callCount: 1
                )

                req.logger.info("📝 代理调用记录: \(model) | prompt:\(usage.promptTokens) completion:\(usage.completionTokens) | ¥\(String(format: "%.6f", cost))")
            }
        } catch {
            req.logger.warning("⚠️ 解析 DeepSeek 响应 usage 失败: \(error.localizedDescription)")
            // 即使解析失败，仍然把响应返回给客户端
        }

        // ---- 步骤 6: 构建并返回响应 ----
        var headers = HTTPHeaders()
        headers.contentType = .json
        // 透传 DeepSeek 的 useful headers
        for (name, value) in deepseekResponse.headers {
            headers.add(name: name, value: value)
        }

        return Response(
            status: deepseekResponse.status,
            headers: headers,
            body: .init(data: responseData)
        )
    }

    // MARK: - 更新今日代理统计

    private func updateTodayProxyStats(on db: Database, tokenCount: Int, callCount: Int) async throws {
        let today = Calendar.current.startOfDay(for: Date())

        if let daily = try await DailyUsage.query(on: db)
            .filter(\.$date == today)
            .first() {
            daily.proxyTokenCount += tokenCount
            daily.proxyCallCount += callCount
            try await daily.save(on: db)
        } else {
            let newDaily = DailyUsage(
                date: today,
                estimatedSpending: "0.00",
                proxyTokenCount: tokenCount,
                proxyCallCount: callCount
            )
            try await newDaily.save(on: db)
        }
    }
}

// MARK: - DeepSeek 聊天响应结构（仅提取 usage 相关字段）

/// DeepSeek /chat/completions 的响应结构
struct DeepSeekChatResponse: Decodable {
    let id: String?
    let model: String?
    let usage: DeepSeekUsage?

    struct DeepSeekUsage: Decodable {
        let promptTokens: Int
        let completionTokens: Int
        let totalTokens: Int

        enum CodingKeys: String, CodingKey {
            case promptTokens = "prompt_tokens"
            case completionTokens = "completion_tokens"
            case totalTokens = "total_tokens"
        }
    }
}
