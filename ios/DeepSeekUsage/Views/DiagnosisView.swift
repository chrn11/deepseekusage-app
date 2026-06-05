import SwiftUI
import WebKit

/// 接口诊断 — 打开平台用量页面，抓取 XHR 请求路径
///
/// 流程：用户在 WebView 中导航到用量统计页 → App 拦截 XHR 请求 →
/// 自动匹配已知的接口模式并更新 PlatformAPI 路径
struct DiagnosisView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var found: [String] = []
    @State private var hasScanned = false

    let onDone: (String) -> Void

    var body: some View {
        ZStack {
            Color(hex: "060D17").ignoresSafeArea()

            VStack(spacing: 0) {
                // 顶栏
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("接口诊断").font(.system(size: 17, weight: .semibold)).foregroundColor(Color(hex: "E8EDF5"))
                        Text("请在平台页面中点击「用量统计」")
                            .font(.system(size: 12)).foregroundColor(Color(hex: "5A6A82"))
                    }
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill").font(.system(size: 22)).foregroundColor(Color(hex: "5A6A82"))
                    }
                }
                .padding(.horizontal, 16).padding(.vertical, 12).background(Color(hex: "0A1228"))

                // 找到的接口列表
                if !found.isEmpty {
                    VStack(spacing: 6) {
                        ForEach(found, id: \.self) { path in
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 12)).foregroundColor(Color(hex: "00E6A0"))
                                Text(path)
                                    .font(.system(size: 12, design: .monospaced)).foregroundColor(Color(hex: "00E6A0"))
                                Spacer()
                            }
                            .padding(8).background(Color(hex: "00E6A0").opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        }

                        Button {
                            applyFound()
                            dismiss()
                        } label: {
                            Text("应用并返回").font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Color(hex: "060D17")).frame(maxWidth: .infinity).padding(.vertical, 10)
                                .background(Color(hex: "00C6FF")).clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .padding(.top, 8)
                    }
                    .padding(14)
                }

                // WebView
                DiagnosisWebView(onXHR: { path, body in
                    analyzeEndpoint(path: path, body: body)
                })
            }
        }
    }

    /// 分析拦截到的请求，判断是否匹配已知接口
    private func analyzeEndpoint(path: String, body: String) {
        let lower = path.lowercased()

        if lower.contains("get_user_summary") || lower.contains("user_summary") {
            updatePath(key: "papi_summary", path: path, label: "汇总")
        }
        if lower.contains("usage/amount") || (lower.contains("usage") && lower.contains("amount")) {
            updatePath(key: "papi_amount", path: path, label: "用量")
        }
        if lower.contains("usage/cost") || (lower.contains("usage") && lower.contains("cost")) {
            updatePath(key: "papi_cost", path: path, label: "费用")
        }
    }

    private func updatePath(key: String, path: String, label: String) {
        let clean = path.hasPrefix("/") ? path : "/\(path)"
        UserDefaults.standard.set(clean, forKey: key)
        if !found.contains("\(label): \(clean)") {
            found.append("\(label): \(clean)")
        }
    }

    private func applyFound() {
        let msg = found.isEmpty ? "未发现新接口" : "已更新 \(found.count) 个接口"
        onDone(msg)
    }
}

/// 拦截 XHR 请求的 WebView
struct DiagnosisWebView: UIViewRepresentable {
    let onXHR: (String, String) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onXHR: onXHR) }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()

        // 注入 JS 拦截 fetch/XHR
        let script = """
        (function(){
            const origFetch = window.fetch;
            window.fetch = async function(...args) {
                const resp = await origFetch.apply(this, args);
                const clone = resp.clone();
                try {
                    const txt = await clone.text();
                    window.webkit.messageHandlers.xhr.postMessage(JSON.stringify({url: args[0], body: txt.substring(0,500)}));
                } catch(e) {}
                return resp;
            };
        })();
        """
        let userScript = WKUserScript(source: script, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        config.userContentController.addUserScript(userScript)
        config.userContentController.add(context.coordinator, name: "xhr")
        config.websiteDataStore = .nonPersistent()

        let prefs = WKWebpagePreferences()
        prefs.allowsContentJavaScript = true
        config.defaultWebpagePreferences = prefs

        let wv = WKWebView(frame: .zero, configuration: config)
        wv.allowsBackForwardNavigationGestures = true
        wv.isOpaque = false
        wv.backgroundColor = UIColor(red: 6/255, green: 13/255, blue: 23/255, alpha: 1)
        wv.scrollView.backgroundColor = UIColor(red: 6/255, green: 13/255, blue: 23/255, alpha: 1)

        // 加载平台主页
        wv.load(URLRequest(url: URL(string: "https://platform.deepseek.com/")!))
        return wv
    }

    func updateUIView(_: WKWebView, context: Context) {}

    class Coordinator: NSObject, WKScriptMessageHandler {
        let onXHR: (String, String) -> Void

        init(onXHR: @escaping (String, String) -> Void) {
            self.onXHR = onXHR
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard let msg = message.body as? String,
                  let data = msg.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: String],
                  let url = json["url"],
                  let body = json["body"] else { return }
            onXHR(url, body)
        }
    }
}
