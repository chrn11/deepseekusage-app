import Vapor
import Fluent
import FluentSQLiteDriver

public func configure(_ app: Application) async throws {
    // ===================
    // 数据库配置 (SQLite)
    // ===================
    // 数据库文件存储在运行目录下的 db.sqlite
    app.databases.use(.sqlite(.file("db.sqlite")), as: .sqlite)

    // ===================
    // 数据库迁移
    // ===================
    app.migrations.add(CreateBalanceRecord())
    app.migrations.add(CreateDailyUsage())
    app.migrations.add(CreateProxyCallRecord())
    try await app.autoMigrate()

    // ===================
    // 注册路由
    // ===================
    try routes(app)

    // ===================
    // 中间件配置
    // ===================
    // 设置最大 body 大小为 10MB（代理转发需要）
    app.routes.defaultMaxBodySize = "10mb"

    app.logger.notice("✅ DeepSeek Usage Tracker 后端启动完成")
    app.logger.notice("📡 API 地址: http://localhost:8080")
}
