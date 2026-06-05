import SwiftUI
import SwiftData

/// DeepSeek 用量追踪 — 纯 iOS 原生 App
///
/// 无需后端服务器，直接调 DeepSeek API。
/// 余额快照存本地（SwiftData），对比差值算消费。
@main
struct DeepSeekUsageApp: App {

    /// SwiftData 容器 — 存储余额快照
    let modelContainer: ModelContainer

    init() {
        do {
            modelContainer = try ModelContainer(for: BalanceSnapshot.self)
        } catch {
            fatalError("SwiftData 初始化失败: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(modelContainer)
        }
    }
}
