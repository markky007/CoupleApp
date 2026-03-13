import Combine
import Foundation
import Supabase

#if os(iOS)
    import UIKit
#endif

// MARK: - Helper Structs

/// Parameters for RPC point update function
struct PointsParams: Encodable, Sendable {
    let user_id: String
    let points_delta: Int
}

/// Parameters for partner update (setting to null)
struct PartnerUpdate: Encodable, Sendable {
    let partner_id: UUID?
    let updated_at: String
}

/// Service for managing user profiles and partner relationships
/// Handles CRUD operations, partner pairing, and point management
class ProfileService {

    // MARK: - Singleton

    static let shared = ProfileService()

    // MARK: - Private Properties

    private let client = supabase
    private var realtimeChannel: RealtimeChannelV2?

    // MARK: - Initialization

    private init() {}

    deinit {
        // Clean up realtime subscription
        Task {
            await realtimeChannel?.unsubscribe()
        }
    }

    // MARK: - Profile CRUD Operations

    /// Fetches a user's profile by ID
    /// - Parameter userId: User's unique identifier
    /// - Returns: User's profile
    /// - Throws: ProfileError if fetch fails
    func fetchProfile(userId: UUID) async throws -> Profile {
        do {
            let response =
                try await client
                .from("profiles")
                .select()
                .eq("id", value: userId)
                .execute()

            // Decode response as array and get first element
            let profiles = try JSONDecoder().decode([Profile].self, from: response.data)
            guard let profile = profiles.first else {
                throw ProfileError.profileNotFound
            }

            print("✅ Profile fetched for user: \(userId)")
            return profile
        } catch let error as ProfileError {
            throw error
        } catch {
            print("❌ Failed to fetch profile: \(error.localizedDescription)")
            throw ProfileError.fetchFailed(error.localizedDescription)
        }
    }

    /// Creates a new profile for a user
    /// - Parameters:
    ///   - userId: User's unique identifier from auth
    ///   - displayName: Optional display name
    /// - Returns: Newly created profile
    /// - Throws: ProfileError if creation fails
    func createProfile(userId: UUID, displayName: String) async throws -> Profile {
        // Validate display name
        guard Profile.isValidDisplayName(displayName) else {
            throw ProfileError.invalidDisplayName
        }

        let newProfile = Profile.new(id: userId, displayName: displayName)

        do {
            let response =
                try await client
                .from("profiles")
                .insert(newProfile)
                .select()
                .execute()

            // Decode response as array and get first element
            let profiles = try JSONDecoder().decode([Profile].self, from: response.data)
            guard let profile = profiles.first else {
                throw ProfileError.creationFailed("Failed to create profile")
            }

            print("✅ Profile created for user: \(userId)")
            return profile
        } catch let error as ProfileError {
            throw error
        } catch {
            print("❌ Failed to create profile: \(error.localizedDescription)")
            throw ProfileError.creationFailed(error.localizedDescription)
        }
    }

    /// Updates a user's display name
    /// - Parameters:
    ///   - userId: User's unique identifier
    ///   - newName: New display name
    /// - Throws: ProfileError if update fails
    func updateDisplayName(userId: UUID, newName: String) async throws {
        // Validate display name
        guard Profile.isValidDisplayName(newName) else {
            throw ProfileError.invalidDisplayName
        }

        do {
            try await client
                .from("profiles")
                .update(["display_name": newName, "updated_at": Date().ISO8601Format()])
                .eq("id", value: userId)
                .execute()

            print("✅ Display name updated for user: \(userId)")
        } catch {
            print("❌ Failed to update display name: \(error.localizedDescription)")
            throw ProfileError.updateFailed(error.localizedDescription)
        }
    }

    // MARK: - Partner Pairing

