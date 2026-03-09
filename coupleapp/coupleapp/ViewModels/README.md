# ViewModels

This directory contains all ViewModel classes following MVVM architecture.

## Structure

- `AuthViewModel.swift` - Authentication flow business logic
- `ProfileViewModel.swift` - Profile management logic
- `QuestViewModel.swift` - Quest board business logic
- `RewardViewModel.swift` - Reward shop logic
- `EventViewModel.swift` - Event management logic
- `DashboardViewModel.swift` - Dashboard data aggregation

## Guidelines

- All ViewModels should be @MainActor ObservableObject
- Use @Published for properties that update UI
- Keep ViewModels focused on business logic, not UI
- Handle loading states and errors
- Clean up subscriptions in deinit
