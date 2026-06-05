import Vapor

@main
struct Main {
    static func main() async throws {
        var env = try Environment.detect()
        try LoggingSystem.bootstrap(from: &env)

        let app = try await Application.make(env)

        // 读取 DEEPSEEK_API_KEY 环境变量
        guard let apiKey = Environment.get("DEEPSEEK_API_KEY"), !apiKey.isEmpty else {
            app.logger.critical("DEEPSEEK_API_KEY 环境变量未设置！")
            fatalError("请在 .env 文件或环境中设置 DEEPSEEK_API_KEY")
        }

        // 存到 Application storage 中供全局使用
        app.storage[DeepSeekAPIKey.self] = apiKey

        // 配置数据库、路由等
        try await configure(app)

        // 启动余额定时监控
        await BalancePollingService.shared.start(on: app)

        try await app.execute()
        try await app.asyncShutdown()
    }
}

/// 用于在 Application storage 中存取 API Key 的 Key
struct DeepSeekAPIKey: StorageKey {
    typealias Value = String
}
