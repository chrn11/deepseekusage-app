import SwiftUI

/// 登录 DeepSeek 平台
///
/// 直接 POST /auth-api/v0/users/login，拿 token + cookie 存钥匙串
struct LoginView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var password = ""
    @State private var isLoggingIn = false
    @State private var result: LoginResult?
    @State private var error: String?

    var body: some View {
        ZStack {
            Color(hex: "060D17").ignoresSafeArea()
            VStack(spacing: 0) {
                // 顶栏
                HStack {
                    Text("登录").font(.system(size: 22, weight: .bold)).foregroundColor(.white)
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill").font(.system(size: 24)).foregroundColor(Color(hex: "5A6A82"))
                    }
                }
                .padding(16).background(Color(hex: "0A1228"))

                if let r = result {
                    successView(r)
                } else {
                    VStack(spacing: 20) {
                        Spacer().frame(height: 40)

                        VStack(alignment: .leading, spacing: 6) {
                            Text("邮箱").font(.system(size: 13, weight: .medium)).foregroundColor(Color(hex: "7B89A0"))
                            TextField("", text: $email)
                                .textContentType(.emailAddress).keyboardType(.emailAddress)
                                .autocapitalization(.none).disableAutocorrection(true)
                                .font(.system(size: 16)).foregroundColor(.white)
                                .padding(14).background(Color(hex: "0A1228")).clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.08), lineWidth: 1))
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("密码").font(.system(size: 13, weight: .medium)).foregroundColor(Color(hex: "7B89A0"))
                            SecureField("", text: $password)
                                .textContentType(.password)
                                .font(.system(size: 16)).foregroundColor(.white)
                                .padding(14).background(Color(hex: "0A1228")).clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.08), lineWidth: 1))
                        }

                        if let e = error {
                            Text(e).font(.system(size: 13)).foregroundColor(Color(hex: "FF6B6B"))
                                .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(hex: "FF6B6B").opacity(0.08)).clipShape(RoundedRectangle(cornerRadius: 10))
                        }

                        Button {
                            login()
                        } label: {
                            HStack {
                                if isLoggingIn { ProgressView().tint(Color(hex: "060D17")) }
                                else { Text("登录").font(.system(size: 17, weight: .semibold)) }
                            }
                            .frame(maxWidth: .infinity).padding(.vertical, 16)
                            .foregroundColor(Color(hex: "060D17"))
                            .background(isLoggingIn || email.isEmpty || password.isEmpty
                                        ? Color(hex: "00C6FF").opacity(0.3)
                                        : Color(hex: "00C6FF"))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .disabled(isLoggingIn || email.isEmpty || password.isEmpty)

                        Spacer()
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
    }

    private func successView(_ r: LoginResult) -> some View {
        VStack(spacing: 24) {
            Spacer()
            ZStack {
                Circle().fill(Color(hex: "00E6A0").opacity(0.15)).frame(width: 100, height: 100)
                Image(systemName: "checkmark").font(.system(size: 44, weight: .bold)).foregroundColor(Color(hex: "00E6A0"))
            }
            Text("登录成功").font(.system(size: 26, weight: .bold)).foregroundColor(.white)
            Text("\(r.email)").font(.system(size: 14)).foregroundColor(Color(hex: "7B89A0"))
            Text("余额 \(r.currency == "CNY" ? "¥" : "$")\(r.balance)").font(.system(size: 18, weight: .semibold, design: .monospaced)).foregroundColor(Color(hex: "00E6A0"))
            Button { dismiss() } label: {
                Text("返回仪表盘").font(.system(size: 17, weight: .semibold))
                    .foregroundColor(Color(hex: "060D17")).frame(width: 200).padding(.vertical, 14)
                    .background(Color(hex: "00C6FF")).clipShape(RoundedRectangle(cornerRadius: 14))
            }
            Spacer()
        }.padding(40)
    }

    private func login() {
        isLoggingIn = true; error = nil
        let deviceId = UUID().uuidString
        Task {
            do {
                let r = try await PlatformAPI.login(email: email, password: password, deviceId: deviceId)
                try KeychainManager.saveToken(r.token)
                result = r
            } catch {
                self.error = error.localizedDescription
            }
            isLoggingIn = false
        }
    }
}
