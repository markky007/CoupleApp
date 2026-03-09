# Couple Quest - Architecture Documentation

## Project Structure

```
coupleapp/
├── Core/               # Configuration and utilities
│   ├── SupabaseConfig.swift    # Supabase client configuration
│   └── AppConstants.swift      # Application-wide constants
│
├── Models/             # Data models
│   ├── Profile.swift           # User profile model
│   ├── Quest.swift             # Quest/task model
│   ├── Reward.swift            # Reward catalog model
│   ├── Event.swift             # Special events model
│   └── Transaction.swift       # Transaction history model
│
├── Services/           # Backend service layer
│   ├── AuthService.swift           # Authentication and session management
│   ├── ProfileService.swift        # Profile and partner pairing
│   ├── QuestService.swift          # Quest CRUD and completion
│   ├── RewardService.swift         # Reward catalog and redemption
│   ├── EventService.swift          # Event management
│   ├── TransactionService.swift    # Transaction history
│   └── NotificationService.swift   # Local notifications
│
├── ViewModels/         # Business logic layer (MVVM)
│   ├── AuthViewModel.swift         # Authentication flow logic
│   ├── ProfileViewModel.swift      # Profile management logic
│   ├── QuestViewModel.swift        # Quest board logic
│   ├── RewardViewModel.swift       # Reward shop logic
│   ├── EventViewModel.swift        # Event management logic
│   └── DashboardViewModel.swift    # Dashboard aggregation
│
└── Views/              # SwiftUI views
    ├── Authentication/
    │   ├── LoginView.swift
    │   ├── SignUpView.swift
    │   └── ForgotPasswordView.swift
    ├── Dashboard/
    │   └── DashboardView.swift
    ├── Profile/
    ├── Quests/
    ├── Rewards/
    ├── Events/
    └── Components/

```

## Architecture Pattern: MVVM

### Models
- Pure data structures
- Conform to `Identifiable` and `Codable`
- Use `CodingKeys` for snake_case ↔ camelCase conversion
- Immutable where possible

### Services
- Handle all backend communication
- Use async/await for network operations
- Singleton pattern where appropriate
- Proper error handling with custom error types

### ViewModels
- `@MainActor` for thread-safe UI updates
- `ObservableObject` with `@Published` properties
- Business logic and state management
- No direct UI code

### Views
- Pure SwiftUI views
- Minimal business logic
- Use `@StateObject` for ViewModels
- Extract reusable components

## Key Principles

1. **Separation of Concerns**: Each layer has a single responsibility
2. **Thread Safety**: All UI updates on main thread via @MainActor
3. **Error Handling**: Comprehensive error types and user-friendly messages
4. **Performance**: Async operations, caching, efficient queries
5. **Security**: RLS policies, input validation, secure session management
6. **Testability**: Dependency injection, mockable services

## Guidelines

### Models
- All models should conform to `Identifiable` and `Codable`
- Use `CodingKeys` enum for snake_case to camelCase conversion
- Include validation rules as comments
- Keep models immutable where possible (use `let` for IDs)

### Services
- Use async/await for all network operations
- Handle errors with proper error types
- Use @MainActor for services that update UI state
- Implement proper cleanup in deinit
- Follow single responsibility principle

### ViewModels
- All ViewModels should be @MainActor ObservableObject
- Use @Published for properties that update UI
- Keep ViewModels focused on business logic, not UI
- Handle loading states and errors
- Clean up subscriptions in deinit

### Views
- Keep views focused on UI only
- Use ViewModels for business logic
- Extract reusable components
- Use proper accessibility labels
- Follow SwiftUI best practices
