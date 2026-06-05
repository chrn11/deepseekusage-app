import SwiftUI
import WebKit

/// 平台登录 — 截取 Cookie 存钥匙串
struct LoginView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var phase: LoginPhase = .loading

    enum LoginPhase {
        case loading
        case success
        case failure(String)
    }

    var body: some View {
        ZStack {
            Color(hex: "060D17").ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Text("登录平台").font(.system(size: 20, weight: .bold)).foregroundColor(Color(hex: "E8EDF5"))
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill").font(.system(size: 24)).foregroundColor(Color(hex: "5A6A82"))
                    }
                }
                .padding(.horizontal, 16).padding(.vertical, 12).background(Color(hex: "0A1228"))

                switch phase {
                case .loading:
                    CookieWebView { result in
                        switch result {
                        case .success(let cookie):
                            do {
                                try KeychainManager.saveCookie(cookie)
                                withAnimation { phase = .success }
                            } catch {
                                withAnimation { phase = .failure(error.localizedDescription) }
                            }
                        case .failure(let e):
                            withAnimation { phase = .failure(e.localizedDescription) }
                        }
                    }

                case .success:
                    VStack(spacing: 24) {
                        Spacer()
                        ZStack {
                            Circle().fill(Color(hex: "00E6A0").opacity(0.15)).frame(width: 100, height: 100)
                            Image(systemName: "checkmark").font(.system(size: 44, weight: .bold)).foregroundColor(Color(hex: "00E6A0"))
                        }
                        Text("已连接").font(.system(size: 26, weight: .bold)).foregroundColor(Color(hex: "E8EDF5"))
                        Text("Cookie 已存储，返回仪表盘刷新即可").font(.system(size: 15)).foregroundColor(Color(hex: "7B89A0"))
                        Button { dismiss() } label: {
                            Text("返回").font(.system(size: 17, weight: .semibold))
                                .foregroundColor(Color(hex: "060D17")).frame(width: 160).padding(.vertical, 14)
                                .background(Color(hex: "00C6FF")).clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        Spacer()
                    }
                    .padding(40)

                case .failure(let msg):
                    VStack(spacing: 24) {
                        Spacer()
                        ZStack {
                            Circle().fill(Color(hex: "FF6B6B").opacity(0.15)).frame(width: 100, height: 100)
                            Image(systemName: "xmark").font(.system(size: 44, weight: .bold)).foregroundColor(Color(hex: "FF6B6B"))
                        }
                        Text("失败").font(.system(size: 26, weight: .bold)).foregroundColor(Color(hex: "E8EDF5"))
                        Text(msg).font(.system(size: 14)).foregroundColor(Color(hex: "7B89A0")).multilineTextAlignment(.center)
                        Button { phase = .loading } label: {
                            Text("重试").font(.system(size: 17, weight: .semibold))
                                .foregroundColor(Color(hex: "00C6FF")).frame(width: 160).padding(.vertical, 14)
                                .background(Color(hex: "00C6FF").opacity(0.1)).clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        Spacer()
                    }
                    .padding(40)
                }
            }
        }
    }
}

// MARK: - Cookie WebView

struct CookieWebView: UIViewRepresentable {
    let onCookie: (Result<String, Error>) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        // 用 default() 常驻存储 — nonPersistent 会在 WebView 销毁时丢失 cookie
        config.websiteDataStore = .default()
        config.defaultWebpagePreferences.allowsContentJavaScript = true

        let wv = WKWebView(frame: .zero, configuration: config)
        wv.navigationDelegate = context.coordinator
        wv.allowsBackForwardNavigationGestures = true
        wv.isOpaque = false
        wv.backgroundColor = UIColor(red: 6/255, green: 13/255, blue: 23/255, alpha: 1)
        wv.scrollView.backgroundColor = wv.backgroundColor

        wv.load(URLRequest(url: URL(string: "https://platform.deepseek.com/")!))
        return wv
    }

    func updateUIView(_: WKWebView, context: Context) {}

    class Coordinator: NSObject, WKNavigationDelegate {
        let parent: CookieWebView
        private var done = false

        init(parent: CookieWebView) { self.parent = parent }

        /// 每次页面加载完都检查 Cookie（用户可能先看到登录页，登录后跳转到首页）
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            guard !done else { return }
            checkCookies(webView)
        }

        /// 等待 1 秒后再检查一次（某些登录后 Cookie 延迟写入）
        private func scheduleLateCheck(_ webView: WKWebView) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                guard let self = self, !self.done else { return }
                self.checkCookies(webView)
            }
        }

        private func checkCookies(_ webView: WKWebView) {
            webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { cookies in
                // 收集所有 deepseek.com 域名的 cookie，不挑名字
                let ds = cookies.filter { c in
                    c.domain.contains("deepseek.com")
                }

                guard !ds.isEmpty else {
                    // 还没登录，排个延迟再检
                    self.scheduleLateCheck(webView)
                    return
                }

                let str = ds.map { "\($0.name)=\($0.value)" }.joined(separator: "; ")

                // 只要数量 >= 3 个 Cookie 就认为已登录
                if ds.count >= 3 {
                    self.done = true
                    self.parent.onCookie(.success(str))
                } else {
                    self.scheduleLateCheck(webView)
                }
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            guard !done else { return }
            done = true
            parent.onCookie(.failure(error))
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            guard !done else { return }
            let ns = error as NSError
            // 用户取消或 SSL 证书不影响
            if ns.domain == NSURLErrorDomain && (ns.code == -999 || ns.code == -1200) { return }
            done = true
            parent.onCookie(.failure(error))
        }
    }
}
