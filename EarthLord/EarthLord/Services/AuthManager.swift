//
//  AuthManager.swift
//  EarthLord
//
//  认证管理器 - 处理用户注册、登录、找回密码等认证流程
//
//  认证模式说明：
//  - 注册：发验证码 → 验证（此时已登录但没密码）→ 强制设置密码 → 完成
//  - 登录：邮箱 + 密码（直接登录）
//  - 找回密码：发验证码 → 验证（此时已登录）→ 设置新密码 → 完成
//

import Foundation
import Combine
import Supabase
import AuthenticationServices
import GoogleSignIn

// MARK: - AuthManager
@MainActor
final class AuthManager: ObservableObject, Sendable {

    // MARK: - Singleton
    static let shared = AuthManager()

    // MARK: - Published Properties

    /// 是否已完成认证（已登录且完成所有流程）
    @Published var isAuthenticated: Bool = false

    /// OTP验证后是否需要设置密码
    @Published var needsPasswordSetup: Bool = false

    /// 当前登录用户
    @Published var currentUser: User? = nil

    /// 是否正在加载
    @Published var isLoading: Bool = false

    /// 错误信息
    @Published var errorMessage: String? = nil

    /// 验证码是否已发送
    @Published var otpSent: Bool = false

    /// 验证码是否已验证（等待设置密码）
    @Published var otpVerified: Bool = false

    // MARK: - Private Properties

    /// 当前操作的邮箱（用于验证流程）
    private var currentEmail: String? = nil

    /// 认证状态监听任务
    private var authStateTask: Task<Void, Never>? = nil

    // MARK: - Initialization

    private init() {
        // 启动认证状态监听
        startAuthStateListener()
    }

    // MARK: - Auth State Listener

    /// 启动认证状态变化监听
    private func startAuthStateListener() {
        authStateTask = Task { [weak self] in
            for await (event, session) in supabase.auth.authStateChanges {
                guard let self = self else { return }

                await MainActor.run {
                    self.handleAuthEvent(event: event, session: session)
                }
            }
        }
    }

    /// 处理认证事件
    private func handleAuthEvent(event: AuthChangeEvent, session: Session?) {
        switch event {
        case .initialSession:
            // 初始会话检查
            if let session = session {
                self.currentUser = session.user
                self.isAuthenticated = true
                print("🔐 初始会话: \(session.user.email ?? "unknown")")
            } else {
                self.currentUser = nil
                self.isAuthenticated = false
                print("🔐 无初始会话")
            }

        case .signedIn:
            // 用户登录（注意：OTP 验证后也会触发，但需要设置密码才算完成）
            if let session = session {
                self.currentUser = session.user
                // 如果不是在注册流程中（需要设置密码），才设置为已认证
                if !self.needsPasswordSetup {
                    self.isAuthenticated = true
                }
                print("🔐 用户登录: \(session.user.email ?? "unknown")")
            }

        case .signedOut:
            // 用户登出
            self.currentUser = nil
            self.isAuthenticated = false
            self.needsPasswordSetup = false
            self.otpSent = false
            self.otpVerified = false
            print("🔐 用户登出")

        case .tokenRefreshed:
            // Token 刷新
            if let session = session {
                self.currentUser = session.user
                print("🔐 Token 已刷新")
            }

        case .userUpdated:
            // 用户信息更新
            if let session = session {
                self.currentUser = session.user
                print("🔐 用户信息已更新")
            }

        case .passwordRecovery:
            // 密码恢复流程
            print("🔐 密码恢复流程")

        case .mfaChallengeVerified:
            // MFA 验证
            print("🔐 MFA 验证完成")

        case .userDeleted:
            // 用户删除
            self.currentUser = nil
            self.isAuthenticated = false
            print("🔐 用户已删除")
        }
    }

    // MARK: - 注册流程

    /// 发送注册验证码
    /// - Parameter email: 用户邮箱
    /// - Note: 调用 signInWithOTP，shouldCreateUser = true 表示允许创建新用户
    func sendRegisterOTP(email: String) async {
        isLoading = true
        errorMessage = nil
        otpSent = false

        do {
            // 发送 OTP 验证码到邮箱
            try await supabase.auth.signInWithOTP(
                email: email,
                shouldCreateUser: true  // 允许创建新用户
            )

            currentEmail = email
            otpSent = true
            print("📧 注册验证码已发送至: \(email)")

        } catch {
            errorMessage = "发送验证码失败: \(error.localizedDescription)"
            print("❌ 发送注册验证码失败: \(error)")
        }

        isLoading = false
    }

