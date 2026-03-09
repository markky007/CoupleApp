import Foundation
import Supabase

/// Service for managing events and special dates
/// Handles CRUD operations and countdown calculations
class EventService {

    // MARK: - Singleton

    static let shared = EventService()

    // MARK: - Private Properties

    private let client = supabase

    // MARK: - Initialization

    private init() {}

    // MARK: - Event CRUD Operations

    /// Fetches upcoming events (sorted by date)
    /// - Returns: Array of events sorted by event date
    /// - Throws: EventError if fetch fails
    func fetchUpcomingEvents() async throws -> [Event] {
        do {
            let events: [Event] =
                try await client
                .from("events")
                .select()
                .order("event_date", ascending: true)
                .execute()
                .value

            print("✅ Fetched \(events.count) events")
            return events
        } catch {
            print("❌ Failed to fetch events: \(error.localizedDescription)")
            throw EventError.fetchFailed(error.localizedDescription)
        }
    }

    /// Creates a new event
    /// - Parameters:
    ///   - title: Event title
    ///   - eventDate: Event date
    ///   - isRecurring: Whether event recurs annually
    /// - Returns: Newly created event
    /// - Throws: EventError if creation fails
    func createEvent(
        title: String,
        eventDate: Date,
        isRecurring: Bool
    ) async throws -> Event {
        // Validate title
        guard Event.isValidTitle(title) else {
            throw EventError.invalidTitle
        }

        // Get current user ID
        guard let userId = AuthService.shared.currentUserId else {
            throw EventError.notAuthenticated
        }

        // Create insert struct (without id, createdAt, updatedAt - let database generate)
        struct EventInsert: Encodable {
            let title: String
            let event_date: Date
            let is_recurring: Bool
            let created_by: UUID
        }

        let insertData = EventInsert(
            title: title,
            event_date: eventDate,
            is_recurring: isRecurring,
            created_by: userId
        )

        do {
            let event: Event =
                try await client
                .from("events")
                .insert(insertData)
                .select()
                .single()
                .execute()
                .value

            print("✅ Event created: \(event.title)")
            return event
        } catch {
            print("❌ Failed to create event: \(error.localizedDescription)")
            throw EventError.creationFailed(error.localizedDescription)
        }
    }

    /// Updates an existing event
    /// - Parameters:
    ///   - eventId: Event's unique identifier
    ///   - title: New event title
    ///   - eventDate: New event date
    ///   - isRecurring: New recurring status
    /// - Throws: EventError if update fails
    func updateEvent(
        eventId: UUID,
        title: String,
        eventDate: Date,
        isRecurring: Bool
    ) async throws {
        // Validate title
        guard Event.isValidTitle(title) else {
            throw EventError.invalidTitle
        }

        // Create update struct
        struct EventUpdate: Encodable {
            let title: String
            let event_date: Date
            let is_recurring: Bool
            let updated_at: Date
        }

        let updateData = EventUpdate(
            title: title,
            event_date: eventDate,
            is_recurring: isRecurring,
            updated_at: Date()
        )

        do {
            try await client
                .from("events")
                .update(updateData)
                .eq("id", value: eventId)
                .execute()

            print("✅ Event updated: \(eventId)")
        } catch {
            print("❌ Failed to update event: \(error.localizedDescription)")
            throw EventError.updateFailed(error.localizedDescription)
        }
    }

    /// Deletes an event
    /// - Parameter eventId: Event's unique identifier
    /// - Throws: EventError if deletion fails
    func deleteEvent(eventId: UUID) async throws {
        do {
            try await client
                .from("events")
                .delete()
                .eq("id", value: eventId)
                .execute()

            print("✅ Event deleted: \(eventId)")
        } catch {
            print("❌ Failed to delete event: \(error.localizedDescription)")
            throw EventError.deletionFailed(error.localizedDescription)
        }
    }

    // MARK: - Countdown Calculations

    /// Calculates days until an event
    /// - Parameter event: Event to calculate countdown for
    /// - Returns: Number of days until event (negative if past, 0 if today)
    func calculateDaysUntil(event: Event) -> Int {
        return event.daysUntil
    }
}

// MARK: - EventError

/// Custom error types for event operations
enum EventError: LocalizedError {
    case fetchFailed(String)
    case creationFailed(String)
    case updateFailed(String)
    case deletionFailed(String)
    case invalidTitle
    case notAuthenticated
    case eventNotFound

    var errorDescription: String? {
        switch self {
        case .fetchFailed(let message):
            return "Failed to fetch events: \(message)"
        case .creationFailed(let message):
            return "Failed to create event: \(message)"
        case .updateFailed(let message):
            return "Failed to update event: \(message)"
        case .deletionFailed(let message):
            return "Failed to delete event: \(message)"
        case .invalidTitle:
            return "Event title must be 1-100 characters"
        case .notAuthenticated:
            return "You must be logged in to create events"
        case .eventNotFound:
            return "Event not found"
        }
    }
}
