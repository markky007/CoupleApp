# Dark Mode Gradients Usage Guide

## Overview

Task 9.2 has added dark mode gradient properties to `AppTheme.swift` to support Requirement 7.7: "THE Theme_System SHALL update all UI components to support both dark and light modes."

## New Properties

### Dark Mode Gradients

Three new gradient properties have been added for dark mode:

1. **`primaryGradientDark`** - Dark mode version of the primary gradient
   - Colors: `#D4145A` → `#8B4A5A`
   - Use for: Main actions and highlights in dark mode

2. **`secondaryGradientDark`** - Dark mode version of the secondary gradient
   - Colors: `#6FA88E` → `#3A8EBA`
   - Use for: Supporting elements in dark mode

3. **`backgroundGradientDark`** - Dark mode version of the background gradient
   - Colors: `#1A1A2E` → `#16213E`
   - Use for: Main screen backgrounds in dark mode

## Adaptive Gradient Helper Function

### `adaptiveGradient(light:dark:colorScheme:)`

A helper function that automatically selects the appropriate gradient based on the current color scheme.

**Parameters:**

- `light: LinearGradient` - The gradient to use in light mode
- `dark: LinearGradient` - The gradient to use in dark mode
- `colorScheme: ColorScheme` - The current color scheme from SwiftUI environment

**Returns:** `LinearGradient` - The appropriate gradient for the current color scheme

## Usage Examples

### Example 1: Using Dark Mode Gradients Directly

```swift
import SwiftUI

struct MyView: View {
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack {
            Text("Hello, World!")
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            colorScheme == .dark
                ? AppTheme.primaryGradientDark
                : AppTheme.primaryGradient
        )
    }
}
```

### Example 2: Using the Adaptive Gradient Helper

```swift
import SwiftUI

struct MyAdaptiveView: View {
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack {
            Text("Adaptive Gradient")
                .foregroundColor(.white)
                .font(AppTheme.headline())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            AppTheme.adaptiveGradient(
                light: AppTheme.primaryGradient,
                dark: AppTheme.primaryGradientDark,
                colorScheme: colorScheme
            )
        )
    }
}
```

### Example 3: Using with Background Gradients

```swift
import SwiftUI

struct BackgroundView: View {
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ZStack {
            // Adaptive background gradient
            AppTheme.adaptiveGradient(
                light: AppTheme.backgroundGradient,
                dark: AppTheme.backgroundGradientDark,
                colorScheme: colorScheme
            )
            .ignoresSafeArea()

            // Content
            VStack {
                Text("Content Here")
                    .foregroundColor(AppTheme.primaryText)
            }
        }
    }
}
```

### Example 4: Using with Buttons

```swift
import SwiftUI

struct GradientButton: View {
    @Environment(\.colorScheme) var colorScheme
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(AppTheme.headline())
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    AppTheme.adaptiveGradient(
                        light: AppTheme.secondaryGradient,
                        dark: AppTheme.secondaryGradientDark,
                        colorScheme: colorScheme
                    )
                )
                .cornerRadius(AppTheme.cornerRadiusMedium)
        }
    }
}
```

## Best Practices

1. **Always use `@Environment(\.colorScheme)`** to get the current color scheme
2. **Use the adaptive gradient helper** for cleaner code when switching between light and dark gradients
3. **Test in both light and dark modes** to ensure proper contrast and visibility
4. **Use semantic colors** from AppTheme for text and backgrounds to ensure proper adaptation
5. **Consider accessibility** - ensure text has sufficient contrast in both modes

## Testing

Tests have been added in `coupleapp/Tests/AppThemeDarkModeTests.swift` to verify:

- All dark mode gradients are defined
- The adaptive gradient helper function works correctly
- The function returns the correct gradient based on color scheme

## Related Requirements

This implementation satisfies:

- **Requirement 7.7**: "THE Theme_System SHALL update all UI components to support both dark and light modes"
- **Requirement 7.8**: "THE Theme_System SHALL ensure text contrast ratios meet accessibility standards in both modes"

## Next Steps

To fully implement dark mode support across the app:

1. Update existing views to use adaptive gradients (Task 19.2)
2. Write property tests for color contrast (Task 9.3)
3. Test all views in both light and dark mode (Task 19.2)
4. Ensure navigation bars use adaptive colors (Task 21.2)
