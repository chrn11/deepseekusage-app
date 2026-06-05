import SwiftUI

/// 主容器 — TabView 架构
///
/// 底部 3 个标签页：
/// 1. 仪表盘 — 用量概览和趋势图
/// 2. 调用记录 — 代理转发历史
/// 3. 设置 — 后端地址等配置
struct ContentView: View {
    var body: some View {
        TabView {
            DashboardView()
                .tabItem {
                    Label("仪表盘", systemImage: "chart.bar.fill")
                }

            CallHistoryView()
                .tabItem {
                    Label("调用记录", systemImage: "list.bullet.rectangle")
                }

            SettingsView()
                .tabItem {
                    Label("设置", systemImage: "gearshape.fill")
                }
        }
    }
}
