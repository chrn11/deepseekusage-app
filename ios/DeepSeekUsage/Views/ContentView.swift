import SwiftUI

/// 主容器 — 两个标签页
/// 1. 仪表盘 — 余额 / 消费趋势
/// 2. 设置 — API Key / 关于
struct ContentView: View {
    var body: some View {
        TabView {
            DashboardView()
                .tabItem {
                    Label("仪表盘", systemImage: "chart.bar.fill")
                }

            SettingsView()
                .tabItem {
                    Label("设置", systemImage: "gearshape.fill")
                }
        }
    }
}
