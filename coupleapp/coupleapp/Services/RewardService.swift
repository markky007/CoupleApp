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
    /// Returns approved rewards (system rewards + custom rewards visible to user)
    /// - Returns: Array of active rewards
    /// - Throws: RewardError if fetch fails
    func fetchActiveRewards() async throws -> [Reward] {
        do {
            // Fetch rewards that are:
            // 1. Active (is_active = true)
            // 2. Approved status (status = 'approved')
            // RLS policies automatically filter custom rewards to only show:
            // - System rewards (visible to all)
            // - Custom rewards created by user or their partner
            let rewards: [Reward] =
                try await client
                .from("rewards")
                .select()
                .eq("is_active", value: true)
                .eq("status", value: "approved")
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

    // MARK: - Custom Reward Operations

    /// Creates a custom reward proposal that requires partner approval
    /// - Parameters:
    ///   - title: Reward title/description
    ///   - pointsCost: Points required to redeem
    ///   - createdBy: User ID of creator
    /// - Returns: Newly created reward with pending status
    /// - Throws: RewardError if validation or creation fails
    func createRewardProposal(title: String, pointsCost: Int, createdBy: UUID) async throws
        -> Reward
    {
        // Validate title
        guard Reward.isValidTitle(title) else {
            throw RewardError.invalidTitle
        }

        // Validate points cost
        guard Reward.isValidPointsCost(pointsCost) else {
            throw RewardError.invalidPointsCost
        }

        // Create custom reward with pending status
        let newReward = Reward.newCustomReward(
            title: title,
            pointsCost: pointsCost,
            createdBy: createdBy
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

            print("✅ Custom reward proposal created: \(title) by user \(createdBy)")
            return reward
        } catch {
            print("❌ Failed to create reward proposal: \(error.localizedDescription)")
            throw RewardError.creationFailed(error.localizedDescription)
        }
    }

    /// Fetches pending reward proposals awaiting the current user's approval
    /// Returns rewards created by the user's partner that are in pending status
    /// - Parameter userId: Current user's ID
    /// - Returns: Array of pending rewards requiring approval
    /// - Throws: RewardError if fetch fails or user has no partner
    func fetchPendingApprovals(userId: UUID) async throws -> [Reward] {
        do {
            // Get user's profile to find partner ID
            let profile = try await ProfileService.shared.fetchProfile(userId: userId)

            guard let partnerId = profile.partnerId else {
                throw RewardError.noPartner
            }

            // Fetch pending rewards created by partner
            let rewards: [Reward] =
                try await client
                .from("rewards")
                .select()
                .eq("status", value: "pending")
                .eq("created_by", value: partnerId)
                .execute()
                .value

            print("✅ Fetched \(rewards.count) pending approvals for user \(userId)")
            return rewards
        } catch let error as RewardError {
            throw error
        } catch {
            print("❌ Failed to fetch pending approvals: \(error.localizedDescription)")
            throw RewardError.fetchFailed(error.localizedDescription)
        }
    }

    /// Approves a pending reward proposal
    /// Validates that the current user is the partner of the reward creator
    /// Updates reward status to approved and sets isActive to true
    /// - Parameters:
    ///   - rewardId: Reward's unique identifier
    ///   - approvingUserId: User ID of the person approving
    /// - Throws: RewardError if validation or approval fails
    func approveReward(rewardId: UUID, approvingUserId: UUID) async throws {
        do {
            // Fetch the reward to validate
            guard let reward = try await fetchReward(rewardId: rewardId) else {
                throw RewardError.notFound
            }

            // Check if reward is pending
            guard reward.status == RewardStatus.pending else {
                throw RewardError.alreadyProcessed
            }

            // Verify the approving user is the partner of the creator
            guard let creatorId = reward.createdBy else {
                throw RewardError.unauthorizedApproval
            }

            let approverProfile = try await ProfileService.shared.fetchProfile(
                userId: approvingUserId)

            guard approverProfile.partnerId == creatorId else {
                throw RewardError.unauthorizedApproval
            }

            // Update reward to approved status
            try await client
                .from("rewards")
                .update([
                    "status": "approved",
                    "is_active": "true",
                    "updated_at": Date().ISO8601Format(),
                ])
                .eq("id", value: rewardId)
                .execute()

            print("✅ Reward \(rewardId) approved by user \(approvingUserId)")
        } catch let error as RewardError {
            throw error
        } catch let error as ProfileError {
            throw RewardError.approvalFailed(error.localizedDescription)
        } catch {
            print("❌ Failed to approve reward: \(error.localizedDescription)")
            throw RewardError.approvalFailed(error.localizedDescription)
        }
    }

    /// Rejects a pending reward proposal
    /// Validates that the current user is the partner of the reward creator
    /// Updates reward status to rejected
    /// - Parameters:
    ///   - rewardId: Reward's unique identifier
    ///   - rejectingUserId: User ID of the person rejecting
    /// - Throws: RewardError if validation or rejection fails
    func rejectReward(rewardId: UUID, rejectingUserId: UUID) async throws {
        do {
            // Fetch the reward to validate
            guard let reward = try await fetchReward(rewardId: rewardId) else {
                throw RewardError.notFound
            }

            // Check if reward is pending
            guard reward.status == RewardStatus.pending else {
                throw RewardError.alreadyProcessed
            }

            // Verify the rejecting user is the partner of the creator
            guard let creatorId = reward.createdBy else {
                throw RewardError.unauthorizedApproval
            }

            let rejecterProfile = try await ProfileService.shared.fetchProfile(
                userId: rejectingUserId)

            guard rejecterProfile.partnerId == creatorId else {
                throw RewardError.unauthorizedApproval
            }

            // Update reward to rejected status
            try await client
                .from("rewards")
                .update([
                    "status": "rejected",
                    "updated_at": Date().ISO8601Format(),
                ])
                .eq("id", value: rewardId)
                .execute()

            print("✅ Reward \(rewardId) rejected by user \(rejectingUserId)")
        } catch let error as RewardError {
            throw error
        } catch let error as ProfileError {
            throw RewardError.rejectionFailed(error.localizedDescription)
        } catch {
            print("❌ Failed to reject reward: \(error.localizedDescription)")
            throw RewardError.rejectionFailed(error.localizedDescription)
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

    // New errors for custom rewards and approval workflow
    case alreadyProcessed
    case unauthorizedApproval
    case noPartner
    case approvalFailed(String)
    case rejectionFailed(String)

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
        case .alreadyProcessed:
            return "This reward has already been approved or rejected"
        case .unauthorizedApproval:
            return "Only your partner can approve this reward"
        case .noPartner:
            return "You must be paired with a partner to approve rewards"
        case .approvalFailed(let message):
            return "Failed to approve reward: \(message)"
        case .rejectionFailed(let message):
            return "Failed to reject reward: \(message)"
        }
    }
}
