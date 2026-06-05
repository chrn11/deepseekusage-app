import Foundation
import SwiftData
import SwiftUI

/// 仪表盘 ViewModel
///
/// 功能：
/// - 从 Keychain 读取 API Key → 直接调 DeepSeek API
/// - 余额快照存 SwiftData（本地）
/// - 通过余额差值推算每日消费
@MainActor
final class DashboardViewModel: ObservableObject {

    @Published var balance: BalanceInfo?
    @Published var isLoading = false
    @Published var errorMessage: String?

    /// 最近 30 天的用量统计（由余额差值计算）
    @Published var dailyStats: [DailyUsageStat] = []

    /// 今日消费
    @Published var todaySpend: Double = 0

    /// 本月消费
    @Published var monthSpend: Double = 0

    /// 本周消费
    @Published var weekSpend: Double = 0

    // MARK: - 加载数据

    func loadData(modelContext: ModelContext) async {
        guard KeychainManager.hasKey else {
            errorMessage = "请先在设置中填入 DeepSeek API Key"
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            // 1. 查余额
            let resp = try await DeepSeekAPI.fetchBalance()
            balance = resp.balanceInfos.first

            // 2. 保存快照到本地
            if let info = resp.balanceInfos.first {
                let snapshot = BalanceSnapshot(
                    totalBalance: info.totalBalanceValue,
                    grantedBalance: info.grantedBalanceValue,
                    toppedUpBalance: info.toppedUpBalanceValue,
                    currency: info.currency
                )
                modelContext.insert(snapshot)
                try modelContext.save()
            }

            // 3. 重新计算用量统计
            calculateStats(modelContext: modelContext)

        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - 从本地快照计算消费

    func calculateStats(modelContext: ModelContext) {
        let now = Date()
        let calendar = Calendar.current

        // 取所有快照
        let descriptor = FetchDescriptor<BalanceSnapshot>(
            sortBy: [SortDescriptor(\.timestamp, order: .forward)]
        )

        guard let snapshots = try? modelContext.fetch(descriptor),
              snapshots.count >= 2 else {
            dailyStats = []
            todaySpend = 0
            monthSpend = 0
            weekSpend = 0
            return
        }

        // 按天分组，每天取最早和最后一次快照
        let grouped = Dictionary(grouping: snapshots) { $0.dateOnly }
            .sorted { $0.key < $1.key }

        var stats: [DailyUsageStat] = []
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"

        for (date, daySnapshots) in grouped {
            guard let first = daySnapshots.first,
                  let last = daySnapshots.last else { continue }

            let spend = max(0, first.totalBalance - last.totalBalance)

            stats.append(DailyUsageStat(
                id: df.string(from: date),
                date: date,
                spend: spend,
                snapshot: last
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
            .map(\.spend)
            .reduce(0, +)

        // 本周
        let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) ?? now
        weekSpend = dailyStats
            .filter { $0.date >= weekStart }
            .map(\.spend)
            .reduce(0, +)
    }

    // MARK: - 格式化

    var formattedTodaySpend: String {
        String(format: "¥%.2f", todaySpend)
    }

    var formattedMonthSpend: String {
        String(format: "¥%.2f", monthSpend)
    }

    var formattedWeekSpend: String {
        String(format: "¥%.2f", weekSpend)
    }
}
