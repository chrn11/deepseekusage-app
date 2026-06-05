import SwiftUI
import WebKit

/// 平台登录页面
///
/// 内嵌 WebView 打开 platform.deepseek.com，让用户登录。
/// 登录成功后自动截取 Cookie 存入钥匙串。
struct LoginView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var cookie: String?
    @State private var error: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let cookie = cookie {
                    // 获取到 Cookie，显示成功
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.green)
                        Text("登录成功")
                            .font(.title2.bold())
                        Text("Cookie 已安全存储到钥匙串")
                            .foregroundColor(.secondary)
                        Button("返回") {
                            dismiss()
                        }
                        .buttonStyle(.borderedProminent)
                        .padding(.top, 8)
                    }
                    .padding(40)
                } else if let error = error {
                    VStack(spacing: 16) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.red)
                        Text("登录失败")
                            .font(.title2.bold())
                        Text(error)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        Button("重试") {
                            self.error = nil
                            self.cookie = nil
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding(40)
                } else {
                    // WebView 登录
                    CookieWebView { result in
                        do {
                            let c = try result.get()
                            try KeychainManager.saveCookie(c)
                            self.cookie = c
                        } catch {
                            self.error = error.localizedDescription
                        }
                    }
                }
            }
            .navigationTitle("登录 DeepSeek")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

/// WKWebView 包装 — 打开 platform.deepseek.com，登录后截取 Cookie
struct CookieWebView: UIViewRepresentable {
    let onCookie: (Result<String, Error>) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onCookie: onCookie)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent() // 无痕模式

        let prefs = WKWebpagePreferences()
        prefs.allowsContentJavaScript = true
        config.defaultWebpagePreferences = prefs

        let wv = WKWebView(frame: .zero, configuration: config)
        wv.navigationDelegate = context.coordinator
        wv.allowsBackForwardNavigationGestures = true

        // 导航到登录页
        let url = URL(string: "https://platform.deepseek.com/")!
        wv.load(URLRequest(url: url))

        return wv
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    class Coordinator: NSObject, WKNavigationDelegate {
        let onCookie: (Result<String, Error>) -> Void
        private var hasReported = false

        init(onCookie: @escaping (Result<String, Error>) -> Void) {
            self.onCookie = onCookie
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            guard !hasReported else { return }

            webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { cookies in
                // 找到 platform.deepseek.com 的 Cookie
                let platformCookies = cookies.filter { c in
                    c.domain.contains("deepseek.com") || c.domain.contains("platform.deepseek.com")
                }

                // 构建完整 Cookie 字符串
                let cookieString = platformCookies.map { "\($0.name)=\($0.value)" }.joined(separator: "; ")

                // 只要有包含 session/auth 的 Cookie 就算登录成功
                let hasAuthCookie = platformCookies.contains { c in
                    c.name.lowercased().contains("session") ||
                    c.name.lowercased().contains("token") ||
                    c.name.lowercased().contains("auth") ||
                    c.name.lowercased().contains("jwt")
                }

                if hasAuthCookie && !cookieString.isEmpty {
                    self.hasReported = true
                    self.onCookie(.success(cookieString))
                }
                // 否则等用户继续操作（可能还在登录页没输完）
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            if !hasReported {
                hasReported = true
                onCookie(.failure(error))
            }
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            if !hasReported {
                hasReported = true
                onCookie(.failure(error))
            }
        }
    }
}
