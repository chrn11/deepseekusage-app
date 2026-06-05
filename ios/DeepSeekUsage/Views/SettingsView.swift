import SwiftUI

/// 设置页面
struct SettingsView: View {
    @State private var apiKey = ""
    @State private var isKeyVisible = false
    @State private var isTesting = false
    @State private var testResult: TestResult?
    @State private var showLogin = false

    enum TestResult: Equatable {
        case success(balance: String)
        case failure(String)
    }

    var body: some View {
        NavigationStack {
            Form {
                // ==================
                // API Key
                // ==================
                Section {
                    HStack {
                        if isKeyVisible {
                            TextField("sk-...", text: $apiKey)
                                .autocapitalization(.none).disableAutocorrection(true)
                                .font(.body.monospaced())
                        } else {
                            SecureField("sk-...", text: $apiKey)
                                .autocapitalization(.none).disableAutocorrection(true)
                                .font(.body.monospaced())
                        }
                        Button { isKeyVisible.toggle() } label: {
                            Image(systemName: isKeyVisible ? "eye.slash" : "eye")
                                .foregroundColor(.secondary)
                        }
                    }

                    HStack(spacing: 12) {
                        Button(action: saveKey) {
                            Label("保存", systemImage: "square.and.arrow.down.fill")
                        }
                        .buttonStyle(.bordered)
                        .disabled(apiKey.trimmingCharacters(in: .whitespaces).isEmpty)

                        Button(action: testConnection) {
                            HStack {
                                if isTesting { ProgressView().scaleEffect(0.7) }
                                else { Image(systemName: "antenna.radiowaves.left.and.right") }
                                Text("测试连接")
                            }
                        }
                        .buttonStyle(.bordered)
                        .disabled(isTesting || apiKey.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                } header: {
                    Text("API Key")
                } footer: {
                    Text("从 [platform.deepseek.com/api_keys](https://platform.deepseek.com/api_keys) 获取。仅用于查询余额，不上传任何第三方。")
                }

                // ==================
                // 平台登录（获取详细用量）
                // ==================
                Section {
                    if KeychainManager.hasCookie {
                        HStack {
                            Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                            Text("已登录")
                            Spacer()
                            Button("重新登录") { showLogin = true }
                                .font(.caption)
                        }
                        Button(role: .destructive) {
                            try? KeychainManager.deleteCookie()
                        } label: {
                            Label("退出登录", systemImage: "rectangle.portrait.and.arrow.right")
                        }
                    } else {
                        Button { showLogin = true } label: {
                            Label("登录 DeepSeek 平台", systemImage: "person.badge.key")
                        }
                    }
                } header: {
                    Text("用量详情")
                } footer: {
                    Text("登录后可以查看每日/每周/每月的 Token 消耗明细和费用曲线。Cookie 仅存储在你手机钥匙串中。")
                }

                // ==================
                // 接口诊断
                // ==================
                Section {
                    Button {
                        // TODO: 自动抓取内部接口
                    } label: {
                        Label("诊断接口", systemImage: "stethoscope")
                    }
                    .disabled(!KeychainManager.hasCookie)
                } header: {
                    Text("高级")
                } footer: {
                    Text("当深求索平台改版导致接口变动时，点击此按钮自动抓取新的接口地址。")
                }

                // ==================
                // 测试结果
                // ==================
                if let r = testResult {
                    Section {
                        switch r {
                        case .success(let b):
                            HStack {
                                Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                                Text("连接成功 — 余额 \(b)").foregroundColor(.green)
                            }
                        case .failure(let m):
                            HStack {
                                Image(systemName: "xmark.circle.fill").foregroundColor(.red)
                                Text(m).foregroundColor(.red)
                            }
                        }
                    }
                }

                // ==================
                // 关于
                // ==================
                Section {
                    HStack {
                        Text("版本")
                        Spacer()
                        Text("1.0.0").foregroundColor(.secondary)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("数据来源")
                            .font(.subheadline)
                        Text("余额：api.deepseek.com/user/balance（API Key）\n用量：platform.deepseek.com 内部接口（登录 Cookie）")
                            .font(.caption).foregroundColor(.secondary)
                    }
                } header: {
                    Text("关于")
                }
            }
            .navigationTitle("设置")
            .onAppear {
                if apiKey.isEmpty, let saved = KeychainManager.loadAPIKey() {
                    apiKey = saved
                }
            }
            .sheet(isPresented: $showLogin) {
                LoginView()
            }
        }
    }

    // MARK: - 操作

    private func saveKey() {
        let t = apiKey.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return }
        do { try KeychainManager.saveAPIKey(t); testResult = .success(balance: "Key 已保存") }
        catch { testResult = .failure(error.localizedDescription) }
    }

    private func testConnection() {
        let t = apiKey.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return }
        isTesting = true; testResult = nil
        Task {
            do {
                let r = try await DeepSeekAPI.validateKey(t)
                let b = r.balanceInfos.first?.formattedTotal ?? "OK"
                testResult = .success(balance: b)
                try? KeychainManager.saveAPIKey(t)
            } catch {
                testResult = .failure(error.localizedDescription)
            }
            isTesting = false
        }
    }
}
