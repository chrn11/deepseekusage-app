import SwiftUI

/// 设置页面 — 深海暗色主题
struct SettingsView: View {
    @State private var apiKey = ""
    @State private var isKeyVisible = false
    @State private var isTesting = false
    @State private var testResult: TestResult?

    // 余额预警
    @AppStorage("balance_alert_threshold") private var alertThreshold: Double = 0
    @State private var thresholdText = ""

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
                    currencySection
                    alertSection
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
                if apiKey.isEmpty, let s = KeychainManager.loadAPIKey() { apiKey = s }
                if thresholdText.isEmpty && alertThreshold > 0 { thresholdText = String(format: "%.0f", alertThreshold) }
            }
            // LoginView 的 sheet 已移到 loginSection
        }
    }

    // MARK: 标题

    private var settingsHeader: some View {
        HStack {
            Text("设置").font(.system(size: 22, weight: .bold)).foregroundColor(Color(hex: "E8EDF5"))
            Spacer()
        }
        .padding(.top, 8).padding(.bottom, 4)
    }

    // MARK: API Key

    private var apiKeySection: some View {
        VStack(spacing: 0) {
            secHead("key.fill", "API Key", "用于查询账户余额，调用官方接口")
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    Group {
                        if isKeyVisible {
                            TextField("sk-...", text: $apiKey)
                        } else {
                            SecureField("sk-...", text: $apiKey)
                        }
                    }
                    .autocapitalization(.none).disableAutocorrection(true)
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundColor(Color(hex: "E8EDF5"))

                    Button { isKeyVisible.toggle() } label: {
                        Image(systemName: isKeyVisible ? "eye.slash.fill" : "eye.fill")
                            .font(.system(size: 15)).foregroundColor(Color(hex: "5A6A82"))
                    }
                }
                .padding(12).background(Color(hex: "0A1228")).clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.06), lineWidth: 1))

                HStack(spacing: 10) {
                    accentBtn("保存", "square.and.arrow.down.fill", saveKey)
                        .disabled(apiKey.trimmingCharacters(in: .whitespaces).isEmpty)
                    accentBtn("测试连接", "antenna.radiowaves.left.and.right", testConnection)
                        .disabled(isTesting || apiKey.trimmingCharacters(in: .whitespaces).isEmpty)
                        .overlay { if isTesting { ProgressView().tint(Color(hex: "00C6FF")) } }
                }
                Text("从 [platform.deepseek.com/api_keys](https://platform.deepseek.com/api_keys) 获取 · 仅存本机钥匙串")
                    .font(.system(size: 10)).foregroundColor(Color(hex: "4A5A72")).padding(.top, 2)
            }
            .padding(14)
        }
        .background(secBg)
    }

    // MARK: 登录

    @State private var showLoginSheet = false

    private var loginSection: some View {
        VStack(spacing: 0) {
            secHead("person.badge.key.fill", "用量详情", "登录平台后获取 Token 消耗和费用曲线")
            VStack(spacing: 10) {
                if KeychainManager.hasToken {
                    HStack {
                        Circle().fill(Color(hex: "00E6A0")).frame(width: 8, height: 8)
                        Text("已登录").font(.system(size: 14, weight: .medium)).foregroundColor(Color(hex: "00E6A0"))
                        Spacer()
                        Button("重新登录") { showLoginSheet = true }.font(.system(size: 13)).foregroundColor(Color(hex: "00C6FF"))
                    }
                    .padding(12).background(Color(hex: "0A1228")).clipShape(RoundedRectangle(cornerRadius: 10))
                    Button(role: .destructive) { KeychainManager.logoutPlatform() } label: {
                        Label("退出登录", systemImage: "rectangle.portrait.and.arrow.right").font(.system(size: 13))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 4)
                } else {
                    Button { showLoginSheet = true } label: {
                        HStack {
                            Image(systemName: "person.badge.key.fill").font(.system(size: 15))
                            Text("登录 DeepSeek 平台").font(.system(size: 14, weight: .medium))
                            Spacer()
                            Image(systemName: "arrow.up.forward.app.fill").font(.system(size: 12))
                        }
                        .foregroundColor(Color(hex: "7C5CFC")).padding(14)
                        .background(Color(hex: "7C5CFC").opacity(0.08)).clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(hex: "7C5CFC").opacity(0.2), lineWidth: 1))
                    }
                }
                Text("在平台网页内登录 · 支持验证码")
                    .font(.system(size: 10)).foregroundColor(Color(hex: "4A5A72"))
            }
            .padding(14)
        }
        .background(secBg)
        .sheet(isPresented: $showLoginSheet) {
            LoginView(onLoginSuccess: {
                showLoginSheet = false
            })
        }
    }

    // MARK: 货币显示

    @AppStorage("currency_display") private var currencyDisplay: String = CurrencyDisplay.cny.rawValue

    private var currencySection: some View {
        VStack(spacing: 0) {
            secHead("dollarsign.circle.fill", "余额显示", nil)
            VStack(spacing: 10) {
                ForEach(CurrencyDisplay.allCases, id: \.rawValue) { mode in
                    Button {
                        currencyDisplay = mode.rawValue
                    } label: {
                        HStack {
                            Text(mode.rawValue).font(.system(size: 15, weight: .medium))
                                .foregroundColor(currencyDisplay == mode.rawValue ? .white : Color(hex: "7B89A0"))
                            Spacer()
                            if currencyDisplay == mode.rawValue {
                                Image(systemName: "checkmark.circle.fill").font(.system(size: 18)).foregroundColor(Color(hex: "00C6FF"))
                            }
                        }
                        .padding(12).background(Color(hex: "0A1228")).clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
                Text("汇率约 $1 = ¥\(String(format: "%.2f", CurrencyDisplay.usdRate)) · 仅影响本 App 显示")
                    .font(.system(size: 11)).foregroundColor(Color(hex: "4A5A72"))
            }
            .padding(14)
        }
        .background(secBg)
    }

    // MARK: 余额预警

    private var alertSection: some View {
        VStack(spacing: 0) {
            secHead("bell.badge.fill", "余额预警", "余额低于阈值时推送通知提醒")
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    Text("¥")
                        .font(.system(size: 16, weight: .bold)).foregroundColor(Color(hex: "00C6FF"))
                    TextField("预警阈值", text: $thresholdText)
                        .keyboardType(.decimalPad)
                        .font(.system(size: 15, weight: .medium, design: .monospaced))
                        .foregroundColor(Color(hex: "E8EDF5"))
                        .onChange(of: thresholdText) { v in
                            alertThreshold = Double(v) ?? 0
                        }
                    if alertThreshold > 0 {
                        Button("清除") { thresholdText = ""; alertThreshold = 0 }
                            .font(.system(size: 12)).foregroundColor(Color(hex: "FF6B6B"))
                    }
                }
                .padding(12).background(Color(hex: "0A1228")).clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(
                    alertThreshold > 0 ? Color(hex: "FF6B6B").opacity(0.3) : Color.white.opacity(0.06), lineWidth: 1))

                if alertThreshold > 0 {
                    HStack {
                        Image(systemName: "info.circle.fill").font(.system(size: 11)).foregroundColor(Color(hex: "FF6B6B"))
                        Text("余额低于 ¥\(String(format: "%.0f", alertThreshold)) 时会收到通知")
                            .font(.system(size: 11)).foregroundColor(Color(hex: "FF6B6B").opacity(0.8))
                    }
                    .padding(.horizontal, 4)
                }
            }
            .padding(14)
        }
        .background(secBg)
    }

    // MARK: 测试结果

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
        .font(.system(size: 13)).padding(14).background(secBg)
    }

    // MARK: 关于

    private var aboutSection: some View {
        VStack(spacing: 0) {
            secHead("info.circle.fill", "关于", nil)
            VStack(spacing: 8) {
                aboutRow("版本", "1.0.0")
                Divider().background(Color.white.opacity(0.04))
                aboutRow("构建", "XcodeGen + GitHub Actions")
                Divider().background(Color.white.opacity(0.04))
                VStack(alignment: .leading, spacing: 4) {
                    Text("数据来源").font(.system(size: 13)).foregroundColor(Color(hex: "7B89A0"))
                    Text("余额：api.deepseek.com/user/balance\n用量：platform.deepseek.com 内部接口\n接口地址支持诊断自动更新")
                        .font(.system(size: 11)).foregroundColor(Color(hex: "4A5A72"))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(14)
        }
        .background(secBg)
    }

    private func aboutRow(_ k: String, _ v: String) -> some View {
        HStack {
            Text(k).font(.system(size: 13)).foregroundColor(Color(hex: "7B89A0"))
            Spacer()
            Text(v).font(.system(size: 13, design: .monospaced)).foregroundColor(Color(hex: "5A6A82"))
        }
    }

    // MARK: 共享

    private func secHead(_ icon: String, _ title: String, _ sub: String?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 12)).foregroundColor(Color(hex: "00C6FF"))
                Text(title).font(.system(size: 15, weight: .semibold)).foregroundColor(Color(hex: "E8EDF5"))
            }
            if let s = sub {
                Text(s).font(.system(size: 11)).foregroundColor(Color(hex: "5A6A82"))
            }
        }
        .padding([.horizontal, .top], 14).padding(.bottom, 8)
    }

    private var secBg: some View {
        RoundedRectangle(cornerRadius: 18)
            .fill(Color(hex: "0A1228").opacity(0.6))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(.white.opacity(0.06), lineWidth: 1))
    }

    private func accentBtn(_ title: String, _ icon: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 11))
                Text(title).font(.system(size: 12, weight: .medium))
            }
            .foregroundColor(Color(hex: "00C6FF")).frame(maxWidth: .infinity).padding(.vertical, 9)
            .background(Color(hex: "00C6FF").opacity(0.08)).clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    // MARK: 逻辑

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
                testResult = .success(balance: r.balanceInfos.first?.formattedTotal ?? "OK")
                try? KeychainManager.saveAPIKey(t)
            } catch {
                testResult = .failure(error.localizedDescription)
            }
            isTesting = false
        }
    }
}
