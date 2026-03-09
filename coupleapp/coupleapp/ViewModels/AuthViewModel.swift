import Combine
import Foundation
import SwiftUI

/// ViewModel for authentication flows
/// Handles business logic for login, signup, and password reset
/// Uses centralized error handling via ErrorManager
@MainActor
class AuthViewModel: ObservableObject {

    // MARK: - Published Properties

    /// Email input field
    @Published var email = ""

    /// Password input field
    @Published var password = ""

    /// Confirm password input field (for signup)
    @Published var confirmPassword = ""

    /// Loading state during auth operations
    @Published var isLoading = false

    /// Success message to display
    @Published var successMessage: String?

    /// Whether to show success alert
    @Published var showSuccess = false

    // MARK: - Dependencies

    private let authService = AuthService.shared
    private let errorManager = ErrorManager.shared
    private let networkMonitor = NetworkMonitor.shared

    // MARK: - Computed Properties

    /// Whether the email is valid
    var isEmailValid: Bool {
        email.contains("@") && email.contains(".")
    }

    /// Whether the password meets minimum requirements
    var isPasswordValid: Bool {
        password.count >= AppConstants.minPasswordLength
    }

    /// Whether passwords match (for signup)
    var passwordsMatch: Bool {
        password == confirmPassword
    }

    /// Whether sign in form is valid
    var canSignIn: Bool {
        !email.isEmpty && !password.isEmpty
    }

    /// Whether sign up form is valid
    var canSignUp: Bool {
        isEmailValid && isPasswordValid && passwordsMatch
    }

    // MARK: - Actions

    /// Signs in user with email and password
    func signIn() async {
        guard canSignIn else {
            errorManager.handle(
                AuthError.invalidPassword,
                context: "Sign In - Form Validation"
            )
            return
        }

        // Check network connectivity
        guard !networkMonitor.isOfflineMode else {
            errorManager.handle(
                AuthError.networkError,
                context: "Sign In - Offline"
            )
            return
        }

        isLoading = true

        do {
            // Retry network operation with exponential backoff
            try await RetryManager.retryNetworkOperation {
                try await self.authService.signIn(email: self.email, password: self.password)
            }
            // Success - session will be updated automatically
            clearForm()
        } catch {
            errorManager.handle(error, context: "Sign In")
        }

        isLoading = false
    }

    /// Signs up new user with email and password
    func signUp() async {
        guard canSignUp else {
            if !isEmailValid {
                errorManager.handle(
                    AuthError.invalidEmail,
                    context: "Sign Up - Form Validation"
                )
            } else if !isPasswordValid {
                errorManager.handle(
                    AuthError.weakPassword,
                    context: "Sign Up - Form Validation"
                )
            } else if !passwordsMatch {
                let error = AppError(
                    title: "Passwords Don't Match",
                    message: "Please make sure both passwords are the same.",
                    type: .validation,
                    retryAction: nil
                )
                errorManager.currentError = error
                errorManager.showError = true
            }
            return
        }

        // Check network connectivity
        guard !networkMonitor.isOfflineMode else {
            errorManager.handle(
                AuthError.networkError,
                context: "Sign Up - Offline"
            )
            return
        }

        isLoading = true

        do {
            // Retry network operation with exponential backoff
            try await RetryManager.retryNetworkOperation {
                try await self.authService.signUp(email: self.email, password: self.password)
            }
            showSuccessMessage("Account created! Please check your email to confirm.")
            clearForm()
        } catch {
            errorManager.handle(error, context: "Sign Up")
        }

        isLoading = false
    }

    /// Sends password reset email
    func resetPassword() async {
        guard isEmailValid else {
            errorManager.handle(
                AuthError.invalidEmail,
                context: "Password Reset - Form Validation"
            )
            return
        }

        // Check network connectivity
        guard !networkMonitor.isOfflineMode else {
            errorManager.handle(
                AuthError.networkError,
                context: "Password Reset - Offline"
            )
            return
        }

        isLoading = true

        do {
            // Retry network operation with exponential backoff
            try await RetryManager.retryNetworkOperation {
                try await self.authService.resetPassword(email: self.email)
            }
            showSuccessMessage("Password reset email sent! Please check your inbox.")
            clearForm()
        } catch {
            errorManager.handle(error, context: "Password Reset")
        }

        isLoading = false
    }

    /// Signs out current user
    func signOut() async {
        isLoading = true

        do {
            try await authService.signOut()
            clearForm()
        } catch {
            errorManager.handle(error, context: "Sign Out")
        }

        isLoading = false
    }

    // MARK: - Helper Methods

    /// Clears all form fields
    private func clearForm() {
        email = ""
        password = ""
        confirmPassword = ""
    }

    /// Shows success message with alert
    private func showSuccessMessage(_ message: String) {
        successMessage = message
        showSuccess = true
    }

    /// Dismisses success alert
    func dismissSuccess() {
        showSuccess = false
        successMessage = nil
    }
}
