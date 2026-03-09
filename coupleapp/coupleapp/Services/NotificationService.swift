import Foundation
import UserNotifications

/// Service for managing local notifications and event reminders
/// Handles notification authorization, scheduling, and cancellation
class NotificationService {

    // MARK: - Singleton

    static let shared = NotificationService()

    // MARK: - Private Properties

    private let notificationCenter = UNUserNotificationCenter.current()

    // MARK: - Initialization

    private init() {}

    // MARK: - Authorization

    /// Requests notification authorization from user
    /// - Returns: True if authorized, false otherwise
    /// - Throws: NotificationError if request fails
    func requestAuthorization() async throws -> Bool {
        do {
            let granted = try await notificationCenter.requestAuthorization(
                options: [.alert, .sound, .badge]
            )

            if granted {
                print("✅ Notification authorization granted")
            } else {
                print("⚠️ Notification authorization denied")
            }

            return granted
        } catch {
            print("❌ Failed to request notification authorization: \(error.localizedDescription)")
            throw NotificationError.authorizationFailed(error.localizedDescription)
        }
    }

    /// Checks current notification authorization status
    /// - Returns: True if authorized, false otherwise
    func checkAuthorizationStatus() async -> Bool {
        let settings = await notificationCenter.notificationSettings()
        return settings.authorizationStatus == .authorized
    }

    // MARK: - Event Reminders

    /// Schedules event reminders at specified days before event
    /// - Parameters:
    ///   - event: Event to schedule reminders for
    ///   - daysBeforeArray: Array of days before event to send reminders (e.g., [3, 1])
    /// - Throws: NotificationError if scheduling fails
    func scheduleEventReminder(
        event: Event,
        daysBeforeArray: [Int]
    ) async throws {
        // Check authorization first
        guard await checkAuthorizationStatus() else {
            throw NotificationError.notAuthorized
        }

        let calendar = Calendar.current

        for daysBefore in daysBeforeArray {
            // Calculate notification date
            guard
                let notificationDate = calendar.date(
                    byAdding: .day,
                    value: -daysBefore,
                    to: event.eventDate
                )
            else {
                continue
            }

            // Skip if notification date is in the past
            if notificationDate < Date() {
                print("⚠️ Skipping past notification date for event: \(event.title)")
                continue
            }

            // Create notification content
            let content = UNMutableNotificationContent()
            content.title = "Upcoming Event"
            content.body = "\(event.title) is in \(daysBefore) day\(daysBefore == 1 ? "" : "s")!"
            content.sound = .default
            content.badge = 1

            // Create date components for trigger
            let dateComponents = calendar.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: notificationDate
            )

            // Create trigger
            let trigger = UNCalendarNotificationTrigger(
                dateMatching: dateComponents,
                repeats: false
            )

            // Create unique identifier
            let identifier = "\(event.id.uuidString)-\(daysBefore)days"

            // Create request
            let request = UNNotificationRequest(
                identifier: identifier,
                content: content,
                trigger: trigger
            )

            // Schedule notification
            do {
                try await notificationCenter.add(request)
                print("✅ Scheduled notification for \(event.title) - \(daysBefore) days before")
            } catch {
                print("❌ Failed to schedule notification: \(error.localizedDescription)")
                throw NotificationError.schedulingFailed(error.localizedDescription)
            }
        }
    }

    /// Cancels all reminders for a specific event
    /// - Parameter eventId: Event's unique identifier
    func cancelEventReminder(eventId: UUID) async {
        // Get all pending notifications
        let pendingNotifications = await notificationCenter.pendingNotificationRequests()

        // Find notifications for this event
        let identifiersToCancel =
            pendingNotifications
            .filter { $0.identifier.hasPrefix(eventId.uuidString) }
            .map { $0.identifier }

        // Cancel notifications
        notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiersToCancel)

        print("✅ Cancelled \(identifiersToCancel.count) notification(s) for event: \(eventId)")
    }

    /// Cancels all pending notifications
    func cancelAllNotifications() async {
        notificationCenter.removeAllPendingNotificationRequests()
        print("✅ Cancelled all pending notifications")
    }

    /// Gets all pending notification requests
    /// - Returns: Array of pending notification requests
    func getPendingNotifications() async -> [UNNotificationRequest] {
        return await notificationCenter.pendingNotificationRequests()
    }
}

// MARK: - NotificationError

/// Custom error types for notification operations
enum NotificationError: LocalizedError {
    case authorizationFailed(String)
    case notAuthorized
    case schedulingFailed(String)
    case invalidDate

    var errorDescription: String? {
        switch self {
        case .authorizationFailed(let message):
            return "Failed to request notification authorization: \(message)"
        case .notAuthorized:
            return "Notification permission not granted. Please enable notifications in Settings."
        case .schedulingFailed(let message):
            return "Failed to schedule notification: \(message)"
        case .invalidDate:
            return "Invalid notification date"
        }
    }
}
