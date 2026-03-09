import Foundation
import SwiftUI
import Combine

/// ViewModel for authentication flows
/// Handles business logic for login, signup, and password reset
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
    
    /// Error message to display
    @Published var errorMessage: String?
    
    /// Success message to display
    @Published var successMessage: String?
    
    /// Whether to show error alert
    @Published var showError = false
    
    /// Whether to show success alert
    @Published var showSuccess = false
    
    // MARK: - Dependencies
    
    private let authService = AuthService.shared
    
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
            showErrorMessage("Please enter email and password")
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            try await authService.signIn(email: email, password: password)
            // Success - session will be updated automatically
            clearForm()
        } catch {
            showErrorMessage(error.localizedDescription)
        }
        
        isLoading = false
    }
    
    /// Signs up new user with email and password
    func signUp() async {
        guard canSignUp else {
            if !isEmailValid {
                showErrorMessage("Please enter a valid email address")
            } else if !isPasswordValid {
                showErrorMessage("Password must be at least \(AppConstants.minPasswordLength) characters")
            } else if !passwordsMatch {
                showErrorMessage("Passwords do not match")
            }
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            try await authService.signUp(email: email, password: password)
            showSuccessMessage("Account created! Please check your email to confirm.")
            clearForm()
        } catch {
            showErrorMessage(error.localizedDescription)
        }
        
        isLoading = false
    }
    
    /// Sends password reset email
    func resetPassword() async {
        guard isEmailValid else {
            showErrorMessage("Please enter a valid email address")
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            try await authService.resetPassword(email: email)
            showSuccessMessage("Password reset email sent! Please check your inbox.")
            clearForm()
        } catch {
            showErrorMessage(error.localizedDescription)
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
            showErrorMessage(error.localizedDescription)
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
    
    /// Shows error message with alert
    private func showErrorMessage(_ message: String) {
        errorMessage = message
        showError = true
    }
    
    /// Shows success message with alert
    private func showSuccessMessage(_ message: String) {
        successMessage = message
        showSuccess = true
    }
    
    /// Dismisses error alert
    func dismissError() {
        showError = false
        errorMessage = nil
    }
    
    /// Dismisses success alert
    func dismissSuccess() {
        showSuccess = false
        successMessage = nil
    }
}
