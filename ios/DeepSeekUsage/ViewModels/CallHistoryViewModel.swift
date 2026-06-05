import Foundation
import SwiftUI

/// 调用历史 ViewModel
///
/// 管理代理调用记录列表，支持分页加载和按模型筛选
@MainActor
class CallHistoryViewModel: ObservableObject {

    // MARK: - 发布的状态

    /// 调用记录列表
    @Published var calls: [ProxyCallItem] = []

    /// 总记录数
    @Published var totalCount = 0

    /// 当前页码
    @Published var currentPage = 1

    /// 是否正在加载
    @Published var isLoading = false

    /// 是否正在加载更多（翻页）
    @Published var isLoadingMore = false

    /// 是否还有更多数据
    @Published var hasMoreData = true

    /// 筛选的模型（nil = 全部）
    @Published var filterModel: String? = nil

    /// 错误消息
    @Published var errorMessage: String?

    // MARK: - 计算属性

    /// 可用的模型列表（从已有记录中提取）
    var availableModels: [String] {
        let models = Set(calls.map(\.model))
        return models.sorted()
    }

    /// 每页条数
    var perPage: Int { 20 }

    /// 是否有数据
    var isEmpty: Bool { calls.isEmpty && !isLoading }

    // MARK: - 数据加载

    /// 首次加载（第一页）
    func loadFirstPage() async {
        isLoading = true
        errorMessage = nil
        currentPage = 1

        do {
            let page = try await APIClient.shared.fetchProxyCalls(page: 1, per: perPage)
            calls = page.items
            totalCount = page.total
            hasMoreData = page.items.count >= perPage
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    /// 加载下一页
    func loadNextPage() async {
        guard !isLoadingMore, hasMoreData else { return }

        isLoadingMore = true
        let nextPage = currentPage + 1

        do {
            let page = try await APIClient.shared.fetchProxyCalls(page: nextPage, per: perPage)
            calls.append(contentsOf: page.items)
            currentPage = nextPage
            hasMoreData = page.items.count >= perPage
            totalCount = page.total
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoadingMore = false
    }

    /// 刷新（回到第一页）
    func refresh() async {
        await loadFirstPage()
    }
}
