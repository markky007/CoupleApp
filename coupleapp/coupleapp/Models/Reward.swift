import Foundation

/// Reward status for approval workflow
enum RewardStatus: String, Codable {
    case pending
    case approved
    case rejected
}

/// Reward model representing a redeemable item in the reward shop
/// Users can redeem rewards by spending their earned points
/// Supports both system rewards (visible to all) and custom rewards (require partner approval)
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

    /// User who created this reward (null for system rewards)
    var createdBy: UUID?

    /// Approval status (pending, approved, rejected)
    var status: RewardStatus

    /// Whether this is a system-defined reward (visible to all users)
    var isSystemReward: Bool

    /// Creation timestamp
    var createdAt: Date?

    /// Last update timestamp
    var updatedAt: Date?

    // MARK: - Coding Keys

    /// Maps Swift property names to database column names (snake_case)
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case pointsCost = "points_cost"
        case isActive = "is_active"
        case createdBy = "created_by"
        case status
        case isSystemReward = "is_system_reward"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    // MARK: - Computed Properties

    /// Whether the reward is available for redemption
    var isAvailable: Bool {
        isActive && status == .approved
    }

    /// Whether this is a custom reward created by a user
    var isCustomReward: Bool {
        !isSystemReward
    }

    /// Whether this reward is pending approval
    var isPending: Bool {
        status == .pending
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

    /// Creates a new system reward with default values
    /// - Parameters:
    ///   - title: Reward title
    ///   - pointsCost: Points cost to redeem
    ///   - isActive: Whether reward is active (defaults to true)
    /// - Returns: New system reward instance
    static func newSystemReward(
        title: String,
        pointsCost: Int,
        isActive: Bool = true
    ) -> Reward {
        Reward(
            id: UUID(),
            title: title,
            pointsCost: pointsCost,
            isActive: isActive,
            createdBy: nil,
            status: .approved,
            isSystemReward: true,
            createdAt: Date(),
            updatedAt: Date()
        )
    }

    /// Creates a new custom reward proposal (pending approval)
    /// - Parameters:
    ///   - title: Reward title
    ///   - pointsCost: Points cost to redeem
    ///   - createdBy: User ID of creator
    /// - Returns: New custom reward instance with pending status
    static func newCustomReward(
        title: String,
        pointsCost: Int,
        createdBy: UUID
    ) -> Reward {
        Reward(
            id: UUID(),
            title: title,
            pointsCost: pointsCost,
            isActive: false,
            createdBy: createdBy,
            status: .pending,
            isSystemReward: false,
            createdAt: Date(),
            updatedAt: Date()
        )
    }

    /// Creates a new reward with default values (legacy method)
    /// - Parameters:
    ///   - title: Reward title
    ///   - pointsCost: Points cost to redeem
    ///   - isActive: Whether reward is active (defaults to true)
    /// - Returns: New reward instance
    @available(*, deprecated, message: "Use newSystemReward or newCustomReward instead")
    static func new(
        title: String,
        pointsCost: Int,
        isActive: Bool = true
    ) -> Reward {
        newSystemReward(title: title, pointsCost: pointsCost, isActive: isActive)
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
 4. isActive defaults to false for custom rewards, true for system rewards
 5. createdBy is required for custom rewards (isSystemReward=false)
 6. createdBy is nullable for system rewards (isSystemReward=true)
 7. status defaults to "pending" for custom rewards, "approved" for system rewards
 8. isSystemReward defaults to false
 9. Only approved rewards with isActive=true appear in shop

 Database Constraints:
 - id: PRIMARY KEY
 - title: NOT NULL, CHECK (length(title) > 0 AND length(title) <= 100)
 - points_cost: NOT NULL, CHECK (points_cost > 0 AND points_cost <= 10000)
 - is_active: NOT NULL, DEFAULT true
 - created_by: REFERENCES profiles(id) ON DELETE CASCADE (nullable)
 - status: NOT NULL, DEFAULT 'approved', CHECK (status IN ('pending', 'approved', 'rejected'))
 - is_system_reward: NOT NULL, DEFAULT false
 */
