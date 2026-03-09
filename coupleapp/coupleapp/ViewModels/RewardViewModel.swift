import Combine
import Foundation
import SwiftUI

/// ViewModel for managing reward shop state and operations
/// Handles reward fetching, redemption, and user point balance
@MainActor
class RewardViewModel: ObservableObject {

    // MARK: - Published Properties

    /// Array of available rewards
    @Published var rewards: [Reward] = []

    /// Current user's point balance
    @Published var userPoints: Int = 0

    /// Loading state
    @Published var isLoading = false

    /// Error state
    @Published var showError = false
    @Published var errorMessage: String?

    /// Success state
    @Published var showSuccess = false
    @Published var successMessage: String?

    /// Redemption confirmation state
    @Published var showRedemptionConfirmation = false
    @Published var selectedReward: Reward?

    // MARK: - Private Properties

    private let rewardService = RewardService.shared
    private let profileService = ProfileService.shared
    private let authService = AuthService.shared

    // MARK: - Initialization

    init() {}

    // MARK: - Public Methods

    /// Fetches active rewards and user's current point balance
    func fetchRewards() async {
        isLoading = true
        defer { isLoading = false }

        do {
            // Fetch rewards
            rewards = try await rewardService.fetchActiveRewards()

            // Fetch user's current points
            if let userId = authService.currentUserId {
                do {
                    let profile = try await profileService.fetchProfile(userId: userId)
                    userPoints = profile.totalPoints
                } catch {
                    // If profile doesn't exist, create it with default values
                    print("⚠️ Profile not found, creating new profile...")
                    let newProfile = try await profileService.createProfile(
                        userId: userId,
                        displayName: "User"
                    )
                    userPoints = newProfile.totalPoints
                }
            }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    /// Shows redemption confirmation dialog for a reward
    /// - Parameter reward: Reward to redeem
    func confirmRedemption(for reward: Reward) {
        selectedReward = reward
        showRedemptionConfirmation = true
    }

    /// Redeems the selected reward
    func redeemSelectedReward() async {
        guard let reward = selectedReward,
            let userId = authService.currentUserId
        else {
            return
        }

        // Check if user has sufficient points
        guard userPoints >= reward.pointsCost else {
            errorMessage =
                "Insufficient points. You need \(reward.pointsCost) points but only have \(userPoints)."
            showError = true
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            // Redeem reward
            try await rewardService.redeemReward(rewardId: reward.id, userId: userId)

            // Update local point balance
            userPoints -= reward.pointsCost

            // Show success message
            successMessage = "Successfully redeemed: \(reward.title)"
            showSuccess = true

            // Clear selected reward
            selectedReward = nil
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
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

    /// Checks if user can afford a reward
    /// - Parameter reward: Reward to check
    /// - Returns: True if user has sufficient points
    func canAfford(_ reward: Reward) -> Bool {
        userPoints >= reward.pointsCost
    }
}