    /// Pairs current user with a partner (creates bidirectional relationship)
    /// - Parameters:
    ///   - userId: Current user's ID
    ///   - partnerId: Partner's user ID
    /// - Throws: ProfileError if pairing fails
    func pairWithPartner(userId: UUID, partnerId: UUID) async throws {
        // Validate inputs
        guard userId != partnerId else {
            throw ProfileError.cannotPairWithSelf
        }

        do {
            // Fetch both profiles to verify they exist and aren't already paired
            let userProfile = try await fetchProfile(userId: userId)
            let partnerProfile = try await fetchProfile(userId: partnerId)

            // Check if already paired
            if userProfile.partnerId != nil {
                throw ProfileError.alreadyPaired
            }

            if partnerProfile.partnerId != nil {
                throw ProfileError.partnerAlreadyPaired
            }

            // Update both profiles to create bidirectional relationship
            // Note: In production, this should be done in a database transaction
            // For now, we'll do it sequentially

            // Update user's profile
            try await client
                .from("profiles")
                .update(["partner_id": partnerId.uuidString, "updated_at": Date().ISO8601Format()])
                .eq("id", value: userId)
                .execute()

            // Update partner's profile
            try await client
                .from("profiles")
                .update(["partner_id": userId.uuidString, "updated_at": Date().ISO8601Format()])
                .eq("id", value: partnerId)
                .execute()

            print("✅ Successfully paired users: \(userId) ↔ \(partnerId)")
        } catch let error as ProfileError {
            throw error
        } catch {
            print("❌ Failed to pair with partner: \(error.localizedDescription)")
            throw ProfileError.pairingFailed(error.localizedDescription)
        }
    }

    /// Unpairs current user from their partner
    /// - Parameter userId: Current user's ID
    /// - Throws: ProfileError if unpairing fails
    func unpairFromPartner(userId: UUID) async throws {
        do {
            let profile = try await fetchProfile(userId: userId)

            guard let partnerId = profile.partnerId else {
                throw ProfileError.notPaired
            }

            // Remove partner relationship from both profiles
            let nullUpdate = PartnerUpdate(
                partner_id: nil,
                updated_at: Date().ISO8601Format()
            )

            try await client
                .from("profiles")
                .update(nullUpdate)
                .eq("id", value: userId)
                .execute()

            try await client
                .from("profiles")
                .update(nullUpdate)
                .eq("id", value: partnerId)
                .execute()

            print("✅ Successfully unpaired users: \(userId) ↔ \(partnerId)")
        } catch let error as ProfileError {
            throw error
        } catch {
            print("❌ Failed to unpair from partner: \(error.localizedDescription)")
            throw ProfileError.unpairingFailed(error.localizedDescription)
        }
    }

    // MARK: - Point Management

    /// Updates a user's point balance
    /// Uses database RPC function for atomic updates
    /// - Parameters:
    ///   - userId: User's unique identifier
    ///   - delta: Point change (positive to add, negative to subtract)
    /// - Throws: ProfileError if update fails
    nonisolated func updatePoints(userId: UUID, delta: Int) async throws {
        do {
            // Use database RPC function for atomic point updates
            // Note: Using JSONEncoder to create params to avoid actor isolation issues
            let paramsDict: [String: AnyJSON] = [
                "user_id": .string(userId.uuidString),
                "points_delta": .integer(delta),
            ]

            try await client
                .rpc("increment_user_points", params: paramsDict)
                .execute()

            print("✅ Points updated for user \(userId): \(delta > 0 ? "+" : "")\(delta)")
        } catch {
            print("❌ Failed to update points: \(error.localizedDescription)")
            throw ProfileError.pointUpdateFailed(error.localizedDescription)
        }
    }

    // MARK: - Partner Code Management

    /// Updates a user's partner code
    /// - Parameters:
    ///   - userId: User's unique identifier
    ///   - code: Partner code to set (6-8 characters, alphanumeric)
    /// - Throws: ProfileError if update fails or code is invalid
    func updatePartnerCode(userId: UUID, code: String) async throws {
        // Validate partner code format
        guard Profile.isValidPartnerCode(code) else {
            throw ProfileError.invalidPartnerCode
        }

        let normalizedCode = code.trimmingCharacters(in: .whitespaces).uppercased()

        do {
            try await client
                .from("profiles")
                .update([
                    "partner_code": normalizedCode,
                    "updated_at": Date().ISO8601Format(),
                ])
                .eq("id", value: userId)
                .execute()

            print("✅ Partner code updated for user: \(userId)")
        } catch {
            print("❌ Failed to update partner code: \(error.localizedDescription)")
            throw ProfileError.updateFailed(error.localizedDescription)
        }
    }

