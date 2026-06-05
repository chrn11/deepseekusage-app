import SwiftUI
import Charts

// MARK: - 仪表盘主视图

struct DashboardView: View {
    @StateObject private var vm = DashboardViewModel()
    @State private var pulseScale: CGFloat = 1
    @State private var appeared = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    headerSection
                    balanceHero
                    statRow
                    if vm.isLoggedIn { monthPicker.transition(.move(edge: .top).combined(with: .opacity)) }
                    if !vm.modelBreakdown.isEmpty { modelSection }
                    if !vm.ioByDay.isEmpty      { ioSection }
                    if !vm.filteredCosts.isEmpty { costSection }
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
                withAnimation(.easeOut(duration: 0.6).delay(0.2)) { appeared = true }
            }
        }
    }

    // MARK: 顶栏 ============================

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
                    else { Image(systemName: "arrow.triangle.2.circlepath").font(.system(size: 18, weight: .medium)).foregroundColor(Color(hex: "00C6FF")) }
                }
                .frame(width: 40, height: 40).scaleEffect(pulseScale)
                .background(Circle().fill(Color(hex: "00C6FF").opacity(0.08)))
                .overlay(Circle().stroke(Color(hex: "00C6FF").opacity(0.15), lineWidth: 1))
            }
            .disabled(vm.isLoading)
        }
        .padding(.top, 8)
    }

    // MARK: 余额卡片 ============================

    private var balanceHero: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24)
                .fill(LinearGradient(colors: [Color(hex: "0A1C3A"), Color(hex: "0D2247"), Color(hex: "091428")], startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(Circle().fill(Color(hex: "00C6FF").opacity(0.18)).frame(width: 160, height: 160).blur(radius: 50).offset(x: 60, y: 40))
                .overlay(Circle().fill(Color(hex: "7C5CFC").opacity(0.12)).frame(width: 100, height: 100).blur(radius: 40).offset(x: -80, y: -20))
                .overlay(
                    // 底部流光线条
                    LinearGradient(colors: [.clear, Color(hex: "00C6FF").opacity(0.3), Color(hex: "7C5CFC").opacity(0.2), .clear], startPoint: .leading, endPoint: .trailing)
                        .frame(height: 1.5)
                        .offset(y: -1)
                        .mask(RoundedRectangle(cornerRadius: 24))
                    , alignment: .bottom)
            RoundedRectangle(cornerRadius: 24)
                .stroke(LinearGradient(colors: [.white.opacity(0.08), Color(hex: "00C6FF").opacity(0.15)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)

            VStack(spacing: 14) {
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "diamond.fill").font(.system(size: 12)).foregroundColor(Color(hex: "00C6FF"))
                        Text("余额").font(.system(size: 13, weight: .medium)).foregroundColor(Color(hex: "7B89A0"))
                    }
                    Spacer()
                    if vm.alertEnabled, let b = vm.balance, b.totalBalanceValue <= vm.alertThreshold {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 10))
                            Text("不足").font(.system(size: 10, weight: .bold))
                        }
                        .foregroundColor(Color(hex: "FF6B6B"))
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Color(hex: "FF6B6B").opacity(0.15)).clipShape(Capsule())
                    }
                    if let c = vm.balance?.currency {
                        Text(c).font(.system(size: 11, weight: .bold).monospacedDigit()).foregroundColor(Color(hex: "00C6FF"))
                            .padding(.horizontal, 10).padding(.vertical, 4)
                            .background(Color(hex: "00C6FF").opacity(0.1)).clipShape(Capsule())
                    }
                }

                if let b = vm.balance {
                    Text(b.formattedTotal)
                        .font(.system(size: 42, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(hex: "E8EDF5"))
                    HStack(spacing: 24) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("充值").font(.system(size: 10)).foregroundColor(Color(hex: "5A6A82"))
                            Text(b.formattedToppedUp).font(.system(size: 16, weight: .semibold, design: .monospaced)).foregroundColor(Color(hex: "00E6A0"))
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("赠送").font(.system(size: 10)).foregroundColor(Color(hex: "5A6A82"))
                            Text(b.formattedGranted).font(.system(size: 16, weight: .semibold, design: .monospaced)).foregroundColor(Color(hex: "00C6FF"))
                        }
                        Spacer()
                    }
                } else if KeychainManager.hasAPIKey {
                    Text("¥ --.--").font(.system(size: 42, weight: .bold, design: .monospaced)).foregroundColor(Color(hex: "E8EDF5").opacity(0.4))
                } else {
                    Text("填入 Key 开始").font(.system(size: 26, weight: .bold)).foregroundColor(Color(hex: "7B89A0"))
                }
            }
            .padding(22)
        }
        .padding(.top, 2)
    }

    // MARK: 统计条 ============================

    private var statRow: some View {
        HStack(spacing: 10) {
            MiniStat(icon: "clock", title: "今日", value: vm.formattedTodaySpend, glow: Color(hex: "FF6B6B"))
            MiniStat(icon: "calendar.badge.clock", title: "本周", value: vm.formattedWeekSpend, glow: Color(hex: "00C6FF"))
            MiniStat(icon: "calendar", title: mcLabel, value: vm.formattedMonthSpend, glow: Color(hex: "7C5CFC"))
            if vm.isLoggedIn {
                MiniStat(icon: "arrow.up.message", title: "调用", value: "\(vm.monthCalls)次", glow: Color(hex: "00E6A0"))
            }
        }
    }

    private var mcLabel: String { vm.selectedMonth == YearMonth.current ? "本月" : "\(vm.selectedMonth.month)月" }

    // MARK: 月份 ============================

    private var monthPicker: some View {
        HStack(spacing: 0) {
            navBtn(-1)
            Text(vm.selectedMonthLabel).font(.system(size: 15, weight: .semibold, design: .monospaced)).foregroundColor(Color(hex: "E8EDF5")).frame(maxWidth: .infinity)
            navBtn(1)
        }
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(hex: "0A1228").opacity(0.6)).overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: "00C6FF").opacity(0.12), lineWidth: 1)))
    }

    private func navBtn(_ dir: Int) -> some View {
        let isPrev = dir == -1
        let ok = isPrev
            ? (vm.availableMonths.firstIndex(of: vm.selectedMonth) ?? 0) + 1 < vm.availableMonths.count
            : (vm.availableMonths.firstIndex(of: vm.selectedMonth) ?? 0) > 0
        return Button { withAnimation { isPrev ? vm.previousMonth() : vm.nextMonth() } } label: {
            Image(systemName: isPrev ? "chevron.left" : "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(ok ? Color(hex: "00C6FF") : Color(hex: "5A6A82").opacity(0.3))
                .frame(width: 36, height: 36)
        }.disabled(!ok)
    }

    // MARK: 模型饼图 ============================

    private var modelSection: some View {
        let top = vm.modelBreakdown.prefix(5)
        let topTokens = top.map(\.tokens).reduce(0, +)
        let midToken = topTokens / max(top.count, 1)

        return VStack(spacing: 0) {
            sectionHead("cpu.fill", "模型用量", "Token 占比")
            VStack(spacing: 0) {
                // 环形图 + 中心数据
                ZStack {
                    NeonDonut(data: Array(top)).frame(height: 180)
                    VStack(spacing: 2) {
                        Text("\(vm.modelBreakdown.count)")
                            .font(.system(size: 32, weight: .bold, design: .monospaced)).foregroundColor(Color(hex: "E8EDF5"))
                        Text("模型").font(.system(size: 11)).foregroundColor(Color(hex: "5A6A82"))
                    }
                }

                // 横向进度条图例
                VStack(spacing: 8) {
                    ForEach(Array(top.enumerated()), id: \.element.model) { i, m in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Circle().fill(modelColor(m.model)).frame(width: 8, height: 8)
                                Text(m.model).font(.system(size: 12, weight: .medium)).foregroundColor(Color(hex: "C8D2E0"))
                                Spacer()
                                Text(m.pct).font(.system(size: 12, weight: .bold, design: .monospaced)).foregroundColor(Color(hex: "E8EDF5"))
                                Text("· \(m.formattedTokens)").font(.system(size: 10, design: .monospaced)).foregroundColor(Color(hex: "5A6A82"))
                                Text("· \(m.formattedCost)").font(.system(size: 10, design: .monospaced)).foregroundColor(Color(hex: "00E6A0"))
                            }
                            GeometryReader { geo in
                                RoundedRectangle(cornerRadius: 2).fill(Color.white.opacity(0.04))
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(modelColor(m.model))
                                    .frame(width: geo.size.width * CGFloat(m.fraction))
                            }
                            .frame(height: 3)
                        }
                    }
                }
                .padding(16)
            }
        }
        .background(panelBg)
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

    // MARK: I/O 图表 ============================

    private var ioSection: some View {
        let totalIn  = vm.filteredAmounts.map(\.inputTokens).reduce(0, +)
        let totalOut = vm.filteredAmounts.map(\.outputTokens).reduce(0, +)
        let totalAll = totalIn + totalOut
        let inPct  = totalAll > 0 ? Double(totalIn)  / Double(totalAll) : 0
        let outPct = totalAll > 0 ? Double(totalOut) / Double(totalAll) : 0

        return VStack(spacing: 0) {
            sectionHead("arrow.left.arrow.right", "Token 流量", "输入 vs 输出")

            // 摘要行
            HStack(spacing: 16) {
                FlowBlock(label: "输入", value: fmtTok(totalIn),  pct: inPct,  color: Color(hex: "00C6FF"))
                FlowBlock(label: "输出", value: fmtTok(totalOut), pct: outPct, color: Color(hex: "7C5CFC"))
                FlowBlock(label: "合计", value: fmtTok(totalAll), pct: 1,     color: Color(hex: "E8EDF5"))
            }
            .padding(.horizontal, 16).padding(.top, 10)

            // 堆叠面积图
            Chart(vm.ioByDay) { pair in
                AreaMark(x: .value("", pair.shortDate), y: .value("输出", pair.output))
                    .foregroundStyle(LinearGradient(colors: [Color(hex: "7C5CFC").opacity(0.5), Color(hex: "7C5CFC").opacity(0.05)], startPoint: .top, endPoint: .bottom))
                LineMark(x: .value("", pair.shortDate), y: .value("输出", pair.output))
                    .foregroundStyle(Color(hex: "7C5CFC")).lineStyle(StrokeStyle(lineWidth: 1.5))
                AreaMark(x: .value("", pair.shortDate), y: .value("输入", pair.input))
                    .foregroundStyle(LinearGradient(colors: [Color(hex: "00C6FF").opacity(0.6), Color(hex: "00C6FF").opacity(0.05)], startPoint: .top, endPoint: .bottom))
                LineMark(x: .value("", pair.shortDate), y: .value("输入", pair.input))
                    .foregroundStyle(Color(hex: "00C6FF")).lineStyle(StrokeStyle(lineWidth: 1.5))
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 5)) { AxisValueLabel().foregroundStyle(Color(hex: "5A6A82")) }
            }
            .chartYAxis {
                AxisMarks { AxisGridLine().foregroundStyle(Color.white.opacity(0.03)) }
            }
            .chartPlotStyle { $0.background(Color.clear) }
            .frame(height: 180)
            .padding(.horizontal, 8).padding(.bottom, 8)
        }
        .background(panelBg)
    }

    private func fmtTok(_ n: Int) -> String {
        n >= 1_000_000 ? String(format: "%.1fM", Double(n)/1_000_000) :
        n >= 1_000     ? String(format: "%.0fK", Double(n)/1_000) : "\(n)"
    }

    // MARK: 费用图表 ============================

    private var costSection: some View {
        let costs = vm.filteredCosts
        let total = costs.map(\.cost).reduce(0, +)
        let avg = costs.isEmpty ? 0 : total / Double(costs.count)
        let peak = costs.map(\.cost).max() ?? 0

        return VStack(spacing: 0) {
            sectionHead("yensign.circle.fill", "消费曲线", "日均 ¥\(String(format: "%.2f", avg))")

            // KPI 行
            HStack(spacing: 16) {
            KpiChip(label: "总计", value: String(format: "¥%.2f", total), color: Color(hex: "00E6A0"))
            KpiChip(label: "峰值", value: String(format: "¥%.2f", peak), color: Color(hex: "FFD93D"))
            KpiChip(label: "日均", value: String(format: "¥%.2f", avg), color: Color(hex: "00C6FF"))
            }
            .padding(.horizontal, 16).padding(.top, 10)

            // 渐变面积图 + 圆点线
            Chart(costs) { item in
                AreaMark(x: .value("", item.formattedDate), y: .value("", item.cost))
                    .foregroundStyle(LinearGradient(
                        colors: [Color(hex: "00E6A0").opacity(0.4), Color(hex: "00E6A0").opacity(0.02)],
                        startPoint: .top, endPoint: .bottom))

                LineMark(x: .value("", item.formattedDate), y: .value("", item.cost))
                    .foregroundStyle(LinearGradient(
                        colors: [Color(hex: "00E6A0"), Color(hex: "00C6FF")],
                        startPoint: .leading, endPoint: .trailing))
                    .lineStyle(StrokeStyle(lineWidth: 2))

                PointMark(x: .value("", item.formattedDate), y: .value("", item.cost))
                    .foregroundStyle(Color(hex: "00E6A0")).symbolSize(20)

                // 平均值参考线
                RuleMark(y: .value("均值", avg))
                    .foregroundStyle(Color(hex: "FFD93D").opacity(0.4))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .annotation(position: .top, alignment: .trailing) {
                        Text("均值 ¥\(String(format: "%.2f", avg))").font(.system(size: 9))
                            .foregroundColor(Color(hex: "FFD93D").opacity(0.7))
                    }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 5)) { AxisValueLabel().foregroundStyle(Color(hex: "5A6A82")) }
            }
            .chartYAxis {
                AxisMarks { AxisGridLine().foregroundStyle(Color.white.opacity(0.03)) }
            }
            .chartPlotStyle { $0.background(Color.clear) }
            .frame(height: 200)
            .padding(.horizontal, 8).padding(.bottom, 8)
        }
        .background(panelBg)
    }

    // MARK: 登录 ============================

    private var loginPrompt: some View {
        NavigationLink { LoginView() } label: {
            HStack(spacing: 10) {
                Image(systemName: "sparkles").foregroundColor(Color(hex: "7C5CFC"))
                VStack(alignment: .leading, spacing: 2) {
                    Text("登录查看详细用量").font(.system(size: 14, weight: .semibold)).foregroundColor(Color(hex: "E8EDF5"))
                    Text("Token 明细 · 消费曲线 · 模型分布").font(.system(size: 12)).foregroundColor(Color(hex: "5A6A82"))
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption).foregroundColor(Color(hex: "00C6FF"))
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 14).fill(Color(hex: "0A1228").opacity(0.7))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(hex: "7C5CFC").opacity(0.15), lineWidth: 1)))
        }
    }

    // MARK: 共享组件 ============================

    private func sectionHead(_ icon: String, _ title: String, _ sub: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 13)).foregroundColor(Color(hex: "00C6FF"))
            Text(title).font(.system(size: 15, weight: .semibold)).foregroundColor(Color(hex: "E8EDF5"))
            Spacer()
            Text(sub).font(.system(size: 10, weight: .medium)).foregroundColor(Color(hex: "5A6A82"))
                .padding(.horizontal, 8).padding(.vertical, 2)
                .background(Color.white.opacity(0.04)).clipShape(Capsule())
        }
        .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 6)
    }

    private var panelBg: some View {
        RoundedRectangle(cornerRadius: 18)
            .fill(Color(hex: "0A1228").opacity(0.5))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(.white.opacity(0.05), lineWidth: 1))
            .padding(.bottom, 6)
    }
}

