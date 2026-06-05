import SwiftUI

/// 设置页面 — 深海暗色主题
///
/// - API Key 管理
/// - 平台登录状态
/// - 接口诊断（预留）
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
            ScrollView {
                VStack(spacing: 14) {
                    settingsHeader
                    apiKeySection
                    loginSection
                    advancedSection
                    if let r = testResult { resultSection(r) }
                    aboutSection
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 100)
            }
            .scrollIndicators(.hidden)
            .background(Color(hex: "060D17"))
            .toolbarBackground(.hidden, for: .navigationBar)
            .onAppear {
                if apiKey.isEmpty, let saved = KeychainManager.loadAPIKey() {
                    apiKey = saved
                }
            }
            .sheet(isPresented: $showLogin) { LoginView() }
        }
    }

    // MARK: - 标题

    private var settingsHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("设置")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(Color(hex: "E8EDF5"))
            }
            Spacer()
        }
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    // MARK: - API Key

    private var apiKeySection: some View {
        VStack(spacing: 0) {
            sectionHeader(icon: "key.fill", title: "API Key",
                          subtitle: "用于查询账户余额，调用官方接口")

            VStack(spacing: 10) {
                // 输入框
                HStack(spacing: 10) {
                    if isKeyVisible {
                        TextField("sk-...", text: $apiKey)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .font(.system(size: 14, design: .monospaced))
                            .foregroundColor(Color(hex: "E8EDF5"))
                    } else {
                        SecureField("sk-...", text: $apiKey)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .font(.system(size: 14, design: .monospaced))
                            .foregroundColor(Color(hex: "E8EDF5"))
                    }

                    Button { isKeyVisible.toggle() } label: {
                        Image(systemName: isKeyVisible ? "eye.slash.fill" : "eye.fill")
                            .font(.system(size: 15))
                            .foregroundColor(Color(hex: "5A6A82"))
                    }
                }
                .padding(12)
                .background(Color(hex: "0A1228"))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )

                // 按钮排
                HStack(spacing: 10) {
                    accentButton(title: "保存", icon: "square.and.arrow.down.fill") {
                        saveKey()
                    }
                    .disabled(apiKey.trimmingCharacters(in: .whitespaces).isEmpty)

                    accentButton(title: "测试连接", icon: "antenna.radiowaves.left.and.right") {
                        testConnection()
                    }
                    .disabled(isTesting || apiKey.trimmingCharacters(in: .whitespaces).isEmpty)
                    .overlay {
                        if isTesting { ProgressView().tint(Color(hex: "00C6FF")) }
                    }
                }

                Text("从 [platform.deepseek.com/api_keys](https://platform.deepseek.com/api_keys) 获取 · 仅存储于本机钥匙串 · 不上传任何第三方")
                    .font(.system(size: 10))
                    .foregroundColor(Color(hex: "4A5A72"))
                    .padding(.top, 2)
            }
            .padding(14)
        }
        .background(sectionBackground)
    }

    // MARK: - 平台登录

    private var loginSection: some View {
        VStack(spacing: 0) {
            sectionHeader(icon: "person.badge.key.fill", title: "用量详情",
                          subtitle: "登录平台后获取每日/每周/每月 Token 消耗")

            VStack(spacing: 10) {
                if KeychainManager.hasCookie {
                    HStack {
                        Circle()
                            .fill(Color(hex: "00E6A0"))
                            .frame(width: 8, height: 8)
                        Text("已登录")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color(hex: "00E6A0"))
                        Spacer()
                        Button("重新登录") { showLogin = true }
                            .font(.system(size: 13))
                            .foregroundColor(Color(hex: "00C6FF"))
                    }
                    .padding(12)
                    .background(Color(hex: "0A1228"))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                    Button(role: .destructive) {
                        try? KeychainManager.deleteCookie()
                    } label: {
                        Label("退出登录", systemImage: "rectangle.portrait.and.arrow.right")
                            .font(.system(size: 13))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
                } else {
                    Button { showLogin = true } label: {
                        HStack {
                            Image(systemName: "person.badge.key.fill")
                                .font(.system(size: 15))
                            Text("登录 DeepSeek 平台")
                                .font(.system(size: 14, weight: .medium))
                            Spacer()
                            Image(systemName: "arrow.up.forward.app.fill")
                                .font(.system(size: 12))
                        }
                        .foregroundColor(Color(hex: "7C5CFC"))
                        .padding(14)
                        .background(Color(hex: "7C5CFC").opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color(hex: "7C5CFC").opacity(0.2), lineWidth: 1)
                        )
                    }
                }

                Text("Cookie 仅存储在手机钥匙串 · 登录态过期后可重新登录")
                    .font(.system(size: 10))
                    .foregroundColor(Color(hex: "4A5A72"))
            }
            .padding(14)
        }
        .background(sectionBackground)
    }

    // MARK: - 高级

    private var advancedSection: some View {
        VStack(spacing: 0) {
            sectionHeader(icon: "wrench.fill", title: "高级",
                          subtitle: "接口诊断 — 当平台改版导致数据异常时使用")

            Button {
                // TODO
            } label: {
                HStack {
                    Image(systemName: "stethoscope")
                        .font(.system(size: 14))
                    Text("诊断接口").font(.system(size: 14))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11))
                }
                .foregroundColor(.white.opacity(0.3))
                .padding(14)
                .background(Color(hex: "0A1228"))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .disabled(!KeychainManager.hasCookie)
            .padding(14)
        }
        .background(sectionBackground)
    }

    // MARK: - 测试结果

    private func resultSection(_ r: TestResult) -> some View {
        HStack(spacing: 8) {
            switch r {
            case .success(let b):
                Image(systemName: "checkmark.circle.fill").foregroundColor(Color(hex: "00E6A0"))
                Text("连接成功 — 余额 \(b)").foregroundColor(Color(hex: "00E6A0"))
            case .failure(let m):
                Image(systemName: "xmark.circle.fill").foregroundColor(Color(hex: "FF6B6B"))
                Text(m).foregroundColor(Color(hex: "FF6B6B"))
            }
        }
        .font(.system(size: 13))
        .padding(14)
        .background(sectionBackground)
    }

    // MARK: - 关于

    private var aboutSection: some View {
        VStack(spacing: 0) {
            sectionHeader(icon: "info.circle.fill", title: "关于", subtitle: nil)

            VStack(spacing: 8) {
                aboutRow("版本", "1.0.0")
                Divider().background(Color.white.opacity(0.04))
                aboutRow("构建", "XcodeGen + GitHub Actions")
                Divider().background(Color.white.opacity(0.04))
                VStack(alignment: .leading, spacing: 4) {
                    Text("数据来源")
                        .font(.system(size: 13)).foregroundColor(Color(hex: "7B89A0"))
                    Text("余额：api.deepseek.com/user/balance\n用量：platform.deepseek.com 内部接口")
                        .font(.system(size: 11)).foregroundColor(Color(hex: "4A5A72"))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(14)
        }
        .background(sectionBackground)
    }

    private func aboutRow(_ key: String, _ val: String) -> some View {
        HStack {
            Text(key).font(.system(size: 13)).foregroundColor(Color(hex: "7B89A0"))
            Spacer()
            Text(val).font(.system(size: 13, design: .monospaced)).foregroundColor(Color(hex: "5A6A82"))
        }
    }

    // MARK: - 共享组件

    private func sectionHeader(icon: String, title: String, subtitle: String?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "00C6FF"))
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Color(hex: "E8EDF5"))
            }
            if let s = subtitle {
                Text(s)
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "5A6A82"))
            }
        }
        .padding([.horizontal, .top], 14)
        .padding(.bottom, 8)
    }

    private var sectionBackground: some View {
        RoundedRectangle(cornerRadius: 18)
            .fill(Color(hex: "0A1228").opacity(0.6))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(.white.opacity(0.06), lineWidth: 1)
            )
    }

    private func accentButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 11))
                Text(title).font(.system(size: 12, weight: .medium))
            }
            .foregroundColor(Color(hex: "00C6FF"))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background(Color(hex: "00C6FF").opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    // MARK: - 逻辑

    private func saveKey() {
        let t = apiKey.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return }
        do { try KeychainManager.saveAPIKey(t); testResult = .success(balance: "已保存") }
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
