import Combine
import Foundation
import Supabase

/// Service for managing partner pairing operations
/// Handles partner code generation, pairing requests, and bidirectional relationships
/// Implements singleton pattern for consistent state across the app
class PairingService {

    // MARK: - Singleton

    /// Shared instance for app-wide access
    static let shared = PairingService()

    // MARK: - Private Properties

    /// Supabase client for database operations
    private let client = supabase

    /// Realtime channel for pairing request notifications
    private var realtimeChannel: RealtimeChannelV2?

    // MARK: - Initialization

    private init() {}

    deinit {
        // Clean up realtime subscription
        Task {
            await realtimeChannel?.unsubscribe()
        }
    }

    // MARK: - Partner Code Management

    /// Generates a unique partner code for a user
    /// - Parameter userId: User's unique identifier
    /// - Returns: Unique 8-character alphanumeric partner code
    /// - Throws: PairingError if generation fails
    func generatePartnerCode(userId: UUID) async throws -> String {
        do {
            // Call the database function to generate a unique code
            let response = try await client.rpc(
                "generate_partner_code"
            ).execute()

            // Decode the response as a string
            guard let code = try? JSONDecoder().decode(String.self, from: response.data) else {
                throw PairingError.codeGenerationFailed
            }

            // Update the user's profile with the generated code
            try await client
                .from("profiles")
                .update(["partner_code": code])
                .eq("id", value: userId.uuidString)
                .execute()

            print("✅ Generated partner code: \(code) for user: \(userId)")
            return code

        } catch let error as PairingError {
            throw error
        } catch {
            print("❌ Failed to generate partner code: \(error.localizedDescription)")
            throw PairingError.codeGenerationFailed
        }
    }

    /// Finds a user by their partner code
    /// - Parameter code: Partner code to search for
    /// - Returns: User ID if found, nil otherwise
    /// - Throws: PairingError if lookup fails
    func findUserByPartnerCode(_ code: String) async throws -> UUID? {
        // Validate code format
        let trimmedCode = code.trimmingCharacters(in: .whitespaces).uppercased()
        guard Profile.isValidPartnerCode(trimmedCode) else {
            throw PairingError.invalidCode
        }

        do {
            // Query profiles table for the partner code
            let profiles: [Profile] =
                try await client
                .from("profiles")
                .select("id")
                .eq("partner_code", value: trimmedCode)
                .execute()
                .value

            // Check if a profile was found
            if profiles.isEmpty {
                return nil
            }

            // Return the first profile's ID
            print("✅ Found user \(profiles[0].id) with partner code: \(trimmedCode)")
            return profiles[0].id

        } catch let error as PairingError {
            throw error
        } catch {
            print("❌ Failed to find user by partner code: \(error.localizedDescription)")
            throw PairingError.databaseError(error.localizedDescription)
        }
    }

    // MARK: - Pairing Request Management

    /// Creates a pairing request from one user to another
    /// - Parameters:
    ///   - requesterId: ID of user sending the request
    ///   - recipientCode: Partner code of the recipient
    /// - Returns: Created pairing request
    /// - Throws: PairingError if request creation fails
    func createPairingRequest(from requesterId: UUID, to recipientCode: String) async throws
        -> PairingRequest
    {
        // Step 1: Validate partner code format
        let code = recipientCode.trimmingCharacters(in: .whitespaces).uppercased()
        guard Profile.isValidPartnerCode(code) else {
            throw PairingError.invalidCode
        }

        // Step 2: Find recipient by partner code
        guard let recipientId = try await findUserByPartnerCode(code) else {
            throw PairingError.codeNotFound
        }

        // Step 3: Validate not pairing with self
        guard requesterId != recipientId else {
            throw PairingError.cannotPairWithSelf
        }

        // Step 4: Check if requester is already paired
        let requesterResponse =
            try await client
            .from("profiles")
            .select("partner_id")
            .eq("id", value: requesterId.uuidString)
            .single()
            .execute()

        struct PartnerCheck: Codable {
            let partner_id: UUID?
        }

        let requesterProfile = try JSONDecoder().decode(
            PartnerCheck.self, from: requesterResponse.data)
        guard requesterProfile.partner_id == nil else {
            throw PairingError.alreadyPaired
        }

        // Step 5: Check if recipient is already paired
        let recipientResponse =
            try await client
            .from("profiles")
            .select("partner_id")
            .eq("id", value: recipientId.uuidString)
            .single()
            .execute()

        let recipientProfile = try JSONDecoder().decode(
            PartnerCheck.self, from: recipientResponse.data)
        guard recipientProfile.partner_id == nil else {
            throw PairingError.recipientAlreadyPaired
        }

        // Step 6: Check for existing pending request
        let existingResponse =
            try await client
            .from("pairing_requests")
            .select()
            .eq("requester_id", value: requesterId.uuidString)
            .eq("recipient_id", value: recipientId.uuidString)
            .eq("status", value: "pending")
            .execute()

        if !existingResponse.data.isEmpty
            && String(data: existingResponse.data, encoding: .utf8) != "[]"
        {
            throw PairingError.requestAlreadyExists
        }

        // Step 7: Create pairing request
        let newRequest = PairingRequest.new(requesterId: requesterId, recipientId: recipientId)

        let insertResponse =
            try await client
            .from("pairing_requests")
            .insert(newRequest)
            .select()
            .single()
            .execute()

        let createdRequest = try JSONDecoder().decode(
            PairingRequest.self, from: insertResponse.data)

        print("✅ Pairing request created: \(requesterId) -> \(recipientId)")
        return createdRequest
    }

