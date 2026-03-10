import Combine
import Foundation
import PhotosUI
import SwiftUI

#if os(iOS)
    import UIKit
#endif

/// ViewModel for profile editing functionality
/// Manages username updates, profile picture uploads, and validation
@MainActor
class ProfileEditViewModel: ObservableObject {

    // MARK: - Published Properties

    /// Current username being edited
    @Published var username: String = ""

    /// Selected profile image (UIImage)
    #if os(iOS)
        @Published var profileImage: UIImage?
    #else
        @Published var profileImage: Data?
    #endif

    /// Current profile picture URL
    @Published var profilePictureUrl: String?

    /// Upload progress indicator
    @Published var isUploading: Bool = false

    /// Error message to display
    @Published var errorMessage: String?

    /// Success message to display
    @Published var successMessage: String?

    /// Username validation error
    @Published var usernameError: String?

    /// Whether the save button should be enabled
    var canSave: Bool {
        !username.isEmpty && usernameError == nil && !isUploading
    }

    // MARK: - Private Properties

    private let profileService = ProfileService.shared
    private let userId: UUID

    // MARK: - Initialization

    init(userId: UUID) {
        self.userId = userId
    }

    // MARK: - Profile Loading

    /// Loads the current profile data
    func loadProfile() async {
        do {
            let profile = try await profileService.fetchProfile(userId: userId)
            username = profile.username ?? ""
            profilePictureUrl = profile.profilePictureUrl
        } catch {
            errorMessage = "Failed to load profile: \(error.localizedDescription)"
        }
    }

    // MARK: - Username Editing (Task 14.2)

    /// Updates the username with validation
    /// - Parameter newUsername: The new username to set
    func updateUsername(_ newUsername: String) async {
        // Clear previous errors
        errorMessage = nil
        successMessage = nil

        // Validate username
        guard validateUsername(newUsername) else {
            return
        }

        do {
            try await profileService.updateUsername(userId: userId, username: newUsername)
            username = newUsername
            successMessage = "Username updated successfully"
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Validates username and sets inline error if invalid
    /// - Parameter username: Username to validate
    /// - Returns: True if valid, false otherwise
    func validateUsername(_ username: String) -> Bool {
        let trimmed = username.trimmingCharacters(in: .whitespaces)

        // Check if empty
        if trimmed.isEmpty {
            usernameError = "Username cannot be empty"
            return false
        }

        // Check length
        if trimmed.count > 50 {
            usernameError = "Username must be 50 characters or less"
            return false
        }

        // Check allowed characters
        let allowedCharacters = CharacterSet.alphanumerics
            .union(CharacterSet(charactersIn: " -_"))

        if !trimmed.unicodeScalars.allSatisfy({ allowedCharacters.contains($0) }) {
            usernameError =
                "Username can only contain letters, numbers, spaces, hyphens, and underscores"
            return false
        }

        // Valid
        usernameError = nil
        return true
    }

    /// Validates username as user types (for inline validation)
    /// - Parameter text: Current username text
    func validateUsernameInline(_ text: String) {
        _ = validateUsername(text)
    }

    // MARK: - Profile Picture Editing (Task 14.3)

    /// Selects a profile picture from the photo library
    /// This method is called when user picks an image
    /// - Parameter image: Selected UIImage
    #if os(iOS)
        func selectProfilePicture(_ image: UIImage) {
            profileImage = image
            errorMessage = nil
        }
    #endif

    /// Uploads the selected profile picture with progress tracking
    #if os(iOS)
        func uploadProfilePicture() async {
            guard let image = profileImage else {
                errorMessage = "No image selected"
                return
            }

            // Clear previous messages
            errorMessage = nil
            successMessage = nil
            isUploading = true

            do {
                // Convert image to JPEG data
                guard let imageData = image.jpegData(compressionQuality: 0.8) else {
                    throw ProfileError.invalidImageData
                }

                // Upload to Supabase Storage
                let url = try await profileService.uploadProfilePicture(
                    userId: userId,
                    imageData: imageData
                )

                // Update local state
                profilePictureUrl = url
                successMessage = "Profile picture updated successfully"

                // Clear the selected image after successful upload
                profileImage = nil

            } catch {
                errorMessage = error.localizedDescription
            }

            isUploading = false
        }
    #else
        func uploadProfilePicture() async {
            errorMessage = "Profile picture upload is not available on macOS"
        }
    #endif

    /// Deletes the current profile picture
    func deleteProfilePicture() async {
        guard profilePictureUrl != nil else {
            return
        }

        // Clear previous messages
        errorMessage = nil
        successMessage = nil
        isUploading = true

        do {
            try await profileService.deleteProfilePicture(userId: userId)

            // Update local state
            profilePictureUrl = nil
            profileImage = nil
            successMessage = "Profile picture removed successfully"

        } catch {
            errorMessage = error.localizedDescription
        }

        isUploading = false
    }

    // MARK: - Save All Changes

    /// Saves all pending changes (username and profile picture)
    func saveChanges() async {
        // Update username if changed
        if !username.isEmpty {
            await updateUsername(username)
        }

        // Upload profile picture if selected
        if profileImage != nil {
            await uploadProfilePicture()
        }
    }

    // MARK: - Error Handling

    /// Clears all error and success messages
    func clearMessages() {
        errorMessage = nil
        successMessage = nil
        usernameError = nil
    }
}
