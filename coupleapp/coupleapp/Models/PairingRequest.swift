import Foundation

/// Pairing request model
/// Represents a request from one user to pair with another user via partner code
struct PairingRequest: Identifiable, Codable, Equatable {

    // MARK: - Properties

    /// Unique identifier for the pairing request
    let id: UUID

    /// ID of the user who initiated the pairing request
    let requesterId: UUID

    /// ID of the user who received the pairing request
    let recipientId: UUID

    /// Current status of the pairing request
    var status: RequestStatus

    /// Request creation timestamp
    let createdAt: Date

    /// Request last update timestamp
    var updatedAt: Date

    /// Profile of the user who initiated the request (populated by service)
    var requesterProfile: Profile?

    // MARK: - Nested Types

    /// Status of a pairing request
    enum RequestStatus: String, Codable, CaseIterable {
        case pending
        case accepted
        case rejected

        var displayName: String {
            switch self {
            case .pending: return "Pending"
            case .accepted: return "Accepted"
            case .rejected: return "Rejected"
            }
        }
    }

    // MARK: - Coding Keys

    /// Maps Swift property names to database column names (snake_case)
    /// Note: requesterProfile is not included as it's populated by service, not stored in DB
    enum CodingKeys: String, CodingKey {
        case id
        case requesterId = "requester_id"
        case recipientId = "recipient_id"
        case status
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    // MARK: - Computed Properties

    /// Whether the request is currently pending
    var isPending: Bool {
        status == .pending
    }

    /// Whether the request has expired (older than 7 days)
    var isExpired: Bool {
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        return createdAt < sevenDaysAgo
    }
}

// MARK: - PairingRequest Extensions

extension PairingRequest {

    /// Creates a new pairing request with default values
    /// - Parameters:
    ///   - requesterId: ID of the user sending the request
    ///   - recipientId: ID of the user receiving the request
    ///   - requesterProfile: Optional profile of the requester
    /// - Returns: New pairing request instance
    static func new(requesterId: UUID, recipientId: UUID, requesterProfile: Profile? = nil)
        -> PairingRequest
    {
        PairingRequest(
            id: UUID(),
            requesterId: requesterId,
            recipientId: recipientId,
            status: .pending,
            createdAt: Date(),
            updatedAt: Date(),
            requesterProfile: requesterProfile
        )
    }

    /// Creates a copy with updated status
    /// - Parameter newStatus: New request status
    /// - Returns: Updated pairing request copy
    func withStatus(_ newStatus: RequestStatus) -> PairingRequest {
        var copy = self
        copy.status = newStatus
        copy.updatedAt = Date()
        return copy
    }
}

// MARK: - PairingRequest Validation Rules

/*
 Validation Rules (from design document):

 1. id must be auto-generated UUID
 2. requesterId must reference existing profile
 3. recipientId must reference existing profile
 4. requesterId cannot equal recipientId (cannot pair with self)
 5. status defaults to 'pending', can transition to 'accepted' or 'rejected'
 6. createdAt is auto-set to current timestamp
 7. updatedAt is auto-updated on status changes
 8. Requests older than 7 days should be automatically deleted
 9. Only one pending request allowed between same two users

 Database Constraints:
 - id: PRIMARY KEY
 - requester_id: REFERENCES profiles(id) ON DELETE CASCADE NOT NULL
 - recipient_id: REFERENCES profiles(id) ON DELETE CASCADE NOT NULL
 - status: CHECK (status IN ('pending', 'accepted', 'rejected'))
 - CONSTRAINT different_users CHECK (requester_id != recipient_id)
 - CONSTRAINT unique_pending_request UNIQUE (requester_id, recipient_id, status)
 */
