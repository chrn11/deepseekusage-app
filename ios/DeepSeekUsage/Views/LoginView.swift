import SwiftUI
import WebKit

// MARK: - WebView 登录页面

/// 用 WKWebView 打开 DeepSeek 平台真实登录页面
/// 用户在网页上完成登录（支持验证码、2FA 等）
/// 登录成功后自动提取 localStorage.userToken 存入 Keychain
struct LoginView: View {
    let onLoginSuccess: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var webView: WKWebView?
    @State private var isLoading = true
    @State private var loginState: WebViewLoginStep = .stepLoading

    enum WebViewLoginStep: Equatable {
        case stepLoading    // WebView 加载中
        case stepReady      // 登录页已加载，等待用户输入
        case stepSuccess    // 登录成功，正在提取凭据
        case stepError(String) // 出错了
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "060D17").ignoresSafeArea()

                switch loginState {
                case .stepLoading:
                    ProgressView()
                        .tint(Color(hex: "00C6FF"))
                        .scaleEffect(1.5)

                case .stepReady, .stepSuccess:
                    if let webView {
                        WebViewRepresentable(webView: webView)
                            .ignoresSafeArea(edges: .bottom)
                    }

                case .stepError(let msg):
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 40))
                            .foregroundColor(Color(hex: "FF6B6B"))
                        Text(msg)
                            .font(.system(size: 14))
                            .foregroundColor(Color(hex: "7B89A0"))
                            .multilineTextAlignment(.center)
                        Button("重试") {
        loginState = .stepLoading
                            setupWebView()
                        }
                        .foregroundColor(Color(hex: "00C6FF"))
                    }
                    .padding(40)
                }

                // 登录成功遮罩
                if case .stepSuccess = loginState {
                    Color(hex: "060D17").opacity(0.85).ignoresSafeArea()
                    VStack(spacing: 24) {
                        ZStack {
                            Circle().fill(Color(hex: "00E6A0").opacity(0.15)).frame(width: 100, height: 100)
                            Image(systemName: "checkmark")
                                .font(.system(size: 44, weight: .bold))
                                .foregroundColor(Color(hex: "00E6A0"))
                        }
                        Text("登录成功")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(.white)
                        ProgressView()
                            .tint(Color(hex: "00C6FF"))
                            .scaleEffect(1.2)
                    }
                }
            }
            .navigationTitle("登录 DeepSeek 平台")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(Color(hex: "0A1228"), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                        .foregroundColor(Color(hex: "00C6FF"))
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if loginState == .stepReady, let webView {
                        Button {
                            webView.reload()
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .foregroundColor(Color(hex: "00C6FF"))
                        }
                    }
                }
            }
        }
        .onAppear {
            if webView == nil { setupWebView() }
        }
    }

    // MARK: - 初始化 WebView

    private func setupWebView() {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = WKWebsiteDataStore.nonPersistent()

        let wv = WKWebView(frame: .zero, configuration: config)
        wv.navigationDelegate = loginDelegate
        wv.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Mobile/15E148 Safari/604.1"
        wv.isOpaque = false
        wv.backgroundColor = UIColor(Color(hex: "060D17"))

        if let url = URL(string: "https://platform.deepseek.com/sign_in") {
            wv.load(URLRequest(url: url))
        }

        webView = wv
        loginState = .stepLoading
    }

    // MARK: - 登录代理

    private var loginDelegate: LoginWebViewDelegate {
        LoginWebViewDelegate(
            onRedirect: { url in
                // 登录成功会跳转到 /usage 或 / 等非登录页
                let path = url.path.lowercased()
                if !path.contains("/sign_in") && !path.isEmpty {
                    handleLoginSuccess(webView: webView)
                }
            },
            onLoad: { url in
                let path = url.path.lowercased()
                if path.contains("/sign_in") {
                    loginState = .stepReady
                }
            }
        )
    }

    // MARK: - 登录成功处理

    private func handleLoginSuccess(webView: WKWebView?) {
        loginState = .stepSuccess

        webView?.evaluateJavaScript("JSON.parse(localStorage.getItem('userToken') || '{}').value || ''") { result, error in
            let token: String
            if let t = result as? String, !t.isEmpty {
                token = t
            } else {
                // localStorage.userToken 可能是直接字符串，不是 JSON
                webView?.evaluateJavaScript("localStorage.getItem('userToken') || ''") { result2, _ in
                    let raw = (result2 as? String) ?? ""
                    // 尝试从 JSON 提取 .value，否则用原始值
                    if let data = raw.data(using: .utf8),
                       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let value = json["value"] as? String, !value.isEmpty {
                        saveTokenAndFinish(value)
                    } else if !raw.isEmpty && raw != "null" {
                        // 去除 JSON 包装
                        saveTokenAndFinish(raw)
                    }
                }
                return
            }
            saveTokenAndFinish(token)
        }
    }

    private func saveTokenAndFinish(_ token: String) {
        do {
            try KeychainManager.saveToken(token)

            // 同时从 WebView cookie store 提取 cookie 备份
            if let wv = webView {
                wv.configuration.websiteDataStore.httpCookieStore.getAllCookies { cookies in
                    let relevant = cookies.filter { $0.domain.hasSuffix("deepseek.com") }
                    let cookieStr = relevant.map { "\($0.name)=\($0.value)" }.joined(separator: "; ")
                    if !cookieStr.isEmpty {
                        try? KeychainManager.saveCookie(cookieStr)
                    }
                }
            }

            // 通知刷新
            DispatchQueue.main.async {
                onLoginSuccess?()
                dismiss()
            }
        } catch {
            loginState = .stepError("保存登录信息失败：\(error.localizedDescription)")
        }
    }
}

// MARK: - WebView 导航代理

final class LoginWebViewDelegate: NSObject, WKNavigationDelegate {
    let onRedirect: (URL) -> Void
    let onLoad: (URL) -> Void

    init(onRedirect: @escaping (URL) -> Void, onLoad: @escaping (URL) -> Void) {
        self.onRedirect = onRedirect
        self.onLoad = onLoad
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if let url = navigationAction.request.url {
            let host = url.host ?? ""
            // 只允许 DeepSeek 相关域名
            if host.hasSuffix("deepseek.com") || host.hasSuffix("deepseek.com") {
                decisionHandler(.allow)
                return
            }
        }
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, didServerRedirectFor navigation: WKNavigation) {
        if let url = webView.url {
            onRedirect(url)
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        if let url = webView.url {
            onLoad(url)
            // 检查是否已经登录（页面加载完就尝试提取 token）
            checkIfAlreadyLoggedIn(webView: webView)
        }
    }

    private func checkIfAlreadyLoggedIn(webView: WKWebView) {
        webView.evaluateJavaScript("JSON.parse(localStorage.getItem('userToken') || '{}').value || ''") { result, _ in
            if let token = result as? String, !token.isEmpty {
                // 已经在 localStorage 里有 token 了，说明已登录
                DispatchQueue.main.async {
                    self.onRedirect(webView.url ?? URL(string: "https://platform.deepseek.com/usage")!)
                }
            }
        }
    }
}