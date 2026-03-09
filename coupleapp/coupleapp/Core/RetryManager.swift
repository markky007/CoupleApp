import Foundation

/// Manages retry logic for transient failures
/// Implements exponential backoff with configurable attempts
actor RetryManager {

    // MARK: - Configuration

    struct RetryConfig {
        let maxAttempts: Int
        let initialDelay: TimeInterval
        let maxDelay: TimeInterval
        let multiplier: Double

        static let `default` = RetryConfig(
            maxAttempts: 3,
            initialDelay: 1.0,
            maxDelay: 10.0,
            multiplier: 2.0
        )

        static let aggressive = RetryConfig(
            maxAttempts: 5,
            initialDelay: 0.5,
            maxDelay: 5.0,
            multiplier: 1.5
        )

        static let conservative = RetryConfig(
            maxAttempts: 2,
            initialDelay: 2.0,
            maxDelay: 15.0,
            multiplier: 3.0
        )
    }

    // MARK: - Retry Logic

    /// Executes an operation with retry logic
    /// - Parameters:
    ///   - config: Retry configuration
    ///   - shouldRetry: Closure to determine if error is retryable
    ///   - operation: The operation to execute
    /// - Returns: Result of the operation
    /// - Throws: The last error if all retries fail
    static func retry<T>(
        config: RetryConfig = .default,
        shouldRetry: ((Error) -> Bool)? = nil,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        var lastError: Error?
        var delay = config.initialDelay

        for attempt in 1...config.maxAttempts {
            do {
                let result = try await operation()

                // Success - log if this was a retry
                if attempt > 1 {
                    print("✅ Operation succeeded on attempt \(attempt)")
                }

                return result
            } catch {
                lastError = error

                // Check if we should retry this error
                if let shouldRetry = shouldRetry, !shouldRetry(error) {
                    print("❌ Error is not retryable: \(error.localizedDescription)")
                    throw error
                }

                // Check if we have more attempts
                if attempt < config.maxAttempts {
                    print(
                        "⚠️ Attempt \(attempt) failed, retrying in \(delay)s: \(error.localizedDescription)"
                    )

                    // Wait before retrying
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))

                    // Calculate next delay with exponential backoff
                    delay = min(delay * config.multiplier, config.maxDelay)
                } else {
                    print("❌ All \(config.maxAttempts) attempts failed")
                }
            }
        }

        // All retries failed
        throw lastError ?? RetryError.allAttemptsFailed
    }

    /// Determines if an error is retryable (network/transient errors)
    static func isRetryable(_ error: Error) -> Bool {
        // Check for network errors
        let nsError = error as NSError

        // Network domain errors are usually retryable
        if nsError.domain == NSURLErrorDomain {
            switch nsError.code {
            case NSURLErrorTimedOut,
                NSURLErrorCannotConnectToHost,
                NSURLErrorNetworkConnectionLost,
                NSURLErrorDNSLookupFailed,
                NSURLErrorNotConnectedToInternet:
                return true
            default:
                return false
            }
        }

        // Check error description for transient keywords
        let description = error.localizedDescription.lowercased()
        let transientKeywords = [
            "timeout",
            "connection",
            "network",
            "temporary",
            "unavailable",
            "try again",
        ]

        return transientKeywords.contains { description.contains($0) }
    }
}

// MARK: - RetryError

enum RetryError: LocalizedError {
    case allAttemptsFailed
    case operationCancelled

    var errorDescription: String? {
        switch self {
        case .allAttemptsFailed:
            return "Operation failed after multiple attempts"
        case .operationCancelled:
            return "Operation was cancelled"
        }
    }
}

// MARK: - Convenience Extensions

extension RetryManager {
    /// Retries a network operation with default configuration
    static func retryNetworkOperation<T>(
        operation: @escaping () async throws -> T
    ) async throws -> T {
        try await retry(
            config: .default,
            shouldRetry: isRetryable,
            operation: operation
        )
    }

    /// Retries a critical operation with aggressive configuration
    static func retryCriticalOperation<T>(
        operation: @escaping () async throws -> T
    ) async throws -> T {
        try await retry(
            config: .aggressive,
            shouldRetry: isRetryable,
            operation: operation
        )
    }
}
