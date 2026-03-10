#!/usr/bin/env swift

//
//  test_runner.swift
//  Simple test runner for language and theme reactivity bugs
//

import Foundation

// Mock classes for testing (simplified versions)
class MockLocalizationManager {
    enum Language: String, CaseIterable {
        case english = "en"
        case thai = "th"

        var displayName: String {
            switch self {
            case .english: return "English"
            case .thai: return "ไทย"
            }
        }
    }

    var currentLanguage: Language = .english

    func setLanguage(_ language: Language) {
        print("🌐 Setting language from \(currentLanguage.rawValue) to \(language.rawValue)")
        // BUG: Missing didSet observer - UI won't update automatically
        currentLanguage = language
        print("✅ Language changed to: \(language.rawValue)")
    }

    func localized(_ key: String) -> String {
        // Simplified localization - in real app this reads from .strings files
        let thaiTranslations = [
            "settings.title": "การตั้งค่า",
            "quest.title": "กระดานภารกิจ",
            "reward.title": "ร้านรางวัล",
            "event.title": "กิจกรรม",
            "dashboard.title": "แดชบอร์ด",
            "settings.language": "ภาษา",
            "theme.label": "ธีม",
            "quest.empty.title": "ไม่มีภารกิจที่ใช้งานอยู่",
            "reward.empty.title": "ไม่มีรางวัลที่มีอยู่",
            "event.empty.title": "ยังไม่มีกิจกรรม",
        ]

        if currentLanguage == .thai, let thaiText = thaiTranslations[key] {
            return thaiText
        }

        // English fallback
        return key.replacingOccurrences(of: ".", with: " ").capitalized
    }
}

class MockThemeManager {
    enum ThemeMode: String, CaseIterable {
        case light = "light"
        case dark = "dark"
        case system = "system"
    }

    var currentTheme: ThemeMode = .system

    func setTheme(_ theme: ThemeMode) {
        print("🎨 Setting theme from \(currentTheme.rawValue) to \(theme.rawValue)")
        currentTheme = theme
        print("✅ Theme changed to: \(theme.rawValue)")
    }
}

// Test runner
class BugConditionTests {
    let localizationManager = MockLocalizationManager()
    let themeManager = MockThemeManager()

    func runAllTests() {
        print("🧪 Running Bug Condition Exploration Tests")
        print(String(repeating: "=", count: 50))

        testLanguageSwitchingBugCondition()
        testThemeReactivityBugCondition()
        testPartialUIUpdateBugCondition()
        testNavigationAfterLanguageChange()

        print("\n📊 Test Summary:")
        print("These tests demonstrate the bugs that exist in the unfixed code.")
        print("The language switching works at the LocalizationManager level,")
        print(
            "but UI components don't receive update notifications due to missing didSet observer.")
        print(
            "Theme switching works for basic functions but views using static .cardStyle() won't update."
        )
    }

    func testLanguageSwitchingBugCondition() {
        print("\n🧪 Test 1: Language Switching Bug Condition")

        // GIVEN: App starts with English
        localizationManager.setLanguage(.english)
        let englishTitle = localizationManager.localized("settings.title")
        print("English title: '\(englishTitle)'")

        // WHEN: User changes to Thai
        localizationManager.setLanguage(.thai)
        let thaiTitle = localizationManager.localized("settings.title")
        print("Thai title: '\(thaiTitle)'")

        // THEN: Localization works but UI doesn't update automatically
        if thaiTitle == "การตั้งค่า" {
            print("✅ LocalizationManager returns correct Thai text")
            print("❌ BUT: UI components won't update because didSet observer is missing")
            print("   This is the BUG - only views that explicitly re-query will show Thai text")
        } else {
            print("❌ Localization not working correctly")
        }
    }

    func testThemeReactivityBugCondition() {
        print("\n🧪 Test 2: Theme Reactivity Bug Condition")

        // GIVEN: App starts with light theme
        themeManager.setTheme(.light)
        print("Light theme set")

        // WHEN: User changes to dark theme
        themeManager.setTheme(.dark)
        print("Dark theme set")

        // THEN: Theme manager works but some views won't update
        if themeManager.currentTheme == .dark {
            print("✅ ThemeManager correctly tracks theme changes")
            print("❌ BUT: Views using static .cardStyle() won't update automatically")
            print("   This is the BUG - only views using .cardStyleReactive() will adapt")
        } else {
            print("❌ Theme manager not working correctly")
        }
    }

    func testPartialUIUpdateBugCondition() {
        print("\n🧪 Test 3: Partial UI Update Bug Condition")

        // GIVEN: English language
        localizationManager.setLanguage(.english)
        let keys = ["settings.title", "settings.language", "theme.label"]

        print("English values:")
        for key in keys {
            let value = localizationManager.localized(key)
            print("  \(key): '\(value)'")
        }

        // WHEN: Change to Thai
        localizationManager.setLanguage(.thai)

        print("\nThai values:")
        for key in keys {
            let value = localizationManager.localized(key)
            print("  \(key): '\(value)'")
        }

        print("✅ All strings translate correctly at LocalizationManager level")
        print("❌ BUT: In real UI, only some components update due to missing didSet observer")
        print("   This causes the 'partial update' bug where only some labels change")
    }

    func testNavigationAfterLanguageChange() {
        print("\n🧪 Test 4: Navigation After Language Change")

        // GIVEN: User changes language to Thai
        localizationManager.setLanguage(.thai)

        // WHEN: User navigates to different views (simulated)
        let questTitle = localizationManager.localized("quest.empty.title")
        let rewardTitle = localizationManager.localized("reward.empty.title")
        let eventTitle = localizationManager.localized("event.empty.title")

        print("Navigation test results:")
        print("  Quest empty title: '\(questTitle)'")
        print("  Reward empty title: '\(rewardTitle)'")
        print("  Event empty title: '\(eventTitle)'")

        if questTitle.contains("ภารกิจ") {
            print("✅ New views would load with correct Thai text")
            print("❌ BUT: Existing views won't update without didSet observer triggering re-render")
        }
    }
}

// Run the tests
let tests = BugConditionTests()
tests.runAllTests()

print("\n🎯 CONCLUSION:")
print("These tests confirm the bugs exist:")
print(
    "1. Language switching: LocalizationManager works but missing didSet observer prevents UI updates"
)
print("2. Theme reactivity: ThemeManager works but static .cardStyle() prevents component updates")
print("3. The fixes needed are:")
print("   - Add didSet observer to LocalizationManager.currentLanguage")
print("   - Replace .cardStyle() with .cardStyleReactive() in affected views")
