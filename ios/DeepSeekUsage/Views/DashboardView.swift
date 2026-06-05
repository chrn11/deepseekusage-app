import SwiftUI
import Charts

// MARK: - 仪表盘主视图

struct DashboardView: View {
    @StateObject private var vm = DashboardViewModel()
    @State private var pulseScale: CGFloat = 1

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    headerRow
                    balanceCard
                    quickStats
                    if vm.isLoggedIn { monthSelector }
                    if !vm.modelBreakdown.isEmpty { modelChart }
                    if !vm.ioByDay.isEmpty      { ioChart }
                    if !vm.filteredCosts.isEmpty { costChart }
                    if !vm.isLoggedIn { loginBanner }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 120)
            }
            .scrollIndicators(.hidden)
            .background(Color(hex: "060D17"))
            .toolbarBackground(.hidden, for: .navigationBar)
            .refreshable { await vm.loadAll(); vm.calculateStats() }
            .alert("", isPresented: .constant(vm.errorMessage != nil)) {
                Button("好") { vm.errorMessage = nil }
            } message: { Text(vm.errorMessage ?? "") }
            .task {
                if vm.balance == nil { await vm.loadAll() }
                vm.calculateStats()
            }
        }
    }

    // ═══════════════════════════════
    // 顶栏
    // ═══════════════════════════════

    private var headerRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("DEEPSEEK").font(.system(size: 14, weight: .bold))
                    .kerning(3).foregroundColor(Color(hex: "00C6FF"))
                Text("用量").font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
            }
            Spacer()
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) { pulseScale = 0.8 }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) { pulseScale = 1 }
                }
                Task { await vm.loadAll(); vm.calculateStats() }
            } label: {
                ZStack {
                    if vm.isLoading {
                        ProgressView().tint(Color(hex: "00C6FF")).scaleEffect(1.2)
                    } else {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(Color(hex: "00C6FF"))
                    }
                }
                .frame(width: 44, height: 44).scaleEffect(pulseScale)
                .background(Circle().fill(Color(hex: "00C6FF").opacity(0.1)))
                .overlay(Circle().stroke(Color(hex: "00C6FF").opacity(0.2), lineWidth: 1))
            }
            .disabled(vm.isLoading)
        }
    }

    // ═══════════════════════════════
    // 余额
    // ═══════════════════════════════

    private var balanceCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22)
                .fill(LinearGradient(
                    colors: [Color(hex: "081830"), Color(hex: "0C2045"), Color(hex: "071226")],
                    startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(
                    Circle().fill(Color(hex: "00C6FF").opacity(0.15)).frame(width: 180).blur(radius: 60).offset(x: 70, y: 30))
                .overlay(
                    Circle().fill(Color(hex: "7C5CFC").opacity(0.1)).frame(width: 120).blur(radius: 50).offset(x: -80, y: -20))
                .overlay(
                    LinearGradient(colors: [.clear, Color(hex: "00C6FF").opacity(0.2), .clear],
                                   startPoint: .leading, endPoint: .trailing)
                    .frame(height: 1.5).padding(.horizontal, 20), alignment: .bottom)

            RoundedRectangle(cornerRadius: 22)
                .stroke(LinearGradient(colors: [.white.opacity(0.1), Color(hex: "00C6FF").opacity(0.2)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)

            VStack(spacing: 18) {
                // 顶行
                HStack {
                    HStack(spacing: 8) {
                        Circle().fill(Color(hex: "00C6FF")).frame(width: 8, height: 8)
                        Text("账户余额").font(.system(size: 15, weight: .medium))
                            .foregroundColor(Color(hex: "A0B0CC"))
                    }
                    Spacer()
                    if vm.alertEnabled, let b = vm.balance, b.totalBalanceValue <= vm.alertThreshold {
                        Label("余额不足", systemImage: "exclamationmark.triangle.fill")
                            .font(.system(size: 12, weight: .bold)).foregroundColor(Color(hex: "FF6B6B"))
                            .padding(.horizontal, 10).padding(.vertical, 4)
                            .background(Color(hex: "FF6B6B").opacity(0.15)).clipShape(Capsule())
                    }
                    if let c = vm.balance?.currency {
                        Text(c).font(.system(size: 13, weight: .bold)).foregroundColor(Color(hex: "00C6FF"))
                            .padding(.horizontal, 10).padding(.vertical, 4)
                            .background(Color(hex: "00C6FF").opacity(0.12)).clipShape(Capsule())
                    }
                }

                // 金额 — 最大字号
                if let b = vm.balance {
                    if BalanceInfo.rateEnabled {
                        VStack(spacing: 4) {
                            Text(b.formattedTotal)
                                .font(.system(size: 38, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                            Text("≈ $\(String(format: "%.2f", b.totalBalanceValue / BalanceInfo.rate)) USD")
                                .font(.system(size: 16, weight: .medium, design: .monospaced))
                                .foregroundColor(Color(hex: "00E6A0"))
                        }
                    } else {
                        Text(b.formattedTotal)
                            .font(.system(size: 40, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                    }
                } else if KeychainManager.hasAPIKey {
                    Text("¥ --.--").font(.system(size: 40, weight: .bold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.3))
                } else {
                    Text("请填入 API Key").font(.system(size: 22, weight: .bold))
                        .foregroundColor(Color(hex: "A0B0CC"))
                }

                // 充值/赠送
                if let b = vm.balance {
                    HStack(spacing: 0) {
                        subRow("充值", b.formattedToppedUp, Color(hex: "00E6A0"))
                        Divider().frame(height: 28).background(.white.opacity(0.08)).padding(.horizontal, 24)
                        subRow("赠送", b.formattedGranted, Color(hex: "00C6FF"))
                        Spacer()
                    }
                }
            }
            .padding(24)
        }
    }

    private func subRow(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label).font(.system(size: 12, weight: .medium)).foregroundColor(Color(hex: "6A7A92"))
            Text(value).font(.system(size: 18, weight: .semibold, design: .monospaced)).foregroundColor(color)
        }
    }

    // ═══════════════════════════════
    // 快速统计
    // ═══════════════════════════════

    private var quickStats: some View {
        HStack(spacing: 12) {
            statPill("今日", vm.formattedTodaySpend, "clock", Color(hex: "FF6B6B"))
            statPill("本周", vm.formattedWeekSpend, "calendar.badge.clock", Color(hex: "00C6FF"))
            statPill(mLabel, vm.formattedMonthSpend, "calendar", Color(hex: "7C5CFC"))
            if vm.isLoggedIn {
                statPill("调用", "\(vm.monthCalls)次", "arrow.up.message", Color(hex: "00E6A0"))
            }
        }
    }

    private var mLabel: String { vm.selectedMonth == YearMonth.current ? "本月" : "\(vm.selectedMonth.month)月" }

    private func statPill(_ title: String, _ val: String, _ icon: String, _ color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).font(.system(size: 14)).foregroundColor(color).frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(val).font(.system(size: 16, weight: .bold, design: .monospaced)).foregroundColor(.white).lineLimit(1)
                Text(title).font(.system(size: 11, weight: .medium)).foregroundColor(Color(hex: "6A7A92"))
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 10).padding(.horizontal, 12)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(hex: "0A1228").opacity(0.7))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(color.opacity(0.15), lineWidth: 1)))
    }

    // ═══════════════════════════════
    // 月份
    // ═══════════════════════════════

    private var monthSelector: some View {
        HStack(spacing: 8) {
            Button { withAnimation { vm.previousMonth() } } label: {
                Image(systemName: "chevron.left").font(.system(size: 18, weight: .semibold))
                    .foregroundColor(canPrev ? Color(hex: "00C6FF") : Color(hex: "3A4A62"))
                    .frame(width: 40, height: 40)
            }.disabled(!canPrev)

            Text(vm.selectedMonthLabel)
                .font(.system(size: 17, weight: .semibold)).foregroundColor(.white).frame(maxWidth: .infinity)

            Button { withAnimation { vm.nextMonth() } } label: {
                Image(systemName: "chevron.right").font(.system(size: 18, weight: .semibold))
                    .foregroundColor(canNext ? Color(hex: "00C6FF") : Color(hex: "3A4A62"))
                    .frame(width: 40, height: 40)
            }.disabled(!canNext)
        }
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color(hex: "0A1228").opacity(0.6))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(hex: "00C6FF").opacity(0.12), lineWidth: 1)))
    }

    private var canPrev: Bool {
        guard let i = vm.availableMonths.firstIndex(of: vm.selectedMonth) else { return false }
        return i + 1 < vm.availableMonths.count
    }
    private var canNext: Bool {
        guard let i = vm.availableMonths.firstIndex(of: vm.selectedMonth) else { return false }
        return i > 0
    }

    // ═══════════════════════════════
    // 模型图
    // ═══════════════════════════════

    private var modelChart: some View {
        panel("模型用量", nil) {
            VStack(spacing: 16) {
                NeonDonut(data: Array(vm.modelBreakdown.prefix(5)))
                    .frame(height: 170)
                    .overlay {
                        VStack(spacing: 2) {
                            Text("\(vm.modelBreakdown.count)").font(.system(size: 34, weight: .bold)).foregroundColor(.white)
                            Text("个模型").font(.system(size: 13, weight: .medium)).foregroundColor(Color(hex: "6A7A92"))
                        }
                    }

                ForEach(Array(vm.modelBreakdown.prefix(5).enumerated()), id: \.element.model) { i, m in
                    VStack(spacing: 6) {
                        HStack {
                            Circle().fill(modelColors[i % modelColors.count]).frame(width: 10, height: 10)
                            Text(m.model).font(.system(size: 14, weight: .semibold)).foregroundColor(.white)
                            Spacer()
                            Text(m.pct).font(.system(size: 14, weight: .bold, design: .monospaced)).foregroundColor(modelColors[i % modelColors.count])
                            Text("· \(m.formattedTokens)").font(.system(size: 12, design: .monospaced)).foregroundColor(Color(hex: "6A7A92"))
                        }
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 2).fill(.white.opacity(0.06)).frame(height: 4)
                                RoundedRectangle(cornerRadius: 2).fill(modelColors[i % modelColors.count])
                                    .frame(width: geo.size.width * CGFloat(m.fraction), height: 4)
                            }
                        }
                        .frame(height: 4)
                    }
                }
            }
        }
    }

    private let modelColors: [Color] = [
        Color(hex: "00C6FF"), Color(hex: "7C5CFC"), Color(hex: "00E6A0"),
        Color(hex: "FF6B6B"), Color(hex: "FFD93D"),
    ]

    // ═══════════════════════════════
    // I/O
    // ═══════════════════════════════

    private var ioChart: some View {
        let totalIn  = vm.filteredAmounts.map(\.inputTokens).reduce(0, +)
        let totalOut = vm.filteredAmounts.map(\.outputTokens).reduce(0, +)
        let totalAll = totalIn + totalOut

        return panel("Token 流量", nil) {
            HStack(spacing: 16) {
                FlowBlock(label: "输入", value: fmtTok(totalIn), color: Color(hex: "00C6FF"))
                FlowBlock(label: "输出", value: fmtTok(totalOut), color: Color(hex: "7C5CFC"))
                FlowBlock(label: "合计", value: fmtTok(totalAll), color: .white)
            }

            Chart(vm.ioByDay) { pair in
                AreaMark(x: .value("", pair.shortDate), y: .value("输出", pair.output))
                    .foregroundStyle(LinearGradient(colors: [Color(hex: "7C5CFC").opacity(0.45), .clear], startPoint: .top, endPoint: .bottom))
                LineMark(x: .value("", pair.shortDate), y: .value("输出", pair.output))
                    .foregroundStyle(Color(hex: "7C5CFC")).lineStyle(StrokeStyle(lineWidth: 2))
                AreaMark(x: .value("", pair.shortDate), y: .value("输入", pair.input))
                    .foregroundStyle(LinearGradient(colors: [Color(hex: "00C6FF").opacity(0.55), .clear], startPoint: .top, endPoint: .bottom))
                LineMark(x: .value("", pair.shortDate), y: .value("输入", pair.input))
                    .foregroundStyle(Color(hex: "00C6FF")).lineStyle(StrokeStyle(lineWidth: 2))
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 5)) { AxisValueLabel().foregroundStyle(Color(hex: "6A7A92")).font(.system(size: 11)) }
            }
            .chartYAxis {
                AxisMarks { AxisGridLine().foregroundStyle(.white.opacity(0.04)) }
            }
            .chartPlotStyle { $0.background(Color.clear) }
            .frame(height: 190)
        }
    }

    private func fmtTok(_ n: Int) -> String {
        n >= 1_000_000 ? String(format: "%.1fM", Double(n)/1_000_000) :
        n >= 1_000     ? String(format: "%.0fK", Double(n)/1_000) : "\(n)"
    }

    // ═══════════════════════════════
    // 费用
    // ═══════════════════════════════

    private var costChart: some View {
        let costs = vm.filteredCosts
        let total = costs.map(\.cost).reduce(0, +)
        let avg   = costs.isEmpty ? 0 : total / Double(costs.count)
        let peak  = costs.map(\.cost).max() ?? 0

        return panel("每日费用", "月合计 ¥\(String(format: "%.2f", total))") {
            HStack(spacing: 12) {
                KpiChip(title: "总计", value: String(format: "¥%.2f", total), color: Color(hex: "00E6A0"))
                KpiChip(title: "峰值", value: String(format: "¥%.2f", peak), color: Color(hex: "FFD93D"))
                KpiChip(title: "日均", value: String(format: "¥%.2f", avg),  color: Color(hex: "00C6FF"))
            }

            Chart(costs) { item in
                AreaMark(x: .value("", item.formattedDate), y: .value("", item.cost))
                    .foregroundStyle(LinearGradient(colors: [Color(hex: "00E6A0").opacity(0.35), .clear], startPoint: .top, endPoint: .bottom))
                LineMark(x: .value("", item.formattedDate), y: .value("", item.cost))
                    .foregroundStyle(LinearGradient(colors: [Color(hex: "00E6A0"), Color(hex: "00C6FF")], startPoint: .leading, endPoint: .trailing))
                    .lineStyle(StrokeStyle(lineWidth: 2.5))
                PointMark(x: .value("", item.formattedDate), y: .value("", item.cost))
                    .foregroundStyle(Color(hex: "00E6A0")).symbolSize(28)
                RuleMark(y: .value("均值", avg))
                    .foregroundStyle(Color(hex: "FFD93D").opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                    .annotation(position: .top, alignment: .trailing) {
                        Text("均值 ¥\(String(format: "%.2f", avg))").font(.system(size: 11, weight: .medium))
                            .foregroundColor(Color(hex: "FFD93D"))
                    }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 5)) { AxisValueLabel().foregroundStyle(Color(hex: "6A7A92")).font(.system(size: 11)) }
            }
            .chartYAxis {
                AxisMarks { AxisGridLine().foregroundStyle(.white.opacity(0.04)) }
            }
            .chartPlotStyle { $0.background(Color.clear) }
            .frame(height: 210)
        }
    }

    // ═══════════════════════════════
    // 登录
    // ═══════════════════════════════

    private var loginBanner: some View {
        NavigationLink { LoginView() } label: {
            HStack(spacing: 12) {
                Image(systemName: "sparkles").font(.system(size: 18)).foregroundColor(Color(hex: "7C5CFC"))
                VStack(alignment: .leading, spacing: 3) {
                    Text("登录查看详细用量").font(.system(size: 16, weight: .semibold)).foregroundColor(.white)
                    Text("Token 明细 · 每日费用 · 模型分布").font(.system(size: 13)).foregroundColor(Color(hex: "6A7A92"))
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 15, weight: .semibold)).foregroundColor(Color(hex: "00C6FF"))
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 16).fill(Color(hex: "0A1228").opacity(0.7))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(hex: "7C5CFC").opacity(0.2), lineWidth: 1)))
            .padding(.vertical, 4)
        }
    }

    // ═══════════════════════════════
    // 共享
    // ═══════════════════════════════

    private func panel(_ title: String, _ sub: String?,
                       @ViewBuilder content: () -> some View) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(title).font(.system(size: 16, weight: .bold)).foregroundColor(.white)
                Spacer()
                if let s = sub {
                    Text(s).font(.system(size: 12, weight: .medium)).foregroundColor(Color(hex: "6A7A92"))
                        .padding(.horizontal, 10).padding(.vertical, 3)
                        .background(.white.opacity(0.04)).clipShape(Capsule())
                }
            }
            .padding(.horizontal, 18).padding(.top, 16).padding(.bottom, 10)
            content().padding(.horizontal, 12).padding(.bottom, 12)
        }
        .background(RoundedRectangle(cornerRadius: 20).fill(Color(hex: "0A1228").opacity(0.5))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(0.06), lineWidth: 1)))
    }
}

