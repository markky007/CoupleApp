//
//  ThemeManager.swift
//  coupleapp
//
//  Created by Kiro on 2025-01-09.
//  Theme management system for dark/light mode support
//

import Combine
import SwiftUI

/// Manages theme preferences and applies color schemes throughout the app
/// Supports light, dark, and system modes with persistence via UserDefaults
@MainActor
class ThemeManager: ObservableObject {

    // MARK: - Shared Instance

    static let shared = ThemeManager()

    // MARK: - Published Properties

    /// Current theme mode - changes trigger UI updates
    @Published var currentTheme: ThemeMode

    // MARK: - Constants

    private let themePreferenceKey = "theme_preference"

    // MARK: - Initialization

    private init() {
        // Load saved theme or use system default
        if let savedTheme = UserDefaults.standard.string(forKey: themePreferenceKey),
            let mode = ThemeMode(rawValue: savedTheme)
        {
            self.currentTheme = mode
        } else {
            self.currentTheme = .system
        }
    }

    // MARK: - Public Methods

    /// Sets the theme mode and persists the preference
    /// - Parameter mode: The theme mode to apply
    func setTheme(_ mode: ThemeMode) {
        currentTheme = mode
        UserDefaults.standard.set(mode.rawValue, forKey: themePreferenceKey)
        print("✅ Theme changed to: \(mode.rawValue)")
    }

    /// Loads the saved theme preference from UserDefaults
    func loadSavedTheme() {
        guard let savedTheme = UserDefaults.standard.string(forKey: themePreferenceKey),
            let mode = ThemeMode(rawValue: savedTheme)
        else {
            currentTheme = .system
            return
        }
        currentTheme = mode
        print("✅ Theme loaded: \(mode.rawValue)")
    }

    /// Returns the color scheme for the current theme
    /// - Returns: ColorScheme (.light or .dark) or nil for system mode
    func getColorScheme() -> ColorScheme? {
        return currentTheme.colorScheme
    }
}

// MARK: - ThemeMode Enum

extension ThemeManager {
    /// Theme mode options for the application
    enum ThemeMode: String, CaseIterable, Codable {
        case light
        case dark
        case system

        /// Display name for the theme mode (English)
        var displayName: String {
            switch self {
            case .light: return "Light"
            case .dark: return "Dark"
            case .system: return "System"
            }
        }

        /// SF Symbol icon name for the theme mode
        var icon: String {
            switch self {
            case .light: return "sun.max.fill"
            case .dark: return "moon.fill"
            case .system: return "circle.lefthalf.filled"
            }
        }

        /// SwiftUI ColorScheme for the theme mode
        /// Returns nil for system mode to use device settings
        var colorScheme: ColorScheme? {
            switch self {
            case .light: return .light
            case .dark: return .dark
            case .system: return nil
            }
        }
    }
}
