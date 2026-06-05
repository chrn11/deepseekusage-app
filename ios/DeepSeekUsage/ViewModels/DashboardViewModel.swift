import Foundation
import SwiftUI

/// 仪表盘 ViewModel
@MainActor
final class DashboardViewModel: ObservableObject {

    // MARK: - 余额
    @Published var balance: BalanceInfo?

    // MARK: - 平台用量（全量原始数据）
    @Published var allAmounts: [DailyAmount] = []
    @Published var allCosts: [DailyCost] = []
    @Published var summary: UsageSummaryData?
    @Published var isLoggedIn: Bool = false

    // MARK: - 月份选择
    @Published var selectedMonth: YearMonth = YearMonth.current
    @Published var availableMonths: [YearMonth] = []

    // MARK: - 当月过滤后的数据
    var filteredCosts: [DailyCost] {
        allCosts.filter { YearMonth(from: $0.date) == selectedMonth }
    }
    var filteredAmounts: [DailyAmount] {
        allAmounts.filter { YearMonth(from: $0.date) == selectedMonth }
    }

    // MARK: - 当月统计
    var monthSpend: Double { filteredCosts.map(\.cost).reduce(0, +) }
    var monthTokens: Int { filteredAmounts.map(\.totalTokens).reduce(0, +) }
    var monthCalls: Int {
        selectedMonth == YearMonth.current ? (summary?.totalCallsThisMonth ?? 0) : 0
    }

    // MARK: - 今日 / 本周
    @Published var todaySpend: Double = 0
    @Published var weekSpend: Double = 0
    @Published var weekTokens: Int = 0

    // MARK: - 状态
    @Published var isLoading = false
    @Published var errorMessage: String?

    // MARK: - 本地快照
    private let store = SnapshotStore.shared
    @Published var dailyStats: [DailyUsageStat] = []

    // MARK: - 加载

    func loadAll() async {
        isLoggedIn = KeychainManager.hasCookie
        isLoading = true
        errorMessage = nil

        async let balanceTask: () = loadBalance()
        async let platformTask: () = loadPlatformData()

        _ = await (balanceTask, platformTask)
        refreshAvailableMonths()
        calculateStats()
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
            errorMessage = error.localizedDescription
        }
    }

    private func loadPlatformData() async {
        guard isLoggedIn else { return }
        do { summary = try await PlatformAPI.fetchUsageSummary().data }
        catch { print("获取汇总失败: \(error)") }

        do { allAmounts = try await PlatformAPI.fetchDailyAmount() }
        catch { print("获取用量失败: \(error)") }

        do { allCosts = try await PlatformAPI.fetchDailyCost() }
        catch { print("获取费用失败: \(error)") }
    }

    // MARK: - 月份管理

    func refreshAvailableMonths() {
        let ymSet = Set(allCosts.map { YearMonth(from: $0.date) })
        availableMonths = ymSet.sorted(by: >)
        // 如果还没选过或是旧数据，默认当前月
        if availableMonths.first == YearMonth.current {
            selectedMonth = YearMonth.current
        }
    }

    func previousMonth() {
        guard let idx = availableMonths.firstIndex(of: selectedMonth),
              idx + 1 < availableMonths.count else { return }
        selectedMonth = availableMonths[idx + 1]
        calculateStats()
    }

    func nextMonth() {
        guard let idx = availableMonths.firstIndex(of: selectedMonth), idx > 0 else { return }
        selectedMonth = availableMonths[idx - 1]
        calculateStats()
    }

    func goToCurrentMonth() {
        selectedMonth = YearMonth.current
        calculateStats()
    }

    // MARK: - 计算统计

    func calculateStats() {
        let calendar = Calendar.current
        let now = Date()
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"

        todaySpend = allCosts.filter { $0.date == df.string(from: now) }.map(\.cost).reduce(0, +)

        let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) ?? now
        weekSpend = allCosts.filter { c in
            guard let d = df.date(from: c.date) else { return false }
            return d >= weekStart
        }.map(\.cost).reduce(0, +)

        weekTokens = allAmounts.filter { a in
            guard let d = df.date(from: a.date) else { return false }
            return d >= weekStart
        }.map(\.totalTokens).reduce(0, +)
    }

    // MARK: - 格式化

    var formattedTodaySpend: String  { String(format: "¥%.2f", todaySpend) }
    var formattedWeekSpend: String   { String(format: "¥%.2f", weekSpend) }
    var formattedMonthSpend: String  { String(format: "¥%.2f", monthSpend) }

    var formattedWeekTokens: String  { formatToken(weekTokens) }
    var formattedMonthTokens: String { formatToken(monthTokens) }

    var selectedMonthLabel: String {
        selectedMonth.label
    }

    private func formatToken(_ n: Int) -> String {
        if n >= 1_000_000 { return String(format: "%.1fM", Double(n) / 1_000_000) }
        if n >= 1_000     { return String(format: "%.0fK", Double(n) / 1_000) }
        return "\(n)"
    }
}

// MARK: - YearMonth 工具

struct YearMonth: Equatable, Hashable, Comparable {
    let year: Int
    let month: Int

    static var current: YearMonth {
        let c = Calendar.current.dateComponents([.year, .month], from: Date())
        return YearMonth(year: c.year ?? 2026, month: c.month ?? 1)
    }

    /// "2026-06-05" → YearMonth(2026, 6)
    init(from dateStr: String) {
        let parts = dateStr.split(separator: "-").prefix(2)
        self.year = parts.count >= 1 ? Int(parts[0]) ?? 2026 : 2026
        self.month = parts.count >= 2 ? Int(parts[1]) ?? 1 : 1
    }

    init(year: Int, month: Int) { self.year = year; self.month = month }

    var label: String {
        let names = ["1月","2月","3月","4月","5月","6月","7月","8月","9月","10月","11月","12月"]
        return "\(year)年 \(names[month - 1])"
    }

    static func < (lhs: YearMonth, rhs: YearMonth) -> Bool {
        lhs.year < rhs.year || (lhs.year == rhs.year && lhs.month < rhs.month)
    }
}
