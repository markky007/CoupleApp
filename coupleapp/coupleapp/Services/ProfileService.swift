import Combine
import Foundation
import Supabase

// MARK: - Helper Structs

/// Parameters for RPC point update function
struct PointsParams: Encodable, Sendable {
    let user_id: String
    let points_delta: Int
}

/// Parameters for partner update (setting to null)
struct PartnerUpdate: Encodable, Sendable {
    let partner_id: UUID?
    let updated_at: String
}

/// Service for managing user profiles and partner relationships
/// Handles CRUD operations, partner pairing, and point management
class ProfileService {

    // MARK: - Singleton

    static let shared = ProfileService()

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

    // MARK: - Profile CRUD Operations

    /// Fetches a user's profile by ID
    /// - Parameter userId: User's unique identifier
    /// - Returns: User's profile
    /// - Throws: ProfileError if fetch fails
    func fetchProfile(userId: UUID) async throws -> Profile {
        do {
            let profile: Profile =
                try await client
                .from("profiles")
                .select()
                .eq("id", value: userId)
                .single()
                .execute()
                .value

            print("✅ Profile fetched for user: \(userId)")
            return profile
        } catch {
            print("❌ Failed to fetch profile: \(error.localizedDescription)")
            throw ProfileError.fetchFailed(error.localizedDescription)
        }
    }

    /// Creates a new profile for a user
    /// - Parameters:
    ///   - userId: User's unique identifier from auth
    ///   - displayName: Optional display name
    /// - Returns: Newly created profile
    /// - Throws: ProfileError if creation fails
    func createProfile(userId: UUID, displayName: String) async throws -> Profile {
        // Validate display name
        guard Profile.isValidDisplayName(displayName) else {
            throw ProfileError.invalidDisplayName
        }

        let newProfile = Profile.new(id: userId, displayName: displayName)

        do {
            let profile: Profile =
                try await client
                .from("profiles")
                .insert(newProfile)
                .select()
                .single()
                .execute()
                .value

            print("✅ Profile created for user: \(userId)")
            return profile
        } catch {
            print("❌ Failed to create profile: \(error.localizedDescription)")
            throw ProfileError.creationFailed(error.localizedDescription)
        }
    }

    /// Updates a user's display name
    /// - Parameters:
    ///   - userId: User's unique identifier
    ///   - newName: New display name
    /// - Throws: ProfileError if update fails
    func updateDisplayName(userId: UUID, newName: String) async throws {
        // Validate display name
        guard Profile.isValidDisplayName(newName) else {
            throw ProfileError.invalidDisplayName
        }

        do {
            try await client
                .from("profiles")
                .update(["display_name": newName, "updated_at": Date().ISO8601Format()])
                .eq("id", value: userId)
                .execute()

            print("✅ Display name updated for user: \(userId)")
        } catch {
            print("❌ Failed to update display name: \(error.localizedDescription)")
            throw ProfileError.updateFailed(error.localizedDescription)
        }
    }

    // MARK: - Partner Pairing

    /// Pairs current user with a partner (creates bidirectional relationship)
    /// - Parameters:
    ///   - userId: Current user's ID
    ///   - partnerId: Partner's user ID
    /// - Throws: ProfileError if pairing fails
    func pairWithPartner(userId: UUID, partnerId: UUID) async throws {
        // Validate inputs
        guard userId != partnerId else {
            throw ProfileError.cannotPairWithSelf
        }

        do {
            // Fetch both profiles to verify they exist and aren't already paired
            let userProfile = try await fetchProfile(userId: userId)
            let partnerProfile = try await fetchProfile(userId: partnerId)

            // Check if already paired
            if userProfile.partnerId != nil {
                throw ProfileError.alreadyPaired
            }

            if partnerProfile.partnerId != nil {
                throw ProfileError.partnerAlreadyPaired
            }

            // Update both profiles to create bidirectional relationship
            // Note: In production, this should be done in a database transaction
            // For now, we'll do it sequentially

            // Update user's profile
            try await client
                .from("profiles")
                .update(["partner_id": partnerId.uuidString, "updated_at": Date().ISO8601Format()])
                .eq("id", value: userId)
                .execute()

            // Update partner's profile
            try await client
                .from("profiles")
                .update(["partner_id": userId.uuidString, "updated_at": Date().ISO8601Format()])
                .eq("id", value: partnerId)
                .execute()

            print("✅ Successfully paired users: \(userId) ↔ \(partnerId)")
        } catch let error as ProfileError {
            throw error
        } catch {
            print("❌ Failed to pair with partner: \(error.localizedDescription)")
            throw ProfileError.pairingFailed(error.localizedDescription)
        }
    }

