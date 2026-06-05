import SwiftUI

/// DeepSeek 用量追踪 — 纯 iOS 原生 App
///
/// 不需要后端服务器。API Key 存钥匙串，余额快照存本地 JSON。
/// iOS 16+ 即可运行。
@main
struct DeepSeekUsageApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
