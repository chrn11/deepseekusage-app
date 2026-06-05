import SwiftUI

/// 设置页面
///
/// 配置项：
/// - 后端服务器地址
/// - API Key 状态（存储在服务器端，这里只显示状态）
/// - 轮询间隔设置
struct SettingsView: View {
    @AppStorage("backend_base_url") private var backendURL: String = "http://localhost:8080"
    @State private var isEditingURL = false
    @State private var editedURL = ""

    // 连接测试
    @State private var isTestingConnection = false
    @State private var connectionStatus: ConnectionStatus = .unknown

    enum ConnectionStatus {
        case unknown
        case testing
        case success
        case failed(String)
    }

    var body: some View {
        NavigationStack {
            Form {
                // ---- 服务器配置 ----
                Section {
                    HStack {
                        Text("后端地址")
                        Spacer()
                        if isEditingURL {
                            TextField("http://your-server:8080", text: $editedURL)
                                .multilineTextAlignment(.trailing)
                                .keyboardType(.URL)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                                .foregroundColor(.secondary)
                        } else {
                            Text(backendURL)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                    }

                    if isEditingURL {
                        Button("保存") {
                            backendURL = editedURL
                            APIClient.shared.configuredBaseURL = editedURL
                            isEditingURL = false
                        }
                        .frame(maxWidth: .infinity)
                        .foregroundColor(.blue)
                    } else {
                        Button("修改") {
                            editedURL = backendURL
                            isEditingURL = true
                        }
                        .frame(maxWidth: .infinity)
                    }
                } header: {
                    Text("服务器配置")
                } footer: {
                    Text("指向 Vapor 后端服务的地址。如果你在自己电脑上运行后端，使用 http://localhost:8080。如果是远程服务器，填入对应的 IP 或域名。")
                }

                // ---- 连接测试 ----
                Section {
                    HStack {
                        Button(action: testConnection) {
                            HStack {
                                Image(systemName: "antenna.radiowaves.left.and.right")
                                Text("测试连接")
                            }
                        }
                        .disabled(isTestingConnection)

                        Spacer()

                        switch connectionStatus {
                        case .unknown:
                            EmptyView()
                        case .testing:
                            ProgressView()
                        case .success:
                            Label("连接成功", systemImage: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.caption)
                        case .failed(let msg):
                            Label("连接失败: \(msg)", systemImage: "xmark.circle.fill")
                                .foregroundColor(.red)
                                .font(.caption)
                        }
                    }
                }

                // ---- API Key 说明 ----
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "key.fill")
                                .foregroundColor(.orange)
                            Text("DeepSeek API Key")
                                .font(.headline)
                        }

                        Text("API Key 配置在后端服务器上，不需要在 App 中填入。")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Text("启动后端时设置环境变量：")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top, 4)

                        Text("export DEEPSEEK_API_KEY=\"sk-your-key\"")
                            .font(.caption.monospaced())
                            .padding(8)
                            .background(Color(.systemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("API Key")
                }

                // ---- 关于 ----
                Section {
                    HStack {
                        Text("版本")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("数据来源")
                        Spacer()
                        Text("余额差值估算 + 代理转发记录")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("关于")
                } footer: {
                    Text("DeepSeek Usage Tracker — 非官方 DeepSeek API 用量追踪工具\n后端采用 Vapor 4 + SwiftUI 原生 iOS 客户端")
                }
            }
            .navigationTitle("设置")
        }
    }

    // MARK: - 连接测试

    private func testConnection() {
        isTestingConnection = true
        connectionStatus = .testing

        Task {
            do {
                let url = URL(string: "\(backendURL)/health")!
                let (_, response) = try await URLSession.shared.data(from: url)

                if let httpResponse = response as? HTTPURLResponse,
                   (200...299).contains(httpResponse.statusCode) {
                    connectionStatus = .success
                } else {
                    connectionStatus = .failed("状态码: \((response as? HTTPURLResponse)?.statusCode ?? 0)")
                }
            } catch {
                connectionStatus = .failed(error.localizedDescription)
            }

            isTestingConnection = false
        }
    }
}
