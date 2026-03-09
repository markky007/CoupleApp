import Foundation

/// Event model
/// Represents a special date or occasion with countdown and notification support
struct Event: Identifiable, Codable, Equatable {

    // MARK: - Properties

    /// Unique identifier
    let id: UUID

    /// Event title (e.g., "Anniversary", "Birthday")
    var title: String

    /// Event date
    var eventDate: Date

    /// Whether event recurs annually
    var isRecurring: Bool

    /// User who created the event
    let createdBy: UUID

    /// Event creation timestamp
    let createdAt: Date?

    /// Event last update timestamp
    var updatedAt: Date?

    // MARK: - Coding Keys

    /// Maps Swift property names to database column names (snake_case)
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case eventDate = "event_date"
        case isRecurring = "is_recurring"
        case createdBy = "created_by"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    // MARK: - Computed Properties

    /// Days until event (negative if past)
    var daysUntil: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let eventDay = calendar.startOfDay(for: eventDate)
        let components = calendar.dateComponents([.day], from: today, to: eventDay)
        return components.day ?? 0
    }

    /// Whether event is in the future
    var isFuture: Bool {
        daysUntil >= 0
    }

    /// Whether event is today
    var isToday: Bool {
        daysUntil == 0
    }

    // MARK: - Validation

    /// Validates event title length
    /// - Parameter title: Title to validate
    /// - Returns: True if valid, false otherwise
    static func isValidTitle(_ title: String?) -> Bool {
        guard let title = title, !title.isEmpty else {
            return false
        }
        return title.count >= 1 && title.count <= 100
    }
}

// MARK: - Event Extensions

extension Event {

    /// Creates a new event with default values
    /// - Parameters:
    ///   - title: Event title
    ///   - eventDate: Event date
    ///   - isRecurring: Whether event recurs annually
    ///   - createdBy: User ID who created the event
    /// - Returns: New event instance
    static func new(
        title: String,
        eventDate: Date,
        isRecurring: Bool,
        createdBy: UUID
    ) -> Event {
        Event(
            id: UUID(),
            title: title,
            eventDate: eventDate,
            isRecurring: isRecurring,
            createdBy: createdBy,
            createdAt: Date(),
            updatedAt: Date()
        )
    }

    /// Creates a copy with updated title
    /// - Parameter newTitle: New title
    /// - Returns: Updated event copy
    func withTitle(_ newTitle: String) -> Event {
        var copy = self
        copy.title = newTitle
        copy.updatedAt = Date()
        return copy
    }

    /// Creates a copy with updated date
    /// - Parameter newDate: New event date
    /// - Returns: Updated event copy
    func withDate(_ newDate: Date) -> Event {
        var copy = self
        copy.eventDate = newDate
        copy.updatedAt = Date()
        return copy
    }

    /// Creates a copy with updated recurring status
    /// - Parameter recurring: New recurring status
    /// - Returns: Updated event copy
    func withRecurring(_ recurring: Bool) -> Event {
        var copy = self
        copy.isRecurring = recurring
        copy.updatedAt = Date()
        return copy
    }
}

// MARK: - Event Validation Rules

/*
 Validation Rules:

 1. id must be valid UUID
 2. title must be 1-100 characters
 3. eventDate must be valid date
 4. isRecurring is boolean flag
 5. createdBy must reference existing user

 Database Constraints:
 - id: PRIMARY KEY
 - created_by: REFERENCES auth.users(id) ON DELETE CASCADE
 - title: NOT NULL, CHECK (length(title) >= 1 AND length(title) <= 100)
 */
