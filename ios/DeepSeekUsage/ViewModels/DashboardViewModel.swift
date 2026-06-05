import Foundation
import SwiftUI

@MainActor
final class DashboardViewModel: ObservableObject {

    // MARK: - 余额
    @Published var balanceInfos: [BalanceInfo] = []
    @Published var summary: SummaryData?

    // MARK: - 余额便捷访问（根据币种设置选取）

    /// 当前设置对应的主余额
    var balance: BalanceInfo? { balanceInfos.primary }

    /// 双币种显示文字
    var balanceBothText: String { balanceInfos.formattedBoth }

    // MARK: - 平台用量
    @Published var isLoggedIn: Bool = false
    @Published var allAmounts: [DayAmount] = []
    @Published var allCosts: [DayAmount] = []
    @Published var currentYear: Int
    @Published var currentMonth: Int
    @Published var availableMonths: [YearMonth] = []

    // MARK: - 统计
    @Published var todaySpend: Double = 0
    @Published var weekSpend: Double = 0
    @Published var monthSpend: Double = 0
    @Published var monthTokens: Int = 0
    @Published var monthCalls: Int = 0
    @Published var weekTokens: Int = 0

    @Published var isLoading = false
    @Published var errorMessage: String?

    private var loadTask: Task<Void, Never>?

    init() {
        let now = Date()
        let cal = Calendar.current
        currentYear  = cal.component(.year, from: now)
        currentMonth = cal.component(.month, from: now)
    }

    // MARK: - 加载

    func loadAll() async {
        isLoggedIn = KeychainManager.hasToken
        loadTask?.cancel()
        loadTask = Task {
            isLoading = true; errorMessage = nil

            async let bt: () = loadBalance()
            async let pt: () = loadPlatform()
            _ = await (bt, pt)

            if !Task.isCancelled {
                computeStats()
                isLoading = false
            }
        }
        _ = await loadTask?.value
    }

    private func loadBalance() async {
        guard KeychainManager.hasAPIKey else { return }
        do {
            let resp = try await DeepSeekAPI.fetchBalance()
            balanceInfos = resp.balanceInfos
        } catch {
            let ns = error as NSError
            if ns.domain == NSURLErrorDomain && ns.code == -999 { return }
            errorMessage = error.localizedDescription
        }
    }

    private func loadPlatform() async {
        guard isLoggedIn else { return }

        // 汇总
        do { summary = try await PlatformAPI.fetchUsageSummary() }
        catch { print("[Dashboard] summary 失败: \(error)") }

        // 用量 (当前月)
        do {
            let data = try await PlatformAPI.fetchUsageAmount(month: currentMonth, year: currentYear)
            allAmounts = data.days ?? []
        } catch {
            allAmounts = []
            print("[Dashboard] amount 失败: \(error)")
            if errorMessage == nil { errorMessage = "用量数据加载失败：\(error.localizedDescription)" }
        }

        // 费用 (当前月)
        do {
            let data = try await PlatformAPI.fetchUsageCost(month: currentMonth, year: currentYear)
            allCosts = data.days ?? []
        } catch {
            allCosts = []
            print("[Dashboard] cost 失败: \(error)")
            if errorMessage == nil { errorMessage = "费用数据加载失败：\(error.localizedDescription)" }
        }

        refreshAvailableMonths()
    }

    // MARK: - 月份切换

    func refreshAvailableMonths() {
        var m = YearMonth(year: currentYear, month: currentMonth)
        var r: [YearMonth] = []
        for _ in 0..<18 { r.append(m); m = m.previous() }
        availableMonths = r
    }

    var selectedYM: YearMonth { YearMonth(year: currentYear, month: currentMonth) }

