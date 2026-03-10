import SwiftUI

/// Sign up screen for new users
struct SignUpView: View {

    @StateObject private var viewModel = AuthViewModel()
    @FocusState private var focusedField: Field?
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.colorScheme) var systemColorScheme

    enum Field {
        case email, password, confirmPassword
    }

    var body: some View {
        ZStack {
            // Background gradient (adaptive to theme)
            AppTheme.backgroundGradient(
                for: themeManager.currentTheme.rawValue, systemScheme: systemColorScheme
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerSection

                    // Form
                    formSection

                    // Password requirements
                    passwordRequirementsSection

                    // Actions
                    actionSection
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 32)
            }
        }
        .navigationTitle("Create Account")
        #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
        #endif
        .disabled(viewModel.isLoading)
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK") {
                viewModel.dismissError()
            }
        } message: {
            Text(viewModel.errorMessage ?? "An error occurred")
        }
        .alert("Success", isPresented: $viewModel.showSuccess) {
            Button("OK") {
                viewModel.dismissSuccess()
                dismiss()
            }
        } message: {
            Text(viewModel.successMessage ?? "Account created successfully")
        }
    }

    // MARK: - View Components

    private var headerSection: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(AppTheme.secondaryGradient)
                    .frame(width: 90, height: 90)
                    .shadow(color: AppTheme.shadowColor, radius: 10, x: 0, y: 5)

                Image(systemName: "person.2.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 45, height: 45)
                    .foregroundStyle(.white)
            }

            Text("Join Couple Quest")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(AppTheme.primaryGradient)

            Text("Start tracking chores and earning rewards")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.bottom, 8)
    }

    private var formSection: some View {
        VStack(spacing: 16) {
            // Email field
            VStack(alignment: .leading, spacing: 8) {
                Text("Email")
                    .font(.subheadline)
                    .fontWeight(.medium)

                TextField("your@email.com", text: $viewModel.email)
                    .foregroundColor(inputTextColor)
                    .padding()
                    .background(inputFieldBackground)
                    .cornerRadius(AppTheme.cornerRadiusMedium)
                    .shadow(color: AppTheme.shadowColor, radius: 4, x: 0, y: 2)
                    .textContentType(.emailAddress)
                    #if os(iOS)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                    #endif
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .email)
                    .submitLabel(.next)
                    .onSubmit {
                        focusedField = .password
                    }

                if !viewModel.email.isEmpty && !viewModel.isEmailValid {
                    Label("Please enter a valid email", systemImage: "exclamationmark.circle")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }

            // Password field
            VStack(alignment: .leading, spacing: 8) {
                Text("Password")
                    .font(.subheadline)
                    .fontWeight(.medium)

                SecureField("Create a password", text: $viewModel.password)
                    .foregroundColor(inputTextColor)
                    .padding()
                    .background(inputFieldBackground)
                    .cornerRadius(AppTheme.cornerRadiusMedium)
                    .shadow(color: AppTheme.shadowColor, radius: 4, x: 0, y: 2)
                    .textContentType(.newPassword)
                    .focused($focusedField, equals: .password)
                    .submitLabel(.next)
                    .onSubmit {
                        focusedField = .confirmPassword
                    }
            }

            // Confirm password field
            VStack(alignment: .leading, spacing: 8) {
                Text("Confirm Password")
                    .font(.subheadline)
                    .fontWeight(.medium)

                SecureField("Confirm your password", text: $viewModel.confirmPassword)
                    .foregroundColor(inputTextColor)
                    .padding()
                    .background(inputFieldBackground)
                    .cornerRadius(AppTheme.cornerRadiusMedium)
                    .shadow(color: AppTheme.shadowColor, radius: 4, x: 0, y: 2)
                    .textContentType(.newPassword)
                    .focused($focusedField, equals: .confirmPassword)
                    .submitLabel(.go)
                    .onSubmit {
                        Task {
                            await viewModel.signUp()
                        }
                    }

                if !viewModel.confirmPassword.isEmpty && !viewModel.passwordsMatch {
                    Label("Passwords do not match", systemImage: "exclamationmark.circle")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
        }
    }

    private var inputFieldBackground: Color {
        let isDarkMode = themeManager.currentTheme.rawValue == "dark"
        return isDarkMode ? Color(hex: "1A1A1A") : Color.white
    }

    private var inputTextColor: Color {
        let isDarkMode = themeManager.currentTheme.rawValue == "dark"
        return isDarkMode ? Color.white : Color.black
    }

    private var passwordRequirementsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Password Requirements")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)

            HStack(spacing: 8) {
                Image(systemName: viewModel.isPasswordValid ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(viewModel.isPasswordValid ? .green : .secondary)

                Text("At least \(AppConstants.minPasswordLength) characters")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        #if os(iOS)
            .background(Color(.systemGray6))
        #else
            .background(Color(NSColor.controlBackgroundColor))
        #endif
        .cornerRadius(8)
    }

    private var actionSection: some View {
        VStack(spacing: 16) {
            // Sign up button
            Button {
                Task {
                    await viewModel.signUp()
                }
            } label: {
                HStack {
                    if viewModel.isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Create Account")
                            .fontWeight(.semibold)
                    }
                }
            }
            .buttonStyle(
                GradientButtonStyle(
                    gradient: AppTheme.primaryGradient,
                    isDisabled: !viewModel.canSignUp || viewModel.isLoading
                )
            )
            .disabled(!viewModel.canSignUp || viewModel.isLoading)

            // Terms and privacy
            Text("By signing up, you agree to our Terms of Service and Privacy Policy")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
}

#Preview {
    NavigationStack {
        SignUpView()
    }
}
