import Fluent

struct CreateDailyUsage: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema(DailyUsage.schema)
            .id()
            .field("date", .date, .required)
            .field("estimated_spending", .string, .required)
            .field("proxy_token_count", .int, .required)
            .field("proxy_call_count", .int, .required)
            .unique(on: "date")
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema(DailyUsage.schema).delete()
    }
}
