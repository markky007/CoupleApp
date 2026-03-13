import Combine
import Foundation
import Supabase

/// Authentication service managing user sessions and auth operations
/// Implements singleton pattern for consistent session state across the app
/// All methods are @MainActor to ensure UI updates happen on main thread
@MainActor
class AuthService: ObservableObject {

    // MARK: - Singleton

    /// Shared instance for app-wide access
    static let shared = AuthService()

    // MARK: - Published Properties

    /// Current authentication session
    /// Nil when user is not authenticated
    @Published private(set) var session: Session?

    /// Current authenticated user
    /// Convenience property derived from session
    var currentUser: User? {
        session?.user
    }

    /// Whether user is currently authenticated
    var isAuthenticated: Bool {
        session != nil
    }

    /// Current user ID (convenience accessor)
    var currentUserId: UUID? {
        session?.user.id
    }

    // MARK: - Private Properties

    /// Task for listening to auth state changes
    private var authStateTask: Task<Void, Never>?

    // MARK: - Initialization

    private init() {
        // Start listening to auth state changes
        startAuthStateListener()
    }

    deinit {
        // Cancel auth state listener when service is deallocated
        authStateTask?.cancel()
    }

    // MARK: - Auth State Management

    /// Starts listening to authentication state changes
    /// Automatically updates session when user signs in/out
    private func startAuthStateListener() {
        authStateTask = Task {
            // Get initial session
            do {
                self.session = try await supabase.auth.session
                print(
                    "🔐 Initial session loaded: \(self.session != nil ? "authenticated" : "not authenticated")"
                )
            } catch {
                // No active session on startup
                self.session = nil
                print("🔐 No initial session found")
            }

            // Listen for auth state changes
            for await authEvent in supabase.auth.authStateChanges {
                // Update session on main thread
                await MainActor.run {
                    print("📡 Auth state changed: \(authEvent.event.rawValue)")
                    self.session = authEvent.session
                    print(
                        "🔐 Session updated: \(self.session != nil ? "authenticated" : "not authenticated")"
                    )
                }
            }
        }
    }

    // MARK: - Authentication Methods

    /// Signs up a new user with email and password
    /// - Parameters:
    ///   - email: User's email address
    ///   - password: User's password (minimum 6 characters)
    /// - Throws: AuthError if signup fails
    /// - Note: User may need to confirm email before signing in
    func signUp(email: String, password: String) async throws {
        // Validate inputs
        guard !email.isEmpty else {
            throw AuthError.invalidEmail
        }

        guard password.count >= AppConstants.minPasswordLength else {
            throw AuthError.weakPassword
        }

        // Attempt signup
        do {
            let response = try await supabase.auth.signUp(
                email: email,
                password: password
            )

            // Session is automatically updated via auth state listener
            print("✅ Sign up successful for: \(email)")

            // Check if email confirmation is required
            if response.session == nil {
                print("📧 Email confirmation required")
            }
        } catch {
            print("❌ Sign up failed: \(error.localizedDescription)")
            throw AuthError.signUpFailed(error.localizedDescription)
        }
    }

    /// Signs in an existing user with email and password
    /// - Parameters:
    ///   - email: User's email address
    ///   - password: User's password
    /// - Throws: AuthError if sign in fails
    func signIn(email: String, password: String) async throws {
        // Validate inputs
        guard !email.isEmpty else {
            throw AuthError.invalidEmail
        }

        guard !password.isEmpty else {
            throw AuthError.invalidPassword
        }

        // Attempt sign in
        do {
            print("🔐 Attempting sign in for: \(email)")

            let response = try await supabase.auth.signIn(
                email: email,
                password: password
            )

            // Session is automatically updated via auth state listener
            print("✅ Sign in successful for: \(email)")
            print("👤 User ID: \(response.user.id.uuidString)")
        } catch {
            print("❌ Sign in failed: \(error.localizedDescription)")
            print("❌ Error type: \(type(of: error))")

            // Check if error is due to invalid credentials
            let errorMessage = error.localizedDescription.lowercased()
            if errorMessage.contains("invalid") || errorMessage.contains("credentials") {
                throw AuthError.signInFailed("Invalid email or password")
            }

            throw AuthError.signInFailed(error.localizedDescription)
        }
    }

    /// Signs out the current user
    /// - Throws: AuthError if sign out fails
    func signOut() async throws {
        guard session != nil else {
            // Already signed out
            return
        }

        do {
            // First, clear the session from Supabase
            try await supabase.auth.signOut()

            // Wait a moment for Supabase to process the logout
            try await Task.sleep(nanoseconds: 500_000_000)  // 0.5 seconds

            // Explicitly clear session on main thread
            await MainActor.run {
                self.session = nil
            }

            print("✅ Sign out successful - session cleared")
        } catch {
            print("❌ Sign out failed: \(error.localizedDescription)")
            throw AuthError.signOutFailed(error.localizedDescription)
        }
    }

    /// Sends a password reset email to the user
    /// - Parameter email: User's email address
    /// - Throws: AuthError if password reset request fails
    func resetPassword(email: String) async throws {
        guard !email.isEmpty else {
            throw AuthError.invalidEmail
        }

        do {
            try await supabase.auth.resetPasswordForEmail(email)
            print("✅ Password reset email sent to: \(email)")
        } catch {
            print("❌ Password reset failed: \(error.localizedDescription)")
            throw AuthError.passwordResetFailed(error.localizedDescription)
        }
    }

    /// Refreshes the current session
    /// Useful for ensuring session is still valid
    /// - Throws: AuthError if refresh fails
    func refreshSession() async throws {
        do {
            // Try to refresh the session
            let newSession = try await supabase.auth.session

            // Update session on main thread
            await MainActor.run {
                self.session = newSession
            }

            print("✅ Session refreshed")
        } catch {
            print("❌ Session refresh failed: \(error.localizedDescription)")

            // If session refresh fails, clear the session
            await MainActor.run {
                self.session = nil
            }

            throw AuthError.sessionRefreshFailed(error.localizedDescription)
        }
    }
}

// MARK: - AuthError

/// Custom error types for authentication operations
enum AuthError: LocalizedError {
    case invalidEmail
    case invalidPassword
    case weakPassword
    case emailNotConfirmed
    case signUpFailed(String)
    case signInFailed(String)
    case signOutFailed(String)
    case passwordResetFailed(String)
    case sessionRefreshFailed(String)
    case networkError

    var errorDescription: String? {
        switch self {
        case .invalidEmail:
            return "Please enter a valid email address"
        case .invalidPassword:
            return "Please enter your password"
        case .weakPassword:
            return "Password must be at least \(AppConstants.minPasswordLength) characters"
        case .emailNotConfirmed:
            return "Please confirm your email address"
        case .signUpFailed(let message):
            return "Sign up failed: \(message)"
        case .signInFailed(let message):
            return "Sign in failed: \(message)"
        case .signOutFailed(let message):
            return "Sign out failed: \(message)"
        case .passwordResetFailed(let message):
            return "Password reset failed: \(message)"
        case .sessionRefreshFailed(let message):
            return "Session refresh failed: \(message)"
        case .networkError:
            return "Network connection failed. Please check your internet connection."
        }
    }
}