// ═══════════════════════════════════
// 子组件
// ═══════════════════════════════════

struct FlowBlock: View {
    let label: String; let value: String; let color: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) {
                Circle().fill(color).frame(width: 7, height: 7)
                Text(label).font(.system(size: 12, weight: .medium)).foregroundColor(Color(hex: "6A7A92"))
            }
            Text(value).font(.system(size: 20, weight: .bold, design: .monospaced)).foregroundColor(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(color.opacity(0.06))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(color.opacity(0.12), lineWidth: 1)))
    }
}

struct KpiChip: View {
    let title: String; let value: String; let color: Color
    var body: some View {
        VStack(spacing: 3) {
            Text(value).font(.system(size: 18, weight: .bold, design: .monospaced)).foregroundColor(color)
            Text(title).font(.system(size: 11, weight: .medium)).foregroundColor(Color(hex: "6A7A92"))
        }
        .frame(maxWidth: .infinity).padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 12).fill(color.opacity(0.06))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(color.opacity(0.12), lineWidth: 1)))
    }
}

struct NeonDonut: View {
    let data: [ModelShare]
    private let cs: [Color] = [Color(hex: "00C6FF"), Color(hex: "7C5CFC"), Color(hex: "00E6A0"), Color(hex: "FF6B6B"), Color(hex: "FFD93D")]

