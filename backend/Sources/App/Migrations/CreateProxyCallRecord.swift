import Fluent

struct CreateProxyCallRecord: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema(ProxyCallRecord.schema)
            .id()
            .field("timestamp", .datetime, .required)
            .field("model", .string, .required)
            .field("prompt_tokens", .int, .required)
            .field("completion_tokens", .int, .required)
            .field("estimated_cost", .string, .required)
            .field("request_hash", .string, .required)
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema(ProxyCallRecord.schema).delete()
    }
}
