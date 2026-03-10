import SwiftUI

/// Password reset screen
struct ForgotPasswordView: View {

    @StateObject private var viewModel = AuthViewModel()
    @FocusState private var isEmailFocused: Bool
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.colorScheme) var systemColorScheme

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

                    // Action
                    actionSection

                    // Info
                    infoSection
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 32)
            }
        }
        .navigationTitle("Reset Password")
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
            Text(viewModel.successMessage ?? "Password reset email sent")
        }
    }

    // MARK: - View Components

    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "lock.rotation")
                .resizable()
                .scaledToFit()
                .frame(width: 60, height: 60)
                .foregroundStyle(.pink.gradient)

            Text("Forgot Your Password?")
                .font(.title2)
                .fontWeight(.bold)

            Text("Enter your email address and we'll send you a link to reset your password")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.bottom, 8)
    }

    private var formSection: some View {
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
                .focused($isEmailFocused)
                .submitLabel(.send)
                .onSubmit {
                    Task {
                        await viewModel.resetPassword()
                    }
                }

            if !viewModel.email.isEmpty && !viewModel.isEmailValid {
                Label("Please enter a valid email", systemImage: "exclamationmark.circle")
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
    }

    private var actionSection: some View {
        Button {
            Task {
                await viewModel.resetPassword()
            }
        } label: {
            HStack {
                if viewModel.isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text("Send Reset Link")
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(viewModel.isEmailValid ? Color.pink : Color.gray)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .disabled(!viewModel.isEmailValid || viewModel.isLoading)
    }

    private var infoSection: some View {
        VStack(spacing: 12) {
            Divider()
                .padding(.vertical, 8)

            VStack(alignment: .leading, spacing: 8) {
                Label("Check your spam folder", systemImage: "info.circle")
                Label("Link expires in 1 hour", systemImage: "clock")
                Label("You can request a new link anytime", systemImage: "arrow.clockwise")
            }
            .font(.caption)
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            #if os(iOS)
                .background(Color(.systemGray6))
            #else
                .background(Color(NSColor.controlBackgroundColor))
            #endif
            .cornerRadius(8)
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
}

#Preview {
    NavigationStack {
        ForgotPasswordView()
    }
}
