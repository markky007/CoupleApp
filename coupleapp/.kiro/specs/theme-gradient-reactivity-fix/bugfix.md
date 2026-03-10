# Bugfix Requirements Document

## Introduction

The theme selection feature currently fails to update gradient backgrounds and component styling across most screens when users switch between Light and Dark themes in Settings. While text colors update correctly and Profile/Settings screens respond properly, other screens (Dashboard, Login, SignUp, etc.) retain their original gradient styling regardless of theme selection. This creates an inconsistent user experience where theme changes appear incomplete or broken.

The root cause is that affected views rely on SwiftUI's `@Environment(\.colorScheme)` which reflects the system color scheme rather than the app's custom theme selection managed by `ThemeManager`. The `preferredColorScheme` modifier doesn't trigger re-renders in child views when `ThemeManager.currentTheme` changes.

## Bug Analysis

### Current Behavior (Defect)

1.1 WHEN a user selects Dark theme in Settings AND navigates to Dashboard, Login, or other non-Profile/Settings screens THEN the system displays light gradients and component backgrounds instead of dark gradients

1.2 WHEN a user selects Light theme in Settings AND navigates to Dashboard, Login, or other non-Profile/Settings screens that were previously showing dark gradients THEN the system displays dark gradients instead of light gradients

1.3 WHEN a user switches theme in Settings AND views use `@Environment(\.colorScheme)` to determine gradient styling THEN the system does not trigger view re-renders and gradients remain unchanged

### Expected Behavior (Correct)

2.1 WHEN a user selects Dark theme in Settings AND navigates to any screen (Dashboard, Login, SignUp, etc.) THEN the system SHALL display dark gradients and dark-themed component backgrounds

2.2 WHEN a user selects Light theme in Settings AND navigates to any screen (Dashboard, Login, SignUp, etc.) THEN the system SHALL display light gradients and light-themed component backgrounds

2.3 WHEN a user switches theme in Settings AND views observe ThemeManager directly via `@EnvironmentObject` THEN the system SHALL immediately trigger view re-renders and update all gradient backgrounds and component styling

### Unchanged Behavior (Regression Prevention)

3.1 WHEN a user is on Profile or Settings screens AND switches theme THEN the system SHALL CONTINUE TO update gradients and styling correctly as it currently does

3.2 WHEN a user switches theme in Settings AND text colors are managed by the theme system THEN the system SHALL CONTINUE TO update text colors correctly across all screens

3.3 WHEN ThemeManager.currentTheme changes AND views that don't use gradients observe the theme THEN the system SHALL CONTINUE TO respond to theme changes for their respective styling needs

3.4 WHEN the app launches AND no custom theme has been selected THEN the system SHALL CONTINUE TO respect the system color scheme as the default
