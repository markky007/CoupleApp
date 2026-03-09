import Combine
import Foundation
import Supabase
import SwiftUI

/// ViewModel for quest management
/// Handles quest state, business logic, and realtime updates
@MainActor
class QuestViewModel: ObservableObject {

    // MARK: - Published Properties

    /// Array of active quests
    @Published var quests: [Quest] = []

    /// Loading state
    @Published var isLoading = false

    /// Error state
    @Published var showError = false
    @Published var errorMessage: String?

    /// Success state
    @Published var showSuccess = false
    @Published var successMessage: String?

    /// Sheet presentation states
    @Published var showCreateSheet = false

    // MARK: - Private Properties

    private let questService = QuestService.shared
    private let authService = AuthService.shared
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
        isLoading = true

        do {
            quests = try await questService.fetchActiveQuests()
            isLoading = false
        } catch {
            isLoading = false
            showError(message: error.localizedDescription)
        }
    }

    /// Creates a new quest
    /// - Parameters:
    ///   - title: Quest title
    ///   - points: Points to award
    func createQuest(title: String, points: Int) async {
        guard let userId = authService.currentUser?.id else {
            showError(message: "User not authenticated")
            return
        }

        isLoading = true

        do {
            let quest = try await questService.createQuest(
                title: title,
                points: points,
                createdBy: userId
            )

            isLoading = false
            showSuccess(message: "Quest created: \(quest.title)")
            showCreateSheet = false

            // Refresh quest list
            await fetchQuests()
        } catch {
            isLoading = false
            showError(message: error.localizedDescription)
        }
    }

    /// Completes a quest
    /// - Parameter quest: Quest to complete
    func completeQuest(_ quest: Quest) async {
        guard let userId = authService.currentUser?.id else {
            showError(message: "User not authenticated")
            return
        }

        isLoading = true

        do {
            try await questService.completeQuest(questId: quest.id, userId: userId)

            isLoading = false
            showSuccess(message: "Quest completed! +\(quest.points) points")

            // Refresh quest list
            await fetchQuests()
        } catch {
            isLoading = false
            showError(message: error.localizedDescription)
        }
    }

    /// Deletes a quest
    /// - Parameter quest: Quest to delete
    func deleteQuest(_ quest: Quest) async {
        isLoading = true

        do {
            try await questService.deleteQuest(questId: quest.id)

            isLoading = false
            showSuccess(message: "Quest deleted")

            // Refresh quest list
            await fetchQuests()
        } catch {
            isLoading = false
            showError(message: error.localizedDescription)
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
                print("Failed to setup realtime subscription: \(error.localizedDescription)")
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

    /// Shows success alert
    /// - Parameter message: Success message
    private func showSuccess(message: String) {
        successMessage = message
        showSuccess = true
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
}