    /// Fetches all pending pairing requests for a user
    /// - Parameter userId: User's unique identifier
    /// - Returns: Array of pending pairing requests
    /// - Throws: PairingError if fetch fails
    func fetchPendingRequests(userId: UUID) async throws -> [PairingRequest] {
        do {
            // Query pairing_requests table for requests where user is recipient
            let response =
                try await client
                .from("pairing_requests")
                .select()
                .eq("recipient_id", value: userId.uuidString)
                .eq("status", value: "pending")
                .order("created_at", ascending: false)
                .execute()

            // Check if response is empty
            if response.data.isEmpty || String(data: response.data, encoding: .utf8) == "[]" {
                return []
            }

            // Decode the array of pairing requests
            let requests = try JSONDecoder().decode([PairingRequest].self, from: response.data)

            print("✅ Fetched \(requests.count) pending requests for user: \(userId)")
            return requests

        } catch let error as PairingError {
            throw error
        } catch {
            print("❌ Failed to fetch pending requests: \(error.localizedDescription)")
            throw PairingError.databaseError(error.localizedDescription)
        }
    }

    /// Accepts a pairing request and creates bidirectional relationship
    /// - Parameter requestId: ID of the pairing request to accept
    /// - Throws: PairingError if acceptance fails
    func acceptPairingRequest(requestId: UUID) async throws {
        do {
            // Use database function for atomic operation
            // This ensures all validations and updates happen atomically
            try await client
                .rpc(
                    "accept_pairing_request",
                    params: ["request_id": requestId.uuidString]
                )
                .execute()

            print("✅ Pairing request accepted: \(requestId)")

        } catch let error as PairingError {
            throw error
        } catch {
            print("❌ Failed to accept pairing request: \(error.localizedDescription)")
            // Check if error message indicates specific failure
            let errorMessage = error.localizedDescription.lowercased()
            if errorMessage.contains("not found") {
                throw PairingError.requestNotFound
            } else if errorMessage.contains("not pending") {
                throw PairingError.requestNotPending
            } else if errorMessage.contains("already paired") {
                throw PairingError.alreadyPaired
            } else {
                throw PairingError.databaseError(error.localizedDescription)
            }
        }
    }

    /// Rejects a pairing request
    /// - Parameter requestId: ID of the pairing request to reject
    /// - Throws: PairingError if rejection fails
    func rejectPairingRequest(requestId: UUID) async throws {
        do {
            // Update request status to 'rejected'
            let response =
                try await client
                .from("pairing_requests")
                .update(["status": "rejected", "updated_at": Date().ISO8601Format()])
                .eq("id", value: requestId.uuidString)
                .execute()

            // Check if any rows were updated
            if response.data.isEmpty || String(data: response.data, encoding: .utf8) == "[]" {
                throw PairingError.requestNotFound
            }

            print("✅ Pairing request rejected: \(requestId)")

        } catch let error as PairingError {
            throw error
        } catch {
            print("❌ Failed to reject pairing request: \(error.localizedDescription)")
            throw PairingError.databaseError(error.localizedDescription)
        }
    }

    // MARK: - Pairing Operations