// MARK: - MiniStat 横向统计条

struct MiniStat: View {
    let icon: String; let title: String; let value: String; let glow: Color
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 13)).foregroundColor(glow).frame(width: 22)
            VStack(alignment: .leading, spacing: 1) {
                Text(value).font(.system(size: 14, weight: .bold, design: .monospaced)).foregroundColor(Color(hex: "E8EDF5")).lineLimit(1)
                Text(title).font(.system(size: 10)).foregroundColor(Color(hex: "5A6A82"))
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 8).padding(.horizontal, 10)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color(hex: "0A1228").opacity(0.6))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(glow.opacity(0.1), lineWidth: 1)))
    }
}

// MARK: - FlowBlock（I/O 摘要块）

struct FlowBlock: View {
    let label: String; let value: String; let pct: Double; let color: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Circle().fill(color).frame(width: 6, height: 6)
                Text(label).font(.system(size: 10)).foregroundColor(Color(hex: "5A6A82"))
            }
            Text(value).font(.system(size: 18, weight: .bold, design: .monospaced)).foregroundColor(color)
            Text(String(format: "%.0f%%", pct * 100)).font(.system(size: 9, weight: .bold)).foregroundColor(color.opacity(0.5))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(color.opacity(0.06)).overlay(RoundedRectangle(cornerRadius: 10).stroke(color.opacity(0.1), lineWidth: 1)))
    }
}

