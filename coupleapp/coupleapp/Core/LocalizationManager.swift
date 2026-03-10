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
    @Published var currentLanguage: Language

    // MARK: - Constants

    private let languagePreferenceKey = "language_preference"

    // MARK: - Initialization

    private init() {
        // Load saved language or use English default
        if let savedLanguage = UserDefaults.standard.string(forKey: languagePreferenceKey),
            let language = Language(rawValue: savedLanguage)
        {
            self.currentLanguage = language
        } else {
            self.currentLanguage = .english
        }
    }

    // MARK: - Public Methods

    /// Sets the language and persists the preference
    /// - Parameter language: The language to apply
    func setLanguage(_ language: Language) {
        currentLanguage = language
        UserDefaults.standard.set(language.rawValue, forKey: languagePreferenceKey)
        print("✅ Language changed to: \(language.rawValue)")
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
        guard let bundlePath = Bundle.main.path(forResource: currentLanguage.code, ofType: "lproj"),
            let bundle = Bundle(path: bundlePath)
        else {
            // Fallback to main bundle (English)
            return NSLocalizedString(key, comment: "")
        }

        let localizedString = bundle.localizedString(forKey: key, value: nil, table: nil)

        // If translation not found, fallback to English
        if localizedString == key {
            print("⚠️ Missing translation for key: \(key) in language: \(currentLanguage.code)")
            return NSLocalizedString(key, comment: "")
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
