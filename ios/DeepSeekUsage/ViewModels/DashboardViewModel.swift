import Foundation
import SwiftUI

/// 仪表盘 ViewModel
///
/// 数据源：
/// - API Key → DeepSeek 官方 /user/balance（实时余额）
/// - Cookie → platform.deepseek.com 内部 API（每日/每周/每月用量）
@MainActor
final class DashboardViewModel: ObservableObject {

    // MARK: - 余额（API Key）
    @Published var balance: BalanceInfo?

    // MARK: - 平台用量（Cookie 登录后）
    @Published var dailyAmounts: [DailyAmount] = []
    @Published var dailyCosts: [DailyCost] = []
    @Published var summary: UsageSummaryData?
    @Published var isLoggedIn: Bool = false

    // MARK: - 状态
    @Published var isLoading = false
    @Published var errorMessage: String?

    // MARK: - 本地余额快照
    private let store = SnapshotStore.shared
    @Published var dailyStats: [DailyUsageStat] = []
    @Published var todaySpend: Double = 0
    @Published var weekSpend: Double = 0
    @Published var monthSpend: Double = 0

    /// 本周 Token 用量（平台接口有则用接口，否则估算）
    @Published var weekTokens: Int = 0
    @Published var monthTokens: Int = 0

    // MARK: - 加载所有数据

    func loadAll() async {
        isLoggedIn = KeychainManager.hasCookie
        isLoading = true
        errorMessage = nil

        // 并行加载
        async let balanceTask: () = loadBalance()
        async let platformTask: () = loadPlatformData()

        _ = await (balanceTask, platformTask)
        calculateStats()
        isLoading = false
    }

    // MARK: - 余额

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

    // MARK: - 平台用量

    private func loadPlatformData() async {
        guard isLoggedIn else { return }

        do {
            // 注意：接口地址可能变化，"诊断"功能后续可以自动抓取
            summary = try await PlatformAPI.fetchUsageSummary().data
        } catch {
            print("获取平台汇总失败: \(error)")
        }

        do {
            dailyAmounts = try await PlatformAPI.fetchDailyAmount()
        } catch {
            print("获取每日用量失败: \(error)")
        }

        do {
            dailyCosts = try await PlatformAPI.fetchDailyCost()
        } catch {
            print("获取每日费用失败: \(error)")
        }
    }

    // MARK: - 计算统计

    func calculateStats() {
        let calendar = Calendar.current
        let now = Date()
        let todayStart = calendar.startOfDay(for: now)
        let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) ?? now
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now

        // ---- 如果有平台接口数据，优先用 ----
        if !dailyCosts.isEmpty {
            let df = DateFormatter()
            df.dateFormat = "yyyy-MM-dd"

            todaySpend = dailyCosts.filter { $0.date == df.string(from: now) }.map(\.cost).reduce(0, +)
            weekSpend  = dailyCosts.filter { c in
                guard let d = df.date(from: c.date) else { return false }
                return d >= weekStart
            }.map(\.cost).reduce(0, +)
            monthSpend = dailyCosts.filter { c in
                guard let d = df.date(from: c.date) else { return false }
                return d >= monthStart
            }.map(\.cost).reduce(0, +)
        }

        if !dailyAmounts.isEmpty {
            let df = DateFormatter()
            df.dateFormat = "yyyy-MM-dd"

            weekTokens  = dailyAmounts.filter { a in
                guard let d = df.date(from: a.date) else { return false }
                return d >= weekStart
            }.map(\.totalTokens).reduce(0, +)
            monthTokens = dailyAmounts.filter { a in
                guard let d = df.date(from: a.date) else { return false }
                return d >= monthStart
            }.map(\.totalTokens).reduce(0, +)
        } else {
            weekTokens  = summary?.totalTokensThisMonth ?? 0
            monthTokens = summary?.totalTokensThisMonth ?? 0
        }
    }

    // MARK: - 格式化

    var formattedTodaySpend: String   { String(format: "¥%.2f", todaySpend) }
    var formattedWeekSpend: String    { String(format: "¥%.2f", weekSpend) }
    var formattedMonthSpend: String   { String(format: "¥%.2f", monthSpend) }

    var formattedWeekTokens: String {
        weekTokens >= 1_000_000 ? String(format: "%.1fM", Double(weekTokens) / 1_000_000) :
        weekTokens >= 1_000     ? String(format: "%.0fK", Double(weekTokens) / 1_000) :
        "\(weekTokens)"
    }

    var formattedMonthTokens: String {
        monthTokens >= 1_000_000 ? String(format: "%.1fM", Double(monthTokens) / 1_000_000) :
        monthTokens >= 1_000     ? String(format: "%.0fK", Double(monthTokens) / 1_000) :
        "\(monthTokens)"
    }

    /// 月调用次数
    var monthCalls: Int { summary?.totalCallsThisMonth ?? 0 }
}
