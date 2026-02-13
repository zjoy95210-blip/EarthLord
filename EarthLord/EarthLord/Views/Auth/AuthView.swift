//
//  AuthView.swift
//  EarthLord
//
//  认证页面 - 登录、注册、找回密码
//

import SwiftUI

// MARK: - AuthView
struct AuthView: View {
    @StateObject private var authManager = AuthManager.shared

    /// 当前选中的 Tab（0: 登录, 1: 注册）
    @State private var selectedTab: Int = 0

    /// 是否显示忘记密码弹窗
    @State private var showForgotPassword: Bool = false

    /// Toast 消息
    @State private var toastMessage: String? = nil

    var body: some View {
        ZStack {
            // 深色渐变背景
            backgroundGradient

            ScrollView {
                VStack(spacing: 32) {
                    // Logo 和标题
                    headerView
                        .padding(.top, 60)

                    // Tab 切换
                    tabSelector

                    // 内容区域
                    if selectedTab == 0 {
                        loginView
                    } else {
                        registerView
                    }

                    // 分隔线
                    dividerView

                    // 第三方登录
                    socialLoginButtons

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 24)
            }

            // 加载遮罩
            if authManager.isLoading {
                loadingOverlay
            }

            // Toast 提示
            if let message = toastMessage {
                toastView(message: message)
            }
        }
        .sheet(isPresented: $showForgotPassword) {
            ForgotPasswordView(authManager: authManager)
        }
        .onChange(of: authManager.errorMessage) { _, newValue in
            if let error = newValue {
                showToast(error)
                authManager.clearError()
            }
        }
    }

    // MARK: - Background
    private var backgroundGradient: some View {
        LinearGradient(
            gradient: Gradient(colors: [
                Color(red: 0.05, green: 0.05, blue: 0.15),
                Color(red: 0.1, green: 0.1, blue: 0.2),
                Color(red: 0.05, green: 0.08, blue: 0.12)
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    // MARK: - Header
    private var headerView: some View {
        VStack(spacing: 16) {
            // Logo
            Image(systemName: "globe.asia.australia.fill")
                .font(.system(size: 80))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue, .cyan, .green],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: .cyan.opacity(0.5), radius: 20)

            // 标题
            Text("地球新主")
                .font(.system(size: 36, weight: .bold))
                .foregroundColor(.white)

            Text("征服世界，从这里开始")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
    }

    // MARK: - Tab Selector
    private var tabSelector: some View {
        HStack(spacing: 0) {
            tabButton(title: "登录", index: 0)
            tabButton(title: "注册", index: 1)
        }
        .background(Color.white.opacity(0.1))
        .cornerRadius(12)
    }

    private func tabButton(title: LocalizedStringKey, index: Int) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTab = index
                authManager.resetFlowState()
            }
        } label: {
            Text(title)
                .font(.headline)
                .foregroundColor(selectedTab == index ? .white : .gray)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    selectedTab == index ?
                    Color.blue.opacity(0.8) : Color.clear
                )
                .cornerRadius(12)
        }
    }

    // MARK: - Login View
    private var loginView: some View {
        LoginFormView(
            authManager: authManager,
            onForgotPassword: {
                showForgotPassword = true
            }
        )
    }

    // MARK: - Register View
    private var registerView: some View {
        RegisterFormView(authManager: authManager)
    }

    // MARK: - Divider
    private var dividerView: some View {
        HStack {
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(height: 1)

            Text("或者使用以下方式登录")
                .font(.caption)
                .foregroundColor(.gray)
                .fixedSize()

            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(height: 1)
        }
        .padding(.vertical, 8)
    }

    // MARK: - Social Login Buttons
    private var socialLoginButtons: some View {
        VStack(spacing: 12) {
            // Apple 登录
            Button {
                Task {
                    await authManager.signInWithApple()
                }
            } label: {
                HStack {
                    Image(systemName: "apple.logo")
                        .font(.title2)
                    Text("通过 Apple 登录")
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.black)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
            }

            // Google 登录
            Button {
                Task {
                    await authManager.signInWithGoogle()
                }
            } label: {
                HStack {
                    Image(systemName: "g.circle.fill")
                        .font(.title2)
                    Text("通过 Google 登录")
                        .fontWeight(.semibold)
                }
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.white)
                .cornerRadius(12)
            }
        }
    }

    // MARK: - Loading Overlay
    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)

                Text("请稍候...")
                    .foregroundColor(.white)
            }
            .padding(32)
            .background(Color.black.opacity(0.8))
            .cornerRadius(16)
        }
    }

    // MARK: - Toast
    private func toastView(message: String) -> some View {
        VStack {
            Spacer()

            Text(message)
                .font(.subheadline)
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .background(Color.red.opacity(0.9))
                .cornerRadius(25)
                .shadow(radius: 10)
                .padding(.bottom, 100)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .zIndex(100)
    }

    private func showToast(_ message: String) {
        withAnimation {
            toastMessage = message
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation {
                toastMessage = nil
            }
        }
    }
}

