import SwiftUI
import WebKit

// MARK: - 充值页面

/// 用 WKWebView 打开 DeepSeek 平台充值页面
/// 注入 localStorage（userToken）实现免登录
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
        // 使用 nonPersistent 避免数据残留，登录凭据通过 JS 注入
        config.websiteDataStore = WKWebsiteDataStore.nonPersistent()

        let wv = WKWebView(frame: .zero, configuration: config)
        wv.navigationDelegate = RechargeNavDelegate.shared
        wv.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Mobile/15E148 Safari/604.1"
        wv.isOpaque = false
        wv.backgroundColor = UIColor(Color(hex: "060D17"))

        // 先加载一个空页面，注入凭据后再导航到充值页
        if let blankURL = URL(string: "about:blank") {
            wv.load(URLRequest(url: blankURL))
        }

        webView = wv

        // 注入凭据后加载充值页
        injectCredentialsAndNavigate(webView: wv)
    }

    private func injectCredentialsAndNavigate(webView: WKWebView) {
        guard let token = KeychainManager.loadToken(), !token.isEmpty else {
            // 没有 token，直接加载登录页（不应该发生，充值按钮只在已登录时显示）
            if let url = URL(string: "https://platform.deepseek.com/sign_in") {
                webView.load(URLRequest(url: url))
            }
            return
        }

        // 第一步：先加载 deepseek 域名以设置 localStorage
        if let baseURL = URL(string: "https://platform.deepseek.com/usage") {
            var request = URLRequest(url: baseURL)
            webView.load(request)
        }

        // 第二步：通过 WKUserScript 在页面加载时注入 token
        // 转义 token 中的特殊字符
        let escaped = token
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")

        let script = WKUserScript(
            source: "localStorage.setItem('userToken', JSON.stringify({value: '\(escaped)', __version: '0'}))",
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        )
        webView.configuration.userContentController.addUserScript(script)

        // 同时注入 cookie（浏览器可能也需要）
        let cookies = createCookies(token: token)
        let group = DispatchGroup()
        for cookie in cookies {
            group.enter()
            webView.configuration.websiteDataStore.httpCookieStore.setCookie(cookie) { group.leave() }
        }

        // 如果还有之前保存的 cookie 字符串，也注入
        if let savedCookieStr = KeychainManager.loadCookie() {
            let pairs = savedCookieStr.split(separator: ";").map { $0.trimmingCharacters(in: .whitespaces) }
            for pair in pairs {
                let parts = pair.split(separator: "=", maxSplits: 1)
                guard parts.count == 2 else { continue }
                if let cookie = HTTPCookie(properties: [
                    .name: String(parts[0]),
                    .value: String(parts[1]),
                    .domain: ".deepseek.com",
                    .path: "/",
                    .secure: true,
                ]) {
                    group.enter()
                    webView.configuration.websiteDataStore.httpCookieStore.setCookie(cookie) { group.leave() }
                }
            }
        }

        // cookie 全部设置完成后重新加载充值页
        group.notify(queue: .main) {
            if let url = URL(string: "https://platform.deepseek.com/top_up") {
                webView.load(URLRequest(url: url))
            }
        }
    }

    private func createCookies(token: String) -> [HTTPCookie] {
        let baseURL = URL(string: "https://platform.deepseek.com")!
        var cookies: [HTTPCookie] = []

        // Bearer token 作为 cookie
        if let authCookie = HTTPCookie(properties: [
            .name: "authorization",
            .value: "Bearer \(token)",
            .domain: ".deepseek.com",
            .path: "/",
            .secure: true,
        ]) {
            cookies.append(authCookie)
        }

        return cookies
    }
}

// MARK: - WebView 包装

struct WebViewRepresentable: UIViewRepresentable {
    let webView: WKWebView

    func makeUIView(context: Context) -> WKWebView { webView }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

// MARK: - 充值导航代理

final class RechargeNavDelegate: NSObject, WKNavigationDelegate {
    static let shared = RechargeNavDelegate()

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if let url = navigationAction.request.url {
            let host = url.host ?? ""
            // 放行 DeepSeek 域名
            if host.hasSuffix("deepseek.com") {
                decisionHandler(.allow)
                return
            }
            // 支付宝支付跳转
            if host.hasSuffix("alipay.com") || host.hasSuffix("alipay.cn") || host.hasSuffix("alipayobjects.com") {
                if UIApplication.shared.canOpenURL(url) {
                    UIApplication.shared.open(url)
                }
                decisionHandler(.cancel)
                return
            }
            // 微信支付跳转
            if host.hasSuffix("wechat.com") || host.hasSuffix("weixin.qq.com") {
                if UIApplication.shared.canOpenURL(url) {
                    UIApplication.shared.open(url)
                }
                decisionHandler(.cancel)
                return
            }
        }
        decisionHandler(.allow)
    }
}