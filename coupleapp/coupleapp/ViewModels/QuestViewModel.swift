import Combine
import Foundation
import SwiftUI

/// ViewModel for quest management
/// Handles quest state, business logic, and realtime updates
/// Uses centralized error handling via ErrorManager
@MainActor
class QuestViewModel: ObservableObject {

    // MARK: - Published Properties

    /// Array of active quests
    @Published var quests: [Quest] = []

    /// Loading state
    @Published var isLoading = false

    /// Success state
    @Published var showSuccess = false
    @Published var successMessage: String?

    /// Success animation state
    @Published var showSuccessAnimation = false
    @Published var successAnimationTitle: String?
    @Published var successAnimationMessage: String?

    /// Sheet presentation states
    @Published var showCreateSheet = false

    // MARK: - Private Properties

    private let questService = QuestService.shared
    private let authService = AuthService.shared
    private let errorManager = ErrorManager.shared
    private let networkMonitor = NetworkMonitor.shared
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init() {
        setupRealtimeSubscription()
    }

    deinit {
        Task {
            await questService.unsubscribeFromQuestChanges()
        }
    }

    // MARK: - Quest Operations

    /// Fetches active quests from the server
    func fetchQuests() async {
        // Check network connectivity
        guard !networkMonitor.isOfflineMode else {
            errorManager.handle(
                QuestError.fetchFailed("No internet connection"),
                context: "Fetch Quests - Offline"
            )
            return
        }

        isLoading = true

        do {
            // Retry network operation with exponential backoff
            quests = try await RetryManager.retryNetworkOperation {
                try await self.questService.fetchActiveQuests()
            }
            isLoading = false
        } catch {
            isLoading = false
            errorManager.handle(error, context: "Fetch Quests")
        }
    }

    /// Creates a new quest
    /// - Parameters:
    ///   - title: Quest title
    ///   - points: Points to award
    func createQuest(title: String, points: Int) async {
        guard let userId = authService.currentUserId else {
            errorManager.handle(
                AuthError.signInFailed("User not authenticated"),
                context: "Create Quest - No User"
            )
            return
        }

        // Check network connectivity
        guard !networkMonitor.isOfflineMode else {
            errorManager.handle(
                QuestError.creationFailed("No internet connection"),
                context: "Create Quest - Offline"
            )
            return
        }

        isLoading = true

        do {
            // Retry network operation with exponential backoff
            let quest = try await RetryManager.retryNetworkOperation {
                try await self.questService.createQuest(
                    title: title,
                    points: points,
                    createdBy: userId
                )
            }

            isLoading = false
            showSuccess(message: "Quest created: \(quest.title)")
            showCreateSheet = false

            // Refresh quest list
            await fetchQuests()
        } catch {
            isLoading = false
            errorManager.handle(error, context: "Create Quest")
        }
    }

    /// Completes a quest
    /// - Parameter quest: Quest to complete
    func completeQuest(_ quest: Quest) async {
        guard let userId = authService.currentUserId else {
            errorManager.handle(
                AuthError.signInFailed("User not authenticated"),
                context: "Complete Quest - No User"
            )
            return
        }

        // Check network connectivity
        guard !networkMonitor.isOfflineMode else {
            errorManager.handle(
                QuestError.completionFailed("No internet connection"),
                context: "Complete Quest - Offline"
            )
            return
        }

        isLoading = true

        do {
            // Retry critical operation (quest completion is important)
            try await RetryManager.retryCriticalOperation {
                try await self.questService.completeQuest(questId: quest.id, userId: userId)
            }

            isLoading = false

            // Show success animation
            successAnimationTitle = "Quest Complete!"
            successAnimationMessage = "You earned \(quest.points) points"
            showSuccessAnimation = true

            // Refresh quest list
            await fetchQuests()
        } catch {
            isLoading = false

            // Provide retry action for quest completion
            let retryAction: () async -> Void = { [weak self] in
                await self?.completeQuest(quest)
            }

            // Create error with retry action
            let appError = AppError(
                title: "Quest Completion Failed",
                message: error.localizedDescription,
                type: .network,
                retryAction: retryAction
            )

            // Use handle method which logs internally
            errorManager.handle(appError, context: "Complete Quest")
        }
    }

    /// Deletes a quest
    /// - Parameter quest: Quest to delete
    func deleteQuest(_ quest: Quest) async {
        // Check network connectivity
        guard !networkMonitor.isOfflineMode else {
            errorManager.handle(
                QuestError.deletionFailed("No internet connection"),
                context: "Delete Quest - Offline"
            )
            return
        }

        isLoading = true

        do {
            // Retry network operation
            try await RetryManager.retryNetworkOperation {
                try await self.questService.deleteQuest(questId: quest.id)
            }

            isLoading = false
            showSuccess(message: "Quest deleted")

            // Refresh quest list
            await fetchQuests()
        } catch {
            isLoading = false
            errorManager.handle(error, context: "Delete Quest")
        }
    }

    // MARK: - Realtime Subscription

    /// Sets up realtime subscription for quest changes
    private func setupRealtimeSubscription() {
        Task {
            do {
                try await questService.subscribeToQuestChanges { [weak self] quests in
                    Task { @MainActor in
                        self?.quests = quests
                    }
                }
            } catch {
                errorManager.handle(error, context: "Setup Realtime Subscription")
            }
        }
    }

    // MARK: - Helper Methods

    /// Shows success alert
    /// - Parameter message: Success message
    private func showSuccess(message: String) {
        successMessage = message
        showSuccess = true
    }

    /// Dismisses success alert
    func dismissSuccess() {
        showSuccess = false
        successMessage = nil
    }
}
