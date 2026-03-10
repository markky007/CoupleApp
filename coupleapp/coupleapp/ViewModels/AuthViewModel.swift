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

    /// Error message to display
    @Published var errorMessage: String?

    /// Whether to show error alert
    @Published var showError = false

    // MARK: - Dependencies

    private let authService = AuthService.shared
    private let profileService = ProfileService.shared
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
            showErrorMessage("Please enter both email and password")
            return
        }

        // Check network connectivity
        guard !networkMonitor.isOfflineMode else {
            showErrorMessage("No internet connection. Please check your network.")
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
        } catch let error as AuthError {
            showErrorMessage(error.localizedDescription)
        } catch {
            showErrorMessage("Failed to sign in: \(error.localizedDescription)")
        }

        isLoading = false
    }

    /// Signs up new user with email and password
    func signUp() async {
        guard canSignUp else {
            if !isEmailValid {
                showErrorMessage("Please enter a valid email address")
            } else if !isPasswordValid {
                showErrorMessage(
                    "Password must be at least \(AppConstants.minPasswordLength) characters")
            } else if !passwordsMatch {
                showErrorMessage("Passwords do not match")
            }
            return
        }

        // Check network connectivity
        guard !networkMonitor.isOfflineMode else {
            showErrorMessage("No internet connection. Please check your network.")
            return
        }

        isLoading = true

        do {
            // Retry network operation with exponential backoff
            try await RetryManager.retryNetworkOperation {
                try await self.authService.signUp(email: self.email, password: self.password)
            }

            // Create profile for the new user
            if let userId = authService.currentUserId {
                // Use email as display name initially
                let displayName = email.components(separatedBy: "@").first ?? "User"
                try await profileService.createProfile(userId: userId, displayName: displayName)
            }

            showSuccessMessage("Account created! Please check your email to confirm.")
            clearForm()
        } catch let error as AuthError {
            showErrorMessage(error.localizedDescription)
        } catch let error as ProfileError {
            showErrorMessage(error.localizedDescription)
        } catch {
            showErrorMessage("Failed to create account: \(error.localizedDescription)")
        }

        isLoading = false
    }

    /// Sends password reset email
    func resetPassword() async {
        guard isEmailValid else {
            showErrorMessage("Please enter a valid email address")
            return
        }

        // Check network connectivity
        guard !networkMonitor.isOfflineMode else {
            showErrorMessage("No internet connection. Please check your network.")
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
        } catch let error as AuthError {
            showErrorMessage(error.localizedDescription)
        } catch {
            showErrorMessage("Failed to send reset email: \(error.localizedDescription)")
        }

        isLoading = false
    }

    /// Signs out current user
    func signOut() async {
        isLoading = true

        do {
            try await authService.signOut()
            clearForm()
        } catch let error as AuthError {
            showErrorMessage(error.localizedDescription)
        } catch {
            showErrorMessage("Failed to sign out: \(error.localizedDescription)")
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

    /// Shows error message with alert
    private func showErrorMessage(_ message: String) {
        errorMessage = message
        showError = true
    }

    /// Dismisses success alert
    func dismissSuccess() {
        showSuccess = false
        successMessage = nil
    }

    /// Dismisses error alert
    func dismissError() {
        showError = false
        errorMessage = nil
    }
}