    /// Fetches a profile by partner code
    /// - Parameter code: Partner code to search for
    /// - Returns: Profile with matching partner code, or nil if not found
    /// - Throws: ProfileError if fetch fails
    func fetchProfileByPartnerCode(_ code: String) async throws -> Profile? {
        let normalizedCode = code.trimmingCharacters(in: .whitespaces).uppercased()

        do {
            // Execute query and manually decode response as array
            let response =
                try await client
                .from("profiles")
                .select()
                .eq("partner_code", value: normalizedCode)
                .execute()

            // Decode response data as array of profiles
            let profiles = try JSONDecoder().decode([Profile].self, from: response.data)

            if profiles.isEmpty {
                return nil
            }

            print("✅ Profile found for partner code: \(normalizedCode)")
            return profiles.first
        } catch {
            print("❌ Failed to fetch profile by partner code: \(error.localizedDescription)")
            throw ProfileError.fetchFailed(error.localizedDescription)
        }
    }

    // MARK: - Profile Picture Management

    /// Uploads a profile picture for a user
    /// - Parameters:
    ///   - userId: User's unique identifier
    ///   - imageData: Image data to upload (will be resized to 512x512 max)
    /// - Returns: Public URL of the uploaded image
    /// - Throws: ProfileError if upload fails
    func uploadProfilePicture(userId: UUID, imageData: Data) async throws -> String {
        #if os(iOS)
            // Validate image data
            guard let image = UIImage(data: imageData) else {
                throw ProfileError.invalidImageData
            }

            // Resize image to max 512x512
            guard let resizedData = ProfilePictureHelper.resizeImage(image, maxSize: 512) else {
                throw ProfileError.imageResizeFailed
            }
        #else
            // On macOS, use imageData directly without resizing
            let resizedData = imageData
        #endif

        // Generate unique filename
        let fileName = "\(UUID().uuidString).jpg"
        let storagePath = "\(userId.uuidString)/\(fileName)"

        do {
            // Delete old profile picture if exists
            let profile = try await fetchProfile(userId: userId)
            if let oldUrl = profile.profilePictureUrl {
                // Extract path from URL and delete
                #if os(iOS)
                    if let oldPath = ProfilePictureHelper.extractStoragePath(from: oldUrl) {
                        try? await client.storage
                            .from("profile-pictures")
                            .remove(paths: [oldPath])
                    }
                #endif
            }

            // Upload to Supabase Storage
            _ = try await client.storage
                .from("profile-pictures")
                .upload(
                    path: storagePath,
                    file: resizedData,
                    options: FileOptions(contentType: "image/jpeg")
                )

            // Get public URL
            let publicURL = try client.storage
                .from("profile-pictures")
                .getPublicURL(path: storagePath)

            // Update profile with new URL
            try await client
                .from("profiles")
                .update([
                    "profile_picture_url": publicURL.absoluteString,
                    "updated_at": Date().ISO8601Format(),
                ])
                .eq("id", value: userId)
                .execute()

            print("✅ Profile picture uploaded for user: \(userId)")
            return publicURL.absoluteString
        } catch let error as ProfileError {
            throw error
        } catch {
            print("❌ Failed to upload profile picture: \(error.localizedDescription)")
            throw ProfileError.uploadFailed(error.localizedDescription)
        }
    }

    /// Deletes a user's profile picture
    /// - Parameter userId: User's unique identifier
    /// - Throws: ProfileError if deletion fails
    func deleteProfilePicture(userId: UUID) async throws {
        do {
            let profile = try await fetchProfile(userId: userId)

            guard let pictureUrl = profile.profilePictureUrl else {
                // No picture to delete
                return
            }

            // Extract path from URL and delete from storage
            #if os(iOS)
                if let storagePath = ProfilePictureHelper.extractStoragePath(from: pictureUrl) {
                    try await client.storage
                        .from("profile-pictures")
                        .remove(paths: [storagePath])
                }
            #endif

            // Clear profile_picture_url in database
            try await client
                .from("profiles")
                .update([
                    "profile_picture_url": nil as String?,
                    "updated_at": Date().ISO8601Format(),
                ])
                .eq("id", value: userId)
                .execute()

            print("✅ Profile picture deleted for user: \(userId)")
        } catch let error as ProfileError {
            throw error
        } catch {
            print("❌ Failed to delete profile picture: \(error.localizedDescription)")
            throw ProfileError.deleteFailed(error.localizedDescription)
        }
    }

