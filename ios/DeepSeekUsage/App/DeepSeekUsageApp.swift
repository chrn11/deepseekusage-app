import SwiftUI

/// DeepSeek 用量追踪 App 入口
///
/// 设计方向："深海仪表盘" — 深蓝黑底色 + 生物荧光点缀
/// 强制深色模式，全 App 统一色调
@main
struct DeepSeekUsageApp: App {
    init() {
        // 全局强制深色模式
        UIView.appearance().overrideUserInterfaceStyle = .dark
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
        }
    }
}
