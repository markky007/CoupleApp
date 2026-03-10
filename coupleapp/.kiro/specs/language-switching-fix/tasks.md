# Implementation Plan

- [x] 1. Write bug condition exploration test
  - **Property 1: Bug Condition** - Language and Theme Reactivity Failures
  - **CRITICAL**: This test MUST FAIL on unfixed code - failure confirms the bug exists
  - **DO NOT attempt to fix the test or the code when it fails**
  - **NOTE**: This test encodes the expected behavior - it will validate the fix when it passes after implementation
  - **GOAL**: Surface counterexamples that demonstrate the bugs exist
  - **Scoped PBT Approach**: Focus on concrete failing cases: Thai language selection and theme changes in specific views
  - Test that language change to Thai updates ALL UI elements (from Bug Condition in design)
  - Test that theme changes update ALL components in QuestBoardView, RewardShopView, EventListView, TransactionHistoryView
  - The test assertions should match the Expected Behavior Properties from design
  - Run test on UNFIXED code
  - **EXPECTED OUTCOME**: Test FAILS (this is correct - it proves the bugs exist)
  - Document counterexamples found to understand root cause
  - Mark task complete when test is written, run, and failure is documented
  - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5_

- [x] 2. Write preservation property tests (BEFORE implementing fix)
  - **Property 2: Preservation** - Existing Language and Theme Functionality
  - **IMPORTANT**: Follow observation-first methodology
  - Observe behavior on UNFIXED code for English language and existing theme functionality
  - Write property-based tests capturing observed behavior patterns from Preservation Requirements
  - Property-based testing generates many test cases for stronger guarantees
  - Test English language display continues to work correctly
  - Test theme and language preferences continue to be saved and loaded
  - Test system theme following continues to work when theme is set to "system"
  - Run tests on UNFIXED code
  - **EXPECTED OUTCOME**: Tests PASS (this confirms baseline behavior to preserve)
  - Mark task complete when tests are written, run, and passing on unfixed code
  - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6_

- [x] 3. Fix for language switching and theme reactivity bugs
  - [x] 3.1 Replace LocalizationManager with fixed version
    - Replace coupleapp/Core/LocalizationManager.swift with LocalizationManager_Fixed.swift content
    - Add didSet observer to currentLanguage property that calls objectWillChange.send() on main queue
    - Remove redundant objectWillChange.send() call from setLanguage() method
    - Ensure UI updates are triggered automatically when currentLanguage changes
    - _Bug_Condition: isBugCondition(input) where input.type == "language_change" AND input.newLanguage == "thai" AND partialUIUpdate()_
    - _Expected_Behavior: Complete language switching across all UI elements_
    - _Preservation: English language display and language preference persistence_
    - _Requirements: 2.1, 2.2, 2.3, 3.1, 3.2, 3.3, 3.4_

  - [x] 3.2 Update QuestBoardView for theme reactivity
    - Ensure @EnvironmentObject var themeManager: ThemeManager is present
    - Replace any .cardStyle() calls with .cardStyleReactive(theme: themeManager.currentTheme.rawValue, systemScheme: systemColorScheme)
    - Verify all gradient backgrounds use reactive functions
    - _Bug_Condition: isBugCondition(input) where input.type == "theme_change" AND input.affectedViews includes "QuestBoardView"_
    - _Expected_Behavior: All components immediately change colors to match selected theme_
    - _Preservation: Existing theme functionality and system theme following_
    - _Requirements: 2.4, 2.5, 3.5, 3.6_

  - [x] 3.3 Update RewardShopView for theme reactivity
    - Ensure @EnvironmentObject var themeManager: ThemeManager is present
    - Replace any .cardStyle() calls with .cardStyleReactive(theme: themeManager.currentTheme.rawValue, systemScheme: systemColorScheme)
    - Update pointBalanceCard to use reactive cardGradient function
    - _Bug_Condition: isBugCondition(input) where input.type == "theme_change" AND input.affectedViews includes "RewardShopView"_
    - _Expected_Behavior: All components immediately change colors to match selected theme_
    - _Preservation: Existing theme functionality and system theme following_
    - _Requirements: 2.4, 2.5, 3.5, 3.6_

  - [x] 3.4 Update EventListView for theme reactivity
    - Ensure @EnvironmentObject var themeManager: ThemeManager is present
    - Replace any .cardStyle() calls with .cardStyleReactive(theme: themeManager.currentTheme.rawValue, systemScheme: systemColorScheme)
    - Verify all components use reactive theme properties
    - _Bug_Condition: isBugCondition(input) where input.type == "theme_change" AND input.affectedViews includes "EventListView"_
    - _Expected_Behavior: All components immediately change colors to match selected theme_
    - _Preservation: Existing theme functionality and system theme following_
    - _Requirements: 2.4, 2.5, 3.5, 3.6_

  - [x] 3.5 Update TransactionHistoryView for theme reactivity
    - Ensure @EnvironmentObject var themeManager: ThemeManager is present
    - Replace any .cardStyle() calls with .cardStyleReactive(theme: themeManager.currentTheme.rawValue, systemScheme: systemColorScheme)
    - Update TransactionRowView to use reactive theme modifiers
    - _Bug_Condition: isBugCondition(input) where input.type == "theme_change" AND input.affectedViews includes "TransactionHistoryView"_
    - _Expected_Behavior: All components immediately change colors to match selected theme_
    - _Preservation: Existing theme functionality and system theme following_
    - _Requirements: 2.4, 2.5, 3.5, 3.6_

  - [x] 3.6 Verify bug condition exploration test now passes
    - **Property 1: Expected Behavior** - Complete Language and Theme Reactivity
    - **IMPORTANT**: Re-run the SAME test from task 1 - do NOT write a new test
    - The test from task 1 encodes the expected behavior
    - When this test passes, it confirms the expected behavior is satisfied
    - Run bug condition exploration test from step 1
    - **EXPECTED OUTCOME**: Test PASSES (confirms bugs are fixed)
    - _Requirements: Expected Behavior Properties from design_

  - [x] 3.7 Verify preservation tests still pass
    - **Property 2: Preservation** - Existing Language and Theme Functionality
    - **IMPORTANT**: Re-run the SAME tests from task 2 - do NOT write new tests
    - Run preservation property tests from step 2
    - **EXPECTED OUTCOME**: Tests PASS (confirms no regressions)
    - Confirm all tests still pass after fix (no regressions)

- [x] 4. Checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.
