import SwiftUI

/// Login screen for existing users
struct LoginView: View {

    @StateObject private var viewModel = AuthViewModel()
    @FocusState private var focusedField: Field?

    enum Field {
        case email, password
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                AppTheme.backgroundGradient
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        headerSection

                        // Form
                        formSection

                        // Actions
                        actionSection

                        // Navigation
                        navigationSection
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 32)
                }
            }
            .navigationTitle("Welcome Back")
            #if os(iOS)
                .navigationBarTitleDisplayMode(.large)
            #endif
            .disabled(viewModel.isLoading)
            .errorAlert()  // Use centralized error handling
            .connectionStatus()  // Show connection status banner
            .alert("Success", isPresented: $viewModel.showSuccess) {
                Button("OK") {
                    viewModel.dismissSuccess()
                }
            } message: {
                Text(viewModel.successMessage ?? "Success")
            }
        }
    }

    // MARK: - View Components

    private var headerSection: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(AppTheme.primaryGradient)
                    .frame(width: 100, height: 100)
                    .shadow(color: AppTheme.shadowColor, radius: 10, x: 0, y: 5)

                Image(systemName: "heart.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 50, height: 50)
                    .foregroundStyle(.white)
            }

            Text("Couple Quest")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.primaryGradient)

            Text("Track chores, earn rewards together")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.bottom, 16)
    }

    private var formSection: some View {
        VStack(spacing: 16) {
            // Email field
            VStack(alignment: .leading, spacing: 8) {
                Text("Email")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(AppTheme.textSecondary)

                TextField("your@email.com", text: $viewModel.email)
                    .padding()
                    .background(Color.white)
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
            }

            // Password field
            VStack(alignment: .leading, spacing: 8) {
                Text("Password")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(AppTheme.textSecondary)

                SecureField("Enter your password", text: $viewModel.password)
                    .padding()
                    .background(Color.white)
                    .cornerRadius(AppTheme.cornerRadiusMedium)
                    .shadow(color: AppTheme.shadowColor, radius: 4, x: 0, y: 2)
                    .textContentType(.password)
                    .focused($focusedField, equals: .password)
                    .submitLabel(.go)
                    .onSubmit {
                        Task {
                            await viewModel.signIn()
                        }
                    }
            }
        }
    }

    private var actionSection: some View {
        VStack(spacing: 16) {
            // Sign in button
            Button {
                HapticManager.shared.medium()
                Task {
                    await viewModel.signIn()
                }
            } label: {
                HStack {
                    if viewModel.isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Sign In")
                            .fontWeight(.semibold)
                    }
                }
            }
            .buttonStyle(
                GradientButtonStyle(
                    gradient: AppTheme.primaryGradient,
                    isDisabled: !viewModel.canSignIn || viewModel.isLoading
                )
            )
            .disabled(!viewModel.canSignIn || viewModel.isLoading)

            // Forgot password
            NavigationLink {
                ForgotPasswordView()
            } label: {
                Text("Forgot Password?")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.primaryGradient)
            }
        }
    }

    private var navigationSection: some View {
        VStack(spacing: 12) {
            Divider()
                .padding(.vertical, 8)

            HStack {
                Text("Don't have an account?")
                    .foregroundColor(.secondary)

                NavigationLink {
                    SignUpView()
                } label: {
                    Text("Sign Up")
                        .fontWeight(.semibold)
                        .foregroundStyle(AppTheme.primaryGradient)
                }
            }
            .font(.subheadline)
        }
    }
}

#Preview {
    LoginView()
}
