import SwiftUI
import Charts

/// 仪表盘主页
struct DashboardView: View {
    @StateObject private var vm = DashboardViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // 余额
                    balanceCard

                    // 消费统计
                    HStack(spacing: 12) {
                        StatCard(title: "今日消费", value: vm.formattedTodaySpend, color: .orange, icon: "clock")
                        StatCard(title: "本周消费", value: vm.formattedWeekSpend, color: .blue, icon: "calendar.badge.clock")
                        StatCard(title: "本月消费", value: vm.formattedMonthSpend, color: .purple, icon: "calendar")
                    }

                    // Token 统计（平台登录后才显示）
                    if vm.isLoggedIn && (vm.weekTokens > 0 || vm.monthTokens > 0) {
                        HStack(spacing: 12) {
                            StatCard(title: "本周 Token", value: vm.formattedWeekTokens, color: .green, icon: "text.word.spacing")
                            StatCard(title: "本月 Token", value: vm.formattedMonthTokens, color: .teal, icon: "text.alignleft")
                            StatCard(title: "调用次数", value: "\(vm.monthCalls)次", color: .indigo, icon: "arrow.up.message")
                        }
                    }

                    // 每日用量折线图（平台接口）
                    if !vm.dailyCosts.isEmpty {
                        platformChart
                    }

                    // 登录提示
                    if !vm.isLoggedIn {
                        loginBanner
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("DeepSeek 用量")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if vm.isLoading {
                        ProgressView()
                    } else {
                        Button {
                            Task { await vm.loadAll() }
                        } label: {
                            Image(systemName: "arrow.triangle.2.circlepath")
                        }
                    }
                }
            }
            .refreshable { await vm.loadAll() }
            .alert("错误", isPresented: .constant(vm.errorMessage != nil)) {
                Button("确定") { vm.errorMessage = nil }
            } message: {
                Text(vm.errorMessage ?? "")
            }
            .task {
                if vm.balance == nil { await vm.loadAll() }
                vm.calculateStats()
            }
        }
    }

    // MARK: - 余额卡片

    private var balanceCard: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "creditcard.fill").foregroundColor(.white)
                Text("账户余额").font(.headline).foregroundColor(.white.opacity(0.9))
                Spacer()
                Text(vm.balance?.currency ?? "---")
                    .font(.caption).foregroundColor(.white.opacity(0.7))
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(.white.opacity(0.2)).clipShape(Capsule())
            }

            if let b = vm.balance {
                Text(b.formattedTotal)
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                HStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("充值余额").font(.caption).foregroundColor(.white.opacity(0.7))
                        Text(b.formattedToppedUp).font(.subheadline.bold()).foregroundColor(.white)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("赠送余额").font(.caption).foregroundColor(.white.opacity(0.7))
                        Text(b.formattedGranted).font(.subheadline.bold()).foregroundColor(.white)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else if KeychainManager.hasAPIKey {
                Text("¥ --.--")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))
            } else {
                Text("请在设置中填入 API Key")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: [Color(red: 0.2, green: 0.4, blue: 0.9),
                         Color(red: 0.1, green: 0.3, blue: 0.7)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - 平台用量图（有 Cookie 时显示）

    private var platformChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("消费趋势（DeepSeek 平台数据）", systemImage: "chart.line.uptrend.xyaxis")
                .font(.headline)

            Chart(dailyCosts) { item in
                BarMark(
                    x: .value("日期", item.formattedDate),
                    y: .value("消费", item.cost)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue.opacity(0.8), .blue.opacity(0.3)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .cornerRadius(4)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 5)) { _ in
                    AxisValueLabel()
                }
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisValueLabel {
                        if let v = value.as(Double.self) {
                            Text("¥\(String(format: "%.0f", v))").font(.caption2)
                        }
                    }
                }
            }
            .frame(height: 200)
        }
        .padding(16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - 登录提示

    private var loginBanner: some View {
        NavigationLink {
            LoginView()
        } label: {
            HStack {
                Image(systemName: "person.badge.key")
                Text("登录 DeepSeek 平台查看详细用量").font(.subheadline)
                Spacer()
                Image(systemName: "chevron.right").font(.caption).foregroundColor(.secondary)
            }
            .padding(14)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(.blue.opacity(0.3), lineWidth: 1)
            )
        }
    }
}

// MARK: - 统计卡片

struct StatCard: View {
    let title: String
    let value: String
    let color: Color
    let icon: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon).font(.caption).foregroundColor(color)
            Text(value).font(.subheadline.bold())
            Text(title).font(.caption2).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
