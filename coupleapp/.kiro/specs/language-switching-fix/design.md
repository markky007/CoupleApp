# Language Switching and Theme Reactivity Bugfix Design

## Overview

This design addresses two critical UI reactivity issues in the Couple Quest iOS app: incomplete language switching and non-reactive theme components. The language switching bug occurs because the LocalizationManager.currentLanguage property lacks a didSet observer to trigger UI updates, causing only partial UI elements to change when users select Thai language. The theme reactivity bug occurs because several views use static .cardStyle() instead of reactive .cardStyleReactive() and are missing proper ThemeManager environment object injection. The fix involves implementing a didSet observer in LocalizationManager and systematically updating all affected views to use reactive theme modifiers.

## Glossary

- **Bug_Condition (C)**: The condition that triggers the bugs - when language switching fails to update all UI elements OR when theme changes fail to update component colors
- **Property (P)**: The desired behavior when language/theme changes occur - all UI elements should immediately reflect the new language/theme
- **Preservation**: Existing functionality that must remain unchanged - current English language display, saved preferences, and working theme/language persistence
- **LocalizationManager**: The service in `coupleapp/Core/LocalizationManager.swift` that manages language preferences and provides localized strings
- **ThemeManager**: The service in `coupleapp/Core/ThemeManager.swift` that manages theme preferences and provides color schemes
- **didSet Observer**: Swift property observer that executes code when a property value changes
- **Reactive Theme Modifier**: The .cardStyleReactive() modifier that responds to theme changes, unlike static .cardStyle()

## Bug Details

### Bug Condition

The bugs manifest when users change language or theme settings in the app. For language switching, the LocalizationManager.setLanguage() method updates the currentLanguage property but lacks a didSet observer to trigger UI refreshes, causing only views that explicitly observe LocalizationManager to update. For theme reactivity, several views use static .cardStyle() instead of reactive .cardStyleReactive() and lack proper @EnvironmentObject var themeManager: ThemeManager injection.

**Formal Specification:**

```
FUNCTION isBugCondition(input)
  INPUT: input of type SettingsChange
  OUTPUT: boolean

  RETURN (input.type == "language_change" AND input.newLanguage == "thai" AND partialUIUpdate())
         OR (input.type == "theme_change" AND input.affectedViews IN ["QuestBoardView", "RewardShopView", "EventListView", "TransactionHistoryView"] AND NOT allComponentsReactive())
END FUNCTION
```

### Examples

- **Language Bug**: User selects Thai in Settings → only "Theme" and "Language" labels change to Thai while quest titles, reward descriptions, and other UI text remain in English
- **Theme Bug**: User switches from light to dark theme → QuestBoardView cards remain in light theme colors while navigation and background adapt to dark theme
- **Navigation Bug**: User changes language then navigates to Quest board → new view loads with English text instead of Thai translations
- **Component Bug**: User changes theme in RewardShopView → some cards use static .cardStyle() and don't adapt to new theme colors

## Expected Behavior

### Preservation Requirements

**Unchanged Behaviors:**

- English language display must continue to work exactly as before
- Theme and language preferences must continue to be saved and loaded correctly
- All existing localization keys and translations must continue to work
- System theme following (when theme is set to "system") must continue to work

**Scope:**
All inputs that do NOT involve language or theme changes should be completely unaffected by this fix. This includes:

- App startup and initialization behavior
- User authentication and profile management
- Quest, reward, and event functionality
- Database operations and API calls

## Hypothesized Root Cause

Based on the bug analysis, the most likely issues are:

1. **Missing didSet Observer**: LocalizationManager.currentLanguage property lacks a didSet observer to trigger objectWillChange.send() when the language changes
   - The fixed version in LocalizationManager_Fixed.swift shows the solution with didSet implementation
   - Views that don't explicitly observe LocalizationManager don't receive update notifications

2. **Static Theme Modifiers**: Several views use .cardStyle() instead of .cardStyleReactive()
   - QuestBoardView, RewardShopView, EventListView, and TransactionHistoryView contain static theme references
   - These views need to use reactive modifiers that accept theme parameters

3. **Missing Environment Objects**: Some views lack @EnvironmentObject var themeManager: ThemeManager injection
   - Views need both themeManager and systemColorScheme to use reactive theme functions
   - Missing environment objects prevent reactive theme updates

4. **Incomplete View Updates**: Views use .id(localizationManager.currentLanguage) but this may not be sufficient without proper didSet triggering

## Correctness Properties

Property 1: Bug Condition - Complete Language Switching

_For any_ language change where the user selects Thai language in Settings, the fixed LocalizationManager SHALL trigger UI updates across all views that observe the LocalizationManager, causing the entire app interface to display Thai text using the available translations.

**Validates: Requirements 2.1, 2.2, 2.3**

Property 2: Bug Condition - Complete Theme Reactivity

_For any_ theme change where the user switches between light and dark themes, all components in QuestBoardView, RewardShopView, EventListView, and TransactionHistoryView SHALL immediately change colors to match the selected theme using reactive theme properties.

**Validates: Requirements 2.4, 2.5**

Property 3: Preservation - Existing Language Functionality

_For any_ input that involves English language selection or existing language functionality, the fixed code SHALL produce exactly the same behavior as the original code, preserving all current English text display and language preference persistence.

**Validates: Requirements 3.1, 3.2, 3.3, 3.4**

Property 4: Preservation - Existing Theme Functionality

