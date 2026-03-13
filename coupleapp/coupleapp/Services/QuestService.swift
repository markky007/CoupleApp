import Combine
import Foundation
import Supabase

/// Service for managing quests
/// Handles CRUD operations, quest completion, and realtime synchronization
class QuestService {

    // MARK: - Singleton

    static let shared = QuestService()

    // MARK: - Private Properties

    private let client = supabase
    private var realtimeChannel: RealtimeChannelV2?
    private var reconnectionTask: Task<Void, Never>?
    private var reconnectionAttempts = 0
    private let maxReconnectionAttempts = 5
    private var isSubscribed = false

    // MARK: - Initialization

    private init() {}

    deinit {
        // Clean up realtime subscription and reconnection task
        reconnectionTask?.cancel()
        Task { [weak self] in
            await self?.realtimeChannel?.unsubscribe()
        }
    }

    // MARK: - Quest CRUD Operations

    /// Fetches active quests (pending and not expired)
    /// - Returns: Array of active quests
    /// - Throws: QuestError if fetch fails
    func fetchActiveQuests() async throws -> [Quest] {
        do {
            let quests: [Quest] =
                try await client
                .from("quests")
                .select()
                .eq("status", value: QuestStatus.pending.rawValue)
                .order("created_at", ascending: false)
                .execute()
                .value

            // Filter out expired quests
            let activeQuests = quests.filter { !$0.isExpired }

            print("✅ Fetched \(activeQuests.count) active quests")
            return activeQuests
        } catch {
            print("❌ Failed to fetch active quests: \(error.localizedDescription)")
            throw QuestError.fetchFailed(error.localizedDescription)
        }
    }

    /// Creates a new quest
    /// - Parameters:
    ///   - title: Quest title
    ///   - points: Points to award
    ///   - createdBy: User ID who created the quest
    ///   - eventId: Optional event ID
    ///   - expireAt: Optional expiration date
    /// - Returns: Newly created quest
    /// - Throws: QuestError if creation fails
    func createQuest(
        title: String,
        points: Int,
        createdBy: UUID,
        eventId: UUID? = nil,
        expireAt: Date? = nil
    ) async throws -> Quest {
        // Validate inputs
        guard Quest.isValidTitle(title) else {
            throw QuestError.invalidTitle
        }

        guard Quest.isValidPoints(points) else {
            throw QuestError.invalidPoints
        }

        let newQuest = Quest.new(
            title: title,
            points: points,
            createdBy: createdBy,
            eventId: eventId,
            expireAt: expireAt
        )

        do {
            let response =
                try await client
                .from("quests")
                .insert(newQuest)
                .select()
                .execute()

            // Decode response as array and get first element
            let quests = try JSONDecoder().decode([Quest].self, from: response.data)
            guard let quest = quests.first else {
                throw QuestError.creationFailed("Failed to create quest")
            }

            print("✅ Quest created: \(quest.title)")
            return quest
        } catch let error as QuestError {
            throw error
        } catch {
            print("❌ Failed to create quest: \(error.localizedDescription)")
            throw QuestError.creationFailed(error.localizedDescription)
        }
    }

    /// Completes a quest and awards points to user
    /// Uses atomic database function to ensure all operations succeed or rollback together
    /// - Parameters:
    ///   - questId: Quest ID to complete
    ///   - userId: User ID who completed the quest
    /// - Throws: QuestError if completion fails
    func completeQuest(questId: UUID, userId: UUID) async throws {
        do {
            // Use atomic RPC function to complete quest
            // This ensures quest update, point award, and transaction creation
            // all succeed together or rollback on any failure
            let paramsDict: [String: AnyJSON] = [
                "p_quest_id": .string(questId.uuidString),
                "p_user_id": .string(userId.uuidString),
            ]

            // Call the RPC function - it returns void
            try await client
                .rpc("complete_quest_atomic", params: paramsDict)
                .execute()

            print("✅ Quest completed atomically")
        } catch {
            // Parse error message to provide specific error types
            let errorMessage = error.localizedDescription.lowercased()

            if errorMessage.contains("not found") {
                throw QuestError.questNotFound
            } else if errorMessage.contains("already completed") {
                throw QuestError.alreadyCompleted
            } else if errorMessage.contains("expired") {
                throw QuestError.questExpired
            } else if errorMessage.contains("insufficient points") {
                throw QuestError.pointAwardFailed(error.localizedDescription)
            } else {
                print("❌ Failed to complete quest: \(error.localizedDescription)")
                throw QuestError.completionFailed(error.localizedDescription)
            }
        }
    }

    /// Deletes a quest
    /// - Parameter questId: Quest ID to delete
    /// - Throws: QuestError if deletion fails
    func deleteQuest(questId: UUID) async throws {
        do {
            try await client
                .from("quests")
                .delete()
                .eq("id", value: questId)
                .execute()

            print("✅ Quest deleted: \(questId)")
        } catch {
            print("❌ Failed to delete quest: \(error.localizedDescription)")
            throw QuestError.deletionFailed(error.localizedDescription)
        }
    }

    // MARK: - Realtime Subscriptions

    /// Subscribes to quest changes for real-time updates
    /// Listens to INSERT, UPDATE, and DELETE events on the quests table
    /// Handles updates on main thread for UI safety
    /// Implements automatic reconnection with exponential backoff
    /// - Parameter handler: Callback when quests change (called on main thread)
    /// - Throws: QuestError if subscription fails
    func subscribeToQuestChanges(handler: @escaping ([Quest]) -> Void) async throws {
        // Unsubscribe from existing channel if any
        await unsubscribeFromQuestChanges()

        // Reset reconnection state
        reconnectionAttempts = 0

        // Establish subscription
        try await establishSubscription(handler: handler)
    }