// MARK: - Login Form View
struct LoginFormView: View {
    @ObservedObject var authManager: AuthManager
    var onForgotPassword: () -> Void

    @State private var email: String = ""
    @State private var password: String = ""

    var body: some View {
        VStack(spacing: 20) {
            // 邮箱输入
            AuthTextField(
                icon: "envelope.fill",
                placeholder: "邮箱地址",
                text: $email,
                keyboardType: .emailAddress
            )

            // 密码输入
            AuthSecureField(
                icon: "lock.fill",
                placeholder: "密码",
                text: $password
            )

            // 登录按钮
            Button {
                Task {
                    await authManager.signIn(email: email, password: password)
                }
            } label: {
                Text("登录")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [.blue, .cyan],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
            }
            .disabled(email.isEmpty || password.isEmpty)
            .opacity(email.isEmpty || password.isEmpty ? 0.6 : 1)

            // 忘记密码
            Button {
                onForgotPassword()
            } label: {
                Text("忘记密码？")
                    .font(.subheadline)
                    .foregroundColor(.cyan)
            }
        }
    }
}

// MARK: - Register Form View
struct RegisterFormView: View {
    @ObservedObject var authManager: AuthManager

    @State private var email: String = ""
    @State private var otpCode: String = ""
    @State private var password: String = ""
    @State private var confirmPassword: String = ""
    @State private var countdown: Int = 0
    @State private var timer: Timer? = nil

    /// 当前注册步骤
    private var currentStep: Int {
        if authManager.needsPasswordSetup && authManager.otpVerified {
            return 3  // 设置密码
        } else if authManager.otpSent {
            return 2  // 输入验证码
        } else {
            return 1  // 输入邮箱
        }
    }

    var body: some View {
        VStack(spacing: 20) {
            // 步骤指示器
            stepIndicator

            // 根据步骤显示不同内容
            switch currentStep {
            case 1:
                step1EmailInput
            case 2:
                step2OTPInput
            case 3:
                step3PasswordSetup
            default:
                EmptyView()
            }
        }
    }

    // MARK: - Step Indicator
    private var stepIndicator: some View {
        HStack(spacing: 8) {
            ForEach(1...3, id: \.self) { step in
                HStack(spacing: 4) {
                    Circle()
                        .fill(step <= currentStep ? Color.cyan : Color.gray.opacity(0.3))
                        .frame(width: 24, height: 24)
                        .overlay(
                            Text("\(step)")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(step <= currentStep ? .black : .gray)
                        )

                    if step < 3 {
                        Rectangle()
                            .fill(step < currentStep ? Color.cyan : Color.gray.opacity(0.3))
                            .frame(height: 2)
                    }
                }
            }
        }
        .padding(.bottom, 8)
    }

    // MARK: - Step 1: Email Input
    private var step1EmailInput: some View {
        VStack(spacing: 20) {
            Text("输入您的邮箱")
                .font(.headline)
                .foregroundColor(.white)

            AuthTextField(
                icon: "envelope.fill",
                placeholder: "邮箱地址",
                text: $email,
                keyboardType: .emailAddress
            )

            Button {
                Task {
                    await authManager.sendRegisterOTP(email: email)
                    startCountdown()
                }
            } label: {
                Text("发送验证码")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [.blue, .cyan],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
            }
            .disabled(email.isEmpty || !isValidEmail(email))
            .opacity(email.isEmpty || !isValidEmail(email) ? 0.6 : 1)
        }
    }

