import SwiftUI
import Charts

/// 仪表盘 — 深海仪表盘
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
                    if vm.isLoggedIn { monthPicker }
                    if !vm.modelBreakdown.isEmpty { modelPie }
                    if !vm.ioByDay.isEmpty      { ioChart }
                    if !vm.filteredCosts.isEmpty { costChart }
                    if !vm.isLoggedIn { loginPrompt }
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 100)
            }
            .scrollIndicators(.hidden)
            .background(Color(hex: "060D17"))
            .toolbarBackground(.hidden, for: .navigationBar)
            .refreshable { await vm.loadAll(); vm.calculateStats() }
            .alert("错误", isPresented: .constant(vm.errorMessage != nil)) {
                Button("确定") { vm.errorMessage = nil }
            } message: { Text(vm.errorMessage ?? "") }
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
                Text("DEEPSEEK").font(.system(size: 13, weight: .bold)).kerning(2)
                    .foregroundColor(Color(hex: "00C6FF"))
                Text("用量追踪").font(.system(size: 22, weight: .bold))
                    .foregroundColor(Color(hex: "E8EDF5"))
            }
            Spacer()
            Button {
                withAnimation(.easeInOut(duration: 0.6)) { pulseScale = 0.85 }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) { pulseScale = 1 }
                }
                Task { await vm.loadAll(); vm.calculateStats() }
            } label: {
                ZStack {
                    if vm.isLoading { ProgressView().tint(Color(hex: "00C6FF")) }
                    else { Image(systemName: "arrow.triangle.2.circlepath").font(.system(size: 18, weight: .medium))
                        .foregroundColor(Color(hex: "00C6FF")) }
                }
                .frame(width: 40, height: 40).scaleEffect(pulseScale)
                .background(Circle().fill(Color(hex: "00C6FF").opacity(0.08)))
                .overlay(Circle().stroke(Color(hex: "00C6FF").opacity(0.15), lineWidth: 1))
            }
            .disabled(vm.isLoading)
        }
        .padding(.top, 8)
    }

    // MARK: - 余额卡片

    private var balanceHero: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24)
                .fill(LinearGradient(colors: [Color(hex: "0A1C3A"), Color(hex: "0D2247"), Color(hex: "091428")],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(Circle().fill(Color(hex: "00C6FF").opacity(0.18)).frame(width: 160, height: 160).blur(radius: 50).offset(x: 60, y: 40))
                .overlay(Circle().fill(Color(hex: "7C5CFC").opacity(0.12)).frame(width: 100, height: 100).blur(radius: 40).offset(x: -80, y: -20))
            RoundedRectangle(cornerRadius: 24)
                .stroke(LinearGradient(colors: [.white.opacity(0.08), Color(hex: "00C6FF").opacity(0.15)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)

            VStack(spacing: 14) {
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "diamond.fill").font(.system(size: 12)).foregroundColor(Color(hex: "00C6FF"))
                        Text("账户余额").font(.system(size: 13, weight: .medium)).foregroundColor(Color(hex: "7B89A0"))
                    }
                    Spacer()
                    if vm.alertEnabled, let b = vm.balance, b.totalBalanceValue <= vm.alertThreshold {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 10))
                            Text("余额不足").font(.system(size: 10, weight: .bold))
                        }
                        .foregroundColor(Color(hex: "FF6B6B"))
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Color(hex: "FF6B6B").opacity(0.15))
                        .clipShape(Capsule())
                    }
                    if let c = vm.balance?.currency {
                        Text(c).font(.system(size: 11, weight: .bold).monospacedDigit())
                            .foregroundColor(Color(hex: "00C6FF"))
                            .padding(.horizontal, 10).padding(.vertical, 4)
                            .background(Color(hex: "00C6FF").opacity(0.1)).clipShape(Capsule())
                    }
                }
                if let b = vm.balance {
                    Text(b.formattedTotal)
                        .font(.system(size: 42, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(hex: "E8EDF5"))
                } else if KeychainManager.hasAPIKey {
                    Text("¥ --.--").font(.system(size: 42, weight: .bold, design: .monospaced)).foregroundColor(Color(hex: "E8EDF5").opacity(0.5))
                } else {
                    Text("填入 Key 开始").font(.system(size: 26, weight: .bold)).foregroundColor(Color(hex: "7B89A0"))
                }
                if let b = vm.balance {
                    HStack(spacing: 0) {
                        subItem("充值", b.formattedToppedUp, Color(hex: "00E6A0"))
                        Divider().frame(height: 24).background(Color.white.opacity(0.06)).padding(.horizontal, 20)
                        subItem("赠送", b.formattedGranted, Color(hex: "00C6FF"))
                        Spacer()
                    }
                }
            }
            .padding(22)
        }
        .padding(.top, 2)
    }

    private func subItem(_ l: String, _ v: String, _ c: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(l).font(.system(size: 11)).foregroundColor(Color(hex: "5A6A82"))
            Text(v).font(.system(size: 15, weight: .semibold, design: .monospaced)).foregroundColor(c)
        }
    }

    // MARK: - 统计

    private var statGrid: some View {
        LazyVGrid(columns: [.init(.flexible()), .init(.flexible()), .init(.flexible())], spacing: 10) {
            GlassStatCard(title: "今日",   value: vm.formattedTodaySpend, icon: "clock",                color: Color(hex: "FF6B6B"))
            GlassStatCard(title: "本周",   value: vm.formattedWeekSpend,  icon: "calendar.badge.clock", color: Color(hex: "00C6FF"))
            GlassStatCard(title: mcLabel,  value: vm.formattedMonthSpend, icon: "calendar", color: Color(hex: "7C5CFC"))
            if vm.isLoggedIn {
                GlassStatCard(title: "周Token", value: vm.formattedWeekTokens,  icon: "text.word.spacing", color: Color(hex: "00E6A0"))
                GlassStatCard(title: "月Token", value: vm.formattedMonthTokens, icon: "text.alignleft",   color: Color(hex: "00C6FF"))
                GlassStatCard(title: "调用",     value: "\(vm.monthCalls)次",   icon: "arrow.up.message", color: Color(hex: "7C5CFC"))
            }
        }
    }

    private var mcLabel: String { vm.selectedMonth == YearMonth.current ? "本月" : "\(vm.selectedMonth.month)月" }

    // MARK: - 月份

    private var monthPicker: some View {
        HStack(spacing: 0) {
            Btn(nav: -1)
            Text(vm.selectedMonthLabel)
                .font(.system(size: 15, weight: .semibold, design: .monospaced))
                .foregroundColor(Color(hex: "E8EDF5")).frame(maxWidth: .infinity)
            Btn(nav: 1)
        }
        .padding(.vertical, 4)
        .background(RoundedRectangle(cornerRadius: 12)
            .fill(Color(hex: "0A1228").opacity(0.6))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: "00C6FF").opacity(0.12), lineWidth: 1)))
    }

    private func Btn(nav: Int) -> some View {
        let isPrev = nav == -1
        let ok = isPrev
            ? (vm.availableMonths.firstIndex(of: vm.selectedMonth) ?? 0) + 1 < vm.availableMonths.count
            : (vm.availableMonths.firstIndex(of: vm.selectedMonth) ?? 0) > 0
        return Button {
            withAnimation { isPrev ? vm.previousMonth() : vm.nextMonth() }
        } label: {
            Image(systemName: isPrev ? "chevron.left" : "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(ok ? Color(hex: "00C6FF") : Color(hex: "5A6A82").opacity(0.3))
                .frame(width: 36, height: 36)
        }
        .disabled(!ok)
    }

    // MARK: - 模型饼图

    private var modelPie: some View {
        chartBox(title: "模型用量占比", subtitle: "\(vm.modelBreakdown.count) 个模型") {
            VStack(spacing: 12) {
                DonutChart(data: vm.modelBreakdown).frame(height: 160)
                LazyVGrid(columns: [.init(.flexible()), .init(.flexible())], spacing: 6) {
                    ForEach(vm.modelBreakdown) { m in
                        HStack(spacing: 4) {
                            Circle().fill(modelColor(m.model)).frame(width: 8, height: 8)
                            Text(m.model).font(.system(size: 11)).foregroundColor(Color(hex: "7B89A0")).lineLimit(1)
                            Text(m.pct).font(.system(size: 10, weight: .bold)).foregroundColor(Color(hex: "5A6A82"))
                            Spacer()
                        }
                    }
                }
                .padding(.horizontal, 8)
            }
            .padding(.bottom, 12)
        }
    }

    private let modelColors: [Color] = [
        Color(hex: "00C6FF"), Color(hex: "7C5CFC"), Color(hex: "00E6A0"),
        Color(hex: "FF6B6B"), Color(hex: "FFD93D"), Color(hex: "FF8C42"),
        Color(hex: "C0A8FF"), Color(hex: "5CE1E6"),
    ]

    private func modelColor(_ name: String) -> Color {
        guard let i = vm.modelBreakdown.map(\.model).firstIndex(of: name) else { return .gray }
        return modelColors[i % modelColors.count]
    }

    // MARK: - I/O 堆叠柱状图

    private var ioChart: some View {
        chartBox(title: "Token 输入 / 输出", subtitle: "蓝色=输入 紫色=输出") {
            Chart(vm.ioByDay) { pair in
                BarMark(x: .value("日期", pair.shortDate), y: .value("输入", pair.input))
                    .foregroundStyle(Color(hex: "00C6FF").opacity(0.8))
                BarMark(x: .value("日期", pair.shortDate), y: .value("输出", pair.output))
                    .foregroundStyle(Color(hex: "7C5CFC").opacity(0.8))
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 5)) {
                    AxisValueLabel().foregroundStyle(Color(hex: "5A6A82"))
                }
            }
            .chartYAxis {
                AxisMarks { AxisGridLine().foregroundStyle(Color.white.opacity(0.04)) }
            }
            .chartPlotStyle { $0.background(Color.clear) }
            .frame(height: 180)
        }
    }

    // MARK: - 费用柱状图

    private var costChart: some View {
        chartBox(title: "消费趋势", subtitle: "日粒度 · ¥") {
            Chart(vm.filteredCosts) { item in
                BarMark(x: .value("日期", item.formattedDate), y: .value("消费", item.cost))
                    .foregroundStyle(LinearGradient(
                        colors: [Color(hex: "00E6A0").opacity(0.9), Color(hex: "00E6A0").opacity(0.2)],
                        startPoint: .top, endPoint: .bottom))
                    .cornerRadius(3)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 5)) {
                    AxisValueLabel().foregroundStyle(Color(hex: "5A6A82"))
                }
            }
            .chartYAxis {
                AxisMarks {
                    AxisValueLabel().foregroundStyle(Color(hex: "5A6A82"))
                    AxisGridLine().foregroundStyle(Color.white.opacity(0.04))
                }
            }
            .chartPlotStyle { $0.background(Color.clear) }
            .frame(height: 180)
        }
    }

    // MARK: - 登录

    private var loginPrompt: some View {
        NavigationLink { LoginView() } label: {
            HStack(spacing: 10) {
                Image(systemName: "sparkles").foregroundColor(Color(hex: "7C5CFC"))
                VStack(alignment: .leading, spacing: 2) {
                    Text("登录查看详细用量").font(.system(size: 14, weight: .semibold)).foregroundColor(Color(hex: "E8EDF5"))
                    Text("Token 明细 · 费用曲线 · 模型分布").font(.system(size: 12)).foregroundColor(Color(hex: "5A6A82"))
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption).foregroundColor(Color(hex: "00C6FF"))
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 14)
                .fill(Color(hex: "0A1228").opacity(0.7))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(hex: "7C5CFC").opacity(0.15), lineWidth: 1)))
        }
    }

    // MARK: - 图表容器

    private func chartBox(title: String, subtitle: String,
                          @ViewBuilder content: () -> some View) -> some View {
        VStack(spacing: 0) {
            HStack {
                Label(title, systemImage: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 14, weight: .semibold)).foregroundColor(Color(hex: "7B89A0"))
                Spacer()
                Text(subtitle).font(.system(size: 11)).foregroundColor(Color(hex: "5A6A82"))
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Color.white.opacity(0.04)).clipShape(Capsule())
            }
            .padding(.horizontal, 16).padding(.top, 16)
            content()
                .padding(.horizontal, 8).padding(.bottom, 8)
        }
        .background(RoundedRectangle(cornerRadius: 18)
            .fill(Color(hex: "0A1228").opacity(0.7))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(.white.opacity(0.06), lineWidth: 1)))
    }
}

