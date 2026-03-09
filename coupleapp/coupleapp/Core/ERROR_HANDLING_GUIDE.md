# Error Handling System Guide

## Overview

The Couple Quest app implements a comprehensive, centralized error handling system that provides:

- **User-friendly error messages** - Technical errors are mapped to clear, actionable messages
- **Retry logic** - Automatic retry with exponential backoff for transient failures
- **Network monitoring** - Real-time connection status with offline mode indicators
- **Centralized management** - Single source of truth for error handling via ErrorManager
- **Error logging** - Debug-friendly error history for troubleshooting

## Architecture

### Core Components

1. **ErrorManager** (`ErrorManager.swift`)
   - Centralized error handling and alert management
   - Maps technical errors to user-friendly AppError types
   - Maintains error log for debugging
   - Singleton pattern for app-wide access

2. **NetworkMonitor** (`NetworkMonitor.swift`)
   - Real-time network connectivity monitoring
   - Detects connection type (WiFi, cellular, etc.)
   - Provides offline mode detection
   - Uses Apple's Network framework

3. **RetryManager** (`RetryManager.swift`)
   - Implements retry logic with exponential backoff
   - Configurable retry attempts and delays
   - Automatic detection of retryable errors
   - Actor-based for thread safety

4. **ErrorAlertView** (`ErrorAlertView.swift`)
   - Reusable error display component
   - Supports retry actions
   - Consistent UI across the app
   - View modifier for easy integration

5. **ConnectionStatusView** (`ConnectionStatusView.swift`)
   - Banner showing connection status
   - Appears when offline
   - Animated indicator
   - View modifier for easy integration

## Usage

### Basic Error Handling

```swift
// In a ViewModel
@MainActor
class MyViewModel: ObservableObject {
    private let errorManager = ErrorManager.shared

    func performOperation() async {
        do {
            try await someOperation()
        } catch {
            // Centralized error handling
            errorManager.handle(error, context: "My Operation")
        }
    }
}
```

### With Retry Logic

```swift
func fetchData() async {
    do {
        // Automatically retries on network failures
        let data = try await RetryManager.retryNetworkOperation {
            try await service.fetchData()
        }
    } catch {
        errorManager.handle(error, context: "Fetch Data")
    }
}
```

### Check Network Status

```swift
@MainActor
class MyViewModel: ObservableObject {
    private let networkMonitor = NetworkMonitor.shared
    private let errorManager = ErrorManager.shared

    func performNetworkOperation() async {
        // Check if offline before attempting operation
        guard !networkMonitor.isOfflineMode else {
            errorManager.handle(
                AuthError.networkError,
                context: "Operation - Offline"
            )
            return
        }

        // Proceed with operation
        // ...
    }
}
```

### Add Error Handling to Views

```swift
struct MyView: View {
    var body: some View {
        VStack {
            // Your content
        }
        .errorAlert()  // Adds centralized error handling
        .connectionStatus()  // Adds connection status banner
    }
}
```

## Error Types

### AppError

The unified error type used throughout the app:

```swift
struct AppError {
    let title: String        // Error title for display
    let message: String      // User-friendly message
    let type: ErrorType      // Category of error
    let retryAction: (() async -> Void)?  // Optional retry
}
```

### Error Categories

- **authentication** - Login, signup, session errors
- **network** - Connection, timeout, server errors
- **validation** - Input validation, constraint violations
- **insufficientPoints** - Not enough points for redemption
- **permission** - Notification, location permissions
- **unknown** - Unexpected errors

### Service-Specific Errors

Each service defines its own error enum:

- `AuthError` - Authentication errors
- `QuestError` - Quest operation errors
- `RewardError` - Reward operation errors
- `ProfileError` - Profile operation errors
- `EventError` - Event operation errors
- `NotificationError` - Notification errors

These are automatically mapped to `AppError` by ErrorManager.

## Retry Configuration

### Predefined Configurations

```swift
// Default: 3 attempts, 1s initial delay
RetryConfig.default

// Aggressive: 5 attempts, 0.5s initial delay
RetryConfig.aggressive

// Conservative: 2 attempts, 2s initial delay
RetryConfig.conservative
```

### Custom Configuration

```swift
let config = RetryConfig(
    maxAttempts: 4,
    initialDelay: 1.5,
    maxDelay: 20.0,
    multiplier: 2.5
)

try await RetryManager.retry(config: config) {
    try await operation()
}
```

### Retryable Errors

The system automatically identifies retryable errors:

