import Foundation
import SwiftUI

/// 仪表盘 ViewModel
///
/// - 从钥匙串读取 API Key → 直接调 DeepSeek API
/// - 余额快照存本地 JSON（SnapshotStore）
/// - 通过余额差值推算每日消费
@MainActor
final class DashboardViewModel: ObservableObject {

    @Published var balance: BalanceInfo?
    @Published var isLoading = false
    @Published var errorMessage: String?

    /// 最近 30 天用量（由余额差值计算）
    @Published var dailyStats: [DailyUsageStat] = []

    /// 今日 / 本周 / 本月消费
    @Published var todaySpend: Double = 0
    @Published var weekSpend: Double = 0
    @Published var monthSpend: Double = 0

    private let store = SnapshotStore.shared

    // MARK: - 加载

    func loadData() async {
        guard KeychainManager.hasKey else {
            errorMessage = "请先在设置中填入 DeepSeek API Key"
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let resp = try await DeepSeekAPI.fetchBalance()
            balance = resp.balanceInfos.first

            // 存快照
            if let info = resp.balanceInfos.first {
                store.add(BalanceSnapshot(
                    timestamp: Date(),
                    totalBalance: info.totalBalanceValue,
                    grantedBalance: info.grantedBalanceValue,
                    toppedUpBalance: info.toppedUpBalanceValue,
                    currency: info.currency
                ))
            }

            calculateStats()

        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - 计算消费统计

    func calculateStats() {
        let snaps = store.snapshots
        let calendar = Calendar.current
        let now = Date()

        guard snaps.count >= 2 else {
            dailyStats = []
            todaySpend = 0; weekSpend = 0; monthSpend = 0
            return
        }

        // 按天分组，每天取最早和最后一次快照
        let grouped = Dictionary(grouping: snaps) { $0.dateOnly }
            .sorted { $0.key < $1.key }

        var stats: [DailyUsageStat] = []
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"

        for (date, daySnapshots) in grouped {
            guard let first = daySnapshots.first,
                  let last = daySnapshots.last,
                  first.totalBalance > last.totalBalance else { continue }

            let spend = first.totalBalance - last.totalBalance

            stats.append(DailyUsageStat(
                id: df.string(from: date),
                date: date,
                spend: spend
            ))
        }

        // 只保留最近 30 天
        let cutoff = calendar.date(byAdding: .day, value: -30, to: now) ?? now
        dailyStats = stats.filter { $0.date >= cutoff }

        // 今日
        let todayStart = calendar.startOfDay(for: now)
        todaySpend = dailyStats.first(where: { calendar.isDate($0.date, inSameDayAs: todayStart) })?.spend ?? 0

        // 本月
        monthSpend = dailyStats
            .filter { calendar.isDate($0.date, equalTo: now, toGranularity: .month) }
            .map(\.spend).reduce(0, +)

        // 本周
        let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) ?? now
        weekSpend = dailyStats
            .filter { $0.date >= weekStart }
            .map(\.spend).reduce(0, +)
    }

    // MARK: - 格式化

    var formattedTodaySpend: String {
        String(format: "¥%.2f", todaySpend)
    }

    var formattedWeekSpend: String {
        String(format: "¥%.2f", weekSpend)
    }

    var formattedMonthSpend: String {
        String(format: "¥%.2f", monthSpend)
    }
}