    func selectMonth(_ ym: YearMonth) {
        currentYear = ym.year; currentMonth = ym.month
        // 切月份需要重新拉数据
        Task {
            isLoading = true
            do { summary = try await PlatformAPI.fetchUsageSummary() } catch { print("[Dashboard] selectMonth summary: \(error)") }
            do { allCosts   = (try await PlatformAPI.fetchUsageCost(month: currentMonth, year: currentYear)).days ?? [] }
            catch { allCosts = []; errorMessage = "费用数据加载失败：\(error.localizedDescription)" }
            do { allAmounts = (try await PlatformAPI.fetchUsageAmount(month: currentMonth, year: currentYear)).days ?? [] }
            catch { allAmounts = []; errorMessage = "用量数据加载失败：\(error.localizedDescription)" }
            computeStats()
            isLoading = false
        }
    }

    var canGoPrev: Bool {
        availableMonths.firstIndex(of: selectedYM).map { $0 + 1 < availableMonths.count } ?? false
    }
    var canGoNext: Bool {
        availableMonths.firstIndex(of: selectedYM).map { $0 > 0 } ?? false
    }

    func previousMonth() {
        guard let i = availableMonths.firstIndex(of: selectedYM), i + 1 < availableMonths.count else { return }
        selectMonth(availableMonths[i + 1])
    }

    func nextMonth() {
        guard let i = availableMonths.firstIndex(of: selectedYM), i > 0 else { return }
        selectMonth(availableMonths[i - 1])
    }

    // MARK: - 计算

    func computeStats() {
        let cal = Calendar.current; let now = Date()
        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
        let todayStr = df.string(from: now)
        let weekStart = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) ?? now

        // 从费用数据算每日消费
        var totalCost: Double = 0; var todayCost: Double = 0; var weekCost: Double = 0
        var totalTokens: Int = 0; var weekT: Int = 0; var totalCalls: Int = 0

        for day in allCosts {
            guard let dayModels = day.data else { continue }
            for m in dayModels {
                for u in (m.usage ?? []) {
                    let amt = Double(u.amount ?? "0") ?? 0
                    totalCost += amt
                    if day.date == todayStr { todayCost += amt }
                    if let d = df.date(from: day.date ?? ""), d >= weekStart { weekCost += amt }
                }
            }
        }

        for day in allAmounts {
            guard let dayModels = day.data else { continue }
            for m in dayModels {
                var dTokens = 0; var dCalls = 0
                for u in (m.usage ?? []) {
                    let t = u.type ?? ""
                    let amt = Int(u.amount ?? "0") ?? 0
                    if t == "REQUEST" { dCalls = amt }
                    else { dTokens += amt }
                }
                totalTokens += dTokens; totalCalls += dCalls
                if let d = df.date(from: day.date ?? ""), d >= weekStart {
                    weekT += dTokens
                }
            }
        }

        todaySpend = todayCost
        weekSpend = weekCost
        monthSpend = totalCost
        monthTokens = totalTokens
        monthCalls = totalCalls
        weekTokens = weekT

