import SwiftUI

/// DeepSeek 用量追踪
@main
struct DeepSeekUsageApp: App {
    init() {
        UIView.appearance().overrideUserInterfaceStyle = .dark
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
        }
    }
}
