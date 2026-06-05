import SwiftUI
import WebKit

// MARK: - 充值页面

/// 用 WKWebView 打开 DeepSeek 平台充值页面
/// 注入已登录的 cookie（从 KeychainManager 读取），实现免登录充值
/// 关闭页面时回调 onDismiss 通知仪表盘刷新余额
struct RechargeView: View {
    let onDismiss: () -> Void

    @State private var webView: WKWebView?

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "060D17").ignoresSafeArea()

                if let webView {
                    WebViewRepresentable(webView: webView)
                        .ignoresSafeArea(edges: .bottom)
                } else {
                    ProgressView()
                        .tint(Color(hex: "00C6FF"))
                        .scaleEffect(1.5)
                }
            }
            .navigationTitle("充值")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(Color(hex: "0A1228"), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("关闭") { onDismiss() }
                        .foregroundColor(Color(hex: "00C6FF"))
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        webView?.reload()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(Color(hex: "00C6FF"))
                    }
                }
            }
        }
        .onAppear { setupWebView() }
    }

    // MARK: - 初始化 WebView

    private func setupWebView() {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = WKWebsiteDataStore.nonPersistent()

        let wv = WKWebView(frame: .zero, configuration: config)
        wv.navigationDelegate = WebViewNavDelegate.shared
        wv.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Mobile/15E148 Safari/604.1"
        wv.isOpaque = false
        wv.backgroundColor = UIColor(Color(hex: "060D17"))

        // 注入 cookie
        injectCookies(into: wv)

        // 加载充值页面
        if let url = URL(string: "https://platform.deepseek.com/usage") {
            wv.load(URLRequest(url: url))
        }

        webView = wv
    }

    private func injectCookies(into wv: WKWebView) {
        // 1. 从 Keychain 读取 token
        guard let token = KeychainManager.loadToken(), !token.isEmpty else { return }

        // 2. 注入 Bearer token 作为 cookie
        let authCookie = HTTPCookie(properties: [
            .name: "authorization",
            .value: "Bearer \(token)",
            .domain: ".deepseek.com",
            .path: "/",
            .secure: true,
        ])!
        wv.configuration.websiteDataStore.httpCookieStore.setCookie(authCookie)

        // 3. 从 Keychain 读取已保存的 cookie 字符串并逐个注入
        if let cookieStr = KeychainManager.loadCookie() {
            let pairs = cookieStr.split(separator: ";").map { $0.trimmingCharacters(in: .whitespaces) }
            for pair in pairs {
                let parts = pair.split(separator: "=", maxSplits: 1)
                guard parts.count == 2 else { continue }
                let name = String(parts[0])
                let value = String(parts[1])
                if let cookie = HTTPCookie(properties: [
                    .name: name,
                    .value: value,
                    .domain: ".deepseek.com",
                    .path: "/",
                    .secure: true,
                ]) {
                    wv.configuration.websiteDataStore.httpCookieStore.setCookie(cookie)
                }
            }
        }
    }
}

// MARK: - WebView 包装

struct WebViewRepresentable: UIViewRepresentable {
    let webView: WKWebView

    func makeUIView(context: Context) -> WKWebView { webView }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

// MARK: - 导航代理

final class WebViewNavDelegate: NSObject, WKNavigationDelegate {
    static let shared = WebViewNavDelegate()

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        // 只允许 DeepSeek 平台域名，阻止外部跳转
        if let url = navigationAction.request.url {
            let host = url.host ?? ""
            if host.hasSuffix("deepseek.com") {
                decisionHandler(.allow)
                return
            }
            // 支付宝支付需要跳转到支付宝 App 或网页
            if host.hasSuffix("alipay.com") || host.hasSuffix("alipay.cn") {
                // 尝试打开支付宝 App
                if UIApplication.shared.canOpenURL(url) {
                    UIApplication.shared.open(url)
                }
                decisionHandler(.cancel)
                return
            }
        }
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        // 加载开始 — 可以显示 loading
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // 加载完成 — 通过 JS 注入 token 到 localStorage（DeepSeek 平台兼容）
        if let token = KeychainManager.loadToken() {
            // 转义 JS 注入中的特殊字符防止语法错误
            let escaped = token
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "'", with: "\\'")
                .replacingOccurrences(of: "\"", with: "\\\"")
                .replacingOccurrences(of: "\n", with: "\\n")
            webView.evaluateJavaScript("localStorage.setItem('token', '\(escaped)')") { _, _ in }
        }
    }
}