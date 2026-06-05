import Foundation
import SwiftData

/// 余额快照 — 存储在设备本地
///
/// 每次刷新余额时保存一条记录。
/// 通过对比两次快照的余额差值，推算消费金额。
@Model
final class BalanceSnapshot {
    /// 采集时间
    var timestamp: Date

    /// 总余额
    var totalBalance: Double

    /// 赠送余额
    var grantedBalance: Double

    /// 充值余额
    var toppedUpBalance: Double

    /// 币种
    var currency: String

    init(timestamp: Date = .now,
         totalBalance: Double,
         grantedBalance: Double,
         toppedUpBalance: Double,
         currency: String) {
        self.timestamp = timestamp
        self.totalBalance = totalBalance
        self.grantedBalance = grantedBalance
        self.toppedUpBalance = toppedUpBalance
        self.currency = currency
    }

    /// 格式化的总余额
    var formattedTotal: String {
        let symbol = currency == "CNY" ? "¥" : "$"
        return "\(symbol)\(String(format: "%.2f", totalBalance))"
    }

    /// 只取日期部分（用于分组）
    var dateOnly: Date {
        Calendar.current.startOfDay(for: timestamp)
    }
}

// MARK: - 每日用量（从余额差值计算得出）

/// 每日用量统计 — 由余额快照的差值计算而来，不直接存储
struct DailyUsageStat: Identifiable {
    let id: String  // 日期字符串 "2026-06-05"
    let date: Date
    let spend: Double       // 当日消费（余额差值）
    let snapshot: BalanceSnapshot

    var formattedSpend: String {
        String(format: "¥%.2f", spend)
    }

    var shortDate: String {
        let f = DateFormatter()
        f.dateFormat = "M/d"
        return f.string(from: date)
    }
}
