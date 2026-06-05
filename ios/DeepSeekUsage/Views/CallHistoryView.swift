import SwiftUI

/// 调用记录列表
///
/// 展示所有通过代理转发的 DeepSeek API 调用记录
/// 支持：
/// - 分页加载（上滑自动加载更多）
/// - 按模型筛选
/// - 每条记录显示：时间、模型、Token 数、费用
struct CallHistoryView: View {
    @StateObject private var viewModel = CallHistoryViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // ---- 模型筛选栏 ----
                if !viewModel.availableModels.isEmpty {
                    filterBar
                }

                // ---- 列表 ----
                if viewModel.isEmpty {
                    emptyView
                } else {
                    listView
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("调用记录")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !viewModel.calls.isEmpty {
                        Text("共 \(viewModel.totalCount) 条")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .task {
                await viewModel.loadFirstPage()
            }
        }
    }

    // MARK: - 模型筛选栏

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // 全部
                FilterChip(
                    title: "全部",
                    isSelected: viewModel.filterModel == nil,
                    color: .gray
                ) {
                    viewModel.filterModel = nil
                }

                // 各个模型
                ForEach(viewModel.availableModels, id: \.self) { model in
                    FilterChip(
                        title: modelDisplayName(model),
                        isSelected: viewModel.filterModel == model,
                        color: model.contains("reasoner") ? .purple : .blue
                    ) {
                        viewModel.filterModel = model
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(Color(.systemBackground))
    }

    // MARK: - 空状态

    private var emptyView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "tray")
                .font(.system(size: 50))
                .foregroundColor(.secondary.opacity(0.5))
            Text("暂无调用记录")
                .font(.headline)
                .foregroundColor(.secondary)
            Text("当你通过代理调用 DeepSeek API 后，\n调用记录会显示在这里")
                .font(.subheadline)
                .foregroundColor(.secondary.opacity(0.8))
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - 记录列表

    private var listView: some View {
        let filteredCalls = viewModel.filterModel == nil
            ? viewModel.calls
            : viewModel.calls.filter { $0.model == viewModel.filterModel }

        return List {
            ForEach(filteredCalls) { call in
                CallRow(call: call)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
            }

            // 加载更多指示器
            if viewModel.hasMoreData {
                HStack {
                    Spacer()
                    if viewModel.isLoadingMore {
                        ProgressView()
                            .padding()
                    }
                    Spacer()
                }
                .listRowSeparator(.hidden)
                .task {
                    await viewModel.loadNextPage()
                }
            }

            // 底部统计
            if !viewModel.calls.isEmpty {
                HStack {
                    Spacer()
                    Text("已加载 \(filteredCalls.count) / \(viewModel.totalCount) 条")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .refreshable {
            await viewModel.refresh()
        }
    }

    // MARK: - 辅助方法

    private func modelDisplayName(_ model: String) -> String {
        switch model {
        case "deepseek-chat": return "Chat"
        case "deepseek-reasoner": return "Reasoner"
        default: return model.replacingOccurrences(of: "deepseek-", with: "")
        }
    }
}

// MARK: - 筛选标签

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption.bold())
                .foregroundColor(isSelected ? .white : color)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? color : color.opacity(0.1))
                .clipShape(Capsule())
        }
    }
}

// MARK: - 单条调用记录行

struct CallRow: View {
    let call: ProxyCallItem

    var body: some View {
        HStack(spacing: 12) {
            // 模型图标
            Image(systemName: call.modelIcon)
                .font(.title3)
                .foregroundColor(call.model.contains("reasoner") ? .purple : .blue)
                .frame(width: 36, height: 36)
                .background(
                    (call.model.contains("reasoner") ? Color.purple : Color.blue)
                        .opacity(0.1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))

            // 主要信息
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(call.modelDisplayName)
                        .font(.subheadline.bold())
                    Spacer()
                    Text(call.formattedCost)
                        .font(.subheadline.bold())
                        .foregroundColor(call.model.contains("reasoner") ? .purple : .blue)
                        .monospacedDigit()
                }

                HStack(spacing: 8) {
                    // Token 信息
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.down")
                            .font(.system(size: 10))
                        Text("\(call.promptTokens)")
                            .font(.caption)
                        Image(systemName: "arrow.up")
                            .font(.system(size: 10))
                        Text("\(call.completionTokens)")
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)

                    Text("·")
                        .foregroundColor(.secondary)

                    // 时间
                    Text(call.relativeTime)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(12)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.03), radius: 3, x: 0, y: 1)
    }
}
