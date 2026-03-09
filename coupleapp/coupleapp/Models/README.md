# Models

This directory contains all data models used in the Couple Quest application.

## Structure

- `Profile.swift` - User profile model
- `Quest.swift` - Quest/task model with status
- `Reward.swift` - Reward catalog model
- `Event.swift` - Special events and anniversaries
- `Transaction.swift` - Point transaction history

## Guidelines

- All models should conform to `Identifiable` and `Codable`
- Use `CodingKeys` enum for snake_case to camelCase conversion
- Include validation rules as comments
- Keep models immutable where possible (use `let` for IDs)
