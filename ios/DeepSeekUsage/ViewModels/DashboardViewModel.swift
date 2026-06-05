import Foundation
import SwiftUI
import UserNotifications

/// 仪表盘 ViewModel
@MainActor
final class DashboardViewModel: ObservableObject {

    // MARK: - 余额
    @Published var balance: BalanceInfo?

    // MARK: - 平台用量
    @Published var allAmounts: [DailyAmount] = []
    @Published var allCosts: [DailyCost] = []
    @Published var summary: UsageSummaryData?
    @Published var isLoggedIn: Bool = false

    // MARK: - 月份
    @Published var selectedMonth: YearMonth = YearMonth.current
    @Published var availableMonths: [YearMonth] = []

    var filteredCosts: [DailyCost]    { allCosts.filter { YearMonth(from: $0.date) == selectedMonth } }
    var filteredAmounts: [DailyAmount] { allAmounts.filter { YearMonth(from: $0.date) == selectedMonth } }

    var monthSpend: Double { filteredCosts.map(\.cost).reduce(0, +) }
    var monthTokens: Int { filteredAmounts.map(\.totalTokens).reduce(0, +) }
    var monthCalls: Int { selectedMonth == YearMonth.current ? (summary?.totalCallsThisMonth ?? 0) : 0 }

    // MARK: - 今日 / 本周
    @Published var todaySpend: Double = 0
    @Published var weekSpend: Double = 0
    @Published var weekTokens: Int = 0

    // MARK: - 状态
    @Published var isLoading = false
    @Published var errorMessage: String?

    // MARK: - 余额预警
    var alertThreshold: Double {
        get { UserDefaults.standard.double(forKey: "balance_alert_threshold") }
        set { UserDefaults.standard.set(newValue, forKey: "balance_alert_threshold") }
    }
    var alertEnabled: Bool { alertThreshold > 0 }

    private var lastAlertBalance: Double = -1
    private let store = SnapshotStore.shared
    @Published var dailyStats: [DailyUsageStat] = []

    // MARK: - 加载

    func loadAll() async {
        isLoggedIn = KeychainManager.hasCookie
        isLoading = true; errorMessage = nil

        async let bt: () = loadBalance()
        async let pt: () = loadPlatformData()
        _ = await (bt, pt)
        refreshAvailableMonths()
        calculateStats()
        checkBalanceAlert()
        isLoading = false
    }

    private func loadBalance() async {
        guard KeychainManager.hasAPIKey else { return }
        do {
            let resp = try await DeepSeekAPI.fetchBalance()
            balance = resp.balanceInfos.first
            if let info = resp.balanceInfos.first {
                store.add(BalanceSnapshot(
                    timestamp: Date(),
                    totalBalance: info.totalBalanceValue,
                    grantedBalance: info.grantedBalanceValue,
                    toppedUpBalance: info.toppedUpBalanceValue,
                    currency: info.currency
                ))
            }
        } catch {
            let ns = error as NSError
            // NSURLErrorCancelled (-999): 刷新时前一个任务取消，无需报错
            if ns.domain == NSURLErrorDomain && ns.code == -999 { return }
            errorMessage = error.localizedDescription
        }
    }

    private func loadPlatformData() async {
        guard isLoggedIn else { return }
        do { summary = try await PlatformAPI.fetchUsageSummary().data } catch { print("summary: \(error)") }
        do { allAmounts = try await PlatformAPI.fetchDailyAmount() }     catch { print("amount: \(error)") }
        do { allCosts   = try await PlatformAPI.fetchDailyCost() }       catch { print("cost: \(error)") }
    }

    // MARK: - 月份

    func refreshAvailableMonths() {
        let ym = Set(allCosts.map { YearMonth(from: $0.date) })
        availableMonths = ym.sorted(by: >)
        if availableMonths.first == YearMonth.current { selectedMonth = YearMonth.current }
    }

    func previousMonth() {
        guard let i = availableMonths.firstIndex(of: selectedMonth), i + 1 < availableMonths.count else { return }
        selectedMonth = availableMonths[i + 1]; calculateStats()
    }
    func nextMonth() {
        guard let i = availableMonths.firstIndex(of: selectedMonth), i > 0 else { return }
        selectedMonth = availableMonths[i - 1]; calculateStats()
    }

    // MARK: - 统计