    // MARK: - Username Management

    /// Updates a user's username
    /// - Parameters:
    ///   - userId: User's unique identifier
    ///   - username: New username (1-50 characters, alphanumeric + spaces/hyphens/underscores)
    /// - Throws: ProfileError if update fails or username is invalid
    func updateUsername(userId: UUID, username: String) async throws {
        // Validate username
        guard validateUsername(username) else {
            throw ProfileError.invalidUsername
        }

        let trimmedUsername = username.trimmingCharacters(in: .whitespaces)

        do {
            try await client
                .from("profiles")
                .update([
                    "username": trimmedUsername,
                    "updated_at": Date().ISO8601Format(),
                ])
                .eq("id", value: userId)
                .execute()

            print("✅ Username updated for user: \(userId)")
        } catch {
            print("❌ Failed to update username: \(error.localizedDescription)")
            throw ProfileError.updateFailed(error.localizedDescription)
        }
    }

    /// Validates a username
    /// - Parameter username: Username to validate
    /// - Returns: True if valid, false otherwise
    func validateUsername(_ username: String) -> Bool {
        return Profile.isValidUsername(username)
    }

    // MARK: - Preference Management

    /// Updates a user's theme preference
    /// - Parameters:
    ///   - userId: User's unique identifier
    ///   - theme: Theme preference ("light", "dark", or "system")
    /// - Throws: ProfileError if update fails
    func updateThemePreference(userId: UUID, theme: String) async throws {
        // Validate theme value
        guard ["light", "dark", "system"].contains(theme) else {
            throw ProfileError.invalidThemePreference
        }

        do {
            try await client
                .from("profiles")
                .update([
                    "theme_preference": theme,
                    "updated_at": Date().ISO8601Format(),
                ])
                .eq("id", value: userId)
                .execute()

            print("✅ Theme preference updated for user: \(userId)")
        } catch {
            print("❌ Failed to update theme preference: \(error.localizedDescription)")
            throw ProfileError.updateFailed(error.localizedDescription)
        }
    }

    /// Updates a user's language preference
    /// - Parameters:
    ///   - userId: User's unique identifier
    ///   - language: Language preference ("en" or "th")
    /// - Throws: ProfileError if update fails
    func updateLanguagePreference(userId: UUID, language: String) async throws {
        // Validate language value
        guard ["en", "th"].contains(language) else {
            throw ProfileError.invalidLanguagePreference
        }

        do {
            try await client
                .from("profiles")
                .update([
                    "language_preference": language,
                    "updated_at": Date().ISO8601Format(),
                ])
                .eq("id", value: userId)
                .execute()

            print("✅ Language preference updated for user: \(userId)")
        } catch {
            print("❌ Failed to update language preference: \(error.localizedDescription)")
            throw ProfileError.updateFailed(error.localizedDescription)
        }
    }

    // MARK: - Realtime Subscriptions

    /// Subscribes to profile changes for real-time updates
    /// - Parameters:
    ///   - userId: User ID to monitor
    ///   - handler: Callback when profile changes
    /// - Throws: ProfileError if subscription fails
    func subscribeToProfileChanges(
        userId: UUID,
        handler: @escaping (Profile) -> Void
    ) async throws {
        do {
            // Unsubscribe from existing channel if any
            await realtimeChannel?.unsubscribe()

            // Create new channel for profile updates
            let channel = client.channel("profile:\(userId)")

            // Subscribe to postgres changes on profiles table
            let changes = await channel.postgresChange(
                InsertAction.self,
                schema: "public",
                table: "profiles",
                filter: "id=eq.\(userId)"
            )

            await channel.subscribe()

            // Listen for changes
            Task {
                for await change in changes {
                    // Decode the new record from the change
                    let newRecord = change.record
                    if let jsonData = try? JSONSerialization.data(withJSONObject: newRecord),
                        let profile = try? JSONDecoder().decode(Profile.self, from: jsonData)
                    {
                        handler(profile)
                    }
                }
            }

            self.realtimeChannel = channel
            print("✅ Subscribed to profile changes for user: \(userId)")
        } catch {
            print("❌ Failed to subscribe to profile changes: \(error.localizedDescription)")
            throw ProfileError.subscriptionFailed(error.localizedDescription)
        }
    }

