import Foundation

/// Reward model representing a redeemable item in the reward shop
/// Users can redeem rewards by spending their earned points
struct Reward: Identifiable, Codable, Equatable {

    // MARK: - Properties

    /// Unique identifier
    let id: UUID

    /// Reward title/description
    var title: String

    /// Points cost to redeem this reward
    var pointsCost: Int

    /// Whether the reward is active and available for redemption
    var isActive: Bool

    // MARK: - Coding Keys

    /// Maps Swift property names to database column names (snake_case)
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case pointsCost = "points_cost"
        case isActive = "is_active"
    }

    // MARK: - Computed Properties

    /// Whether the reward is available for redemption
    var isAvailable: Bool {
        isActive
    }

    // MARK: - Validation

    /// Validates reward title length
    /// - Parameter title: Title to validate
    /// - Returns: True if valid, false otherwise
    static func isValidTitle(_ title: String) -> Bool {
        !title.isEmpty && title.count <= AppConstants.maxRewardTitleLength
    }

    /// Validates reward points cost
    /// - Parameter cost: Points cost to validate
    /// - Returns: True if valid, false otherwise
    static func isValidPointsCost(_ cost: Int) -> Bool {
        cost >= AppConstants.minRewardCost && cost <= AppConstants.maxRewardCost
    }

    /// Validates the reward instance
    var isValid: Bool {
        Self.isValidTitle(title) && Self.isValidPointsCost(pointsCost)
    }
}

// MARK: - Reward Extensions

extension Reward {

    /// Creates a new reward with default values
    /// - Parameters:
    ///   - title: Reward title
    ///   - pointsCost: Points cost to redeem
    ///   - isActive: Whether reward is active (defaults to true)
    /// - Returns: New reward instance
    static func new(
        title: String,
        pointsCost: Int,
        isActive: Bool = true
    ) -> Reward {
        Reward(
            id: UUID(),
            title: title,
            pointsCost: pointsCost,
            isActive: isActive
        )
    }

    /// Creates a copy with updated title
    /// - Parameter newTitle: New title
    /// - Returns: Updated reward copy
    func withTitle(_ newTitle: String) -> Reward {
        var copy = self
        copy.title = newTitle
        return copy
    }

    /// Creates a copy with updated points cost
    /// - Parameter newCost: New points cost
    /// - Returns: Updated reward copy
    func withPointsCost(_ newCost: Int) -> Reward {
        var copy = self
        copy.pointsCost = newCost
        return copy
    }

    /// Creates a copy with updated active status
    /// - Parameter active: New active status
    /// - Returns: Updated reward copy
    func withActiveStatus(_ active: Bool) -> Reward {
        var copy = self
        copy.isActive = active
        return copy
    }
}

// MARK: - Reward Validation Rules

/*
 Validation Rules (from design document):

 1. id is auto-generated UUID
 2. title is required, non-empty string (max 100 characters)
 3. pointsCost must be positive integer (1-10000 range)
 4. isActive defaults to true
 5. Only active rewards appear in shop

 Database Constraints:
 - id: PRIMARY KEY
 - title: NOT NULL, CHECK (length(title) > 0 AND length(title) <= 100)
 - points_cost: NOT NULL, CHECK (points_cost > 0 AND points_cost <= 10000)
 - is_active: NOT NULL, DEFAULT true
 */
