import Foundation
import SwiftUI

/// 仪表盘 ViewModel
///
/// 管理仪表盘页面的所有数据状态，包括：
/// - 实时账户余额
/// - 今日用量统计
/// - 最近 30 天消费趋势（用于图表）
@MainActor
class DashboardViewModel: ObservableObject {

    // MARK: - 发布的状态

    /// 账户余额
    @Published var balance: BalanceDetail?

    /// 今日用量
    @Published var todayUsage: DailyUsageItem?

    /// 最近 30 天用量数据（用于图表）
    @Published var recentUsage: [DailyUsageItem] = []

    /// 是否正在加载
    @Published var isLoading = false

    /// 错误消息（非 nil 表示有错误）
    @Published var errorMessage: String?

    // MARK: - 计算属性

    /// 本月总消费（根据 recentUsage 计算）
    var monthlySpending: Double {
        let now = Date()
        let calendar = Calendar.current
        return recentUsage
            .filter { item in
                guard let date = item.parsedDate else { return false }
                return calendar.isDate(date, equalTo: now, toGranularity: .month)
            }
            .compactMap { Double($0.estimatedSpending) }
            .reduce(0, +)
    }

    /// 格式化的本月消费
    var formattedMonthlySpending: String {
        String(format: "¥%.2f", monthlySpending)
    }

    /// 本月总 Token 消耗
    var monthlyTokens: Int {
        let now = Date()
        let calendar = Calendar.current
        return recentUsage
            .filter { item in
                guard let date = item.parsedDate else { return false }
                return calendar.isDate(date, equalTo: now, toGranularity: .month)
            }
            .map(\.proxyTokenCount)
            .reduce(0, +)
    }

    /// 格式化的本月 Token 数
    var formattedMonthlyTokens: String {
        if monthlyTokens >= 1_000_000 {
            return String(format: "%.1fM", Double(monthlyTokens) / 1_000_000)
        } else if monthlyTokens >= 1_000 {
            return String(format: "%.0fK", Double(monthlyTokens) / 1_000)
        }
        return "\(monthlyTokens)"
    }

    /// 本月 API 调用次数
    var monthlyCalls: Int {
        let now = Date()
        let calendar = Calendar.current
        return recentUsage
            .filter { item in
                guard let date = item.parsedDate else { return false }
                return calendar.isDate(date, equalTo: now, toGranularity: .month)
            }
            .map(\.proxyCallCount)
            .reduce(0, +)
    }

    /// 消费最高的那一天
    var peakDay: DailyUsageItem? {
        recentUsage.max { a, b in
            (Double(a.estimatedSpending) ?? 0) < (Double(b.estimatedSpending) ?? 0)
        }
    }

    // MARK: - 数据加载

    /// 加载仪表盘所有数据
    func loadAllData() async {
        isLoading = true
        errorMessage = nil

        // 并行加载余额、今日用量、30 天趋势
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.fetchBalance() }
            group.addTask { await self.fetchTodayUsage() }
            group.addTask { await self.fetchRecentUsage() }
        }
        isLoading = false
    }

    /// 手动刷新（下拉刷新触发）
    func refresh() async {
        await loadAllData()
    }

    /// 手动触发余额抓取
    func triggerPoll() async {
        do {
            _ = try await APIClient.shared.triggerBalancePoll()
            _ = try? await APIClient.shared.fetchBalance()
            await loadAllData()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - 私有方法

    private func fetchBalance() async {
        do {
            let info = try await APIClient.shared.fetchBalance()
            balance = info.balanceInfos.first
        } catch {
            errorMessage = "获取余额失败: \(error.localizedDescription)"
        }
    }

    private func fetchTodayUsage() async {
        do {
            todayUsage = try await APIClient.shared.fetchTodayUsage()
        } catch {
            errorMessage = "获取今日用量失败: \(error.localizedDescription)"
        }
    }

    private func fetchRecentUsage() async {
        do {
            recentUsage = try await APIClient.shared.fetchRecent30DaysUsage()
        } catch {
            errorMessage = "获取用量趋势失败: \(error.localizedDescription)"
        }
    }
}