_For any_ input that involves existing theme functionality (system theme following, theme persistence), the fixed code SHALL produce exactly the same behavior as the original code, preserving all current theme management capabilities.

**Validates: Requirements 3.5, 3.6**

## Fix Implementation

### Changes Required

Assuming our root cause analysis is correct:

**File**: `coupleapp/Core/LocalizationManager.swift`

**Function**: `LocalizationManager` class

**Specific Changes**:

1. **Add didSet Observer**: Replace the currentLanguage property declaration with the fixed version from LocalizationManager_Fixed.swift
   - Add didSet observer that calls objectWillChange.send() on main queue
   - Remove redundant objectWillChange.send() call from setLanguage() method
   - Ensure UI updates are triggered automatically when currentLanguage changes

2. **Update QuestBoardView**: Replace static theme references with reactive ones
   - Ensure @EnvironmentObject var themeManager: ThemeManager is present
   - Replace any .cardStyle() calls with .cardStyleReactive(theme: themeManager.currentTheme.rawValue, systemScheme: systemColorScheme)
   - Verify all gradient backgrounds use reactive functions

3. **Update RewardShopView**: Replace static theme references with reactive ones
   - Ensure @EnvironmentObject var themeManager: ThemeManager is present
   - Replace any .cardStyle() calls with .cardStyleReactive(theme: themeManager.currentTheme.rawValue, systemScheme: systemColorScheme)
   - Update pointBalanceCard to use reactive cardGradient function

4. **Update EventListView**: Replace static theme references with reactive ones
   - Ensure @EnvironmentObject var themeManager: ThemeManager is present
   - Replace any .cardStyle() calls with .cardStyleReactive(theme: themeManager.currentTheme.rawValue, systemScheme: systemColorScheme)
   - Verify all components use reactive theme properties

5. **Update TransactionHistoryView**: Replace static theme references with reactive ones
   - Ensure @EnvironmentObject var themeManager: ThemeManager is present
   - Replace any .cardStyle() calls with .cardStyleReactive(theme: themeManager.currentTheme.rawValue, systemScheme: systemColorScheme)
   - Update TransactionRowView to use reactive theme modifiers

## Testing Strategy

### Validation Approach

The testing strategy follows a two-phase approach: first, surface counterexamples that demonstrate the bugs on unfixed code, then verify the fixes work correctly and preserve existing behavior.

### Exploratory Bug Condition Checking

**Goal**: Surface counterexamples that demonstrate the bugs BEFORE implementing the fix. Confirm or refute the root cause analysis. If we refute, we will need to re-hypothesize.

**Test Plan**: Write tests that simulate language and theme changes and assert that all UI components update correctly. Run these tests on the UNFIXED code to observe failures and understand the root cause.

**Test Cases**:

1. **Language Switching Test**: Change language to Thai and verify all views update (will fail on unfixed code)
2. **Theme Switching Test**: Change theme and verify all components in problematic views update (will fail on unfixed code)
3. **Navigation After Language Change**: Change language then navigate to different views (will fail on unfixed code)
4. **Partial Update Test**: Verify that only some components update when language changes (will demonstrate bug on unfixed code)

**Expected Counterexamples**:

- Only "Theme" and "Language" labels change to Thai while other UI elements remain in English
- Some components in QuestBoardView, RewardShopView, EventListView, and TransactionHistoryView don't change colors when theme is switched
- Possible causes: missing didSet observer, static theme modifiers, missing environment objects

### Fix Checking

**Goal**: Verify that for all inputs where the bug condition holds, the fixed function produces the expected behavior.

**Pseudocode:**

```
FOR ALL input WHERE isBugCondition(input) DO
  result := fixedLocalizationManager(input) OR fixedThemeReactivity(input)
  ASSERT expectedBehavior(result)
END FOR
```

### Preservation Checking

**Goal**: Verify that for all inputs where the bug condition does NOT hold, the fixed function produces the same result as the original function.

**Pseudocode:**

```
FOR ALL input WHERE NOT isBugCondition(input) DO
  ASSERT originalBehavior(input) = fixedBehavior(input)
END FOR
```

**Testing Approach**: Property-based testing is recommended for preservation checking because:

- It generates many test cases automatically across the input domain
- It catches edge cases that manual unit tests might miss
- It provides strong guarantees that behavior is unchanged for all non-buggy inputs

**Test Plan**: Observe behavior on UNFIXED code first for English language and existing theme functionality, then write property-based tests capturing that behavior.

**Test Cases**:

1. **English Language Preservation**: Verify English text display continues to work correctly after fix
2. **Theme Persistence Preservation**: Verify theme preferences continue to be saved and loaded correctly
3. **Language Persistence Preservation**: Verify language preferences continue to be saved and loaded correctly
4. **System Theme Following Preservation**: Verify system theme following continues to work when theme is set to "system"

### Unit Tests

- Test LocalizationManager didSet observer triggers UI updates
- Test that all views with @EnvironmentObject themeManager receive theme change notifications
- Test that reactive theme modifiers respond correctly to theme changes
- Test that language changes trigger complete UI updates across all views

### Property-Based Tests

- Generate random language and theme combinations and verify all UI components update correctly
- Generate random navigation sequences after language/theme changes and verify consistency
- Test that all non-language/theme inputs continue to work across many scenarios

### Integration Tests

- Test full language switching flow from Settings to all major views
- Test full theme switching flow from Settings to all major views
- Test that app startup correctly applies saved language and theme preferences
- Test that cross-device synchronization of preferences continues to work