- Network timeouts
- Connection failures
- DNS lookup failures
- Temporary server errors
- "Try again" messages

## Network Monitoring

### Connection Status

```swift
let monitor = NetworkMonitor.shared

// Check connection
if monitor.isConnected {
    // Online
}

// Check connection type
switch monitor.connectionType {
case .wifi:
    // WiFi connection
case .cellular:
    // Cellular connection
case .wired:
    // Wired connection
case .unknown:
    // Unknown connection
}

// Check if expensive (cellular data)
if monitor.isExpensive {
    // Warn user about data usage
}
```

### Offline Mode

```swift
if networkMonitor.isOfflineMode {
    // Show cached data
    // Disable network operations
    // Queue operations for later
}
```

## Error Logging

### View Error Log

```swift
let errorManager = ErrorManager.shared

// Access error log
for entry in errorManager.errorLog {
    print("\(entry.formattedTimestamp): \(entry.error.title)")
    if let context = entry.context {
        print("  Context: \(context)")
    }
}
```

### Clear Error Log

```swift
errorManager.clearErrorLog()
```

## Best Practices

### 1. Always Provide Context

```swift
// Good
errorManager.handle(error, context: "Quest Completion")

// Bad
errorManager.handle(error)
```

### 2. Check Network Before Operations

```swift
guard !networkMonitor.isOfflineMode else {
    errorManager.handle(AuthError.networkError, context: "Operation")
    return
}
```

### 3. Use Retry for Network Operations

```swift
// Automatically retries transient failures
try await RetryManager.retryNetworkOperation {
    try await service.fetchData()
}
```

### 4. Add View Modifiers to Root Views

```swift
struct ContentView: View {
    var body: some View {
        NavigationStack {
            // Content
        }
        .errorAlert()
        .connectionStatus()
    }
}
```

### 5. Map Custom Errors to AppError

```swift
// In ErrorManager
private func mapCustomError(_ error: CustomError) -> AppError {
    AppError(
        title: "Custom Error",
        message: error.localizedDescription,
        type: .validation,
        retryAction: nil
    )
}
```

## Testing

### Simulate Network Errors

```swift
// In tests, inject a mock NetworkMonitor
class MockNetworkMonitor: NetworkMonitor {
    override var isConnected: Bool { false }
}
```

### Test Retry Logic

```swift
func testRetryLogic() async throws {
    var attempts = 0

    let result = try await RetryManager.retry(
        config: .default,
        shouldRetry: { _ in true }
    ) {
        attempts += 1
        if attempts < 3 {
            throw TestError.transient
        }
        return "Success"
    }

    XCTAssertEqual(attempts, 3)
    XCTAssertEqual(result, "Success")
}
```

### Test Error Handling

```swift
func testErrorHandling() async {
    let errorManager = ErrorManager.shared

    errorManager.handle(
        AuthError.invalidEmail,
        context: "Test"
    )

    XCTAssertTrue(errorManager.showError)
    XCTAssertNotNil(errorManager.currentError)
    XCTAssertEqual(errorManager.errorLog.count, 1)
}
```

## Troubleshooting

### Errors Not Displaying

1. Ensure `.errorAlert()` modifier is added to view
2. Check that ErrorManager.shared is being used
3. Verify error is being handled via `errorManager.handle()`

### Retry Not Working

1. Check that error is retryable (network/transient)
2. Verify retry configuration is appropriate
3. Ensure operation is wrapped in `RetryManager.retry()`

### Connection Status Not Updating

1. Verify NetworkMonitor.shared is initialized
2. Check that `.connectionStatus()` modifier is added
3. Ensure app has network permissions in Info.plist

## Future Enhancements

Potential improvements to the error handling system:

1. **Error Analytics** - Track error frequency and patterns
2. **Offline Queue** - Queue operations when offline, execute when online
3. **Custom Retry Strategies** - Per-operation retry configurations
4. **Error Recovery Actions** - Automatic recovery for specific errors
5. **User Feedback** - Allow users to report errors
6. **Crash Reporting** - Integration with crash reporting services
7. **Error Notifications** - Push notifications for critical errors
8. **Localization** - Multi-language error messages

## Summary

The error handling system provides:

✅ Centralized error management via ErrorManager
✅ User-friendly error messages with clear actions
✅ Automatic retry logic for transient failures
✅ Real-time network monitoring and offline detection
✅ Consistent error UI across the app
✅ Debug-friendly error logging
✅ Easy integration with view modifiers

This creates a robust, user-friendly error handling experience that improves app reliability and user satisfaction.