    /// 验证注册 OTP
    /// - Parameters:
    ///   - email: 用户邮箱
    ///   - code: 验证码
    /// - Note: 验证成功后用户已登录，但必须设置密码才能完成注册
    func verifyRegisterOTP(email: String, code: String) async {
        isLoading = true
        errorMessage = nil

        do {
            // 验证 OTP（type 为 .email）
            let session = try await supabase.auth.verifyOTP(
                email: email,
                token: code,
                type: .email
            )

            // 验证成功，用户已登录
            currentUser = session.user
            otpVerified = true
            needsPasswordSetup = true  // 需要设置密码
            // isAuthenticated 保持 false，直到设置密码完成

            print("✅ 注册验证码验证成功，等待设置密码")

        } catch {
            errorMessage = "验证码验证失败: \(error.localizedDescription)"
            print("❌ 注册验证码验证失败: \(error)")
        }

        isLoading = false
    }

    /// 完成注册（设置密码）
    /// - Parameter password: 用户密码
    /// - Note: 必须在 verifyRegisterOTP 成功后调用
    func completeRegistration(password: String) async {
        guard otpVerified && needsPasswordSetup else {
            errorMessage = "请先完成验证码验证"
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            // 更新用户密码
            try await supabase.auth.update(user: UserAttributes(password: password))

            // 密码设置成功，完成注册流程
            needsPasswordSetup = false
            isAuthenticated = true
            otpVerified = false
            otpSent = false

            print("✅ 注册完成，密码已设置")

        } catch {
            errorMessage = "设置密码失败: \(error.localizedDescription)"
            print("❌ 设置密码失败: \(error)")
        }

        isLoading = false
    }

    // MARK: - 登录方法

    /// 邮箱密码登录
    /// - Parameters:
    ///   - email: 用户邮箱
    ///   - password: 用户密码
    func signIn(email: String, password: String) async {
        isLoading = true
        errorMessage = nil

        do {
            let session = try await supabase.auth.signIn(
                email: email,
                password: password
            )

            currentUser = session.user
            isAuthenticated = true

            print("✅ 登录成功: \(email)")

        } catch {
            errorMessage = "登录失败: \(error.localizedDescription)"
            print("❌ 登录失败: \(error)")
        }

        isLoading = false
    }

    // MARK: - 找回密码流程

    /// 发送重置密码验证码
    /// - Parameter email: 用户邮箱
    /// - Note: 使用 resetPasswordForEmail，触发 Reset Password 邮件模板
    func sendResetOTP(email: String) async {
        isLoading = true
        errorMessage = nil
        otpSent = false

        do {
            // 发送重置密码邮件
            try await supabase.auth.resetPasswordForEmail(email)

            currentEmail = email
            otpSent = true
            print("📧 重置密码验证码已发送至: \(email)")

        } catch {
            errorMessage = "发送验证码失败: \(error.localizedDescription)"
            print("❌ 发送重置密码验证码失败: \(error)")
        }

        isLoading = false
    }

    /// 验证重置密码 OTP
    /// - Parameters:
    ///   - email: 用户邮箱
    ///   - code: 验证码
    /// - Note: type 必须是 .recovery 不是 .email
    func verifyResetOTP(email: String, code: String) async {
        isLoading = true
        errorMessage = nil

        do {
            // 验证 OTP（type 为 .recovery）
            let session = try await supabase.auth.verifyOTP(
                email: email,
                token: code,
                type: .recovery  // ⚠️ 重置密码必须用 .recovery
            )

            // 验证成功，用户已登录
            currentUser = session.user
            otpVerified = true
            needsPasswordSetup = true  // 需要设置新密码

            print("✅ 重置密码验证码验证成功，等待设置新密码")

        } catch {
            errorMessage = "验证码验证失败: \(error.localizedDescription)"
            print("❌ 重置密码验证码验证失败: \(error)")
        }

        isLoading = false
    }

    /// 重置密码（设置新密码）
    /// - Parameter newPassword: 新密码
    /// - Note: 必须在 verifyResetOTP 成功后调用
    func resetPassword(newPassword: String) async {
        guard otpVerified && needsPasswordSetup else {
            errorMessage = "请先完成验证码验证"
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            // 更新用户密码
            try await supabase.auth.update(user: UserAttributes(password: newPassword))

            // 密码重置成功
            needsPasswordSetup = false
            isAuthenticated = true
            otpVerified = false
            otpSent = false

            print("✅ 密码重置成功")

        } catch {
            errorMessage = "重置密码失败: \(error.localizedDescription)"
            print("❌ 重置密码失败: \(error)")
        }

        isLoading = false
    }

    // MARK: - 第三方登录（预留）

    /// Apple 登录
    /// - TODO: 实现 Sign in with Apple
    func signInWithApple() async {
        // TODO: 实现 Apple 登录
        // 1. 使用 ASAuthorizationController 获取 Apple ID credential
        // 2. 调用 supabase.auth.signInWithIdToken(credentials:)
        // 3. 处理登录结果
        print("⚠️ Apple 登录功能待实现")
        errorMessage = "Apple 登录功能即将推出"
    }

