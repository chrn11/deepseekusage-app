import SwiftUI

/// 设置页面
///
/// - 输入 / 管理 DeepSeek API Key（安全存储在 Keychain）
/// - 测试连接
/// - 版本信息
struct SettingsView: View {
    @State private var apiKey = ""
    @State private var isKeyVisible = false
    @State private var isTesting = false
    @State private var testResult: TestResult?

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
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                                .font(.body.monospaced())
                        } else {
                            SecureField("sk-...", text: $apiKey)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                                .font(.body.monospaced())
                        }

                        Button {
                            isKeyVisible.toggle()
                        } label: {
                            Image(systemName: isKeyVisible ? "eye.slash" : "eye")
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("DeepSeek API Key")
                } footer: {
                    Text("去 [platform.deepseek.com/api_keys](https://platform.deepseek.com/api_keys) 创建你的 API Key。Key 只会存储在你手机的钥匙串中，不会上传到任何地方。")
                }

                // ==================
                // 操作按钮
                // ==================
                Section {
                    Button {
                        saveKey()
                    } label: {
                        HStack {
                            Image(systemName: "square.and.arrow.down.fill")
                            Text("保存")
                        }
                    }
                    .disabled(apiKey.trimmingCharacters(in: .whitespaces).isEmpty)

                    Button {
                        testConnection()
                    } label: {
                        HStack {
                            if isTesting {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "antenna.radiowaves.left.and.right")
                            }
                            Text("测试连接")
                        }
                    }
                    .disabled(isTesting || apiKey.trimmingCharacters(in: .whitespaces).isEmpty)

                    if KeychainManager.hasKey {
                        Button(role: .destructive) {
                            deleteKey()
                        } label: {
                            HStack {
                                Image(systemName: "trash")
                                Text("删除已保存的 Key")
                            }
                        }
                    }
                }

                // ==================
                // 测试结果
                // ==================
                if let result = testResult {
                    Section {
                        switch result {
                        case .success(let balance):
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("连接成功 — 余额 \(balance)")
                                    .foregroundColor(.green)
                            }
                        case .failure(let msg):
                            HStack {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.red)
                                Text(msg)
                                    .foregroundColor(.red)
                            }
                        }
                    }
                }

                // ==================
                // 工作原理
                // ==================
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("📡 工作原理")
                            .font(.subheadline.bold())

                        Text("""
                        本 App 直接调用 DeepSeek 官方 API：

                        GET https://api.deepseek.com/user/balance

                        每次刷新时，App 用你填入的 API Key 去查余额，然后把结果存到你手机上。对比前后两次余额的差值，就能算出你花了多少钱。

                        全程不走任何第三方服务器。
                        """)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("关于")
                }

                Section {
                    HStack {
                        Text("版本")
                        Spacer()
                        Text("1.0.0").foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("设置")
            .onAppear {
                if apiKey.isEmpty, let saved = KeychainManager.load() {
                    apiKey = saved
                }
            }
        }
    }

    // MARK: - 操作

    private func saveKey() {
        let trimmed = apiKey.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        do {
            try KeychainManager.save(key: trimmed)
            testResult = .success(balance: "Key 已保存")
        } catch {
            testResult = .failure("保存失败: \(error.localizedDescription)")
        }
    }

    private func testConnection() {
        let trimmed = apiKey.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        isTesting = true
        testResult = nil

        Task {
            do {
                let resp = try await DeepSeekAPI.validateKey(trimmed)
                if let info = resp.balanceInfos.first {
                    testResult = .success(balance: info.formattedTotal)
                    // 顺便保存
                    try? KeychainManager.save(key: trimmed)
                } else {
                    testResult = .success(balance: "OK")
                }
            } catch {
                testResult = .failure(error.localizedDescription)
            }
            isTesting = false
        }
    }

    private func deleteKey() {
        try? KeychainManager.delete()
        apiKey = ""
        testResult = nil
    }
}
