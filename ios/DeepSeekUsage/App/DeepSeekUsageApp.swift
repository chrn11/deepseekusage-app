import SwiftUI

/// DeepSeek Usage Tracker iOS App 入口
///
/// 使用方法：
/// 1. 在 Xcode 中创建新的 iOS App 项目，选择 SwiftUI
/// 2. 把 DeepSeekUsage 文件夹拖入项目
/// 3. 在项目设置中把 @main 入口改为这个文件
/// 4. 运行！
@main
struct DeepSeekUsageApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
