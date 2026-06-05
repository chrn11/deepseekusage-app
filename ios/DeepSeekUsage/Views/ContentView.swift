import SwiftUI

/// 主容器
///
/// 自定义 TabBar — 磨砂玻璃 + 荧光选中态
struct ContentView: View {
    @State private var selection = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            // 深海底色
            Color(hex: "060D17").ignoresSafeArea()

            // 页面切换
            TabView(selection: $selection) {
                DashboardView()
                    .tag(0)
                SettingsView()
                    .tag(1)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            // 自定义底部导航
            customTabBar
        }
    }

    // MARK: - 自定义 TabBar

    private var customTabBar: some View {
        HStack(spacing: 0) {
            tabItem(index: 0, icon: "chart.line.uptrend.xyaxis", title: "仪表盘")
            tabItem(index: 1, icon: "gearshape.fill", title: "设置")
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(.ultraThinMaterial)
                .opacity(0.95)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(.white.opacity(0.06), lineWidth: 1)
        )
        .padding(.horizontal, 40)
        .padding(.bottom, 8)
    }

    private func tabItem(index: Int, icon: String, title: String) -> some View {
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                selection = index
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: selection == index ? .bold : .regular))
                if selection == index {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .transition(.move(edge: .leading).combined(with: .opacity))
                }
            }
            .foregroundColor(selection == index ? Color(hex: "00C6FF") : Color(hex: "5A6A82"))
            .frame(height: 40)
            .frame(maxWidth: selection == index ? .infinity : 48)
            .background(
                selection == index
                    ? Color(hex: "00C6FF").opacity(0.1)
                    : Color.clear
            )
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .animation(.spring(response: 0.35, dampingFraction: 0.7), value: selection)
        }
    }
}

// MARK: - HEX 颜色扩展

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (255, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = ((int >> 24) & 0xFF, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
