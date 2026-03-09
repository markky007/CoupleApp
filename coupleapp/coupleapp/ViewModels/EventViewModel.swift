import Combine
import Foundation

/// ViewModel for managing events and special dates
/// Handles event CRUD operations and notification scheduling
@MainActor
class EventViewModel: ObservableObject {

    // MARK: - Published Properties

    /// Array of events sorted by date
    @Published var events: [Event] = []

    /// Loading state
    @Published var isLoading = false

    /// Error message for display
    @Published var errorMessage: String?

    /// Success message for display
    @Published var successMessage: String?

    /// Whether to show success message
    @Published var showSuccessMessage = false

    // MARK: - Private Properties

    private let eventService = EventService.shared
    private let notificationService = NotificationService.shared

    // MARK: - Initialization

    init() {
        Task {
            await loadEvents()
        }
    }

    // MARK: - Event Operations

    /// Loads all events from database
    func loadEvents() async {
        isLoading = true
        errorMessage = nil

        do {
            events = try await eventService.fetchUpcomingEvents()
            print("✅ Loaded \(events.count) events")
        } catch {
            errorMessage = "Failed to load events: \(error.localizedDescription)"
            print("❌ \(errorMessage ?? "")")
        }

        isLoading = false
    }

    /// Creates a new event with notification scheduling
    /// - Parameters:
    ///   - title: Event title
    ///   - eventDate: Event date
    ///   - isRecurring: Whether event recurs annually
    func createEvent(
        title: String,
        eventDate: Date,
        isRecurring: Bool
    ) async {
        isLoading = true
        errorMessage = nil

        do {
            // Create event
            let newEvent = try await eventService.createEvent(
                title: title,
                eventDate: eventDate,
                isRecurring: isRecurring
            )

            // Request notification permission if not already granted
            let isAuthorized = await notificationService.checkAuthorizationStatus()
            if !isAuthorized {
                _ = try? await notificationService.requestAuthorization()
            }

            // Schedule notifications (3 days and 1 day before)
            try? await notificationService.scheduleEventReminder(
                event: newEvent,
                daysBeforeArray: [3, 1]
            )

            // Reload events
            await loadEvents()

            successMessage = "Event created successfully!"
            showSuccessMessage = true

            // Hide success message after 2 seconds
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            showSuccessMessage = false

        } catch {
            errorMessage = "Failed to create event: \(error.localizedDescription)"
            print("❌ \(errorMessage ?? "")")
        }

        isLoading = false
    }

    /// Updates an existing event
    /// - Parameters:
    ///   - eventId: Event's unique identifier
    ///   - title: New event title
    ///   - eventDate: New event date
    ///   - isRecurring: New recurring status
    func updateEvent(
        eventId: UUID,
        title: String,
        eventDate: Date,
        isRecurring: Bool
    ) async {
        isLoading = true
        errorMessage = nil

        do {
            // Update event
            try await eventService.updateEvent(
                eventId: eventId,
                title: title,
                eventDate: eventDate,
                isRecurring: isRecurring
            )

            // Cancel old notifications
            await notificationService.cancelEventReminder(eventId: eventId)

            // Schedule new notifications
            if let updatedEvent = events.first(where: { $0.id == eventId }) {
                var event = updatedEvent
                event.title = title
                event.eventDate = eventDate
                event.isRecurring = isRecurring

                try? await notificationService.scheduleEventReminder(
                    event: event,
                    daysBeforeArray: [3, 1]
                )
            }

            // Reload events
            await loadEvents()

            successMessage = "Event updated successfully!"
            showSuccessMessage = true

            // Hide success message after 2 seconds
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            showSuccessMessage = false

        } catch {
            errorMessage = "Failed to update event: \(error.localizedDescription)"
            print("❌ \(errorMessage ?? "")")
        }

        isLoading = false
    }

    /// Deletes an event
    /// - Parameter eventId: Event's unique identifier
    func deleteEvent(eventId: UUID) async {
        isLoading = true
        errorMessage = nil

        do {
            // Delete event
            try await eventService.deleteEvent(eventId: eventId)

            // Cancel notifications
            await notificationService.cancelEventReminder(eventId: eventId)

            // Reload events
            await loadEvents()

            successMessage = "Event deleted successfully!"
            showSuccessMessage = true

            // Hide success message after 2 seconds
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            showSuccessMessage = false

        } catch {
            errorMessage = "Failed to delete event: \(error.localizedDescription)"
            print("❌ \(errorMessage ?? "")")
        }

        isLoading = false
    }

    // MARK: - Helper Methods

    /// Calculates days until an event
    /// - Parameter event: Event to calculate countdown for
    /// - Returns: Number of days until event
    func daysUntil(event: Event) -> Int {
        return eventService.calculateDaysUntil(event: event)
    }

    /// Formats countdown text for display
    /// - Parameter event: Event to format countdown for
    /// - Returns: Formatted countdown string
    func countdownText(for event: Event) -> String {
        let days = daysUntil(event: event)

        if days < 0 {
            return "\(abs(days)) day\(abs(days) == 1 ? "" : "s") ago"
        } else if days == 0 {
            return "Today!"
        } else {
            return "In \(days) day\(days == 1 ? "" : "s")"
        }
    }
}
