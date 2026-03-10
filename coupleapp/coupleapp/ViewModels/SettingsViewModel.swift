//
//  SettingsViewModel.swift
//  coupleapp
//
//  Created by Kiro on 2025-01-09.
//  ViewModel for settings management
//

import Combine
import Foundation
import SwiftUI

/// ViewModel for settings screen
/// Handles theme, language, and partner management
/// Coordinates between ThemeManager, LocalizationManager, ProfileService, and PairingService
@MainActor
class SettingsViewModel: ObservableObject {

    // MARK: - Published Properties

    /// Current theme mode (bound to ThemeManager)
    @Published var currentTheme: ThemeManager.ThemeMode

    /// Current language (bound to LocalizationManager)
    @Published var currentLanguage: LocalizationManager.Language

    /// Current user profile
    @Published var profile: Profile?

    /// Loading state during operations
    @Published var isLoading = false

    /// Error message to display
    @Published var errorMessage: String?

    /// Whether to show error alert
    @Published var showError = false

    /// Whether to show unpair confirmation dialog
    @Published var showUnpairConfirmation = false

    /// Success message to display
    @Published var successMessage: String?

    /// Whether to show success alert
    @Published var showSuccess = false

    // MARK: - Dependencies

    private let themeManager = ThemeManager.shared
    private let localizationManager = LocalizationManager.shared
    private let profileService = ProfileService.shared
    private let pairingService = PairingService.shared

    // MARK: - Private Properties

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init() {
        // Initialize with current values from managers
        self.currentTheme = themeManager.currentTheme
        self.currentLanguage = localizationManager.currentLanguage

        // Bind to ThemeManager changes
        themeManager.$currentTheme
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newTheme in
                self?.currentTheme = newTheme
            }
            .store(in: &cancellables)

        // Bind to LocalizationManager changes
        localizationManager.$currentLanguage
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newLanguage in
                self?.currentLanguage = newLanguage
            }
            .store(in: &cancellables)
    }

    // MARK: - Profile Management

    /// Loads the current user's profile
    /// - Parameter userId: User's unique identifier
    func loadProfile(userId: UUID) async {
        isLoading = true
        errorMessage = nil

        do {
            profile = try await profileService.fetchProfile(userId: userId)
            print("✅ Profile loaded in SettingsViewModel")
        } catch {
            errorMessage = "Failed to load profile: \(error.localizedDescription)"
            showError = true
            print("❌ Failed to load profile: \(error.localizedDescription)")
        }

        isLoading = false
    }

    // MARK: - Theme Management

    /// Changes the theme mode
    /// - Parameter mode: New theme mode to apply
    func changeTheme(_ mode: ThemeManager.ThemeMode) {
        themeManager.setTheme(mode)
        print("✅ Theme changed to: \(mode.rawValue)")

        // Optionally sync to database for cross-device consistency
        if let userId = profile?.id {
            Task {
                do {
                    try await profileService.updateThemePreference(
                        userId: userId,
                        theme: mode.rawValue
                    )
                    print("✅ Theme preference synced to database")
                } catch {
                    print(
                        "⚠️ Failed to sync theme preference to database: \(error.localizedDescription)"
                    )
                    // Don't show error to user - local preference is already saved
                }
            }
        }
    }

    // MARK: - Language Management

    /// Changes the language
    /// - Parameter language: New language to apply
    func changeLanguage(_ language: LocalizationManager.Language) {
        localizationManager.setLanguage(language)
        print("✅ Language changed to: \(language.rawValue)")

        // Optionally sync to database for cross-device consistency
        if let userId = profile?.id {
            Task {
                do {
                    try await profileService.updateLanguagePreference(
                        userId: userId,
                        language: language.rawValue
                    )
                    print("✅ Language preference synced to database")
                } catch {
                    print(
                        "⚠️ Failed to sync language preference to database: \(error.localizedDescription)"
                    )
                    // Don't show error to user - local preference is already saved
                }
            }
        }
    }

    // MARK: - Partner Management

    /// Shows unpair confirmation dialog
    func requestUnpair() {
        showUnpairConfirmation = true
    }

    /// Unpairs the current user from their partner
    /// Requires confirmation before executing
    func unpairPartner() async {
        guard let userId = profile?.id else {
            errorMessage = "User profile not loaded"
            showError = true
            return
        }

        guard profile?.partnerId != nil else {
            errorMessage = "You are not currently paired with anyone"
            showError = true
            return
        }

        isLoading = true
        errorMessage = nil
        showUnpairConfirmation = false

        do {
            try await pairingService.unpairUsers(userId: userId)

            // Reload profile to reflect changes
            profile = try await profileService.fetchProfile(userId: userId)

            successMessage = "Successfully unpaired from partner"
            showSuccess = true
            print("✅ Successfully unpaired from partner")
        } catch {
            errorMessage = "Failed to unpair: \(error.localizedDescription)"
            showError = true
            print("❌ Failed to unpair: \(error.localizedDescription)")
        }

        isLoading = false
    }

    /// Cancels unpair operation
    func cancelUnpair() {
        showUnpairConfirmation = false
    }

    // MARK: - Alert Management

    /// Dismisses error alert
    func dismissError() {
        showError = false
        errorMessage = nil
    }

    /// Dismisses success alert
    func dismissSuccess() {
        showSuccess = false
        successMessage = nil
    }
}
