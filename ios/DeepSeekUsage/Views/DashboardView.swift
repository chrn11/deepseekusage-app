import SwiftUI
import SwiftData
import Charts

/// 仪表盘主页
///
/// 展示：
/// - 账户余额卡片
/// - 今日 / 本周 / 本月消费
/// - 30 天消费趋势图
struct DashboardView: View {
    @StateObject private var vm = DashboardViewModel()
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // 余额卡片
                    balanceCard

                    // 今日 / 本周 / 本月
                    HStack(spacing: 12) {
                        StatCard(title: "今日", value: vm.formattedTodaySpend, color: .orange, icon: "clock")
                        StatCard(title: "本周", value: vm.formattedWeekSpend, color: .blue, icon: "calendar.badge.clock")
                        StatCard(title: "本月", value: vm.formattedMonthSpend, color: .purple, icon: "calendar")
                    }

                    // 趋势图
                    chartSection
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
                            Task { await vm.loadData(modelContext: modelContext) }
                        } label: {
                            Image(systemName: "arrow.triangle.2.circlepath")
                        }
                    }
                }
            }
            .refreshable {
                await vm.loadData(modelContext: modelContext)
            }
            .alert("错误", isPresented: .constant(vm.errorMessage != nil)) {
                Button("确定") { vm.errorMessage = nil }
            } message: {
                Text(vm.errorMessage ?? "")
            }
            .task {
                if vm.balance == nil {
                    await vm.loadData(modelContext: modelContext)
                }
                vm.calculateStats(modelContext: modelContext)
            }
        }
    }

    // MARK: - 余额卡片

    private var balanceCard: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "creditcard.fill")
                    .foregroundColor(.white)
                Text("账户余额")
                    .font(.headline)
                    .foregroundColor(.white.opacity(0.9))
                Spacer()
                Text(vm.balance?.currency ?? "---")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(.white.opacity(0.2))
                    .clipShape(Capsule())
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
            } else {
                Text(vm.errorMessage?.contains("请先在设置中填入") == true
                     ? "请在设置中填入 API Key"
                     : "¥ --.--")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))
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

    // MARK: - 趋势图

    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("消费趋势（最近30天）", systemImage: "chart.line.uptrend.xyaxis")
                .font(.headline)

            if vm.dailyStats.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "chart.bar.xaxis")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary.opacity(0.4))
                    Text("多刷新几次就有数据了")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(height: 200).frame(maxWidth: .infinity)
            } else {
                Chart(vm.dailyStats) { stat in
                    BarMark(
                        x: .value("日期", stat.shortDate),
                        y: .value("消费", stat.spend)
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
                    AxisMarks(values: .stride(by: .day, count: 5)) {
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
        }
        .padding(16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - 统计小卡片

struct StatCard: View {
    let title: String
    let value: String
    let color: Color
    let icon: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(color)
            Text(value)
                .font(.subheadline.bold())
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
