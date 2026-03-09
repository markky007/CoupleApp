import Combine
import Foundation
import SwiftUI

/// ViewModel for dashboard view
/// Aggregates data from multiple services for unified dashboard display
@MainActor
class DashboardViewModel: ObservableObject {

    // MARK: - Published Properties

    /// User profile
    @Published var userProfile: Profile?

    /// Partner profile
    @Published var partnerProfile: Profile?

    /// Recent quests (last 5)
    @Published var recentQuests: [Quest] = []

    /// Upcoming event (next event)
    @Published var upcomingEvent: Event?

    /// Available rewards preview (first 3)
    @Published var rewardsPreview: [Reward] = []

    /// Loading state
    @Published var isLoading = false

    /// Error state
    @Published var showError = false
    @Published var errorMessage: String?

    // MARK: - Private Properties

    private let profileService = ProfileService.shared
    private let questService = QuestService.shared
    private let eventService = EventService.shared
    private let rewardService = RewardService.shared
    private let authService = AuthService.shared
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Computed Properties

    /// User's point balance
    var userPoints: Int {
        userProfile?.totalPoints ?? 0
    }

    /// Partner's point balance
    var partnerPoints: Int {
        partnerProfile?.totalPoints ?? 0
    }

    /// Days until upcoming event
    var daysUntilEvent: Int? {
        guard let event = upcomingEvent else { return nil }
        return eventService.calculateDaysUntil(event: event)
    }

    /// User's display name or fallback
    var userName: String {
        userProfile?.displayName ?? "You"
    }

    /// Partner's display name or fallback
    var partnerName: String {
        partnerProfile?.displayName ?? "Partner"
    }

    // MARK: - Initialization

    init() {
        setupRealtimeSubscriptions()
    }

    deinit {
        Task {
            await questService.unsubscribeFromQuestChanges()
            await profileService.unsubscribeFromProfileChanges()
        }
    }

    // MARK: - Data Loading

    /// Loads all dashboard data
    func loadDashboardData() async {
        guard let userId = authService.currentUserId else {
            showError(message: "User not authenticated")
            return
        }

        isLoading = true

        // Load data in parallel for better performance
        async let profileTask = loadUserProfile(userId: userId)
        async let questsTask = loadRecentQuests()
        async let eventsTask = loadUpcomingEvent()
        async let rewardsTask = loadRewardsPreview()

        // Wait for all tasks to complete
        await profileTask
        await questsTask
        await eventsTask
        await rewardsTask

        isLoading = false
    }

    /// Loads user profile and partner profile
    private func loadUserProfile(userId: UUID) async {
        do {
            userProfile = try await profileService.fetchProfile(userId: userId)

            // Load partner profile if paired
            if let partnerId = userProfile?.partnerId {
                partnerProfile = try await profileService.fetchProfile(userId: partnerId)
            }
        } catch {
            print("Failed to load profile: \(error.localizedDescription)")
            showError(message: "Failed to load profile data")
        }
    }

    /// Loads recent quests (last 5)
    private func loadRecentQuests() async {
        do {
            let allQuests = try await questService.fetchActiveQuests()
            recentQuests = Array(allQuests.prefix(5))
        } catch {
            print("Failed to load quests: \(error.localizedDescription)")
            // Don't show error for non-critical data
        }
    }

    /// Loads upcoming event (next event)
    private func loadUpcomingEvent() async {
        do {
            let events = try await eventService.fetchUpcomingEvents()
            // Find the next upcoming event (future events only)
            upcomingEvent = events.first { $0.isFuture }
        } catch {
            print("Failed to load events: \(error.localizedDescription)")
            // Don't show error for non-critical data
        }
    }

    /// Loads rewards preview (first 3 active rewards)
    private func loadRewardsPreview() async {
        do {
            let allRewards = try await rewardService.fetchActiveRewards()
            rewardsPreview = Array(allRewards.prefix(3))
        } catch {
            print("Failed to load rewards: \(error.localizedDescription)")
            // Don't show error for non-critical data
        }
    }

    // MARK: - Realtime Subscriptions

    /// Sets up realtime subscriptions for live updates
    private func setupRealtimeSubscriptions() {
        // Subscribe to quest changes
        Task {
            do {
                try await questService.subscribeToQuestChanges { [weak self] quests in
                    Task { @MainActor in
                        self?.recentQuests = Array(quests.prefix(5))
                    }
                }
            } catch {
                print("Failed to setup quest subscription: \(error.localizedDescription)")
            }
        }

        // Subscribe to profile changes
        Task {
            guard let userId = authService.currentUserId else { return }

            do {
                try await profileService.subscribeToProfileChanges(userId: userId) {
                    [weak self] profile in
                    Task { @MainActor in
                        self?.userProfile = profile

                        // Reload partner profile if partner changed
                        if let partnerId = profile.partnerId {
                            do {
                                self?.partnerProfile = try await self?.profileService.fetchProfile(
                                    userId: partnerId)
                            } catch {
                                print(
                                    "Failed to reload partner profile: \(error.localizedDescription)"
                                )
                            }
                        } else {
                            self?.partnerProfile = nil
                        }
                    }
                }
            } catch {
                print("Failed to setup profile subscription: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Helper Methods

    /// Shows error alert
    /// - Parameter message: Error message
    private func showError(message: String) {
        errorMessage = message
        showError = true
    }

    /// Dismisses error alert
    func dismissError() {
        showError = false
        errorMessage = nil
    }

    /// Refreshes all dashboard data
    func refresh() async {
        await loadDashboardData()
    }
}