// MARK: - KPI Chip 费用摘要

struct KpiChip: View {
    let label: String; let value: String; let color: Color
    var body: some View {
        VStack(spacing: 2) {
            Text(value).font(.system(size: 17, weight: .bold, design: .monospaced)).foregroundColor(color)
            Text(label).font(.system(size: 9)).foregroundColor(Color(hex: "5A6A82"))
        }
        .frame(maxWidth: .infinity).padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 10).fill(color.opacity(0.06)).overlay(RoundedRectangle(cornerRadius: 10).stroke(color.opacity(0.1), lineWidth: 1)))
    }
}

// MARK: - NeonDonut 发光环形图

struct NeonDonut: View {
    let data: [ModelShare]
    private let colors: [Color] = [Color(hex: "00C6FF"), Color(hex: "7C5CFC"), Color(hex: "00E6A0"), Color(hex: "FF6B6B"), Color(hex: "FFD93D")]

    var body: some View {
        Canvas { ctx, size in
            let total = data.map(\.tokens).reduce(0, +)
            guard total > 0 else { return }
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = min(size.width, size.height) / 2 * 0.7
            let inner = radius * 0.58
            var angle = -Double.pi / 2
            let totalFracs = data.map { Double($0.tokens) / Double(total) }

            // 分段
            for (i, frac) in totalFracs.enumerated() {
                let end = angle + frac * 2 * .pi
                let path = Path { p in
                    p.addArc(center: center, radius: radius, startAngle: Angle(radians: angle), endAngle: .radians(end), clockwise: false)
                    p.addArc(center: center, radius: inner, startAngle: .radians(end), endAngle: Angle(radians: angle), clockwise: true)
                    p.closeSubpath()
                }
                // 发光阴影层
                ctx.addFilter(.blur(radius: 3))
                ctx.fill(path, with: .color(colors[i % colors.count].opacity(0.3)))
                ctx.addFilter(.blur(radius: 0))
                // 实心层
                ctx.fill(path, with: .color(colors[i % colors.count]))
                angle = end
            }

            // 外圈发光环
            let ring = Path { p in
                p.addArc(center: center, radius: radius + 2, startAngle: .zero, endAngle: .degrees(360), clockwise: false)
            }
            ctx.stroke(ring, with: .color(.white.opacity(0.08)), lineWidth: 1)
        }
    }
}
