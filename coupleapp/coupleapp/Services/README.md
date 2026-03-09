# Services

This directory contains all service classes that interact with Supabase backend.

## Structure

- `AuthService.swift` - Authentication and session management
- `ProfileService.swift` - User profile and partner pairing operations
- `QuestService.swift` - Quest CRUD and completion logic
- `RewardService.swift` - Reward catalog and redemption
- `EventService.swift` - Event management and countdown calculations
- `TransactionService.swift` - Transaction history queries
- `NotificationService.swift` - Local notification scheduling

## Guidelines

- Use async/await for all network operations
- Handle errors with proper error types
- Use @MainActor for services that update UI state
- Implement proper cleanup in deinit
- Follow single responsibility principle
