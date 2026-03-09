import Foundation
import Supabase

/// Service for managing rewards and redemption operations
/// Handles reward catalog management and point-based redemptions
class RewardService {

    // MARK: - Singleton

    static let shared = RewardService()

    // MARK: - Private Properties

    private let client = supabase

    // MARK: - Initialization

    private init() {}

    // MARK: - Reward Catalog Operations

    /// Fetches all active rewards available for redemption
    /// - Returns: Array of active rewards
    /// - Throws: RewardError if fetch fails
    func fetchActiveRewards() async throws -> [Reward] {
        do {
            let rewards: [Reward] =
                try await client
                .from("rewards")
                .select()
                .eq("is_active", value: true)
                .execute()
                .value

            print("✅ Fetched \(rewards.count) active rewards")
            return rewards
        } catch {
            print("❌ Failed to fetch active rewards: \(error.localizedDescription)")
            throw RewardError.fetchFailed(error.localizedDescription)
        }
    }

    /// Creates a new reward in the catalog
    /// - Parameters:
    ///   - title: Reward title/description
    ///   - pointsCost: Points required to redeem
    /// - Returns: Newly created reward
    /// - Throws: RewardError if validation or creation fails
    func createReward(title: String, pointsCost: Int) async throws -> Reward {
        // Validate title
        guard Reward.isValidTitle(title) else {
            throw RewardError.invalidTitle
        }

        // Validate points cost
        guard Reward.isValidPointsCost(pointsCost) else {
            throw RewardError.invalidPointsCost
        }

        let newReward = Reward.new(
            title: title,
            pointsCost: pointsCost,
            isActive: true
        )

        do {
            let reward: Reward =
                try await client
                .from("rewards")
                .insert(newReward)
                .select()
                .single()
                .execute()
                .value

            print("✅ Reward created: \(title) (\(pointsCost) points)")
            return reward
        } catch {
            print("❌ Failed to create reward: \(error.localizedDescription)")
            throw RewardError.creationFailed(error.localizedDescription)
        }
    }

    /// Toggles a reward's active status
    /// - Parameters:
    ///   - rewardId: Reward's unique identifier
    ///   - isActive: New active status
    /// - Throws: RewardError if update fails
    func toggleRewardActive(rewardId: UUID, isActive: Bool) async throws {
        do {
            try await client
                .from("rewards")
                .update(["is_active": isActive])
                .eq("id", value: rewardId)
                .execute()

            print("✅ Reward \(rewardId) active status set to: \(isActive)")
        } catch {
            print("❌ Failed to toggle reward active status: \(error.localizedDescription)")
            throw RewardError.updateFailed(error.localizedDescription)
        }
    }

    // MARK: - Redemption Operations

    /// Redeems a reward for a user
    /// Validates reward exists, is active, and user has sufficient points
    /// Atomically deducts points and creates transaction record using database function
    /// - Parameters:
    ///   - rewardId: Reward's unique identifier
    ///   - userId: User's unique identifier
    /// - Throws: RewardError if validation or redemption fails
    func redeemReward(rewardId: UUID, userId: UUID) async throws {
        // Use atomic database function to ensure all-or-nothing redemption
        // This function performs:
        // 1. Reward validation (exists and is active)
        // 2. Balance validation (user has sufficient points)
        // 3. Point deduction (atomic)
        // 4. Transaction record creation
        // All operations succeed together or rollback on any failure

        do {
            let result: [String: AnyJSON] =
                try await client
                .rpc(
                    "redeem_reward_atomic",
                    params: [
                        "p_reward_id": rewardId,
                        "p_user_id": userId,
                    ]
                )
                .execute()
                .value

            // Extract result details
            if let success = result["success"]?.boolValue, success {
                let pointsDeducted = result["points_deducted"]?.intValue ?? 0
                print("✅ Reward redeemed atomically: \(pointsDeducted) points for user \(userId)")
            } else {
                throw RewardError.redemptionFailed
            }
        } catch {
            // Parse error message to provide specific error types
            let errorMessage = error.localizedDescription.lowercased()

            if errorMessage.contains("reward not found") {
                throw RewardError.notFound
            } else if errorMessage.contains("not active") {
                throw RewardError.notActive
            } else if errorMessage.contains("insufficient points") {
                // Try to extract required and available from error message
                // Format: "Insufficient points. Required: X, Available: Y"
                throw RewardError.insufficientPointsGeneric
            } else {
                print("❌ Reward redemption failed: \(error.localizedDescription)")
                throw RewardError.redemptionFailed
            }
        }
    }

    // MARK: - Helper Methods

    /// Fetches a single reward by ID
    /// - Parameter rewardId: Reward's unique identifier
    /// - Returns: Reward if found, nil otherwise
    /// - Throws: RewardError if fetch fails
    private func fetchReward(rewardId: UUID) async throws -> Reward? {
        do {
            let reward: Reward =
                try await client
                .from("rewards")
                .select()
                .eq("id", value: rewardId)
                .single()
                .execute()
                .value

            return reward
        } catch {
            // Check if it's a "not found" error
            if error.localizedDescription.contains("not found")
                || error.localizedDescription.contains("no rows")
            {
                return nil
            }
            throw RewardError.fetchFailed(error.localizedDescription)
        }
    }
}

// MARK: - RewardError

/// Custom error types for reward operations
enum RewardError: LocalizedError {
    case fetchFailed(String)
    case creationFailed(String)
    case updateFailed(String)
    case transactionFailed(String)
    case invalidTitle
    case invalidPointsCost
    case notFound
    case notActive
    case insufficientPoints(required: Int, available: Int)
    case insufficientPointsGeneric
    case redemptionFailed

    var errorDescription: String? {
        switch self {
        case .fetchFailed(let message):
            return "Failed to fetch rewards: \(message)"
        case .creationFailed(let message):
            return "Failed to create reward: \(message)"
        case .updateFailed(let message):
            return "Failed to update reward: \(message)"
        case .transactionFailed(let message):
            return "Failed to record transaction: \(message)"
        case .invalidTitle:
            return "Reward title must be 1-\(AppConstants.maxRewardTitleLength) characters"
        case .invalidPointsCost:
            return
                "Points cost must be between \(AppConstants.minRewardCost) and \(AppConstants.maxRewardCost)"
        case .notFound:
            return "Reward not found"
        case .notActive:
            return "This reward is no longer available"
        case .insufficientPoints(let required, let available):
            return "Insufficient points. Required: \(required), Available: \(available)"
        case .insufficientPointsGeneric:
            return "Insufficient points to redeem this reward"
        case .redemptionFailed:
            return "Reward redemption failed. Please try again."
        }
    }
}
