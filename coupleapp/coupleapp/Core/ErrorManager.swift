import Combine
import Foundation
import SwiftUI

/// Centralized error handling and alert management system
/// Provides user-friendly error messages and retry logic
@MainActor
class ErrorManager: ObservableObject {

    // MARK: - Singleton

    static let shared = ErrorManager()

    // MARK: - Published Properties

    /// Current error to display
    @Published var currentError: AppError?

    /// Whether to show error alert
    @Published var showError = false

    /// Error history for debugging
    @Published private(set) var errorLog: [ErrorLogEntry] = []

    // MARK: - Private Properties

    private let maxLogEntries = 50

    // MARK: - Initialization

    private init() {}

    // MARK: - Error Handling

    /// Handles an error and displays it to the user
    /// - Parameters:
    ///   - error: The error to handle
    ///   - context: Optional context about where the error occurred
    func handle(_ error: Error, context: String? = nil) {
        let appError = mapToAppError(error, context: context)
        currentError = appError
        showError = true

        // Log error
        logError(appError, context: context)

        // Print to console for debugging
        print("❌ Error: \(appError.title) - \(appError.message)")
        if let context = context {
            print("   Context: \(context)")
        }
    }

    /// Maps any error to an AppError with user-friendly messages
    private func mapToAppError(_ error: Error, context: String?) -> AppError {
        // Check if already an AppError
        if let appError = error as? AppError {
            return appError
        }

        // Map known error types
        if let authError = error as? AuthError {
            return mapAuthError(authError)
        } else if let questError = error as? QuestError {
            return mapQuestError(questError)
        } else if let rewardError = error as? RewardError {
            return mapRewardError(rewardError)
        } else if let profileError = error as? ProfileError {
            return mapProfileError(profileError)
        } else if let eventError = error as? EventError {
            return mapEventError(eventError)
        } else if let notificationError = error as? NotificationError {
            return mapNotificationError(notificationError)
        }

        // Check for network errors
        if isNetworkError(error) {
            return AppError(
                title: "Connection Error",
                message:
                    "Unable to connect to the server. Please check your internet connection and try again.",
                type: .network,
                retryAction: nil
            )
        }

        // Generic error
        return AppError(
            title: "Something Went Wrong",
            message: error.localizedDescription,
            type: .unknown,
            retryAction: nil
        )
    }

    // MARK: - Error Mapping

    private func mapAuthError(_ error: AuthError) -> AppError {
        let message = error.errorDescription ?? "Authentication failed"
        // Check if it's a network error by examining the error description
        let isNetworkError =
            message.lowercased().contains("network") || message.lowercased().contains("connection")
        let type: AppError.ErrorType = isNetworkError ? .network : .authentication

        return AppError(
            title: "Authentication Error",
            message: message,
            type: type,
            retryAction: nil
        )
    }

    private func mapQuestError(_ error: QuestError) -> AppError {
        let message = error.errorDescription ?? "Quest operation failed"
        var type: AppError.ErrorType = .validation

        switch error {
        case .fetchFailed, .creationFailed, .completionFailed, .deletionFailed:
            type = .network
        case .alreadyCompleted, .questExpired:
            type = .validation
        default:
            type = .unknown
        }

        return AppError(
            title: "Quest Error",
            message: message,
            type: type,
            retryAction: nil
        )
    }

    private func mapRewardError(_ error: RewardError) -> AppError {
        let message = error.errorDescription ?? "Reward operation failed"
        var type: AppError.ErrorType = .validation

        switch error {
        case .insufficientPoints, .insufficientPointsGeneric:
            type = .insufficientPoints
        case .fetchFailed, .creationFailed, .redemptionFailed:
            type = .network
        default:
            type = .validation
        }

        return AppError(
            title: "Reward Error",
            message: message,
            type: type,
            retryAction: nil
        )
    }

    private func mapProfileError(_ error: ProfileError) -> AppError {
        let message = error.errorDescription ?? "Profile operation failed"

        return AppError(
            title: "Profile Error",
            message: message,
            type: .network,
            retryAction: nil
        )
    }

    private func mapEventError(_ error: EventError) -> AppError {
        let message = error.errorDescription ?? "Event operation failed"

        return AppError(
            title: "Event Error",
            message: message,
            type: .network,
            retryAction: nil
        )
    }

    private func mapNotificationError(_ error: NotificationError) -> AppError {
        let message = error.errorDescription ?? "Notification operation failed"

        return AppError(
            title: "Notification Error",
            message: message,
            type: .permission,
            retryAction: nil
        )
    }

    // MARK: - Network Detection

    private func isNetworkError(_ error: Error) -> Bool {
        let nsError = error as NSError

        // Check for common network error codes
        if nsError.domain == NSURLErrorDomain {
            return true
        }

        // Check error description for network-related keywords
        let description = error.localizedDescription.lowercased()
        return description.contains("network") || description.contains("connection")
            || description.contains("internet") || description.contains("offline")
            || description.contains("timeout")
    }

    // MARK: - Error Logging

    private func logError(_ error: AppError, context: String?) {
        let entry = ErrorLogEntry(
            error: error,
            context: context,
            timestamp: Date()
        )

        errorLog.insert(entry, at: 0)

        // Limit log size
        if errorLog.count > maxLogEntries {
            errorLog.removeLast()
        }
    }

    /// Clears the error log
    func clearErrorLog() {
        errorLog.removeAll()
        print("🗑️ Error log cleared")
    }

    // MARK: - Dismissal

    /// Dismisses the current error
    func dismissError() {
        showError = false
        currentError = nil
    }
}

// MARK: - AppError

/// Unified error type for the application
struct AppError: Error, Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let type: ErrorType
    let retryAction: (() async -> Void)?

    enum ErrorType {
        case authentication
        case network
        case validation
        case insufficientPoints
        case permission
        case unknown
    }

    /// Whether this error supports retry
    var canRetry: Bool {
        retryAction != nil
    }

    /// Icon for the error type
    var icon: String {
        switch type {
        case .authentication:
            return "person.crop.circle.badge.exclamationmark"
        case .network:
            return "wifi.exclamationmark"
        case .validation:
            return "exclamationmark.triangle"
        case .insufficientPoints:
            return "star.slash"
        case .permission:
            return "lock.shield"
        case .unknown:
            return "exclamationmark.circle"
        }
    }

    /// Color for the error type
    var color: Color {
        switch type {
        case .authentication:
            return .orange
        case .network:
            return .red
        case .validation:
            return .yellow
        case .insufficientPoints:
            return .purple
        case .permission:
            return .blue
        case .unknown:
            return .gray
        }
    }
}

// MARK: - ErrorLogEntry

/// Entry in the error log for debugging
struct ErrorLogEntry: Identifiable {
    let id = UUID()
    let error: AppError
    let context: String?
    let timestamp: Date

    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter.string(from: timestamp)
    }
}