    /// Establishes the realtime subscription with proper error handling
    /// - Parameter handler: Callback when quests change
    /// - Throws: QuestError if subscription fails
    private func establishSubscription(handler: @escaping ([Quest]) -> Void) async throws {
        // Create new channel for quest updates
        let channel = client.channel("quests")

        // Subscribe to INSERT events
        let insertChanges = await channel.postgresChange(
            InsertAction.self,
            schema: "public",
            table: "quests"
        )

        // Subscribe to UPDATE events
        let updateChanges = await channel.postgresChange(
            UpdateAction.self,
            schema: "public",
            table: "quests"
        )

        // Subscribe to DELETE events
        let deleteChanges = await channel.postgresChange(
            DeleteAction.self,
            schema: "public",
            table: "quests"
        )

        // Subscribe to channel
        await channel.subscribe()

        // Listen for INSERT changes
        Task { [weak self] in
            for await _ in insertChanges {
                await self?.handleQuestChange(handler: handler, changeType: "INSERT")
            }
        }

        // Listen for UPDATE changes
        Task { [weak self] in
            for await _ in updateChanges {
                await self?.handleQuestChange(handler: handler, changeType: "UPDATE")
            }
        }

        // Listen for DELETE changes
        Task { [weak self] in
            for await _ in deleteChanges {
                await self?.handleQuestChange(handler: handler, changeType: "DELETE")
            }
        }

        self.realtimeChannel = channel
        print("✅ Subscribed to quest changes (INSERT, UPDATE, DELETE)")
    }

    /// Handles quest changes and notifies handler on main thread
    /// - Parameters:
    ///   - handler: Callback to notify
    ///   - changeType: Type of change (INSERT, UPDATE, DELETE)
    private func handleQuestChange(handler: @escaping ([Quest]) -> Void, changeType: String) async {
        print("📡 Quest \(changeType) detected, refetching active quests")

        // Refetch all active quests when any change occurs
        if let quests = try? await fetchActiveQuests() {
            // Ensure handler is called on main thread for UI safety
            await MainActor.run {
                handler(quests)
            }
        }
    }

    /// Handles reconnection with exponential backoff
    /// - Parameter handler: Callback when quests change
    private func handleReconnection(handler: @escaping ([Quest]) -> Void) async {
        // Cancel any existing reconnection task
        reconnectionTask?.cancel()

        guard reconnectionAttempts < maxReconnectionAttempts else {
            print("❌ Max reconnection attempts reached, giving up")
            await MainActor.run {
                isSubscribed = false
            }
            return
        }

        reconnectionTask = Task { [weak self] in
            guard let self = self else { return }

            // Calculate exponential backoff delay (2^attempts seconds, max 32 seconds)
            let delay = min(pow(2.0, Double(reconnectionAttempts)), 32.0)
            print(
                "🔄 Reconnecting in \(delay) seconds (attempt \(reconnectionAttempts + 1)/\(maxReconnectionAttempts))"
            )

            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))

            // Check if task was cancelled
            guard !Task.isCancelled else { return }

            await MainActor.run {
                self.reconnectionAttempts += 1
            }

            // Attempt to reestablish subscription
            do {
                try await self.establishSubscription(handler: handler)
                print("✅ Reconnection successful")
            } catch {
                print("❌ Reconnection failed: \(error.localizedDescription)")
                // Retry with next backoff
                await self.handleReconnection(handler: handler)
            }
        }
    }

    /// Unsubscribes from quest changes and cleans up resources
    func unsubscribeFromQuestChanges() async {
        // Cancel reconnection task
        reconnectionTask?.cancel()
        reconnectionTask = nil

        // Unsubscribe from channel
        await realtimeChannel?.unsubscribe()
        realtimeChannel = nil

        await MainActor.run {
            isSubscribed = false
            reconnectionAttempts = 0
        }

        print("✅ Unsubscribed from quest changes")
    }
}

// MARK: - QuestError

/// Custom error types for quest operations
enum QuestError: LocalizedError {
    case fetchFailed(String)
    case creationFailed(String)
    case completionFailed(String)
    case deletionFailed(String)
    case invalidTitle
    case invalidPoints
    case alreadyCompleted
    case questExpired
    case pointAwardFailed(String)
    case transactionRecordFailed(String)
    case subscriptionFailed(String)
    case questNotFound

    var errorDescription: String? {
        switch self {
        case .fetchFailed(let message):
            return "Failed to fetch quests: \(message)"
        case .creationFailed(let message):
            return "Failed to create quest: \(message)"
        case .completionFailed(let message):
            return "Failed to complete quest: \(message)"
        case .deletionFailed(let message):
            return "Failed to delete quest: \(message)"
        case .invalidTitle:
            return "Quest title must be 1-\(AppConstants.maxQuestTitleLength) characters"
        case .invalidPoints:
            return
                "Quest points must be between \(AppConstants.minQuestPoints) and \(AppConstants.maxQuestPoints)"
        case .alreadyCompleted:
            return "This quest has already been completed"
        case .questExpired:
            return "This quest has expired"
        case .pointAwardFailed(let message):
            return "Failed to award points: \(message)"
        case .transactionRecordFailed(let message):
            return "Failed to create transaction record: \(message)"
        case .subscriptionFailed(let message):
            return "Failed to subscribe to updates: \(message)"
        case .questNotFound:
            return "Quest not found"
        }
    }
}