    /// Pairs two users together (creates bidirectional relationship)
    /// - Parameters:
    ///   - userId: First user's ID
    ///   - partnerId: Second user's ID
    /// - Throws: PairingError if pairing fails
    func pairUsers(userId: UUID, partnerId: UUID) async throws {
        do {
            // Step 1: Validate users are different
            guard userId != partnerId else {
                throw PairingError.cannotPairWithSelf
            }

            // Step 2: Check if either user is already paired
            let userResponse =
                try await client
                .from("profiles")
                .select("partner_id")
                .eq("id", value: userId.uuidString)
                .single()
                .execute()

            struct PartnerCheck: Codable {
                let partner_id: UUID?
            }

            let userProfile = try JSONDecoder().decode(PartnerCheck.self, from: userResponse.data)
            guard userProfile.partner_id == nil else {
                throw PairingError.alreadyPaired
            }

            let partnerResponse =
                try await client
                .from("profiles")
                .select("partner_id")
                .eq("id", value: partnerId.uuidString)
                .single()
                .execute()

            let partnerProfile = try JSONDecoder().decode(
                PartnerCheck.self, from: partnerResponse.data)
            guard partnerProfile.partner_id == nil else {
                throw PairingError.recipientAlreadyPaired
            }

            // Step 3: Update first user's partner_id (userId -> partnerId)
            try await client
                .from("profiles")
                .update(["partner_id": partnerId.uuidString, "updated_at": Date().ISO8601Format()])
                .eq("id", value: userId.uuidString)
                .execute()

            // Step 4: Update second user's partner_id (partnerId -> userId) - bidirectional
            try await client
                .from("profiles")
                .update(["partner_id": userId.uuidString, "updated_at": Date().ISO8601Format()])
                .eq("id", value: partnerId.uuidString)
                .execute()

            print("✅ Users paired successfully: \(userId) <-> \(partnerId)")

        } catch let error as PairingError {
            throw error
        } catch {
            print("❌ Failed to pair users: \(error.localizedDescription)")
            throw PairingError.databaseError(error.localizedDescription)
        }
    }

    /// Unpairs a user from their partner
    /// - Parameter userId: User's unique identifier
    /// - Throws: PairingError if unpairing fails
    func unpairUsers(userId: UUID) async throws {
        do {
            // Step 1: Get user's current partner_id
            let userResponse =
                try await client
                .from("profiles")
                .select("partner_id")
                .eq("id", value: userId.uuidString)
                .single()
                .execute()

            struct PartnerCheck: Codable {
                let partner_id: UUID?
            }

            let userProfile = try JSONDecoder().decode(PartnerCheck.self, from: userResponse.data)

            // Step 2: Check if user has a partner
            guard let partnerId = userProfile.partner_id else {
                // User is not paired, nothing to do
                print("ℹ️ User \(userId) is not paired")
                return
            }

            // Step 3: Remove partner_id from first user (userId)
            // Use AnyJSON.null for null values
            try await client
                .from("profiles")
                .update([
                    "partner_id": AnyJSON.null,
                    "updated_at": AnyJSON.string(Date().ISO8601Format()),
                ])
                .eq("id", value: userId.uuidString)
                .execute()

            // Step 4: Remove partner_id from second user (partnerId) - bidirectional
            try await client
                .from("profiles")
                .update([
                    "partner_id": AnyJSON.null,
                    "updated_at": AnyJSON.string(Date().ISO8601Format()),
                ])
                .eq("id", value: partnerId.uuidString)
                .execute()

            print("✅ Users unpaired successfully: \(userId) <-> \(partnerId)")

        } catch let error as PairingError {
            throw error
        } catch {
            print("❌ Failed to unpair users: \(error.localizedDescription)")
            throw PairingError.databaseError(error.localizedDescription)
        }
    }

    // MARK: - Realtime Subscriptions

