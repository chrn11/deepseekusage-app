import SwiftUI
import Charts

/// 仪表盘 — "深海仪表盘"设计
///
/// - 呼吸发光余额卡片
/// - 磨砂玻璃统计小组件
/// - 深色主题趋势图
/// - 声呐脉冲加载动画
struct DashboardView: View {
    @StateObject private var vm = DashboardViewModel()
    @State private var pulseScale: CGFloat = 1

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    headerSection
                    balanceHero
                    statGrid
                    if !vm.dailyCosts.isEmpty { usageChart }
                    if !vm.isLoggedIn { loginPrompt }
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 100)
            }
            .scrollIndicators(.hidden)
            .background(Color(hex: "060D17"))
            .toolbarBackground(.hidden, for: .navigationBar)
            .refreshable {
                await vm.loadAll()
                vm.calculateStats()
            }
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

    // MARK: - 顶栏

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("DEEPSEEK")
                    .font(.system(size: 13, weight: .bold))
                    .kerning(2)
                    .foregroundColor(Color(hex: "00C6FF"))
                Text("用量追踪")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(Color(hex: "E8EDF5"))
            }
            Spacer()

            // 刷新按钮 — 脉冲动画
            Button {
                withAnimation(.easeInOut(duration: 0.6)) { pulseScale = 0.85 }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) { pulseScale = 1 }
                }
                Task { await vm.loadAll(); vm.calculateStats() }
            } label: {
                ZStack {
                    if vm.isLoading {
                        ProgressView()
                            .tint(Color(hex: "00C6FF"))
                    } else {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(Color(hex: "00C6FF"))
                    }
                }
                .frame(width: 40, height: 40)
                .scaleEffect(pulseScale)
                .background(
                    Circle()
                        .fill(Color(hex: "00C6FF").opacity(0.08))
                )
                .overlay(
                    Circle()
                        .stroke(Color(hex: "00C6FF").opacity(0.15), lineWidth: 1)
                )
            }
            .disabled(vm.isLoading)
        }
        .padding(.top, 8)
    }

    // MARK: - 余额大卡片

    private var balanceHero: some View {
        ZStack {
            // 发光背景层
            RoundedRectangle(cornerRadius: 24)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: "0A1C3A"),
                            Color(hex: "0D2247"),
                            Color(hex: "091428")
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    // 右下角光晕
                    Circle()
                        .fill(Color(hex: "00C6FF").opacity(0.18))
                        .frame(width: 160, height: 160)
                        .blur(radius: 50)
                        .offset(x: 60, y: 40)
                )
                .overlay(
                    // 左上角紫色光晕
                    Circle()
                        .fill(Color(hex: "7C5CFC").opacity(0.12))
                        .frame(width: 100, height: 100)
                        .blur(radius: 40)
                        .offset(x: -80, y: -20)
                )

            // 边框
            RoundedRectangle(cornerRadius: 24)
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.08), Color(hex: "00C6FF").opacity(0.15)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )

            // 内容
            VStack(spacing: 14) {
                // 顶行：标签 + 币种
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "diamond.fill")
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: "00C6FF"))
                        Text("账户余额")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color(hex: "7B89A0"))
                    }
                    Spacer()
                    if let c = vm.balance?.currency {
                        Text(c)
                            .font(.system(size: 11, weight: .bold).monospacedDigit())
                            .foregroundColor(Color(hex: "00C6FF"))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color(hex: "00C6FF").opacity(0.1))
                            .clipShape(Capsule())
                    }
                }

                // 金额
                if let b = vm.balance {
                    HStack(alignment: .lastTextBaseline, spacing: 2) {
                        Text(b.formattedTotal)
                            .font(.system(size: 42, weight: .bold, design: .monospaced))
                            .foregroundColor(Color(hex: "E8EDF5"))
                    }
                } else if KeychainManager.hasAPIKey {
                    Text("¥ --.--")
                        .font(.system(size: 42, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(hex: "E8EDF5").opacity(0.5))
                } else {
                    Text("填入 Key 开始")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(Color(hex: "7B89A0"))
                }

                // 底行：充值 + 赠送
                if let b = vm.balance {
                    HStack(spacing: 0) {
                        balanceSubItem(label: "充值", value: b.formattedToppedUp, color: Color(hex: "00E6A0"))
                        Divider()
                            .frame(height: 24)
                            .background(Color.white.opacity(0.06))
                            .padding(.horizontal, 20)
                        balanceSubItem(label: "赠送", value: b.formattedGranted, color: Color(hex: "00C6FF"))
                        Spacer()
                    }
                }
            }
            .padding(22)
        }
        .padding(.top, 2)
    }

    private func balanceSubItem(label: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(Color(hex: "5A6A82"))
            Text(value)
                .font(.system(size: 15, weight: .semibold, design: .monospaced))
                .foregroundColor(color)
        }
    }

    // MARK: - 统计网格

    private var statGrid: some View {
        LazyVGrid(columns: [.init(.flexible()), .init(.flexible()), .init(.flexible())], spacing: 10) {
            GlassStatCard(
                title: "今日",
                value: vm.formattedTodaySpend,
                icon: "clock",
                color: Color(hex: "FF6B6B")
            )
            GlassStatCard(
                title: "本周",
                value: vm.formattedWeekSpend,
                icon: "calendar.badge.clock",
                color: Color(hex: "00C6FF")
            )
            GlassStatCard(
                title: "本月",
                value: vm.formattedMonthSpend,
                icon: "calendar",
                color: Color(hex: "7C5CFC")
            )

            if vm.isLoggedIn && vm.weekTokens > 0 {
                GlassStatCard(
                    title: "周Token",
                    value: vm.formattedWeekTokens,
                    icon: "text.word.spacing",
                    color: Color(hex: "00E6A0")
                )
                GlassStatCard(
                    title: "月Token",
                    value: vm.formattedMonthTokens,
                    icon: "text.alignleft",
                    color: Color(hex: "00C6FF")
                )
                GlassStatCard(
                    title: "调用",
                    value: "\(vm.monthCalls)次",
                    icon: "arrow.up.message",
                    color: Color(hex: "7C5CFC")
                )
            }
        }
    }

    // MARK: - 趋势图

    private var usageChart: some View {
        VStack(spacing: 0) {
            // 图标题栏
            HStack {
                Label("消费趋势", systemImage: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(hex: "7B89A0"))
                Spacer()
                Text("日粒度")
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "5A6A82"))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.white.opacity(0.04))
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)

            Chart(vm.dailyCosts) { item in
                BarMark(
                    x: .value("日期", item.formattedDate),
                    y: .value("消费", item.cost)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color(hex: "00C6FF").opacity(0.9),
                                 Color(hex: "00C6FF").opacity(0.2)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .cornerRadius(3)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 5)) {
                    AxisValueLabel()
                        .foregroundStyle(Color(hex: "5A6A82"))
                }
            }
            .chartYAxis {
                AxisMarks {
                    AxisValueLabel()
                        .foregroundStyle(Color(hex: "5A6A82"))
                    AxisGridLine()
                        .foregroundStyle(Color.white.opacity(0.04))
                }
            }
            .chartPlotStyle { plot in
                plot.background(Color.clear)
            }
            .frame(height: 180)
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
        }
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(hex: "0A1228").opacity(0.7))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(.white.opacity(0.06), lineWidth: 1)
                )
        )
    }

    // MARK: - 登录引导

    private var loginPrompt: some View {
        NavigationLink {
            LoginView()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "sparkles")
                    .foregroundColor(Color(hex: "7C5CFC"))
                VStack(alignment: .leading, spacing: 2) {
                    Text("登录查看详细用量").font(.system(size: 14, weight: .semibold))
                    Text("Token 明细 · 费用曲线 · 模型分布").font(.system(size: 12))
                        .foregroundColor(Color(hex: "5A6A82"))
                }
                .foregroundColor(Color(hex: "E8EDF5"))
                Spacer()
                Image(systemName: "chevron.right").font(.caption)
                    .foregroundColor(Color(hex: "00C6FF"))
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(hex: "0A1228").opacity(0.7))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color(hex: "7C5CFC").opacity(0.15), lineWidth: 1)
                    )
            )
        }
    }
}

// MARK: - 磨砂统计卡片

struct GlassStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundColor(color)
                .frame(height: 20)
            Text(value)
                .font(.system(size: 15, weight: .bold, design: .monospaced))
                .foregroundColor(Color(hex: "E8EDF5"))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(title)
                .font(.system(size: 10))
                .foregroundColor(Color(hex: "5A6A82"))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(hex: "0A1228").opacity(0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(color.opacity(0.12), lineWidth: 1)
                )
        )
    }
}
