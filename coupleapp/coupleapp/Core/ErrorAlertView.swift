import SwiftUI

/// Reusable error alert view with retry support
/// Displays user-friendly error messages with appropriate icons and actions
struct ErrorAlertView: View {
    let error: AppError
    let onDismiss: () -> Void
    let onRetry: (() async -> Void)?

    @State private var isRetrying = false

    var body: some View {
        VStack(spacing: 20) {
            // Error icon
            ZStack {
                Circle()
                    .fill(error.color.opacity(0.2))
                    .frame(width: 80, height: 80)

                Image(systemName: error.icon)
                    .font(.system(size: 36))
                    .foregroundColor(error.color)
            }

            // Error title
            Text(error.title)
                .font(.title2)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)

            // Error message
            Text(error.message)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            // Actions
            VStack(spacing: 12) {
                // Retry button (if available)
                if let retryAction = onRetry {
                    Button {
                        Task {
                            isRetrying = true
                            await retryAction()
                            isRetrying = false
                        }
                    } label: {
                        HStack {
                            if isRetrying {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "arrow.clockwise")
                                Text("Try Again")
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(
                        GradientButtonStyle(
                            gradient: AppTheme.primaryGradient,
                            isDisabled: isRetrying
                        )
                    )
                    .disabled(isRetrying)
                }

                // Dismiss button
                Button {
                    onDismiss()
                } label: {
                    Text(onRetry == nil ? "OK" : "Cancel")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(24)
        .background(Color(.systemBackground))
        .cornerRadius(AppTheme.cornerRadiusLarge)
        .shadow(color: AppTheme.shadowColor, radius: 20, x: 0, y: 10)
        .padding(.horizontal, 32)
    }
}

// MARK: - View Modifier

/// View modifier to display error alerts using ErrorManager
struct ErrorAlertModifier: ViewModifier {
    @ObservedObject var errorManager = ErrorManager.shared

    func body(content: Content) -> some View {
        content
            .overlay {
                if errorManager.showError, let error = errorManager.currentError {
                    ZStack {
                        // Dimmed background
                        Color.black.opacity(0.4)
                            .ignoresSafeArea()
                            .onTapGesture {
                                errorManager.dismissError()
                            }

                        // Error alert
                        ErrorAlertView(
                            error: error,
                            onDismiss: {
                                errorManager.dismissError()
                            },
                            onRetry: error.retryAction
                        )
                        .transition(.scale.combined(with: .opacity))
                    }
                    .animation(
                        .spring(response: 0.3, dampingFraction: 0.8), value: errorManager.showError)
                }
            }
    }
}

extension View {
    /// Adds error alert handling to the view
    func errorAlert() -> some View {
        modifier(ErrorAlertModifier())
    }
}

#Preview("Network Error") {
    ErrorAlertView(
        error: AppError(
            title: "Connection Error",
            message:
                "Unable to connect to the server. Please check your internet connection and try again.",
            type: .network,
            retryAction: {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        ),
        onDismiss: {},
        onRetry: {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
        }
    )
}

#Preview("Validation Error") {
    ErrorAlertView(
        error: AppError(
            title: "Invalid Input",
            message: "Quest title must be between 1 and 200 characters.",
            type: .validation,
            retryAction: nil
        ),
        onDismiss: {},
        onRetry: nil
    )
}