    /// Google 登录
    func signInWithGoogle() async {
        print("🔵 [Google登录] 开始 Google 登录流程...")
        isLoading = true
        errorMessage = nil

        do {
            // 1. 获取当前窗口的 rootViewController
            print("🔵 [Google登录] 正在获取 rootViewController...")
            guard let windowScene = await UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let rootViewController = await windowScene.windows.first?.rootViewController else {
                print("❌ [Google登录] 无法获取 rootViewController")
                errorMessage = "无法启动 Google 登录"
                isLoading = false
                return
            }
            print("✅ [Google登录] 成功获取 rootViewController")

            // 2. 调用 Google Sign-In SDK
            print("🔵 [Google登录] 正在调用 Google Sign-In SDK...")
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)
            print("✅ [Google登录] Google Sign-In 成功")

            // 3. 获取 ID Token
            guard let idToken = result.user.idToken?.tokenString else {
                print("❌ [Google登录] 无法获取 ID Token")
                errorMessage = "Google 登录失败：无法获取 ID Token"
                isLoading = false
                return
            }
            print("✅ [Google登录] 成功获取 ID Token: \(idToken.prefix(20))...")

            // 4. 获取 Access Token
            let accessToken = result.user.accessToken.tokenString
            print("✅ [Google登录] 成功获取 Access Token: \(accessToken.prefix(20))...")

            // 5. 使用 Supabase 验证 Google Token
            print("🔵 [Google登录] 正在向 Supabase 发送验证请求...")
            let session = try await supabase.auth.signInWithIdToken(
                credentials: .init(
                    provider: .google,
                    idToken: idToken,
                    accessToken: accessToken
                )
            )

            // 6. 登录成功
            currentUser = session.user
            isAuthenticated = true
            print("✅ [Google登录] Supabase 验证成功！")
            print("✅ [Google登录] 用户邮箱: \(session.user.email ?? "未知")")
            print("✅ [Google登录] 用户ID: \(session.user.id)")

        } catch let error as GIDSignInError {
            // Google Sign-In 错误
            print("❌ [Google登录] Google Sign-In 错误: \(error.localizedDescription)")
            print("❌ [Google登录] 错误代码: \(error.code)")

            switch error.code {
            case .canceled:
                print("ℹ️ [Google登录] 用户取消了登录")
                errorMessage = nil // 用户取消不显示错误
            case .hasNoAuthInKeychain:
                print("❌ [Google登录] Keychain 中没有认证信息")
                errorMessage = "请重新登录 Google 账号"
            default:
                errorMessage = "Google 登录失败: \(error.localizedDescription)"
            }
        } catch {
            // 其他错误（可能是 Supabase 错误）
            print("❌ [Google登录] 错误: \(error)")
            print("❌ [Google登录] 错误类型: \(type(of: error))")
            errorMessage = "登录失败: \(error.localizedDescription)"
        }

        isLoading = false
        print("🔵 [Google登录] 登录流程结束")
    }

    // MARK: - 其他方法

    /// 退出登录
    func signOut() async {
        isLoading = true
        errorMessage = nil

        do {
            try await supabase.auth.signOut()

            // 重置所有状态
            currentUser = nil
            isAuthenticated = false
            needsPasswordSetup = false
            otpSent = false
            otpVerified = false
            currentEmail = nil

            print("✅ 已退出登录")

        } catch {
            errorMessage = "退出登录失败: \(error.localizedDescription)"
            print("❌ 退出登录失败: \(error)")
        }

        isLoading = false
    }

    /// 检查现有会话
    /// - Note: 应用启动时调用，恢复登录状态
    func checkSession() async {
        isLoading = true

        do {
            let session = try await supabase.auth.session
            currentUser = session.user

            // 检查用户是否有密码（通过 identities 判断）
            // 如果用户只有 email identity 且没有设置过密码，可能需要设置密码
            // 这里简化处理：有有效 session 就认为已完成认证
            isAuthenticated = true

            print("✅ 已恢复登录状态: \(session.user.email ?? "unknown")")

        } catch {
            // 没有有效会话，保持未登录状态
            currentUser = nil
            isAuthenticated = false
            print("ℹ️ 无有效会话")
        }

        isLoading = false
    }

    // MARK: - Helper Methods

    /// 清除错误信息
    func clearError() {
        errorMessage = nil
    }

    /// 重置注册/重置密码流程状态
    func resetFlowState() {
        otpSent = false
        otpVerified = false
        needsPasswordSetup = false
        currentEmail = nil
        errorMessage = nil
    }
}
