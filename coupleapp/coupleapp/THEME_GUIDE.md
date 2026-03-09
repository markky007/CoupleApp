# Couple Quest - Theme Guide

## Overview

This document describes the gradient-based color theme system implemented in the Couple Quest iOS app. The theme provides a modern, user-friendly visual experience with consistent gradient colors throughout the application.

## Theme File

**Location**: `coupleapp/Core/AppTheme.swift`

## Color Palette

### Primary Gradients

#### 1. Primary Gradient

- **Colors**: Pink (#FF6B9D) → Rose (#C06C84)
- **Usage**: Main actions, buttons, highlights, branding
- **Example**: Sign in button, create quest button

#### 2. Secondary Gradient

- **Colors**: Mint (#A8E6CF) → Sky Blue (#56CCF2)
- **Usage**: Supporting elements, secondary actions
- **Example**: Create event button, empty state icons

#### 3. Success Gradient

- **Colors**: Light Green (#84FAB0) → Light Blue (#8FD3F4)
- **Usage**: Completed actions, success states
- **Example**: Quest completion button

#### 4. Warning Gradient

- **Colors**: Light Orange (#FFD89B) → Coral (#FF9A76)
- **Usage**: Alerts, important notices
- **Example**: Warnings, important messages

#### 5. Points Gradient

- **Colors**: Gold (#FFD700) → Orange (#FFA500)
- **Usage**: Point displays, rewards
- **Example**: User points display

#### 6. Partner Gradient

- **Colors**: Purple (#B06AB3) → Blue (#4568DC)
- **Usage**: Partner-related elements
- **Example**: Partner points display

#### 7. Background Gradient

- **Colors**: Light Pink (#FFEEF8) → Light Gray (#F3F4F6)
- **Usage**: Main screen backgrounds
- **Example**: Login screen, dashboard background

#### 8. Card Gradient

- **Colors**: White (90% opacity) → White (70% opacity)
- **Usage**: Elevated content cards
- **Example**: Quest cards, profile cards

## Solid Colors

For accessibility and specific use cases, solid color versions are available:

- `AppTheme.primary` - #FF6B9D
- `AppTheme.secondary` - #56CCF2
- `AppTheme.success` - #84FAB0
- `AppTheme.warning` - #FFD89B
- `AppTheme.points` - #FFD700
- `AppTheme.partner` - #B06AB3

## View Modifiers

### 1. Primary Gradient Background

```swift
.primaryGradientBackground()
```

Applies the primary gradient as a background.

### 2. Card Style

```swift
.cardStyle()
```

Applies card gradient with rounded corners and shadow:

- Background: Card gradient
- Corner radius: 12pt
- Shadow: Black 10% opacity, 8pt radius

### 3. Gradient Button

```swift
.gradientButton(gradient: AppTheme.primaryGradient)
```

Applies gradient button styling:

- Full width
- Height: 50pt
- White text
- Rounded corners: 12pt
- Shadow effect

## Button Style

### GradientButtonStyle

Custom button style with gradient background and press animation:

```swift
Button("Sign In") {
    // action
}
.buttonStyle(GradientButtonStyle(
    gradient: AppTheme.primaryGradient,
    isDisabled: false
))
```

**Features**:

- Gradient background
- Press animation (scale: 0.98)
- Disabled state (gray gradient)
- Dynamic shadow

## Design Constants

### Corner Radius

- Small: 8pt
- Medium: 12pt
- Large: 16pt

### Shadows

- Color: Black 10% opacity
- Radius: 8pt
- Offset: (0, 2)

## Usage Examples

### 1. Login Button

```swift
Button {
    await viewModel.signIn()
} label: {
    Text("Sign In")
        .fontWeight(.semibold)
}
.buttonStyle(GradientButtonStyle(
    gradient: AppTheme.primaryGradient,
    isDisabled: !viewModel.canSignIn
))
```

### 2. Points Display

```swift
Text("100")
    .font(.system(size: 36, weight: .bold))
    .foregroundStyle(AppTheme.pointsGradient)
```

### 3. Quest Card

```swift
VStack {
    // content
}
.padding()
.cardStyle()
```

### 4. Icon with Gradient Background

```swift
ZStack {
    Circle()
        .fill(AppTheme.primaryGradient)
        .frame(width: 70, height: 70)
        .shadow(color: AppTheme.shadowColor, radius: 8, x: 0, y: 4)

    Image(systemName: "heart.fill")
        .foregroundStyle(.white)
}
```

## Accessibility

- All gradients have sufficient contrast ratios
- Solid color alternatives available for high contrast mode
- Text on gradients uses white color for readability
- Interactive elements have clear visual feedback

## Platform Support

- iOS 16.0+
- macOS (with platform-specific adjustments)
- Supports both light and dark mode

## Best Practices

1. **Consistency**: Use predefined gradients instead of creating custom ones
2. **Hierarchy**: Primary gradient for main actions, secondary for supporting actions
3. **Contrast**: Always use white text on gradient backgrounds
4. **Spacing**: Maintain consistent padding and spacing using design constants
5. **Shadows**: Use AppTheme shadow properties for consistency

## Migration from Old Theme

### Before (Old Theme)

```swift
.background(Color.pink)
.foregroundColor(.pink)
```

### After (New Theme)

```swift
.buttonStyle(GradientButtonStyle(gradient: AppTheme.primaryGradient))
.foregroundStyle(AppTheme.primaryGradient)
```

## Updated Views

The following views have been updated to use the new gradient theme:

1. **LoginView** - Background gradient, gradient buttons, gradient icons
2. **SignUpView** - Background gradient, gradient buttons, gradient icons
3. **DashboardView** - Background gradient, gradient cards, gradient points display
4. **QuestBoardView** - Background gradient, gradient cards, gradient completion button
5. **CreateQuestView** - Background gradient, gradient submit button

## Future Enhancements

- Dark mode specific gradients
- Animated gradient transitions
- Custom gradient angles
- Gradient text effects
- Seasonal theme variations
