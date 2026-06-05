import Fluent

struct CreateBalanceRecord: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema(BalanceRecord.schema)
            .id()
            .field("timestamp", .datetime, .required)
            .field("total_balance", .string, .required)
            .field("granted_balance", .string, .required)
            .field("topped_up_balance", .string, .required)
            .field("currency", .string, .required)
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema(BalanceRecord.schema).delete()
    }
}
