import SwiftUI
import Charts

// MARK: - 仪表盘主视图

struct DashboardView: View {
    @StateObject private var vm = DashboardViewModel()
    @State private var pulseScale: CGFloat = 1
    @State private var showRecharge = false
    @State private var showLoginSheet = false
    @State private var expandedModels: Set<String> = []
    @State private var selectedCost: DailyCost?    // 费用图选中点
    @State private var selectedCostUSD: DailyCost? // USD 费用图选中点
    @State private var selectedIO: IOPair?         // I/O 图选中点
    @State private var selectedRequestDay: (model: String, day: DayValue)?  // 请求图选中点
    @State private var selectedTokenDay: (model: String, day: DayValue)?   // Token 图选中点

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    headerRow
                    balanceCard
                    rechargeButton
                    quickStats
                    utcInfoLabel
                    if vm.isLoggedIn { monthSelector }
                    if !vm.cachedModelBreakdown.isEmpty { modelChart }
                    if !vm.cachedIOByDay.isEmpty      { ioChart }
                    if !vm.cachedCostByDay.isEmpty { costChart }
                    if !vm.cachedCostByDayUSD.isEmpty { costChartUSD }
                    if !vm.requestsByModelAndDay.isEmpty { requestCharts }
                    if !vm.tokensByModelAndDay.isEmpty { tokenCharts }
                    if !vm.isLoggedIn { loginBanner }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 120)
            }
            .scrollIndicators(.hidden)
            .background(Color(hex: "060D17"))
            .toolbarBackground(.hidden, for: .navigationBar)
            .refreshable { await vm.loadAll(); vm.computeStats() }
            .alert("", isPresented: .constant(vm.errorMessage != nil)) {
                Button("好") { vm.errorMessage = nil }
            } message: { Text(vm.errorMessage ?? "") }
            .task {
                if vm.balance == nil { await vm.loadAll() }
                vm.computeStats()
            }
            .onReceive(NotificationCenter.default.publisher(for: KeychainManager.loginStatusChanged)) { _ in
                vm.isLoggedIn = KeychainManager.hasToken
                Task { await vm.loadAll(); vm.computeStats() }
            }
            .sheet(isPresented: $showLoginSheet) {
                LoginView(onLoginSuccess: {
                    showLoginSheet = false
                    Task { await vm.loadAll(); vm.computeStats() }
                })
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
                Task { await vm.loadAll(); vm.computeStats() }
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
                    Circle().fill(Color(hex: "00C6FF").opacity(0.2)).frame(width: 180).blur(radius: 60).offset(x: 70, y: 30))
                .overlay(
                    Circle().fill(Color(hex: "7C5CFC").opacity(0.12)).frame(width: 120).blur(radius: 50).offset(x: -80, y: -20))
                .overlay(
                    LinearGradient(colors: [.clear, Color(hex: "00C6FF").opacity(0.3), .clear],
                                   startPoint: .leading, endPoint: .trailing)
                    .frame(height: 1.5).padding(.horizontal, 20), alignment: .bottom)

            RoundedRectangle(cornerRadius: 22)
                .stroke(LinearGradient(colors: [.white.opacity(0.15), Color(hex: "00C6FF").opacity(0.3)],
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
                    // 币种标签：双币种模式显示两个
                    if CurrencyDisplay.current == .both {
                        if let c = vm.balanceInfos.cny?.currency {
                            currencyTag(c)
                        }
                        if let u = vm.balanceInfos.usd?.currency {
                            currencyTag(u)
                        }
                    } else if let c = vm.balance?.currency {
                        currencyTag(c)
                    }
                }

                // 金额
                if !vm.balanceInfos.isEmpty {
                    if CurrencyDisplay.current == .both {
                        Text(vm.balanceBothText)
                            .font(.system(size: 30, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                    } else if let b = vm.balance {
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

                // 余额不足预警
                if vm.alertEnabled, let b = vm.balanceInfos.primary, b.totalBalanceValue <= vm.alertThreshold {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 12))
                        Text("余额低于 ¥\(String(format: "%.0f", vm.alertThreshold))，建议充值")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(Color(hex: "FF6B6B"))
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(Color(hex: "FF6B6B").opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                // 充值/赠送（取主币种数据）
                if let b = vm.balance {
                    HStack(spacing: 0) {
                        subRow("充值", b.formattedToppedUp, Color(hex: "00E6A0"))
                        Divider().frame(height: 28).background(.white.opacity(0.15)).padding(.horizontal, 24)
                        subRow("赠送", b.formattedGranted, Color(hex: "00C6FF"))
                        Spacer()
                    }
                }
            }
            .padding(24)
        }
    }

    private func currencyTag(_ text: String) -> some View {
        Text(text).font(.system(size: 13, weight: .bold)).foregroundColor(Color(hex: "00C6FF"))
            .padding(.horizontal, 10).padding(.vertical, 4)
            .background(Color(hex: "00C6FF").opacity(0.12)).clipShape(Capsule())
    }

    private func subRow(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label).font(.system(size: 12, weight: .medium)).foregroundColor(Color(hex: "8C9DB5"))
            Text(value).font(.system(size: 18, weight: .semibold, design: .monospaced)).foregroundColor(color)
        }
    }

    // ═══════════════════════════════
    // 充值
    // ═══════════════════════════════

    private var rechargeButton: some View {
        Group {
            if KeychainManager.hasToken {
                Button {
                    showRecharge = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "creditcard.fill")
                            .font(.system(size: 16, weight: .medium))
                        Text("充值")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(Color(hex: "060D17"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            colors: [Color(hex: "00C6FF"), Color(hex: "00E6A0")],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .sheet(isPresented: $showRecharge) {
                    RechargeView {
                        showRecharge = false
                        // 充值完成后自动刷新余额
                        Task { await vm.loadAll(); vm.computeStats() }
                    }
                }
            }
        }
    }

    // ═══════════════════════════════
    // 快速统计
    // ═══════════════════════════════

    private var quickStats: some View {
        let pills: [StatItem] = [
            StatItem(id: "today",  title: "今日", value: vm.formattedTodaySpend, icon: "clock",                color: Color(hex: "FF6B6B")),
            StatItem(id: "week",   title: "本周", value: vm.formattedWeekSpend,  icon: "calendar.badge.clock", color: Color(hex: "00C6FF")),
            StatItem(id: "month",  title: mLabel, value: vm.formattedMonthSpend, icon: "calendar",              color: Color(hex: "7C5CFC")),
        ]
        var items = pills
        if vm.isLoggedIn {
            items.append(StatItem(id: "calls", title: "调用", value: "\(vm.monthCalls)次", icon: "arrow.up.message", color: Color(hex: "00E6A0")))
            items.append(StatItem(id: "tokens", title: "Token", value: vm.formattedMonthTokens, icon: "bolt.fill", color: Color(hex: "FFD93D")))
        }

        return LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 10) {
            ForEach(items) { item in
                statPill(item.title, item.value, item.icon, item.color)
            }
        }
    }

    private var mLabel: String { vm.selectedYM == YearMonth.current ? "本月" : "\(vm.selectedYM.month)月" }
    
    private var utcInfoLabel: some View {
        Text("所有日期均按 UTC 时间显示，数据可能有 5 分钟延迟。")
            .font(.system(size: 11))
            .foregroundColor(Color(hex: "5C6E82"))
            .frame(maxWidth: .infinity, alignment: .center)
    }

    private func statPill(_ title: String, _ val: String, _ icon: String, _ color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).font(.system(size: 14)).foregroundColor(color).frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(val).font(.system(size: 16, weight: .bold, design: .monospaced)).foregroundColor(.white).lineLimit(1)
                Text(title).font(.system(size: 11, weight: .medium)).foregroundColor(Color(hex: "8C9DB5"))
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
                    .foregroundColor(canPrev ? Color(hex: "00C6FF") : Color(hex: "5A6A82"))
                    .frame(width: 40, height: 40)
            }.disabled(!canPrev)

            Text(vm.selectedMonthLabel)
                .font(.system(size: 17, weight: .semibold)).foregroundColor(.white).frame(maxWidth: .infinity)

            Button { withAnimation { vm.nextMonth() } } label: {
                Image(systemName: "chevron.right").font(.system(size: 18, weight: .semibold))
                    .foregroundColor(canNext ? Color(hex: "00C6FF") : Color(hex: "5A6A82"))
                    .frame(width: 40, height: 40)
            }.disabled(!canNext)
        }
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color(hex: "0A1228").opacity(0.6))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(hex: "00C6FF").opacity(0.12), lineWidth: 1)))
    }

    private var canPrev: Bool {
        guard let i = vm.availableMonths.firstIndex(of: vm.selectedYM) else { return false }
        return i + 1 < vm.availableMonths.count
    }
    private var canNext: Bool {
        guard let i = vm.availableMonths.firstIndex(of: vm.selectedYM) else { return false }
        return i > 0
    }

    // ═══════════════════════════════
    // 模型图
    // ═══════════════════════════════

    private var modelChart: some View {
        panel("模型用量", nil) {
            VStack(spacing: 16) {
                NeonDonut(data: Array(vm.cachedModelBreakdown.prefix(5)))
                    .frame(height: 170)
                    .overlay {
                        VStack(spacing: 2) {
                            Text("\(vm.cachedModelBreakdown.count)").font(.system(size: 34, weight: .bold)).foregroundColor(.white)
                            Text("个模型").font(.system(size: 13, weight: .medium)).foregroundColor(Color(hex: "8C9DB5"))
                        }
                    }

                ForEach(Array(vm.cachedModelBreakdown.prefix(5).enumerated()), id: \.element.model) { i, m in
                    VStack(spacing: 6) {
                        HStack {
                            Circle().fill(modelColors[i % modelColors.count]).frame(width: 10, height: 10)
                            Text(m.model).font(.system(size: 14, weight: .semibold)).foregroundColor(.white)
                            Spacer()
                            Text(m.pct).font(.system(size: 14, weight: .bold, design: .monospaced)).foregroundColor(modelColors[i % modelColors.count])
                            Text("· \(m.formattedTokens)").font(.system(size: 12, design: .monospaced)).foregroundColor(Color(hex: "8C9DB5"))
                        }
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 2).fill(.white.opacity(0.10)).frame(height: 4)
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
        let totalIn  = vm.cachedIOByDay.map(\.input).reduce(0, +)
        let totalOut = vm.cachedIOByDay.map(\.output).reduce(0, +)
        let totalAll = totalIn + totalOut

        return panel("Token 流量", nil) {
            HStack(spacing: 16) {
                FlowBlock(label: "输入", value: fmtTok(totalIn), color: Color(hex: "00C6FF"))
                FlowBlock(label: "输出", value: fmtTok(totalOut), color: Color(hex: "7C5CFC"))
                FlowBlock(label: "合计", value: fmtTok(totalAll), color: .white)
            }

            if let sel = selectedIO {
                chartBubble(date: sel.shortDate, value: "入\(fmtTok(sel.input)) 出\(fmtTok(sel.output))")
            }

            Chart(vm.cachedIOByDay) { pair in
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
                AxisMarks(values: .stride(by: .day, count: 5)) { AxisValueLabel().foregroundStyle(Color(hex: "8C9DB5")).font(.system(size: 11)) }
            }
            .chartYAxis {
                AxisMarks {
                    AxisValueLabel().foregroundStyle(Color(hex: "8C9DB5")).font(.system(size: 11))
                    AxisGridLine().foregroundStyle(.white.opacity(0.04))
                }
            }
            .chartPlotStyle { $0.background(Color.clear) }
            .frame(height: 190)
            .chartOverlay { proxy in
                GeometryReader { geo in
                    Rectangle().fill(.clear).contentShape(Rectangle())
                        .gesture(DragGesture(minimumDistance: 0)
                            .onChanged { v in
                                let x = v.location.x - geo[proxy.plotAreaFrame].origin.x
                                guard let date: String = proxy.value(atX: x) else { return }
                                selectedIO = vm.cachedIOByDay.first(where: { $0.date == date })
                            }
                            .onEnded { _ in selectedIO = nil })
                }
            }
        }
    }

    private func fmtTok(_ n: Int) -> String {
        n >= 1_000_000 ? String(format: "%.1fM", Double(n)/1_000_000) :
        n >= 1_000     ? String(format: "%.0fK", Double(n)/1_000) : "\(n)"
    }

    // 触摸气泡
    private func chartBubble(date: String, value: String) -> some View {
        HStack(spacing: 6) {
            Text(date).font(.system(size: 12, weight: .medium)).foregroundColor(.white.opacity(0.8))
            Text(value).font(.system(size: 12, weight: .bold)).foregroundColor(.white)
        }
        .padding(.horizontal, 12).padding(.vertical, 6)
        .background(Color(hex: "1A2332"))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(.white.opacity(0.1), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // ═══════════════════════════════
    // 费用
    // ═══════════════════════════════

    private var costChart: some View {
        let costs = vm.cachedCostByDay
        let total = costs.map(\.cost).reduce(0, +)
        let avg   = costs.isEmpty ? 0 : total / Double(costs.count)
        let peak  = costs.map(\.cost).max() ?? 0

        return panel("每日费用", "月合计 ¥\(String(format: "%.2f", total))") {
            HStack(spacing: 12) {
                KpiChip(title: "总计", value: String(format: "¥%.2f", total), color: Color(hex: "00E6A0"))
                KpiChip(title: "峰值", value: String(format: "¥%.2f", peak), color: Color(hex: "FFD93D"))
                KpiChip(title: "日均", value: String(format: "¥%.2f", avg),  color: Color(hex: "00C6FF"))
            }

            if let sel = selectedCost {
                chartBubble(date: sel.formattedDate, value: sel.formattedCostCNY)
            }

            Chart(costs) { item in
                AreaMark(x: .value("", item.formattedDate), y: .value("", item.cost))
                    .foregroundStyle(LinearGradient(colors: [Color(hex: "00E6A0").opacity(0.35), .clear], startPoint: .top, endPoint: .bottom))
                LineMark(x: .value("", item.formattedDate), y: .value("", item.cost))
                    .foregroundStyle(LinearGradient(colors: [Color(hex: "00E6A0"), Color(hex: "00C6FF")], startPoint: .leading, endPoint: .trailing))
                    .lineStyle(StrokeStyle(lineWidth: 2.5))
                PointMark(x: .value("", item.formattedDate), y: .value("", item.cost))
                    .foregroundStyle(Color(hex: "00E6A0")).symbolSize(selectedCost != nil ? 40 : 28)
                RuleMark(y: .value("均值", avg))
                    .foregroundStyle(Color(hex: "FFD93D").opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                    .annotation(position: .top, alignment: .trailing) {
                        Text("均值 ¥\(String(format: "%.2f", avg))").font(.system(size: 11, weight: .medium))
                            .foregroundColor(Color(hex: "FFD93D"))
                    }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 5)) { AxisValueLabel().foregroundStyle(Color(hex: "8C9DB5")).font(.system(size: 11)) }
            }
            .chartYAxis {
                AxisMarks {
                    AxisValueLabel().foregroundStyle(Color(hex: "8C9DB5")).font(.system(size: 11))
                    AxisGridLine().foregroundStyle(.white.opacity(0.04))
                }
            }
            .chartPlotStyle { $0.background(Color.clear) }
            .frame(height: 210)
            .chartOverlay { proxy in
                GeometryReader { geo in
                    Rectangle().fill(.clear).contentShape(Rectangle())
                        .gesture(DragGesture(minimumDistance: 0)
                            .onChanged { v in
                                let x = v.location.x - geo[proxy.plotAreaFrame].origin.x
                                guard let date: String = proxy.value(atX: x) else { return }
                                selectedCost = costs.first(where: { $0.date == date })
                            }
                            .onEnded { _ in selectedCost = nil })
                }
            }

            // 模型费用明细列表
            if !vm.cachedModelCostBreakdown.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("模型费用明细")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color(hex: "A0B0CC"))
                        .padding(.top, 16)

                    ForEach(Array(vm.cachedModelCostBreakdown.prefix(5))) { detail in
                        ModelCostRow(
                            detail: detail,
                            isExpanded: expandedModels.contains(detail.model)
                        ) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                if expandedModels.contains(detail.model) {
                                    expandedModels.remove(detail.model)
                                } else {
                                    expandedModels.insert(detail.model)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    // ═══════════════════════════════
    // 费用 USD
    // ═══════════════════════════════

    private var costChartUSD: some View {
        let costs = vm.cachedCostByDayUSD
        let total = costs.map(\.cost).reduce(0, +)
        let avg   = costs.isEmpty ? 0 : total / Double(costs.count)
        let peak  = costs.map(\.cost).max() ?? 0

        return panel("每日费用 (USD)", "月合计 $\(String(format: "%.2f", total))") {
            HStack(spacing: 12) {
                KpiChip(title: "总计", value: String(format: "$%.2f", total), color: Color(hex: "7C5CFC"))
                KpiChip(title: "峰值", value: String(format: "$%.2f", peak), color: Color(hex: "FFD93D"))
                KpiChip(title: "日均", value: String(format: "$%.2f", avg),  color: Color(hex: "00C6FF"))
            }

            if let sel = selectedCostUSD {
                chartBubble(date: sel.formattedDate, value: sel.formattedCostUSD)
            }

            Chart(costs) { item in
                AreaMark(x: .value("", item.formattedDate), y: .value("", item.cost))
                    .foregroundStyle(LinearGradient(colors: [Color(hex: "7C5CFC").opacity(0.35), .clear], startPoint: .top, endPoint: .bottom))
                LineMark(x: .value("", item.formattedDate), y: .value("", item.cost))
                    .foregroundStyle(LinearGradient(colors: [Color(hex: "7C5CFC"), Color(hex: "00C6FF")], startPoint: .leading, endPoint: .trailing))
                    .lineStyle(StrokeStyle(lineWidth: 2.5))
                PointMark(x: .value("", item.formattedDate), y: .value("", item.cost))
                    .foregroundStyle(Color(hex: "7C5CFC")).symbolSize(selectedCostUSD != nil ? 40 : 28)
                RuleMark(y: .value("均值", avg))
                    .foregroundStyle(Color(hex: "FFD93D").opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                    .annotation(position: .top, alignment: .trailing) {
                        Text("均值 $\(String(format: "%.2f", avg))").font(.system(size: 11, weight: .medium))
                            .foregroundColor(Color(hex: "FFD93D"))
                    }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 5)) { AxisValueLabel().foregroundStyle(Color(hex: "8C9DB5")).font(.system(size: 11)) }
            }
            .chartYAxis {
                AxisMarks {
                    AxisValueLabel().foregroundStyle(Color(hex: "8C9DB5")).font(.system(size: 11))
                    AxisGridLine().foregroundStyle(.white.opacity(0.04))
                }
            }
            .chartPlotStyle { $0.background(Color.clear) }
            .frame(height: 210)
            .chartOverlay { proxy in
                GeometryReader { geo in
                    Rectangle().fill(.clear).contentShape(Rectangle())
                        .gesture(DragGesture(minimumDistance: 0)
                            .onChanged { v in
                                let x = v.location.x - geo[proxy.plotAreaFrame].origin.x
                                guard let date: String = proxy.value(atX: x) else { return }
                                selectedCostUSD = costs.first(where: { $0.date == date })
                            }
                            .onEnded { _ in selectedCostUSD = nil })
                }
            }
        }
    }
    
    // ═══════════════════════════════
    // 每日请求（按模型）
    // ═══════════════════════════════

    private var requestCharts: some View {
        modelDayChart(
            title: "每日请求",
            data: vm.requestsByModelAndDay,
            selection: $selectedRequestDay,
            kpiColor: Color(hex: "00C6FF"),
            formatValue: { "\(fmtTok($0))次" },
            formatAvg: { String(format: "%.0f次", $0) }
        )
    }

    // ═══════════════════════════════
    // 每日 Token（按模型）
    // ═══════════════════════════════

    private var tokenCharts: some View {
        modelDayChart(
            title: "每日 Token",
            data: vm.tokensByModelAndDay,
            selection: $selectedTokenDay,
            kpiColor: Color(hex: "7C5CFC"),
            formatValue: { fmtTok($0) },
            formatAvg: { fmtTok(Int($0)) }
        )
    }

    // ═══════════════════════════════
    // 模型日图表（共用）
    // ═══════════════════════════════

    private func modelDayChart(
        title: String,
        data: [ModelDayData],
        selection: Binding<(model: String, day: DayValue)?>,
        kpiColor: Color,
        formatValue: @escaping (Int) -> String,
        formatAvg: @escaping (Double) -> String
    ) -> some View {
        let allDays = data.flatMap { $0.days }
        let total = allDays.map(\.value).reduce(0, +)
        let peak = allDays.map(\.value).max() ?? 0
        let avg = allDays.isEmpty ? 0 : Double(total) / Double(allDays.map(\.date).count)

        return panel(title, "共 \(formatValue(total))") {
            HStack(spacing: 12) {
                KpiChip(title: "总计", value: formatValue(total), color: kpiColor)
                KpiChip(title: "峰值", value: formatValue(peak), color: Color(hex: "FFD93D"))
                KpiChip(title: "日均", value: formatAvg(avg), color: Color(hex: "00E6A0"))
            }

            ForEach(Array(data.enumerated()), id: \.element.id) { index, md in
                let color = modelColors[index % modelColors.count]
                let avg = md.days.isEmpty ? 0 : Double(md.total) / Double(md.days.count)

                VStack(spacing: 8) {
                    HStack {
                        Circle().fill(color).frame(width: 10, height: 10)
                        Text(md.model).font(.system(size: 14, weight: .semibold)).foregroundColor(.white)
                        Spacer()
                        Text(formatValue(md.total)).font(.system(size: 14, weight: .bold, design: .monospaced)).foregroundColor(color)
                    }

                    if let sel = selection.wrappedValue, sel.model == md.model {
                        chartBubble(date: sel.day.shortDate, value: formatValue(sel.day.value))
                    }

                    Chart(md.days) { day in
                        AreaMark(x: .value("", day.shortDate), y: .value("", day.value))
                            .foregroundStyle(LinearGradient(colors: [color.opacity(0.35), .clear], startPoint: .top, endPoint: .bottom))
                        LineMark(x: .value("", day.shortDate), y: .value("", day.value))
                            .foregroundStyle(color).lineStyle(StrokeStyle(lineWidth: 2))
                        PointMark(x: .value("", day.shortDate), y: .value("", day.value))
                            .foregroundStyle(color).symbolSize(selection.wrappedValue?.model == md.model ? 40 : 20)
                        RuleMark(y: .value("均值", avg))
                            .foregroundStyle(Color(hex: "FFD93D").opacity(0.4))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    }
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .day, count: 5)) {
                            AxisValueLabel().foregroundStyle(Color(hex: "8C9DB5")).font(.system(size: 11))
                        }
                    }
                    .chartYAxis {
                        AxisMarks {
                            AxisValueLabel().foregroundStyle(Color(hex: "8C9DB5")).font(.system(size: 11))
                            AxisGridLine().foregroundStyle(.white.opacity(0.04))
                        }
                    }
                    .chartPlotStyle { $0.background(Color.clear) }
                    .frame(height: 150)
                    .chartOverlay { proxy in
                        GeometryReader { geo in
                            Rectangle().fill(.clear).contentShape(Rectangle())
                                .gesture(DragGesture(minimumDistance: 0)
                                    .onChanged { v in
                                        let x = v.location.x - geo[proxy.plotAreaFrame].origin.x
                                        guard let date: String = proxy.value(atX: x) else { return }
                                        if let day = md.days.first(where: { $0.date == date }) {
                                            selection.wrappedValue = (model: md.model, day: day)
                                        }
                                    }
                                    .onEnded { _ in selection.wrappedValue = nil })
                        }
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color(hex: "0A1228").opacity(0.55))
                        .overlay(RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(0.12), lineWidth: 1))
                )
            }
        }
    }

    // ═══════════════════════════════
    // 登录
    // ═══════════════════════════════

    private var loginBanner: some View {
        Button {
            showLoginSheet = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "sparkles").font(.system(size: 18)).foregroundColor(Color(hex: "7C5CFC"))
                VStack(alignment: .leading, spacing: 3) {
                    Text("登录查看详细用量").font(.system(size: 16, weight: .semibold)).foregroundColor(.white)
                    Text("Token 明细 · 每日费用 · 模型分布").font(.system(size: 13)).foregroundColor(Color(hex: "8C9DB5"))
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
                    Text(s).font(.system(size: 12, weight: .medium)).foregroundColor(Color(hex: "8C9DB5"))
                        .padding(.horizontal, 10).padding(.vertical, 3)
                        .background(.white.opacity(0.04)).clipShape(Capsule())
                }
            }
            .padding(.horizontal, 18).padding(.top, 16).padding(.bottom, 10)
            content().padding(.horizontal, 12).padding(.bottom, 12)
        }
        .background(RoundedRectangle(cornerRadius: 20).fill(Color(hex: "0A1228").opacity(0.55))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(0.12), lineWidth: 1)))
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
                Text(label).font(.system(size: 12, weight: .medium)).foregroundColor(Color(hex: "8C9DB5"))
            }
            Text(value).font(.system(size: 20, weight: .bold, design: .monospaced)).foregroundColor(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(color.opacity(0.08))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(color.opacity(0.15), lineWidth: 1)))
    }
}

