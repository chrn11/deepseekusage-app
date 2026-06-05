import SwiftUI
import WebKit

/// WebView 登录 — 深海暗色主题
struct LoginView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var cookie: String?
    @State private var error: String?

    var body: some View {
        ZStack {
            Color(hex: "060D17").ignoresSafeArea()

            VStack(spacing: 0) {
                // 顶栏
                HStack {
                    Text("登录 DeepSeek 平台")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(Color(hex: "E8EDF5"))
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(Color(hex: "5A6A82"))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(hex: "0A1228"))

                // 内容区
                if let _ = cookie {
                    successView
                } else if let error = error {
                    failureView(error)
                } else {
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
        }
    }

    private var successView: some View {
        VStack(spacing: 20) {
            Spacer()
            ZStack {
                Circle()
                    .fill(Color(hex: "00E6A0").opacity(0.1))
                    .frame(width: 80, height: 80)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 44))
                    .foregroundColor(Color(hex: "00E6A0"))
            }
            Text("登录成功")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(Color(hex: "E8EDF5"))
            Text("Cookie 已安全存储到钥匙串\n回到仪表盘刷新即可查看用量")
                .font(.system(size: 14))
                .foregroundColor(Color(hex: "5A6A82"))
                .multilineTextAlignment(.center)

            Button {
                dismiss()
            } label: {
                Text("返回仪表盘")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Color(hex: "060D17"))
                    .padding(.horizontal, 32)
                    .padding(.vertical, 12)
                    .background(Color(hex: "00C6FF"))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.top, 8)
            Spacer()
        }
        .padding(40)
    }

    private func failureView(_ error: String) -> some View {
        VStack(spacing: 20) {
            Spacer()
            ZStack {
                Circle()
                    .fill(Color(hex: "FF6B6B").opacity(0.1))
                    .frame(width: 80, height: 80)
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 44))
                    .foregroundColor(Color(hex: "FF6B6B"))
            }
            Text("登录失败")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(Color(hex: "E8EDF5"))
            Text(error)
                .font(.system(size: 14))
                .foregroundColor(Color(hex: "5A6A82"))
                .multilineTextAlignment(.center)

            Button {
                self.error = nil
                self.cookie = nil
            } label: {
                Text("重试")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Color(hex: "00C6FF"))
                    .padding(.horizontal, 32)
                    .padding(.vertical, 12)
                    .background(Color(hex: "00C6FF").opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.top, 8)
            Spacer()
        }
        .padding(40)
    }
}

/// WKWebView 包装
struct CookieWebView: UIViewRepresentable {
    let onCookie: (Result<String, Error>) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onCookie: onCookie) }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        let prefs = WKWebpagePreferences()
        prefs.allowsContentJavaScript = true
        config.defaultWebpagePreferences = prefs

        let wv = WKWebView(frame: .zero, configuration: config)
        wv.navigationDelegate = context.coordinator
        wv.allowsBackForwardNavigationGestures = true
        wv.isOpaque = false
        wv.backgroundColor = UIColor(red: 6/255, green: 13/255, blue: 23/255, alpha: 1)
        wv.scrollView.backgroundColor = UIColor(red: 6/255, green: 13/255, blue: 23/255, alpha: 1)

        wv.load(URLRequest(url: URL(string: "https://platform.deepseek.com/")!))

        return wv
    }

    func updateUIView(_: WKWebView, context: Context) {}

    class Coordinator: NSObject, WKNavigationDelegate {
        let onCookie: (Result<String, Error>) -> Void
        private var hasReported = false

        init(onCookie: @escaping (Result<String, Error>) -> Void) {
            self.onCookie = onCookie
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            guard !hasReported else { return }

            webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { cookies in
                let platformCookies = cookies.filter { c in
                    c.domain.contains("deepseek.com") || c.domain.contains("platform.deepseek.com")
                }
                let cookieString = platformCookies.map { "\($0.name)=\($0.value)" }.joined(separator: "; ")
                let hasAuth = platformCookies.contains { c in
                    c.name.lowercased().contains("session") ||
                    c.name.lowercased().contains("token") ||
                    c.name.lowercased().contains("auth") ||
                    c.name.lowercased().contains("jwt")
                }

                if hasAuth && !cookieString.isEmpty {
                    self.hasReported = true
                    self.onCookie(.success(cookieString))
                }
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            guard !hasReported else { return }
            hasReported = true
            onCookie(.failure(error))
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            guard !hasReported else { return }
            hasReported = true
            onCookie(.failure(error))
        }
    }
}