    func calculateStats() {
        let cal = Calendar.current; let now = Date(); let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
        todaySpend = allCosts.filter { $0.date == df.string(from: now) }.map(\.cost).reduce(0, +)
        let ws = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) ?? now
        weekSpend  = allCosts.filter { c in guard let d = df.date(from: c.date) else { return false }; return d >= ws }.map(\.cost).reduce(0, +)
        weekTokens = allAmounts.filter { a in guard let d = df.date(from: a.date) else { return false }; return d >= ws }.map(\.totalTokens).reduce(0, +)
    }

    // MARK: - 模型饼图

    /// 按模型聚合当月用量
    var modelBreakdown: [ModelShare] {
        let grouped = Dictionary(grouping: filteredAmounts, by: \.modelDisplayName)
        let total = Double(filteredAmounts.map(\.totalTokens).reduce(0, +))
        return grouped.map { model, items in
            let tokens = items.map(\.totalTokens).reduce(0, +)
            let cost   = items.map(\.estimatedCost).reduce(0, +)
            return ModelShare(model: model, tokens: tokens, cost: cost, fraction: total > 0 ? Double(tokens) / total : 0)
        }.sorted { $0.tokens > $1.tokens }
    }

    // MARK: - I/O 日聚合

    /// 按天聚合 I/O Token
    var ioByDay: [IOPair] {
        let grouped = Dictionary(grouping: filteredAmounts, by: \.date)
        return grouped.map { date, items in
            IOPair(date: date, input: items.map(\.inputTokens).reduce(0, +),
                   output: items.map(\.outputTokens).reduce(0, +))
        }.sorted { $0.date < $1.date }
    }

    // MARK: - 余额预警

    func checkBalanceAlert() {
        guard alertEnabled, let b = balance else { return }
        let total = b.totalBalanceValue
        if total <= alertThreshold && abs(total - lastAlertBalance) > 0.01 {
            lastAlertBalance = total
            sendLowBalanceNotification(balance: total, currency: b.currency)
        }
    }

    private func sendLowBalanceNotification(balance: Double, currency: String) {
        let sym = currency == "CNY" ? "¥" : "$"
        let content = UNMutableNotificationContent()
        content.title = "余额不足"
        content.body = "当前余额 \(sym)\(String(format: "%.2f", balance))，低于预警线 \(sym)\(String(format: "%.2f", alertThreshold))"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "low_balance_\(Date().timeIntervalSince1970)",
                                            content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - 格式化

    var formattedTodaySpend: String  { String(format: "¥%.2f", todaySpend) }
    var formattedWeekSpend: String   { String(format: "¥%.2f", weekSpend) }
    var formattedMonthSpend: String  { String(format: "¥%.2f", monthSpend) }
    var formattedWeekTokens: String  { fmtTok(weekTokens) }
    var formattedMonthTokens: String { fmtTok(monthTokens) }
    var selectedMonthLabel: String   { selectedMonth.label }
    private func fmtTok(_ n: Int) -> String {
        if n >= 1_000_000 { return String(format: "%.1fM", Double(n)/1_000_000) }
        if n >= 1_000     { return String(format: "%.0fK", Double(n)/1_000) }
        return "\(n)"
    }
}

// MARK: - 模型份额

struct ModelShare: Identifiable {
    let id = UUID()
    let model: String
    let tokens: Int
    let cost: Double
    let fraction: Double

    var pct: String { String(format: "%.0f%%", fraction * 100) }
    var formattedTokens: String {
        tokens >= 1_000_000 ? String(format: "%.1fM", Double(tokens)/1_000_000)
        : tokens >= 1_000 ? String(format: "%.0fK", Double(tokens)/1_000)
        : "\(tokens)"
    }
    var formattedCost: String { String(format: "¥%.2f", cost) }
}

// MARK: - I/O Pair

struct IOPair: Identifiable {
    let id = UUID()
    let date: String
    let input: Int
    let output: Int
    var shortDate: String { date.count >= 10 ? String(date.suffix(5)) : date }
}

// MARK: - YearMonth

struct YearMonth: Equatable, Hashable, Comparable {
    let year, month: Int
    static var current: YearMonth {
        let c = Calendar.current.dateComponents([.year, .month], from: Date())
        return YearMonth(year: c.year ?? 2026, month: c.month ?? 1)
    }
    init(from s: String) {
        let p = s.split(separator: "-").prefix(2)
        year = p.count >= 1 ? Int(p[0]) ?? 2026 : 2026
        month = p.count >= 2 ? Int(p[1]) ?? 1 : 1
    }
    init(year: Int, month: Int) { self.year = year; self.month = month }
    var label: String {
        ["1月","2月","3月","4月","5月","6月","7月","8月","9月","10月","11月","12月"][month - 1]
        + " \(year)"
    }
    static func < (l: YearMonth, r: YearMonth) -> Bool { l.year < r.year || (l.year == r.year && l.month < r.month) }
}