    var body: some View {
        Canvas { ctx, size in
            let total = data.map(\.tokens).reduce(0, +)
            guard total > 0 else { return }
            let c = CGPoint(x: size.width / 2, y: size.height / 2)
            let r = min(size.width, size.height) / 2 * 0.7
            let inner = r * 0.58
            var a = -Double.pi / 2
            for (i, m) in data.enumerated() {
                let frac = Double(m.tokens) / Double(total)
                let end = a + frac * 2 * .pi
                let path = Path { p in
                    p.addArc(center: c, radius: r, startAngle: Angle(radians: a), endAngle: Angle(radians: end), clockwise: false)
                    p.addArc(center: c, radius: inner, startAngle: Angle(radians: end), endAngle: Angle(radians: a), clockwise: true)
                    p.closeSubpath()
                }
                ctx.addFilter(.blur(radius: 4))
                ctx.fill(path, with: .color(cs[i % cs.count].opacity(0.25)))
                ctx.addFilter(.blur(radius: 0))
                ctx.fill(path, with: .color(cs[i % cs.count]))
                a = end
            }
            // 外圈
            let ring = Path { p in
                p.addArc(center: c, radius: r + 3, startAngle: .zero, endAngle: .degrees(360), clockwise: false)
            }
            ctx.stroke(ring, with: .color(.white.opacity(0.06)), lineWidth: 1)
        }
    }
}