// MARK: - Canvas 饼图（iOS 16 兼容，SectorMark 仅 iOS 17+）

struct DonutChart: View {
    let data: [ModelShare]
    private let colors: [Color] = [Color(hex: "00C6FF"), Color(hex: "7C5CFC"), Color(hex: "00E6A0"),
                                    Color(hex: "FF6B6B"), Color(hex: "FFD93D"), Color(hex: "FF8C42"),
                                    Color(hex: "C0A8FF"), Color(hex: "5CE1E6")]

    var body: some View {
        Canvas { ctx, size in
            let total = data.map(\.tokens).reduce(0, +)
            guard total > 0 else { return }
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = min(size.width, size.height) / 2 * 0.75
            let inner = radius * 0.55
            var startAngle = -Double.pi / 2

            for (i, m) in data.enumerated() {
                let frac = Double(m.tokens) / Double(total)
                let endAngle = startAngle + frac * 2 * .pi
                let path = Path { p in
                    p.addArc(center: center, radius: radius, startAngle: Angle(radians: startAngle),
                             endAngle: Angle(radians: endAngle), clockwise: false)
                    p.addArc(center: center, radius: inner, startAngle: Angle(radians: endAngle),
                             endAngle: Angle(radians: startAngle), clockwise: true)
                    p.closeSubpath()
                }
                ctx.fill(path, with: .color(colors[i % colors.count]))
                startAngle = endAngle
            }
        }
    }
}

// MARK: - 统计卡片

struct GlassStatCard: View {
    let title: String; let value: String; let icon: String; let color: Color
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon).font(.system(size: 13)).foregroundColor(color).frame(height: 20)
            Text(value).font(.system(size: 15, weight: .bold, design: .monospaced))
                .foregroundColor(Color(hex: "E8EDF5")).lineLimit(1).minimumScaleFactor(0.7)
            Text(title).font(.system(size: 10)).foregroundColor(Color(hex: "5A6A82"))
        }
        .frame(maxWidth: .infinity).padding(.vertical, 14)
        .background(RoundedRectangle(cornerRadius: 14)
            .fill(Color(hex: "0A1228").opacity(0.6))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(color.opacity(0.12), lineWidth: 1)))
    }
}