struct KpiChip: View {
    let title: String; let value: String; let color: Color
    var body: some View {
        VStack(spacing: 3) {
            Text(value).font(.system(size: 18, weight: .bold, design: .monospaced)).foregroundColor(color)
            Text(title).font(.system(size: 11, weight: .medium)).foregroundColor(Color(hex: "8C9DB5"))
        }
        .frame(maxWidth: .infinity).padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 12).fill(color.opacity(0.08))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(color.opacity(0.15), lineWidth: 1)))
    }
}

// MARK: - 统计项标识

struct StatItem: Identifiable {
    let id: String
    let title: String; let value: String; let icon: String; let color: Color
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
            ctx.stroke(ring, with: .color(.white.opacity(0.12)), lineWidth: 1)
        }
    }
}

struct ModelCostRow: View {
    let detail: ModelCostDetail
    let isExpanded: Bool
    let onToggle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 主行
            Button(action: onToggle) {
                HStack(spacing: 8) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color(hex: "00C6FF"))
                        .frame(width: 16)

                    Text(detail.model)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    Spacer()

                    Text(String(format: "¥%.2f", detail.totalCost))
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(hex: "00E6A0"))
                }
            }
            .buttonStyle(.plain)

            // 展开的明细
            if isExpanded {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(detail.details.sorted(by: { $0.amount > $1.amount })) { d in
                        HStack {
                            Text(typeDisplayName(d.type))
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(Color(hex: "8C9DB5"))
                            Spacer()
                            Text(String(format: "¥%.4f", d.amount))
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(Color(hex: "A0B0CC"))
                        }
                        .padding(.leading, 24)
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(.vertical, 6)
    }

    private func typeDisplayName(_ type: String) -> String {
        switch type {
        case "PROMPT_TOKEN": return "提示Token"
        case "PROMPT_CACHE_HIT_TOKEN": return "缓存命中"
        case "PROMPT_CACHE_MISS_TOKEN": return "缓存未命中"
        case "RESPONSE_TOKEN": return "输出Token"
        case "REQUEST": return "请求次数"
        default: return type
        }
    }
}