    /// Unpairs current user from their partner
    /// - Parameter userId: Current user's ID
    /// - Throws: ProfileError if unpairing fails
    func unpairFromPartner(userId: UUID) async throws {
        do {
            let profile = try await fetchProfile(userId: userId)

            guard let partnerId = profile.partnerId else {
                throw ProfileError.notPaired
            }

            // Remove partner relationship from both profiles
            let nullUpdate = PartnerUpdate(
                partner_id: nil,
                updated_at: Date().ISO8601Format()
            )

            try await client
                .from("profiles")
                .update(nullUpdate)
                .eq("id", value: userId)
                .execute()

            try await client
                .from("profiles")
                .update(nullUpdate)
                .eq("id", value: partnerId)
                .execute()

            print("✅ Successfully unpaired users: \(userId) ↔ \(partnerId)")
        } catch let error as ProfileError {
            throw error
        } catch {
            print("❌ Failed to unpair from partner: \(error.localizedDescription)")
            throw ProfileError.unpairingFailed(error.localizedDescription)
        }
    }

    // MARK: - Point Management

    /// Updates a user's point balance
    /// Uses database RPC function for atomic updates
    /// - Parameters:
    ///   - userId: User's unique identifier
    ///   - delta: Point change (positive to add, negative to subtract)
    /// - Throws: ProfileError if update fails
    nonisolated func updatePoints(userId: UUID, delta: Int) async throws {
        do {
            // Use database RPC function for atomic point updates
            // Note: Using JSONEncoder to create params to avoid actor isolation issues
            let paramsDict: [String: AnyJSON] = [
                "user_id": .string(userId.uuidString),
                "points_delta": .integer(delta),
            ]

            try await client
                .rpc("increment_user_points", params: paramsDict)
                .execute()

            print("✅ Points updated for user \(userId): \(delta > 0 ? "+" : "")\(delta)")
        } catch {
            print("❌ Failed to update points: \(error.localizedDescription)")
            throw ProfileError.pointUpdateFailed(error.localizedDescription)
        }
    }

    // MARK: - Realtime Subscriptions

    /// Subscribes to profile changes for real-time updates
    /// - Parameters:
    ///   - userId: User ID to monitor
    ///   - handler: Callback when profile changes
    /// - Throws: ProfileError if subscription fails
    func subscribeToProfileChanges(
        userId: UUID,
        handler: @escaping (Profile) -> Void
    ) async throws {
        do {
            // Unsubscribe from existing channel if any
            await realtimeChannel?.unsubscribe()

            // Create new channel for profile updates
            let channel = client.channel("profile:\(userId)")

            // Subscribe to postgres changes on profiles table
            let changes = await channel.postgresChange(
                InsertAction.self,
                schema: "public",
                table: "profiles",
                filter: "id=eq.\(userId)"
            )

            await channel.subscribe()

            // Listen for changes
            Task {
                for await change in changes {
                    // Decode the new record from the change
                    let newRecord = change.record
                    if let jsonData = try? JSONSerialization.data(withJSONObject: newRecord),
                        let profile = try? JSONDecoder().decode(Profile.self, from: jsonData)
                    {
                        handler(profile)
                    }
                }
            }

            self.realtimeChannel = channel
            print("✅ Subscribed to profile changes for user: \(userId)")
        } catch {
            print("❌ Failed to subscribe to profile changes: \(error.localizedDescription)")
            throw ProfileError.subscriptionFailed(error.localizedDescription)
        }
    }

    /// Unsubscribes from profile changes
    func unsubscribeFromProfileChanges() async {
        await realtimeChannel?.unsubscribe()
        realtimeChannel = nil
        print("✅ Unsubscribed from profile changes")
    }
}

// MARK: - ProfileError

/// Custom error types for profile operations
enum ProfileError: LocalizedError {
    case fetchFailed(String)
    case creationFailed(String)
    case updateFailed(String)
    case invalidDisplayName
    case cannotPairWithSelf
    case alreadyPaired
    case partnerAlreadyPaired
    case notPaired
    case pairingFailed(String)
    case unpairingFailed(String)
    case pointUpdateFailed(String)
    case subscriptionFailed(String)
    case profileNotFound

    var errorDescription: String? {
        switch self {
        case .fetchFailed(let message):
            return "Failed to fetch profile: \(message)"
        case .creationFailed(let message):
            return "Failed to create profile: \(message)"
        case .updateFailed(let message):
            return "Failed to update profile: \(message)"
        case .invalidDisplayName:
            return "Display name must be 1-\(AppConstants.maxDisplayNameLength) characters"
        case .cannotPairWithSelf:
            return "You cannot pair with yourself"
        case .alreadyPaired:
            return "You are already paired with a partner"
        case .partnerAlreadyPaired:
            return "This user is already paired with someone else"
        case .notPaired:
            return "You are not currently paired with anyone"
        case .pairingFailed(let message):
            return "Failed to pair with partner: \(message)"
        case .unpairingFailed(let message):
            return "Failed to unpair from partner: \(message)"
        case .pointUpdateFailed(let message):
            return "Failed to update points: \(message)"
        case .subscriptionFailed(let message):
            return "Failed to subscribe to updates: \(message)"
        case .profileNotFound:
            return "Profile not found"
        }
    }
}