        // summary 兜底：当明细数据不可用时用汇总接口的数据
        if let s = summary {
            // 月度消费：明细为0时用 summary
            if monthSpend == 0 { monthSpend = s.costCNY > 0 ? s.costCNY : s.costUSD }
            // Token 总量
            if monthTokens == 0, let t = s.totalUsage { monthTokens = t }
            // 调用次数
            if monthCalls == 0, let t = s.monthlyTokenUsage.flatMap(Int.init) { monthCalls = t }
        }
    }

    // MARK: - 摘要

    /// 模型份额（从 amounts 汇总所有天的数据）
    var modelBreakdown: [ModelShare] {
        var map: [String: (tokens: Int, cost: Double)] = [:]
        for day in allAmounts {
            guard let models = day.data else { continue }
            for m in models {
                let name = m.model ?? "Unknown"
                var tk = 0
                for u in (m.usage ?? []) {
                    if u.type != "REQUEST" { tk += Int(u.amount ?? "0") ?? 0 }
                }
                if tk > 0 { map[name, default: (0, 0)].tokens += tk }
            }
        }
        let total = Double(map.values.map(\.tokens).reduce(0, +))
        return map.map { ModelShare(model: $0.key, tokens: $0.value.tokens, cost: 0, fraction: total > 0 ? Double($0.value.tokens) / total : 0) }
            .sorted { $0.tokens > $1.tokens }
    }

    /// I/O 每日聚合
    var ioByDay: [IOPair] {
        allAmounts.compactMap { day in
            guard let models = day.data else { return nil }
            var input = 0; var output = 0
            for m in models {
                for u in (m.usage ?? []) {
                    let t = u.type ?? ""; let a = Int(u.amount ?? "0") ?? 0
                    if t.contains("RESPONSE") { output += a }
                    else { input += a } // PROMPT_TOKEN, CACHE_HIT/MISS
                }
            }
            return IOPair(date: day.date ?? "", input: input, output: output)
        }.sorted { $0.date < $1.date }
    }

    /// 费用每日聚合
    var costByDay: [DailyCost] {
        allCosts.compactMap { day in
            guard let models = day.data else { return nil }
            var total: Double = 0
            for m in models {
                for u in (m.usage ?? []) {
                    total += Double(u.amount ?? "0") ?? 0
                }
            }
            return DailyCost(date: day.date ?? "", cost: total)
        }.sorted { $0.date < $1.date }
    }

    // MARK: - fmt

    var formattedTodaySpend: String  { String(format: "¥%.2f", todaySpend) }
    var formattedWeekSpend: String   { String(format: "¥%.2f", weekSpend) }
    var formattedMonthSpend: String  { String(format: "¥%.2f", monthSpend) }
    var formattedWeekTokens: String  { fmtN(weekTokens) }
    var formattedMonthTokens: String { fmtN(monthTokens) }
    var selectedMonthLabel: String   { selectedYM.label }
    private func fmtN(_ n: Int) -> String {
        n >= 1_000_000 ? String(format: "%.1fM", Double(n)/1_000_000)
        : n >= 1_000   ? String(format: "%.0fK", Double(n)/1_000) : "\(n)"
    }
}

// MARK: - 共享模型

struct ModelShare: Identifiable {
    let id = UUID()
    let model: String; let tokens: Int; let cost: Double; let fraction: Double
    var pct: String { String(format: "%.0f%%", fraction * 100) }
    var formattedTokens: String {
        tokens >= 1_000_000 ? String(format: "%.1fM", Double(tokens)/1_000_000)
        : tokens >= 1_000   ? String(format: "%.0fK", Double(tokens)/1_000) : "\(tokens)"
    }
    var formattedCost: String { String(format: "¥%.2f", cost) }
}

struct DailyCost: Identifiable {
    let id = UUID(); let date: String; let cost: Double
    var formattedDate: String { date.count >= 10 ? String(date.suffix(5)) : date }
    var formattedCost: String { String(format: "¥%.2f", cost) }
}

struct IOPair: Identifiable {
    let id = UUID(); let date: String; let input: Int; let output: Int
    var shortDate: String { date.count >= 10 ? String(date.suffix(5)) : date }
}

// MARK: - YearMonth

struct YearMonth: Equatable, Hashable, Comparable {
    let year, month: Int
    static var current: YearMonth {
        let c = Calendar.current.dateComponents([.year, .month], from: Date())
        return YearMonth(year: c.year ?? 2026, month: c.month ?? 1)
    }
    init(year: Int, month: Int) { self.year = year; self.month = month }

    var label: String {
        let names = ["1月","2月","3月","4月","5月","6月","7月","8月","9月","10月","11月","12月"]
        return "\(year)年 \(names[month - 1])"
    }

    func previous() -> YearMonth {
        month > 1 ? YearMonth(year: year, month: month - 1)
                  : YearMonth(year: year - 1, month: 12)
    }
    static func < (l: YearMonth, r: YearMonth) -> Bool {
        l.year < r.year || (l.year == r.year && l.month < r.month)
    }
}
