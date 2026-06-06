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
    @Published var allCostGroups: [CostCurrencyGroup] = []
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

    // MARK: - 缓存的计算属性（computeStats 时更新，避免重复计算）
    @Published var cachedCostByDay: [DailyCost] = []
    @Published var cachedCostByDayUSD: [DailyCost] = []
    @Published var cachedModelBreakdown: [ModelShare] = []
    @Published var cachedIOByDay: [IOPair] = []
    @Published var cachedModelCharts: [ModelChartData] = []
    @Published var cachedModelCostBreakdown: [ModelCostDetail] = []

    // MARK: - 余额预警
    @Published var alertThreshold: Double {
        didSet { UserDefaults.standard.set(alertThreshold, forKey: "balance_alert_threshold") }
    }
    var alertEnabled: Bool { alertThreshold > 0 }

    @Published var isLoading = false
    @Published var errorMessage: String?

    private var loadTask: Task<Void, Never>?

    init() {
        let now = Date()
        let cal = Calendar.current
        currentYear  = cal.component(.year, from: now)
        currentMonth = cal.component(.month, from: now)
        alertThreshold = UserDefaults.standard.double(forKey: "balance_alert_threshold")
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

        // 汇总 — 带 1 次重试
        do { summary = try await fetchWithRetry { try await PlatformAPI.fetchUsageSummary() } }
        catch { print("[Dashboard] summary 失败: \(error)") }

        // 用量
        do {
            let data = try await fetchWithRetry { try await PlatformAPI.fetchUsageAmount(month: currentMonth, year: currentYear) }
            allAmounts = data.days ?? []
        } catch {
            allAmounts = []
            print("[Dashboard] amount 失败: \(error)")
            if errorMessage == nil { errorMessage = "用量数据加载失败：\(error.localizedDescription)" }
        }

        // 费用
        do {
            let groups = try await fetchWithRetry { try await PlatformAPI.fetchUsageCost(month: currentMonth, year: currentYear) }
            allCostGroups = groups
        } catch {
            allCostGroups = []
            print("[Dashboard] cost 失败: \(error)")
            if errorMessage == nil { errorMessage = "费用数据加载失败：\(error.localizedDescription)" }
        }

        refreshAvailableMonths()
    }

    /// 带 1 次重试的 fetch（仅重试非认证/非 4xx 错误）
    private func fetchWithRetry<T>(_ f: @escaping () async throws -> T) async throws -> T {
        do { return try await f() }
        catch {
            if let pe = error as? PlatformError, case .notLoggedIn = pe { throw error }
            if let pe = error as? PlatformError, case .loginExpired = pe { throw error }
            // 等 1.5s 重试一次
            try await Task.sleep(nanoseconds: 1_500_000_000)
            return try await f()
        }
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
        Task {
            isLoading = true
            do { summary = try await fetchWithRetry { try await PlatformAPI.fetchUsageSummary() } } catch { print("[Dashboard] selectMonth summary: \(error)") }
            do { allCostGroups   = try await fetchWithRetry { try await PlatformAPI.fetchUsageCost(month: currentMonth, year: currentYear) } }
            catch { allCostGroups = []; errorMessage = "费用数据加载失败：\(error.localizedDescription)" }
            do { allAmounts = (try await fetchWithRetry { try await PlatformAPI.fetchUsageAmount(month: currentMonth, year: currentYear) }).days ?? [] }
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
        let now = Date()
        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"; df.timeZone = TimeZone(identifier: "UTC")
        let todayStr = df.string(from: now)
        var utcCal = Calendar(identifier: .gregorian); utcCal.timeZone = TimeZone(identifier: "UTC")!
        let weekStart = utcCal.date(from: utcCal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) ?? now

        // 费用统计
        var totalCost: Double = 0; var todayCost: Double = 0; var weekCost: Double = 0
        var totalTokens: Int = 0; var weekT: Int = 0; var totalCalls: Int = 0
        let costGroup = allCostGroups.first(where: { $0.currency == "CNY" }) ?? allCostGroups.first

        if let days = costGroup?.days {
            for day in days {
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
                if let d = df.date(from: day.date ?? ""), d >= weekStart { weekT += dTokens }
            }
        }

        todaySpend = todayCost; weekSpend = weekCost; monthSpend = totalCost
        monthTokens = totalTokens; monthCalls = totalCalls; weekTokens = weekT

        // 缓存所有派生数据
        cachedCostByDay = computeCostByDay()
        cachedCostByDayUSD = computeCostByDayUSD()
        cachedModelBreakdown = computeModelBreakdown()
        cachedIOByDay = computeIOByDay()
        cachedModelCharts = computeModelCharts()
        cachedModelCostBreakdown = computeModelCostBreakdown()
    }

    // MARK: - 摘要（一次计算缓存）

    private func computeModelBreakdown() -> [ModelShare] {
        var costMap: [String: Double] = [:]
        let cnyGroup = allCostGroups.first(where: { $0.currency == "CNY" }) ?? allCostGroups.first
        for m in (cnyGroup?.total ?? []) {
            guard let name = m.model else { continue }
            costMap[name] = (m.usage ?? []).reduce(0) { $0 + (Double($1.amount ?? "0") ?? 0) }
        }
        var map: [String: (tokens: Int, cost: Double)] = [:]
        for day in allAmounts {
            for m in (day.data ?? []) {
                let name = m.model ?? "Unknown"; var tk = 0
                for u in (m.usage ?? []) { if u.type != "REQUEST" { tk += Int(u.amount ?? "0") ?? 0 } }
                if tk > 0 { map[name, default: (0, 0)].tokens += tk }
            }
        }
        for (name, _) in map { map[name]?.cost = costMap[name] ?? 0 }
        let total = Double(map.values.map(\.tokens).reduce(0, +))
        return map.map { ModelShare(model: $0.key, tokens: $0.value.tokens, cost: $0.value.cost, fraction: total > 0 ? Double($0.value.tokens) / total : 0) }
            .sorted { $0.tokens > $1.tokens }
    }

    private func computeIOByDay() -> [IOPair] {
        allAmounts.compactMap { day in
            guard let models = day.data else { return nil }
            var input = 0; var output = 0
            for m in models { for u in (m.usage ?? []) {
                let t = u.type ?? ""; let a = Int(u.amount ?? "0") ?? 0
                t.contains("RESPONSE") ? (output += a) : (input += a)
            }}
            return IOPair(date: day.date ?? "", input: input, output: output)
        }.sorted { $0.date < $1.date }
    }

    private func computeCostByDay() -> [DailyCost] {
        (allCostGroups.first(where: { $0.currency == "CNY" }) ?? allCostGroups.first)?.days?.compactMap { day in
            guard let models = day.data else { return nil }
            let total = models.flatMap { $0.usage ?? [] }.reduce(0) { $0 + (Double($1.amount ?? "0") ?? 0) }
            return DailyCost(date: day.date ?? "", cost: total)
        }.sorted { $0.date < $1.date } ?? []
    }

    private func computeCostByDayUSD() -> [DailyCost] {
        allCostGroups.first(where: { $0.currency == "USD" })?.days?.compactMap { day in
            guard let models = day.data else { return nil }
            let total = models.flatMap { $0.usage ?? [] }.reduce(0) { $0 + (Double($1.amount ?? "0") ?? 0) }
            return DailyCost(date: day.date ?? "", cost: total)
        }.sorted { $0.date < $1.date } ?? []
    }

    private func computeModelCostBreakdown() -> [ModelCostDetail] {
        (allCostGroups.first(where: { $0.currency == "CNY" }) ?? allCostGroups.first)?.total?.compactMap { m in
            guard let name = m.model else { return nil }
            var total: Double = 0; var details: [CostDetail] = []
            for u in (m.usage ?? []) {
                let amt = Double(u.amount ?? "0") ?? 0; total += amt
                details.append(CostDetail(type: u.type ?? "未知", amount: amt))
            }
            return ModelCostDetail(model: name, totalCost: total, details: details)
        }.sorted { $0.totalCost > $1.totalCost } ?? []
    }

    private func computeModelCharts() -> [ModelChartData] {
        var reqMap: [String: [String: Int]] = [:]; var tokMap: [String: [String: Int]] = [:]
        for day in allAmounts {
            guard let dd = day.date, let models = day.data else { continue }
            for m in models {
                guard let name = m.model else { continue }
                for u in (m.usage ?? []) {
                    let t = u.type ?? ""; let amt = Int(u.amount ?? "0") ?? 0
                    if t == "REQUEST" {
                        if reqMap[name] == nil { reqMap[name] = [:] }
                        reqMap[name]?[dd] = (reqMap[name]?[dd] ?? 0) + amt
                    } else {
                        if tokMap[name] == nil { tokMap[name] = [:] }
                        tokMap[name]?[dd] = (tokMap[name]?[dd] ?? 0) + amt
                    }
                }
            }
        }
        let allModels = Set(reqMap.keys).union(tokMap.keys)
        return allModels.map { model in
            let req = (reqMap[model] ?? [:]).sorted(by: <).map { DayValue(date: $0.key, value: $0.value) }
            let tok = (tokMap[model] ?? [:]).sorted(by: <).map { DayValue(date: $0.key, value: $0.value) }
            return ModelChartData(model: model, requestDays: req, tokenDays: tok)
        }.sorted { $0.totalTokens > $1.totalTokens }.prefix(5).map { $0 }
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

/// 模型费用明细（按类型分组）
struct ModelCostDetail: Identifiable {
    let id = UUID()
    let model: String
    let totalCost: Double
    let details: [CostDetail]
}

/// 单项费用明细（PROMPT_TOKEN / CACHE_HIT / CACHE_MISS / RESPONSE_TOKEN / REQUEST）
struct CostDetail: Identifiable {
    let id = UUID()
    let type: String
    let amount: Double
}

struct DailyCost: Identifiable {
    let id = UUID(); let date: String; let cost: Double
    var formattedDate: String { date.count >= 10 ? String(date.suffix(5)) : date }
    var formattedCostCNY: String { String(format: "¥%.2f", cost) }
    var formattedCostUSD: String { String(format: "$%.2f", cost) }
}

struct IOPair: Identifiable {
    let id = UUID(); let date: String; let input: Int; let output: Int
    var shortDate: String { date.count >= 10 ? String(date.suffix(5)) : date }
}

// MARK: - 按模型每日数据

/// 每日数值数据
struct DayValue: Identifiable {
    let id = UUID()
    let date: String
    let value: Int
    var shortDate: String { date.count >= 10 ? String(date.suffix(5)) : date }
}

/// 模型每日数据
struct ModelDayData: Identifiable {
    let id = UUID()
    let model: String
    let days: [DayValue]
    var total: Int { days.map(\.value).reduce(0, +) }
}

/// 按模型聚合的请求+Token 图表数据
struct ModelChartData: Identifiable {
    let id = UUID()
    let model: String
    let requestDays: [DayValue]
    let tokenDays: [DayValue]
    var totalRequests: Int { requestDays.map(\.value).reduce(0, +) }
    var totalTokens: Int { tokenDays.map(\.value).reduce(0, +) }
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
