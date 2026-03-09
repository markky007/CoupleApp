# 🚀 Quick Reference Guide

## Common Commands

### Build Verification

```bash
# Verify build works
./scripts/verify-build.sh

# Fix common issues (interactive)
./scripts/fix-common-issues.sh

# Clean everything and rebuild
rm -rf ~/Library/Developer/Xcode/DerivedData/*
xcodebuild clean -project coupleapp.xcodeproj -scheme coupleapp
xcodebuild build -project coupleapp.xcodeproj -scheme coupleapp -sdk iphonesimulator
```

### Xcode Shortcuts

- **Build**: `Cmd + B`
- **Clean Build Folder**: `Cmd + Shift + K`
- **Run**: `Cmd + R`
- **Test**: `Cmd + U`
- **Stop**: `Cmd + .`

## Platform-Specific Code Patterns

### iOS-Only Modifiers

```swift
TextField("Email", text: $email)
    #if os(iOS)
    .textInputAutocapitalization(.never)
    .keyboardType(.emailAddress)
    #endif
```

### Platform-Agnostic Colors

```swift
// Define once
private var backgroundColor: Color {
    #if os(iOS)
    return Color(.systemGray6)
    #else
    return Color(NSColor.controlBackgroundColor)
    #endif
}

// Use everywhere
.background(backgroundColor)
```

## Required Imports

### For Views

```swift
import SwiftUI
```

### For ViewModels

```swift
import Foundation
import SwiftUI
import Combine  // For @Published
```

### For Services

```swift
import Foundation
import Supabase
import Combine  // For @Published if ObservableObject
```

### For Models

```swift
import Foundation
```

## Common Error Fixes

| Error                                   | Solution                         |
| --------------------------------------- | -------------------------------- |
| No such module 'Combine'                | Add `import Combine`             |
| No such module 'Supabase'               | Resolve packages in Xcode        |
| textInputAutocapitalization unavailable | Wrap in `#if os(iOS)`            |
| Duplicate output file                   | Remove duplicate README.md files |
| Cannot find type                        | Check imports and spelling       |

## Build Troubleshooting Steps

1. **First Try**: Clean Build Folder (`Cmd + Shift + K`)
2. **Second Try**: Resolve Packages (`File > Packages > Resolve Package Versions`)
3. **Third Try**: Clean DerivedData
   ```bash
   rm -rf ~/Library/Developer/Xcode/DerivedData/*
   ```
4. **Fourth Try**: Run fix script
   ```bash
   ./scripts/fix-common-issues.sh
   ```
5. **Last Resort**: Close Xcode, delete DerivedData, reopen, resolve packages

## File Structure Quick Reference

```
coupleapp/
├── Core/                    # Config & utilities
│   ├── SupabaseConfig.swift
│   └── AppConstants.swift
├── Models/                  # Data models
├── Services/                # Backend services
├── ViewModels/              # Business logic
└── Views/                   # SwiftUI views
    ├── Authentication/
    ├── Dashboard/
    ├── Profile/
    ├── Quests/
    ├── Rewards/
    └── Events/
```

## Git Workflow

```bash
# Before committing
./scripts/verify-build.sh

# If build fails
./scripts/fix-common-issues.sh

# Commit
git add .
git commit -m "Your message"

# Skip build check (not recommended)
git commit --no-verify -m "Your message"
```

## Supabase Commands

```bash
# Start local Supabase
supabase start

# Stop local Supabase
supabase stop

# Reset database
supabase db reset

# Check status
supabase status
```

## Performance Tips

- Use `LazyVStack` for long lists
- Implement pagination for large datasets
- Cache frequently accessed data
- Use `@StateObject` for ViewModels
- Avoid heavy computations in body
- Use `Task` for async operations

## Security Checklist

- [ ] Never commit Supabase service role key
- [ ] Use RLS policies for all tables
- [ ] Validate all user inputs
- [ ] Use HTTPS for all connections
- [ ] Implement proper error handling
- [ ] Log security events

## Testing Quick Commands

```bash
# Run all tests
xcodebuild test -project coupleapp.xcodeproj -scheme coupleapp -destination 'platform=iOS Simulator,name=iPhone 15'

# Run specific test
# In Xcode: Click diamond next to test function
```

## Useful Links

- [SwiftUI Documentation](https://developer.apple.com/documentation/swiftui)
- [Supabase Swift Docs](https://github.com/supabase/supabase-swift)
- [Swift Concurrency](https://docs.swift.org/swift-book/LanguageGuide/Concurrency.html)
- [MVVM Pattern](https://www.hackingwithswift.com/books/ios-swiftui/introducing-mvvm-into-your-swiftui-project)