    /// Unsubscribes from profile changes
    func unsubscribeFromProfileChanges() async {
        await realtimeChannel?.unsubscribe()
        realtimeChannel = nil
        print("✅ Unsubscribed from profile changes")
    }

}

// MARK: - ProfileError

/// Custom error types for profile operations
enum ProfileError: LocalizedError {
    case fetchFailed(String)
    case creationFailed(String)
    case updateFailed(String)
    case invalidDisplayName
    case cannotPairWithSelf
    case alreadyPaired
    case partnerAlreadyPaired
    case notPaired
    case pairingFailed(String)
    case unpairingFailed(String)
    case pointUpdateFailed(String)
    case subscriptionFailed(String)
    case profileNotFound
    case invalidPartnerCode
    case invalidImageData
    case imageResizeFailed
    case uploadFailed(String)
    case deleteFailed(String)
    case invalidUsername
    case invalidThemePreference
    case invalidLanguagePreference

    var errorDescription: String? {
        switch self {
        case .fetchFailed(let message):
            return "Failed to fetch profile: \(message)"
        case .creationFailed(let message):
            return "Failed to create profile: \(message)"
        case .updateFailed(let message):
            return "Failed to update profile: \(message)"
        case .invalidDisplayName:
            return "Display name must be 1-\(AppConstants.maxDisplayNameLength) characters"
        case .cannotPairWithSelf:
            return "You cannot pair with yourself"
        case .alreadyPaired:
            return "You are already paired with a partner"
        case .partnerAlreadyPaired:
            return "This user is already paired with someone else"
        case .notPaired:
            return "You are not currently paired with anyone"
        case .pairingFailed(let message):
            return "Failed to pair with partner: \(message)"
        case .unpairingFailed(let message):
            return "Failed to unpair from partner: \(message)"
        case .pointUpdateFailed(let message):
            return "Failed to update points: \(message)"
        case .subscriptionFailed(let message):
            return "Failed to subscribe to updates: \(message)"
        case .profileNotFound:
            return "Profile not found"
        case .invalidPartnerCode:
            return "Partner code must be 6-8 alphanumeric characters"
        case .invalidImageData:
            return "Invalid image data"
        case .imageResizeFailed:
            return "Failed to resize image"
        case .uploadFailed(let message):
            return "Failed to upload profile picture: \(message)"
        case .deleteFailed(let message):
            return "Failed to delete profile picture: \(message)"
        case .invalidUsername:
            return
                "Username must be 1-50 characters and contain only letters, numbers, spaces, hyphens, and underscores"
        case .invalidThemePreference:
            return "Theme preference must be 'light', 'dark', or 'system'"
        case .invalidLanguagePreference:
            return "Language preference must be 'en' or 'th'"
        }
    }
}

// MARK: - ProfilePictureHelper

/// Helper struct for profile picture operations
#if os(iOS)
    struct ProfilePictureHelper {

        /// Resizes an image to fit within maximum dimensions while maintaining aspect ratio
        /// - Parameters:
        ///   - image: Original UIImage
        ///   - maxSize: Maximum width/height in pixels
        /// - Returns: JPEG data of resized image, or nil if resize fails
        static func resizeImage(_ image: UIImage, maxSize: CGFloat = 512) -> Data? {
            let size = image.size
            let ratio = min(maxSize / size.width, maxSize / size.height)

            // If image is already smaller than maxSize, use original size
            let newSize: CGSize
            if ratio >= 1.0 {
                newSize = size
            } else {
                newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
            }

            UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
            image.draw(in: CGRect(origin: .zero, size: newSize))
            let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()

            return resizedImage?.jpegData(compressionQuality: 0.8)
        }

        /// Extracts storage path from a Supabase Storage public URL
        /// - Parameter url: Public URL string
        /// - Returns: Storage path (e.g., "userId/filename.jpg"), or nil if extraction fails
        static func extractStoragePath(from url: String) -> String? {
            // URL format: https://{project}.supabase.co/storage/v1/object/public/profile-pictures/{path}
            guard let urlComponents = URLComponents(string: url),
                let pathComponents = urlComponents.path.components(
                    separatedBy: "/profile-pictures/"
                )
                .last
            else {
                return nil
            }
            return pathComponents
        }
    }
#endif
