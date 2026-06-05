import Foundation

/// 余额快照 — 存本地 JSON 文件
///
/// 每次刷新余额时保存一条。
/// 通过对比两次快照的余额差值，推算消费。
struct BalanceSnapshot: Codable, Identifiable {
    var id: String { UUID().uuidString }
    let timestamp: Date
    let totalBalance: Double
    let grantedBalance: Double
    let toppedUpBalance: Double
    let currency: String

    /// 格式化的总余额
    var formattedTotal: String {
        let symbol = currency == "CNY" ? "¥" : "$"
        return "\(symbol)\(String(format: "%.2f", totalBalance))"
    }

    /// 只取日期部分
    var dateOnly: Date {
        Calendar.current.startOfDay(for: timestamp)
    }
}

// MARK: - 本地持久化

/// 余额快照的本地存储（JSON 文件）
final class SnapshotStore: ObservableObject {
    static let shared = SnapshotStore()

    @Published var snapshots: [BalanceSnapshot] = []

    private let fileName = "balance_snapshots.json"

    private var fileURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent(fileName)
    }

    init() {
        load()
    }

    /// 添加一条快照
    func add(_ snapshot: BalanceSnapshot) {
        // 去重：同一分钟内不重复存
        if let last = snapshots.last,
           abs(last.timestamp.timeIntervalSince(snapshot.timestamp)) < 60,
           last.totalBalance == snapshot.totalBalance {
            return
        }
        snapshots.append(snapshot)
        // 只保留最近 60 天
        let cutoff = Date().addingTimeInterval(-60 * 24 * 3600)
        snapshots = snapshots.filter { $0.timestamp > cutoff }
        save()
    }

    /// 删除所有数据
    func clear() {
        snapshots = []
        save()
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(snapshots)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("SnapshotStore 保存失败: \(error)")
        }
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let data = try Data(contentsOf: fileURL)
            snapshots = try JSONDecoder().decode([BalanceSnapshot].self, from: data)
        } catch {
            print("SnapshotStore 加载失败: \(error)")
        }
    }
}

// MARK: - 每日用量（由余额差值计算）

struct DailyUsageStat: Identifiable {
    let id: String   // "2026-06-05"
    let date: Date
    let spend: Double

    var formattedSpend: String {
        String(format: "¥%.2f", spend)
    }

    var shortDate: String {
        let f = DateFormatter()
        f.dateFormat = "M/d"
        return f.string(from: date)
    }
}
