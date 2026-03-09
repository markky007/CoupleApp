import Combine
import Foundation
import SwiftUI
internal import Auth

/// ViewModel for profile management and partner pairing
/// Handles profile state, partner pairing logic, and UI updates
@MainActor
class ProfileViewModel: ObservableObject {

    // MARK: - Published Properties

    /// Current user's profile
    @Published var profile: Profile?

    /// Partner's profile (if paired)
    @Published var partnerProfile: Profile?

    /// Display name input field
    @Published var displayName = ""

    /// Partner ID input field for pairing
    @Published var partnerIdInput = ""

    /// Loading state
    @Published var isLoading = false

    /// Error message
    @Published var errorMessage: String?

    /// Success message
    @Published var successMessage: String?

    /// Show error alert
    @Published var showError = false

    /// Show success alert
    @Published var showSuccess = false

    // MARK: - Dependencies

    private let profileService = ProfileService.shared
    private let authService = AuthService.shared

    // MARK: - Computed Properties

    /// Whether user has a partner
    var hasPart: Bool {
        profile?.hasPart ?? false
    }

    /// Whether display name is valid
    var isDisplayNameValid: Bool {
        Profile.isValidDisplayName(displayName)
    }

    /// Whether partner ID input is valid UUID
    var isPartnerIdValid: Bool {
        UUID(uuidString: partnerIdInput) != nil
    }

    /// Current user ID
    var currentUserId: UUID? {
        authService.currentUser?.id
    }

    // MARK: - Initialization

    init() {
        // Load profile on initialization
        Task {
            await loadProfile()
        }
    }

    // MARK: - Profile Operations

    /// Loads current user's profile
    func loadProfile() async {
        guard let userId = currentUserId else {
            showErrorMessage("No authenticated user")
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            // Fetch user's profile
            profile = try await profileService.fetchProfile(userId: userId)

            // If user has a partner, fetch partner's profile
            if let partnerId = profile?.partnerId {
                partnerProfile = try await profileService.fetchProfile(userId: partnerId)
            }

            // Update display name field
            if let name = profile?.displayName {
                displayName = name
            }

            print("✅ Profile loaded successfully")
        } catch {
            showErrorMessage(error.localizedDescription)
        }

        isLoading = false
    }

    /// Creates a new profile for current user
    /// - Parameter name: Display name
    func createProfile(name: String) async {
        guard let userId = currentUserId else {
            showErrorMessage("No authenticated user")
            return
        }

        guard Profile.isValidDisplayName(name) else {
            showErrorMessage(
                "Display name must be 1-\(AppConstants.maxDisplayNameLength) characters")
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            profile = try await profileService.createProfile(userId: userId, displayName: name)
            showSuccessMessage("Profile created successfully!")
        } catch {
            showErrorMessage(error.localizedDescription)
        }

        isLoading = false
    }

    /// Updates user's display name
    func updateDisplayName() async {
        guard let userId = currentUserId else {
            showErrorMessage("No authenticated user")
            return
        }

        guard isDisplayNameValid else {
            showErrorMessage(
                "Display name must be 1-\(AppConstants.maxDisplayNameLength) characters")
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            try await profileService.updateDisplayName(userId: userId, newName: displayName)
            profile = profile?.withDisplayName(displayName)
            showSuccessMessage("Display name updated!")
        } catch {
            showErrorMessage(error.localizedDescription)
        }

        isLoading = false
    }

    // MARK: - Partner Pairing

    /// Pairs current user with a partner
    func pairWithPartner() async {
        guard let userId = currentUserId else {
            showErrorMessage("No authenticated user")
            return
        }

        guard let partnerId = UUID(uuidString: partnerIdInput) else {
            showErrorMessage("Invalid partner ID format")
            return
        }

        guard userId != partnerId else {
            showErrorMessage("You cannot pair with yourself")
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            try await profileService.pairWithPartner(userId: userId, partnerId: partnerId)

            // Reload profiles
            await loadProfile()

            showSuccessMessage("Successfully paired with partner!")
            partnerIdInput = ""  // Clear input
        } catch {
            showErrorMessage(error.localizedDescription)
        }

        isLoading = false
    }

    /// Unpairs current user from their partner
    func unpairFromPartner() async {
        guard let userId = currentUserId else {
            showErrorMessage("No authenticated user")
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            try await profileService.unpairFromPartner(userId: userId)

            // Clear partner profile
            partnerProfile = nil
            profile = profile?.withPartner(UUID())  // This will set partnerId to nil in the model

            showSuccessMessage("Successfully unpaired from partner")
        } catch {
            showErrorMessage(error.localizedDescription)
        }

        isLoading = false
    }

    // MARK: - Realtime Updates

    /// Subscribes to profile changes for real-time updates
    func subscribeToUpdates() async {
        guard let userId = currentUserId else { return }

        do {
            try await profileService.subscribeToProfileChanges(userId: userId) {
                [weak self] updatedProfile in
                Task { @MainActor in
                    self?.profile = updatedProfile

                    // If partner changed, reload partner profile
                    if let partnerId = updatedProfile.partnerId {
                        self?.partnerProfile = try? await self?.profileService.fetchProfile(
                            userId: partnerId)
                    } else {
                        self?.partnerProfile = nil
                    }
                }
            }
        } catch {
            print("Failed to subscribe to profile updates: \(error.localizedDescription)")
        }
    }

    /// Unsubscribes from profile changes
    func unsubscribeFromUpdates() async {
        await profileService.unsubscribeFromProfileChanges()
    }

    // MARK: - Helper Methods

    /// Shows error message with alert
    private func showErrorMessage(_ message: String) {
        errorMessage = message
        showError = true
    }

    /// Shows success message with alert
    private func showSuccessMessage(_ message: String) {
        successMessage = message
        showSuccess = true
    }

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

    /// Copies user ID to clipboard
    func copyUserIdToClipboard() {
        guard let userId = currentUserId else { return }

        #if os(iOS)
            UIPasteboard.general.string = userId.uuidString
        #elseif os(macOS)
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(userId.uuidString, forType: .string)
        #endif

        showSuccessMessage("User ID copied to clipboard!")
    }
}
