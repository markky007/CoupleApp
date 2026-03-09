import Foundation

/// Quest status enumeration
enum QuestStatus: String, Codable {
    case pending = "pending"
    case completed = "completed"
}

/// Quest model representing a task or challenge
/// Users can create quests and complete them to earn points
struct Quest: Identifiable, Codable, Equatable {

    // MARK: - Properties

    /// Unique identifier
    let id: UUID

    /// Quest title/description
    let title: String

    /// Points awarded upon completion
    let points: Int

    /// Current status (pending or completed)
    var status: QuestStatus

    /// User ID who created the quest
    let createdBy: UUID

    /// Optional event ID this quest is associated with
    let eventId: UUID?

    /// Optional expiration timestamp
    let expireAt: Date?

    /// Quest creation timestamp
    let createdAt: Date

    /// Quest last update timestamp
    var updatedAt: Date

    // MARK: - Coding Keys

    /// Maps Swift property names to database column names (snake_case)
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case points
        case status
        case createdBy = "created_by"
        case eventId = "event_id"
        case expireAt = "expire_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    // MARK: - Computed Properties

    /// Whether the quest is completed
    var isCompleted: Bool {
        status == .completed
    }

    /// Whether the quest is expired
    var isExpired: Bool {
        guard let expireAt = expireAt else { return false }
        return expireAt < Date()
    }

    /// Whether the quest is active (pending and not expired)
    var isActive: Bool {
        status == .pending && !isExpired
    }

    /// Whether the quest is associated with an event
    var hasEvent: Bool {
        eventId != nil
    }

    // MARK: - Validation

    /// Validates quest title length
    /// - Parameter title: Title to validate
    /// - Returns: True if valid, false otherwise
    static func isValidTitle(_ title: String) -> Bool {
        !title.isEmpty && title.count <= AppConstants.maxQuestTitleLength
    }

    /// Validates quest points value
    /// - Parameter points: Points to validate
    /// - Returns: True if valid, false otherwise
    static func isValidPoints(_ points: Int) -> Bool {
        points > 0 && points <= AppConstants.maxQuestPoints
    }
}

// MARK: - Quest Extensions

extension Quest {

    /// Creates a new quest with default values
    /// - Parameters:
    ///   - title: Quest title
    ///   - points: Points to award
    ///   - createdBy: User ID who created the quest
    ///   - eventId: Optional event ID
    ///   - expireAt: Optional expiration date
    /// - Returns: New quest instance
    static func new(
        title: String,
        points: Int,
        createdBy: UUID,
        eventId: UUID? = nil,
        expireAt: Date? = nil
    ) -> Quest {
        Quest(
            id: UUID(),
            title: title,
            points: points,
            status: .pending,
            createdBy: createdBy,
            eventId: eventId,
            expireAt: expireAt,
            createdAt: Date(),
            updatedAt: Date()
        )
    }

    /// Creates a copy with completed status
    /// - Returns: Updated quest copy
    func withCompletedStatus() -> Quest {
        var copy = self
        copy.status = .completed
        copy.updatedAt = Date()
        return copy
    }
}

// MARK: - Quest Validation Rules

/*
 Validation Rules (from design document):

 1. title must not be empty and max 200 characters
 2. points must be positive integer (1-1000)
 3. status must be 'pending' or 'completed'
 4. createdBy must reference existing profile
 5. eventId must reference existing event or be nil
 6. expireAt must be future date or nil
 7. Completed quests cannot be completed again

 Database Constraints:
 - id: PRIMARY KEY
 - created_by: REFERENCES profiles(id) ON DELETE CASCADE
 - event_id: REFERENCES events(id) ON DELETE SET NULL
 - points: CHECK (points > 0)
 - status: CHECK (status IN ('pending', 'completed'))
 */