    // MARK: - Step 2: OTP Input
    private var step2OTPInput: some View {
        VStack(spacing: 20) {
            Text("输入验证码")
                .font(.headline)
                .foregroundColor(.white)

            Text("验证码已发送至 \(email)")
                .font(.caption)
                .foregroundColor(.gray)

            // 验证码输入
            AuthTextField(
                icon: "number",
                placeholder: "6位验证码",
                text: $otpCode,
                keyboardType: .numberPad
            )

            // 验证按钮
            Button {
                Task {
                    await authManager.verifyRegisterOTP(email: email, code: otpCode)
                }
            } label: {
                Text("验证")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [.blue, .cyan],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
            }
            .disabled(otpCode.count < 6)
            .opacity(otpCode.count < 6 ? 0.6 : 1)

            // 重发验证码
            Button {
                if countdown == 0 {
                    Task {
                        await authManager.sendRegisterOTP(email: email)
                        startCountdown()
                    }
                }
            } label: {
                if countdown > 0 {
                    Text("重新发送 (\(countdown)s)")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                } else {
                    Text("重新发送验证码")
                        .font(.subheadline)
                        .foregroundColor(.cyan)
                }
            }
            .disabled(countdown > 0)
        }
    }

    // MARK: - Step 3: Password Setup
    private var step3PasswordSetup: some View {
        VStack(spacing: 20) {
            Text("设置您的密码")
                .font(.headline)
                .foregroundColor(.white)

            Text("验证成功！请设置登录密码完成注册")
                .font(.caption)
                .foregroundColor(.green)

            AuthSecureField(
                icon: "lock.fill",
                placeholder: "设置密码（至少6位）",
                text: $password
            )

            AuthSecureField(
                icon: "lock.fill",
                placeholder: "确认密码",
                text: $confirmPassword
            )

            // 密码匹配提示
            if !confirmPassword.isEmpty && password != confirmPassword {
                Text("两次输入的密码不一致")
                    .font(.caption)
                    .foregroundColor(.red)
            }

            Button {
                Task {
                    await authManager.completeRegistration(password: password)
                }
            } label: {
                Text("完成注册")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [.green, .cyan],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
            }
            .disabled(!isPasswordValid)
            .opacity(isPasswordValid ? 1 : 0.6)
        }
    }

    // MARK: - Helpers
    private var isPasswordValid: Bool {
        password.count >= 6 && password == confirmPassword
    }

    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }

    private func startCountdown() {
        countdown = 60
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if countdown > 0 {
                countdown -= 1
            } else {
                timer?.invalidate()
            }
        }
    }
}

// MARK: - Forgot Password View
struct ForgotPasswordView: View {
    @ObservedObject var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss

    @State private var email: String = ""
    @State private var otpCode: String = ""
    @State private var newPassword: String = ""
    @State private var confirmPassword: String = ""
    @State private var countdown: Int = 0
    @State private var timer: Timer? = nil

