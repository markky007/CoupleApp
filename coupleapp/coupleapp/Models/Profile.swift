import Foundation

/// User profile model
/// Represents a user's profile with point balance and partner relationship
struct Profile: Identifiable, Codable, Equatable {

    // MARK: - Properties

    /// Unique identifier (matches auth.users.id)
    let id: UUID

    /// User's display name (optional, max 50 characters)
    var displayName: String?

    /// Username for UI display (1-50 characters, alphanumeric + spaces/hyphens/underscores)
    var username: String?

    /// Partner's user ID (optional, creates bidirectional relationship)
    var partnerId: UUID?

    /// Unique code for partner pairing (6-8 characters, alphanumeric)
    var partnerCode: String?

    /// URL to profile picture in Supabase Storage
    var profilePictureUrl: String?

    /// Theme preference: "light", "dark", or "system" (default: "system")
    var themePreference: String?

    /// Language preference: "en" or "th" (default: "en")
    var languagePreference: String?

    /// Total points earned by user (must be non-negative)
    var totalPoints: Int

    /// Profile creation timestamp
    let createdAt: Date?

    /// Profile last update timestamp
    var updatedAt: Date?

    // MARK: - Coding Keys

    /// Maps Swift property names to database column names (snake_case)
    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case username
        case partnerId = "partner_id"
        case partnerCode = "partner_code"
        case profilePictureUrl = "profile_picture_url"
        case themePreference = "theme_preference"
        case languagePreference = "language_preference"
        case totalPoints = "total_points"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    // MARK: - Computed Properties

    /// Whether user has a partner
    var hasPart: Bool {
        partnerId != nil
    }

    /// Whether user has set a display name
    var hasDisplayName: Bool {
        displayName != nil && !displayName!.isEmpty
    }

    // MARK: - Validation

    /// Validates display name length
    /// - Parameter name: Display name to validate
    /// - Returns: True if valid, false otherwise
    static func isValidDisplayName(_ name: String?) -> Bool {
        guard let name = name, !name.isEmpty else {
            return false
        }
        return name.count <= AppConstants.maxDisplayNameLength
    }

    /// Validates username format and length
    /// - Parameter username: Username to validate
    /// - Returns: True if valid, false otherwise
    static func isValidUsername(_ username: String) -> Bool {
        let trimmed = username.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 1 && trimmed.count <= 50 else { return false }

        // Allow letters, numbers, spaces, hyphens, underscores
        let allowedCharacters = CharacterSet.alphanumerics
            .union(CharacterSet(charactersIn: " -_"))
        return trimmed.unicodeScalars.allSatisfy { allowedCharacters.contains($0) }
    }

    /// Validates partner code format
    /// - Parameter code: Partner code to validate
    /// - Returns: True if valid, false otherwise
    static func isValidPartnerCode(_ code: String) -> Bool {
        let trimmed = code.trimmingCharacters(in: .whitespaces).uppercased()
        guard trimmed.count >= 6 && trimmed.count <= 8 else { return false }

        // Only alphanumeric characters
        return trimmed.allSatisfy { $0.isLetter || $0.isNumber }
    }

    /// Validates that total points is non-negative
    var isValidPointBalance: Bool {
        totalPoints >= 0
    }
}

// MARK: - Profile Extensions

extension Profile {

    /// Creates a new profile with default values
    /// - Parameters:
    ///   - id: User ID from authentication
    ///   - displayName: Optional display name
    /// - Returns: New profile instance
    static func new(id: UUID, displayName: String? = nil) -> Profile {
        Profile(
            id: id,
            displayName: displayName,
            username: nil,
            partnerId: nil,
            partnerCode: nil,
            profilePictureUrl: nil,
            themePreference: nil,
            languagePreference: nil,
            totalPoints: 0,
            createdAt: Date(),
            updatedAt: Date()
        )
    }

    /// Creates a copy with updated display name
    /// - Parameter newName: New display name
    /// - Returns: Updated profile copy
    func withDisplayName(_ newName: String) -> Profile {
        var copy = self
        copy.displayName = newName
        copy.updatedAt = Date()
        return copy
    }

    /// Creates a copy with updated partner
    /// - Parameter newPartnerId: New partner ID
    /// - Returns: Updated profile copy
    func withPartner(_ newPartnerId: UUID) -> Profile {
        var copy = self
        copy.partnerId = newPartnerId
        copy.updatedAt = Date()
        return copy
    }

    /// Creates a copy with updated points
    /// - Parameter newPoints: New point total
    /// - Returns: Updated profile copy
    func withPoints(_ newPoints: Int) -> Profile {
        var copy = self
        copy.totalPoints = max(0, newPoints)  // Ensure non-negative
        copy.updatedAt = Date()
        return copy
    }
}

// MARK: - Profile Validation Rules

/*
 Validation Rules (from design document):

 1. id must be valid UUID matching auth.users.id
 2. displayName is optional but recommended (max 50 characters)
 3. partnerId must reference existing profile or be nil
 4. totalPoints must be non-negative integer (>= 0)
 5. Partner relationship must be bidirectional when set

 Database Constraints:
 - id: PRIMARY KEY, REFERENCES auth.users ON DELETE CASCADE
 - partner_id: REFERENCES profiles(id) ON DELETE SET NULL
 - total_points: CHECK (total_points >= 0)
 */
