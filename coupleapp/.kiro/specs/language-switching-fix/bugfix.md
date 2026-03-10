# Bugfix Requirements Document

## Introduction

The language switching functionality in the Couple Quest iOS app is partially broken. When users select Thai language in Settings, only the "Theme" and "Language" labels change to Thai while the rest of the UI remains in English. This prevents users from experiencing the app in their preferred language and undermines the comprehensive localization implementation that has been completed with 80+ Thai translations.

## Bug Analysis

### Current Behavior (Defect)

1.1 WHEN user selects Thai language in Settings THEN only "Theme" and "Language" labels change to Thai while rest of UI remains in English

1.2 WHEN user navigates to other views after changing language THEN the views continue to display English text instead of Thai translations

1.3 WHEN LocalizationManager.setLanguage() is called THEN the currentLanguage property changes but UI components are not notified to refresh their displayed text

### Expected Behavior (Correct)

2.1 WHEN user selects Thai language in Settings THEN the entire app UI SHALL immediately switch to Thai using the available translations

2.2 WHEN user navigates to other views after changing language THEN all views SHALL display Thai text using localizationManager.localized() calls

2.3 WHEN LocalizationManager.setLanguage() is called THEN the currentLanguage property SHALL change and trigger UI updates across all views that observe the LocalizationManager

### Unchanged Behavior (Regression Prevention)

3.1 WHEN user selects English language THEN the system SHALL CONTINUE TO display all text in English as it currently does

3.2 WHEN app starts with saved language preference THEN the system SHALL CONTINUE TO load and apply the saved language correctly

3.3 WHEN localizationManager.localized() is called for existing keys THEN the system SHALL CONTINUE TO return the correct translations for the current language

3.4 WHEN Thai translations are missing for a key THEN the system SHALL CONTINUE TO fallback to English translations as designed