    /// 当前步骤
    private var currentStep: Int {
        if authManager.needsPasswordSetup && authManager.otpVerified {
            return 3
        } else if authManager.otpSent {
            return 2
        } else {
            return 1
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // 背景
                Color(red: 0.05, green: 0.05, blue: 0.15)
                    .ignoresSafeArea()

                VStack(spacing: 24) {
                    // 步骤指示
                    stepIndicator

                    // 内容
                    switch currentStep {
                    case 1:
                        step1EmailInput
                    case 2:
                        step2OTPInput
                    case 3:
                        step3NewPassword
                    default:
                        EmptyView()
                    }

                    Spacer()
                }
                .padding(24)

                // 加载遮罩
                if authManager.isLoading {
                    loadingOverlay
                }
            }
            .navigationTitle("找回密码")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        authManager.resetFlowState()
                        dismiss()
                    }
                    .foregroundColor(.cyan)
                }
            }
            .onChange(of: authManager.isAuthenticated) { _, isAuth in
                if isAuth {
                    dismiss()
                }
            }
        }
    }

    // MARK: - Step Indicator
    private var stepIndicator: some View {
        HStack(spacing: 8) {
            ForEach(1...3, id: \.self) { step in
                HStack(spacing: 4) {
                    Circle()
                        .fill(step <= currentStep ? Color.orange : Color.gray.opacity(0.3))
                        .frame(width: 24, height: 24)
                        .overlay(
                            Text("\(step)")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(step <= currentStep ? .black : .gray)
                        )

                    if step < 3 {
                        Rectangle()
                            .fill(step < currentStep ? Color.orange : Color.gray.opacity(0.3))
                            .frame(height: 2)
                    }
                }
            }
        }
    }

    // MARK: - Step 1
    private var step1EmailInput: some View {
        VStack(spacing: 20) {
            Text("输入您的注册邮箱")
                .font(.headline)
                .foregroundColor(.white)

            AuthTextField(
                icon: "envelope.fill",
                placeholder: "邮箱地址",
                text: $email,
                keyboardType: .emailAddress
            )

            Button {
                Task {
                    await authManager.sendResetOTP(email: email)
                    startCountdown()
                }
            } label: {
                Text("发送验证码")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.orange)
                    .cornerRadius(12)
            }
            .disabled(email.isEmpty)
            .opacity(email.isEmpty ? 0.6 : 1)
        }
    }

    // MARK: - Step 2
    private var step2OTPInput: some View {
        VStack(spacing: 20) {
            Text("输入验证码")
                .font(.headline)
                .foregroundColor(.white)

            Text("验证码已发送至 \(email)")
                .font(.caption)
                .foregroundColor(.gray)

            AuthTextField(
                icon: "number",
                placeholder: "6位验证码",
                text: $otpCode,
                keyboardType: .numberPad
            )

            Button {
                Task {
                    await authManager.verifyResetOTP(email: email, code: otpCode)
                }
            } label: {
                Text("验证")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.orange)
                    .cornerRadius(12)
            }
            .disabled(otpCode.count < 6)
            .opacity(otpCode.count < 6 ? 0.6 : 1)

            // 重发
            Button {
                if countdown == 0 {
                    Task {
                        await authManager.sendResetOTP(email: email)
                        startCountdown()
                    }
                }
            } label: {
                if countdown > 0 {
                    Text("重新发送 (\(countdown)s)")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                } else {
                    Text("重新发送验证码")
                        .font(.subheadline)
                        .foregroundColor(.orange)
                }
            }
            .disabled(countdown > 0)
        }
    }

    // MARK: - Step 3
    private var step3NewPassword: some View {
        VStack(spacing: 20) {
            Text("设置新密码")
                .font(.headline)
                .foregroundColor(.white)

            AuthSecureField(
                icon: "lock.fill",
                placeholder: "新密码（至少6位）",
                text: $newPassword
            )

            AuthSecureField(
                icon: "lock.fill",
                placeholder: "确认新密码",
                text: $confirmPassword
            )

            if !confirmPassword.isEmpty && newPassword != confirmPassword {
                Text("两次输入的密码不一致")
                    .font(.caption)
                    .foregroundColor(.red)
            }

            Button {
                Task {
                    await authManager.resetPassword(newPassword: newPassword)
                }
            } label: {
                Text("重置密码")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.orange)
                    .cornerRadius(12)
            }
            .disabled(newPassword.count < 6 || newPassword != confirmPassword)
            .opacity(newPassword.count >= 6 && newPassword == confirmPassword ? 1 : 0.6)
        }
    }

    // MARK: - Loading
    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()

            ProgressView()
                .scaleEffect(1.5)
                .tint(.white)
        }
    }

    private func startCountdown() {
        countdown = 60
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if countdown > 0 {
                countdown -= 1
            } else {
                timer?.invalidate()
            }
        }
    }
}

// MARK: - Custom Text Field
struct AuthTextField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.gray)
                .frame(width: 24)

            TextField(placeholder, text: $text)
                .keyboardType(keyboardType)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .foregroundColor(.white)
        }
        .padding()
        .background(Color.white.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Custom Secure Field
struct AuthSecureField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    @State private var isSecure: Bool = true

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.gray)
                .frame(width: 24)

            if isSecure {
                SecureField(placeholder, text: $text)
                    .foregroundColor(.white)
            } else {
                TextField(placeholder, text: $text)
                    .foregroundColor(.white)
            }

            Button {
                isSecure.toggle()
            } label: {
                Image(systemName: isSecure ? "eye.slash" : "eye")
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .background(Color.white.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Preview
#Preview {
    AuthView()
}
