import SwiftUI
import UserNotifications

/// DeepSeek 用量追踪
@main
struct DeepSeekUsageApp: App {
    init() {
        UIView.appearance().overrideUserInterfaceStyle = .dark
        // 请求通知权限（余额预警用）
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
        }
    }
}
