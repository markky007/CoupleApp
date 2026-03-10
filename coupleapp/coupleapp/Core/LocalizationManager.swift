//
//  LocalizationManager.swift
//  coupleapp
//
//  Created by Kiro on 2025-01-09.
//  Localization management system for Thai/English language support
//

import Combine
import Foundation
import SwiftUI

/// Manages language preferences and provides localized strings throughout the app
/// Supports Thai and English with persistence via UserDefaults
@MainActor
class LocalizationManager: ObservableObject {

    // MARK: - Shared Instance

    static let shared = LocalizationManager()

    // MARK: - Published Properties

    /// Current language - changes trigger UI updates
    @Published var currentLanguage: Language {
        didSet {
            print("🔄 currentLanguage didSet: \(currentLanguage.rawValue)")
            // Force UI update
            DispatchQueue.main.async { [weak self] in
                self?.objectWillChange.send()
            }
        }
    }

    // MARK: - Constants

    private let languagePreferenceKey = "language_preference"

    // MARK: - Initialization

    private init() {
        print("🚀 LocalizationManager initializing...")
        // Load saved language or use English default
        if let savedLanguage = UserDefaults.standard.string(forKey: languagePreferenceKey),
            let language = Language(rawValue: savedLanguage)
        {
            self.currentLanguage = language
            print("📱 Loaded saved language: \(language.rawValue)")
        } else {
            self.currentLanguage = .english
            print("📱 Using default language: english")
        }

        // Test bundle paths
        print("🔍 Testing bundle paths:")
        for lang in Language.allCases {
            if let bundlePath = Bundle.main.path(forResource: lang.code, ofType: "lproj") {
                print("✅ Found bundle for \(lang.code): \(bundlePath)")
            } else {
                print("❌ Missing bundle for \(lang.code)")
            }
        }

        // Test a key immediately
        let testResult = localized("settings.language")
        print("🧪 Initial test of 'settings.language': '\(testResult)'")
    }

    // MARK: - Public Methods

    /// Sets the language and persists the preference
    /// - Parameter language: The language to apply
    func setLanguage(_ language: Language) {
        print("🌐 Setting language from \(currentLanguage.rawValue) to \(language.rawValue)")

        // Update language (this will trigger didSet)
        currentLanguage = language
        UserDefaults.standard.set(language.rawValue, forKey: languagePreferenceKey)
        print("✅ Language changed to: \(language.rawValue)")
        print("💾 Saved to UserDefaults with key: \(languagePreferenceKey)")

        // Test localization immediately
        let testKey = "settings.language"
        let testResult = localized(testKey)
        print("🧪 Test localization for '\(testKey)': '\(testResult)'")

        // Force UI update by posting notification
        NotificationCenter.default.post(name: NSNotification.Name("LanguageChanged"), object: nil)
        print("📢 Posted LanguageChanged notification")
    }

    /// Loads the saved language preference from UserDefaults
    func loadSavedLanguage() {
        guard let savedLanguage = UserDefaults.standard.string(forKey: languagePreferenceKey),
            let language = Language(rawValue: savedLanguage)
        else {
            currentLanguage = .english
            return
        }
        currentLanguage = language
        print("✅ Language loaded: \(language.rawValue)")
    }

    /// Returns a localized string for the given key
    /// - Parameter key: The localization key
    /// - Returns: Localized string or fallback to English
    func localized(_ key: String) -> String {
        print("🔍 Localizing key: '\(key)' for language: '\(currentLanguage.code)'")

        guard let bundlePath = Bundle.main.path(forResource: currentLanguage.code, ofType: "lproj"),
            let bundle = Bundle(path: bundlePath)
        else {
            print("❌ Bundle not found for language: \(currentLanguage.code)")
            // Fallback to main bundle (English)
            let fallback = NSLocalizedString(key, comment: "")
            print("🔄 Fallback result: '\(fallback)'")
            return fallback
        }

        print("✅ Bundle found at: \(bundlePath)")
        let localizedString = bundle.localizedString(forKey: key, value: nil, table: nil)
        print("📝 Localized result: '\(localizedString)'")

        // If translation not found, fallback to English
        if localizedString == key {
            print("⚠️ Missing translation for key: \(key) in language: \(currentLanguage.code)")
            let fallback = NSLocalizedString(key, comment: "")
            print("🔄 English fallback: '\(fallback)'")
            return fallback
        }

        return localizedString
    }

    /// Returns a localized string with format arguments
    /// - Parameters:
    ///   - key: The localization key
    ///   - args: Format arguments
    /// - Returns: Formatted localized string
    func localized(_ key: String, _ args: CVarArg...) -> String {
        let format = localized(key)
        return String(format: format, arguments: args)
    }
}

// MARK: - Language Enum

extension LocalizationManager {
    /// Language options for the application
    enum Language: String, CaseIterable, Codable {
        case english = "en"
        case thai = "th"

        /// Display name for the language
        var displayName: String {
            switch self {
            case .english: return "English"
            case .thai: return "ไทย"
            }
        }

        /// Flag emoji for the language
        var flag: String {
            switch self {
            case .english: return "🇬🇧"
            case .thai: return "🇹🇭"
            }
        }

        /// SF Symbol icon for the language
        var icon: String {
            switch self {
            case .english: return "globe"
            case .thai: return "globe"
            }
        }

        /// Locale for the language
        var locale: Locale {
            Locale(identifier: rawValue)
        }

        /// Language code (same as rawValue)
        var code: String {
            rawValue
        }
    }
}