    /// Subscribes to pairing request notifications for a user
    /// Monitors INSERT, UPDATE, and DELETE events on pairing_requests table
    /// where the user is the recipient
    /// - Parameters:
    ///   - userId: User ID to monitor
    ///   - handler: Callback when new requests arrive (called on main thread)
    /// - Throws: PairingError if subscription fails
    func subscribeToRequests(userId: UUID, handler: @escaping ([PairingRequest]) -> Void)
        async throws
    {
        do {
            // Unsubscribe from existing channel if any
            await unsubscribeFromRequests()

            // Create new channel for pairing request updates
            let channel = client.channel("pairing_requests_\(userId.uuidString)")

            // Subscribe to INSERT events (new pairing requests)
            let insertChanges = await channel.postgresChange(
                InsertAction.self,
                schema: "public",
                table: "pairing_requests",
                filter: "recipient_id=eq.\(userId.uuidString)"
            )

            // Subscribe to UPDATE events (request status changes)
            let updateChanges = await channel.postgresChange(
                UpdateAction.self,
                schema: "public",
                table: "pairing_requests",
                filter: "recipient_id=eq.\(userId.uuidString)"
            )

            // Subscribe to DELETE events (request deletions)
            let deleteChanges = await channel.postgresChange(
                DeleteAction.self,
                schema: "public",
                table: "pairing_requests",
                filter: "recipient_id=eq.\(userId.uuidString)"
            )

            // Subscribe to channel
            await channel.subscribe()

            // Listen for INSERT changes
            Task { [weak self] in
                for await _ in insertChanges {
                    await self?.handleRequestChange(
                        userId: userId, handler: handler, changeType: "INSERT")
                }
            }

            // Listen for UPDATE changes
            Task { [weak self] in
                for await _ in updateChanges {
                    await self?.handleRequestChange(
                        userId: userId, handler: handler, changeType: "UPDATE")
                }
            }

            // Listen for DELETE changes
            Task { [weak self] in
                for await _ in deleteChanges {
                    await self?.handleRequestChange(
                        userId: userId, handler: handler, changeType: "DELETE")
                }
            }

            self.realtimeChannel = channel

            print("✅ Subscribed to pairing requests for user: \(userId)")

            // Fetch and send initial data
            let initialRequests = try await fetchPendingRequests(userId: userId)
            await MainActor.run {
                handler(initialRequests)
            }

        } catch let error as PairingError {
            throw error
        } catch {
            print("❌ Failed to subscribe to pairing requests: \(error.localizedDescription)")
            throw PairingError.subscriptionFailed(error.localizedDescription)
        }
    }

    /// Handles pairing request changes and notifies handler on main thread
    /// - Parameters:
    ///   - userId: User ID to fetch requests for
    ///   - handler: Callback to notify
    ///   - changeType: Type of change (INSERT, UPDATE, DELETE)
    private func handleRequestChange(
        userId: UUID,
        handler: @escaping ([PairingRequest]) -> Void,
        changeType: String
    ) async {
        print("📡 Pairing request \(changeType) detected for user: \(userId)")

        do {
            // Fetch updated pending requests
            let requests = try await fetchPendingRequests(userId: userId)

            // Notify handler on main thread
            await MainActor.run {
                handler(requests)
            }

            print("✅ Notified handler with \(requests.count) pending requests")

        } catch {
            print("❌ Failed to fetch requests after \(changeType): \(error.localizedDescription)")
        }
    }

    /// Unsubscribes from pairing request notifications
    func unsubscribeFromRequests() async {
        await realtimeChannel?.unsubscribe()
        realtimeChannel = nil
        print("✅ Unsubscribed from pairing requests")
    }
}

// MARK: - PairingError

/// Custom error types for pairing operations
enum PairingError: LocalizedError {
    case invalidCode
    case codeNotFound
    case cannotPairWithSelf
    case alreadyPaired
    case recipientAlreadyPaired
    case requestAlreadyExists
    case requestNotFound
    case requestNotPending
    case networkError(String)
    case databaseError(String)
    case codeGenerationFailed
    case subscriptionFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidCode:
            return "Invalid partner code format. Code must be 6-8 alphanumeric characters."
        case .codeNotFound:
            return "No user found with this partner code."
        case .cannotPairWithSelf:
            return "You cannot pair with yourself."
        case .alreadyPaired:
            return "You are already paired with a partner."
        case .recipientAlreadyPaired:
            return "This user is already paired with someone else."
        case .requestAlreadyExists:
            return "A pairing request already exists between these users."
        case .requestNotFound:
            return "Pairing request not found."
        case .requestNotPending:
            return "This pairing request is no longer pending."
        case .networkError(let message):
            return "Network error: \(message)"
        case .databaseError(let message):
            return "Database error: \(message)"
        case .codeGenerationFailed:
            return "Failed to generate unique partner code."
        case .subscriptionFailed(let message):
            return "Failed to subscribe to pairing requests: \(message)"
        }
    }
}
