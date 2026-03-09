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

    // MARK: - Initialization

    private init() {}

    deinit {
        // Clean up realtime subscription
        Task {
            await realtimeChannel?.unsubscribe()
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
            let quest: Quest =
                try await client
                .from("quests")
                .insert(newQuest)
                .select()
                .single()
                .execute()
                .value

            print("✅ Quest created: \(quest.title)")
            return quest
        } catch {
            print("❌ Failed to create quest: \(error.localizedDescription)")
            throw QuestError.creationFailed(error.localizedDescription)
        }
    }

    /// Completes a quest and awards points to user
    /// - Parameters:
    ///   - questId: Quest ID to complete
    ///   - userId: User ID who completed the quest
    /// - Throws: QuestError if completion fails
    func completeQuest(questId: UUID, userId: UUID) async throws {
        do {
            // Fetch the quest first to validate
            let quest: Quest =
                try await client
                .from("quests")
                .select()
                .eq("id", value: questId)
                .single()
                .execute()
                .value

            // Validate quest can be completed
            guard quest.status == .pending else {
                throw QuestError.alreadyCompleted
            }

            guard !quest.isExpired else {
                throw QuestError.questExpired
            }

            // Update quest status to completed
            try await client
                .from("quests")
                .update([
                    "status": QuestStatus.completed.rawValue, "updated_at": Date().ISO8601Format(),
                ])
                .eq("id", value: questId)
                .execute()

            // Award points to user
            try await ProfileService.shared.updatePoints(userId: userId, delta: quest.points)

            // Create transaction record
            try await createTransactionRecord(
                userId: userId,
                type: "earn",
                amount: quest.points,
                description: "Completed quest: \(quest.title)"
            )

            print("✅ Quest completed: \(quest.title) (+\(quest.points) points)")
        } catch let error as QuestError {
            throw error
        } catch let error as ProfileError {
            print("❌ Failed to award points: \(error.localizedDescription)")
            throw QuestError.pointAwardFailed(error.localizedDescription)
        } catch {
            print("❌ Failed to complete quest: \(error.localizedDescription)")
            throw QuestError.completionFailed(error.localizedDescription)
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

    // MARK: - Helper Methods

    /// Creates a transaction record
    /// - Parameters:
    ///   - userId: User ID
    ///   - type: Transaction type (earn/redeem)
    ///   - amount: Point amount
    ///   - description: Transaction description
    /// - Throws: QuestError if creation fails
    private func createTransactionRecord(
        userId: UUID,
        type: String,
        amount: Int,
        description: String
    ) async throws {
        struct TransactionInsert: Encodable {
            let user_id: String
            let type: String
            let amount: Int
            let description: String
            let created_at: String
        }

        let transaction = TransactionInsert(
            user_id: userId.uuidString,
            type: type,
            amount: amount,
            description: description,
            created_at: Date().ISO8601Format()
        )

        do {
            try await client
                .from("transactions")
                .insert(transaction)
                .execute()

            print("✅ Transaction record created")
        } catch {
            print("❌ Failed to create transaction record: \(error.localizedDescription)")
            throw QuestError.transactionRecordFailed(error.localizedDescription)
        }
    }

    // MARK: - Realtime Subscriptions

    /// Subscribes to quest changes for real-time updates
    /// - Parameter handler: Callback when quests change
    /// - Throws: QuestError if subscription fails
    func subscribeToQuestChanges(handler: @escaping ([Quest]) -> Void) async throws {
        do {
            // Unsubscribe from existing channel if any
            await realtimeChannel?.unsubscribe()

            // Create new channel for quest updates
            let channel = client.channel("quests")

            // Subscribe to all changes on quests table
            let changes = await channel.postgresChange(
                InsertAction.self,
                schema: "public",
                table: "quests"
            )

            await channel.subscribe()

            // Listen for changes and refetch active quests
            Task {
                for await _ in changes {
                    // Refetch all active quests when any change occurs
                    if let quests = try? await fetchActiveQuests() {
                        handler(quests)
                    }
                }
            }

            self.realtimeChannel = channel
            print("✅ Subscribed to quest changes")
        } catch {
            print("❌ Failed to subscribe to quest changes: \(error.localizedDescription)")
            throw QuestError.subscriptionFailed(error.localizedDescription)
        }
    }

    /// Unsubscribes from quest changes
    func unsubscribeFromQuestChanges() async {
        await realtimeChannel?.unsubscribe()
        realtimeChannel = nil
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
