import SwiftUI
import Charts

/// 仪表盘主页
///
/// 展示内容：
/// - 账户余额卡片（实时）
/// - 今日用量卡片
/// - 本月统计卡片（消费/Token/调用次数）
/// - 最近 30 天消费趋势折线图
struct DashboardView: View {
    @StateObject private var viewModel = DashboardViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // ---- 余额卡片 ----
                    balanceCard

                    // ---- 今日用量 + 本月统计（2 列） ----
                    HStack(spacing: 12) {
                        todayCard
                        monthCard
                    }

                    // ---- 消费趋势图 ----
                    chartSection

                    // ---- 手动触发按钮 ----
                    pollButton
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("DeepSeek 用量")
            .refreshable {
                await viewModel.refresh()
            }
            .overlay {
                if viewModel.isLoading && viewModel.balance == nil {
                    ProgressView("加载中...")
                }
            }
            .alert("错误", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("确定") {
                    viewModel.errorMessage = nil
                }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .task {
                await viewModel.loadAllData()
            }
        }
    }

    // MARK: - 余额卡片

    private var balanceCard: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "creditcard.fill")
                    .font(.title2)
                    .foregroundColor(.white)
                Text("账户余额")
                    .font(.headline)
                    .foregroundColor(.white.opacity(0.9))
                Spacer()
                Text(viewModel.balance?.currency ?? "CNY")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.white.opacity(0.2))
                    .clipShape(Capsule())
            }

            if let balance = viewModel.balance {
                Text(balance.formattedTotal)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                HStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("充值余额")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                        Text(balance.formattedToppedUp)
                            .font(.subheadline.bold())
                            .foregroundColor(.white)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("赠送余额")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                        Text(balance.formattedGranted)
                            .font(.subheadline.bold())
                            .foregroundColor(.white)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text("¥ --.--")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .redacted(reason: .placeholder)
            }
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: [Color(red: 0.2, green: 0.4, blue: 0.9),
                         Color(red: 0.1, green: 0.3, blue: 0.7)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - 今日用量卡片

    private var todayCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "clock")
                    .foregroundColor(.orange)
                Text("今日用量")
                    .font(.subheadline.bold())
                    .foregroundColor(.secondary)
            }

            if let today = viewModel.todayUsage {
                Text(today.formattedSpending)
                    .font(.title2.bold())
                    .foregroundColor(.primary)

                HStack(spacing: 12) {
                    Label(today.formattedTokens, systemImage: "text.word.spacing")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Label("\(today.proxyCallCount)次", systemImage: "arrow.up.message")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                Text("¥0.00")
                    .font(.title2.bold())
                    .foregroundColor(.primary)
                Text("暂无代理调用")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 130, alignment: .leading)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }

    // MARK: - 本月统计卡片

    private var monthCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "calendar")
                    .foregroundColor(.green)
                Text("本月统计")
                    .font(.subheadline.bold())
                    .foregroundColor(.secondary)
            }

            Text(viewModel.formattedMonthlySpending)
                .font(.title2.bold())
                .foregroundColor(.primary)

            HStack(spacing: 12) {
                Label(viewModel.formattedMonthlyTokens, systemImage: "text.word.spacing")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Label("\(viewModel.monthlyCalls)次", systemImage: "arrow.up.message")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 130, alignment: .leading)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }

    // MARK: - 消费趋势图

    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundColor(.blue)
                Text("消费趋势（最近30天）")
                    .font(.headline)
                Spacer()

                if let peak = viewModel.peakDay {
                    Text("峰值 \(peak.formattedSpending)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.blue.opacity(0.1))
                        .clipShape(Capsule())
                }
            }

            if viewModel.recentUsage.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "chart.bar.xaxis")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("暂无消费数据")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(height: 200)
                .frame(maxWidth: .infinity)
            } else {
                Chart(viewModel.recentUsage) { item in
                    BarMark(
                        x: .value("日期", item.shortDate),
                        y: .value("消费", Double(item.estimatedSpending) ?? 0)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue.opacity(0.8), .blue.opacity(0.3)],
                            startPoint: .top,
                            endPoint: .bottom
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
                            if let amount = value.as(Double.self) {
                                Text("¥\(String(format: "%.0f", amount))")
                                    .font(.caption2)
                            }
                        }
                    }
                }
                .frame(height: 200)
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }

    // MARK: - 手动触发按钮

    private var pollButton: some View {
        Button {
            Task {
                await viewModel.triggerPoll()
            }
        } label: {
            HStack {
                Image(systemName: "arrow.triangle.2.circlepath")
                Text("手动刷新余额")
            }
            .font(.subheadline)
            .foregroundColor(.blue)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.blue.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
}
