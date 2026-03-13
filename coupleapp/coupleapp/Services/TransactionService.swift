import Foundation
import Supabase

/// Service for managing transaction history and audit trail
/// Provides queries for transaction records and transaction creation
class TransactionService {

    // MARK: - Singleton

    static let shared = TransactionService()

    // MARK: - Private Properties

    private let client = supabase

    // MARK: - Initialization

    private init() {}

    // MARK: - Transaction Query Operations

    /// Fetches transaction history for a specific user
    /// Returns transactions sorted by created_at descending (newest first)
    /// - Parameters:
    ///   - userId: User's unique identifier
    ///   - limit: Optional limit on number of transactions to return
    /// - Returns: Array of transactions
    /// - Throws: TransactionError if fetch fails
    func fetchUserTransactions(userId: UUID, limit: Int? = nil) async throws -> [Transaction] {
        do {
            var query =
                client
                .from("transactions")
                .select()
                .eq("user_id", value: userId)
                .order("created_at", ascending: false)

            if let limit = limit {
                query = query.limit(limit)
            }

            let transactions: [Transaction] = try await query.execute().value

            print("✅ Fetched \(transactions.count) transactions for user \(userId)")
            return transactions
        } catch {
            print("❌ Failed to fetch user transactions: \(error.localizedDescription)")
            throw TransactionError.fetchFailed(error.localizedDescription)
        }
    }

    /// Fetches combined transaction history for both partners
    /// Returns transactions for both users sorted by created_at descending
    /// - Parameters:
    ///   - userId: First user's unique identifier
    ///   - partnerId: Partner's unique identifier
    ///   - limit: Optional limit on number of transactions to return
    /// - Returns: Array of transactions for both users
    /// - Throws: TransactionError if fetch fails
    func fetchPartnerTransactions(
        userId: UUID,
        partnerId: UUID,
        limit: Int? = nil
    ) async throws -> [Transaction] {
        do {
            var query =
                client
                .from("transactions")
                .select()
                .in("user_id", values: [userId, partnerId])
                .order("created_at", ascending: false)

            if let limit = limit {
                query = query.limit(limit)
            }

            let transactions: [Transaction] = try await query.execute().value

            print(
                "✅ Fetched \(transactions.count) combined transactions for users \(userId) and \(partnerId)"
            )
            return transactions
        } catch {
            print("❌ Failed to fetch partner transactions: \(error.localizedDescription)")
            throw TransactionError.fetchFailed(error.localizedDescription)
        }
    }

    // MARK: - Transaction Creation Operations

    /// Creates a new transaction record
    /// Validates inputs and inserts transaction into database
    /// - Parameters:
    ///   - userId: User's unique identifier
    ///   - type: Transaction type (earn or redeem)
    ///   - amount: Point amount (positive for earn, negative for redeem)
    ///   - description: Transaction description
    /// - Returns: Created transaction
    /// - Throws: TransactionError if validation or creation fails
    func createTransaction(
        userId: UUID,
        type: TransactionType,
        amount: Int,
        description: String
    ) async throws -> Transaction {
        // Validate description
        guard Transaction.isValidDescription(description) else {
            throw TransactionError.invalidDescription
        }

        // Validate amount matches type
        guard Transaction.isValidAmount(amount, for: type) else {
            throw TransactionError.invalidAmount(type: type, amount: amount)
        }

        // Create transaction instance
        let transaction = Transaction(
            id: UUID(),
            userId: userId,
            type: type,
            amount: amount,
            description: description,
            createdAt: Date()
        )

        do {
            let response =
                try await client
                .from("transactions")
                .insert(transaction)
                .select()
                .execute()

            // Decode response as array and get first element
            let transactions = try JSONDecoder().decode([Transaction].self, from: response.data)
            guard let createdTransaction = transactions.first else {
                throw TransactionError.creationFailed("Failed to create transaction")
            }

            print(
                "✅ Transaction created: \(type.rawValue) \(amount) points for user \(userId)"
            )
            return createdTransaction
        } catch let error as TransactionError {
            throw error
        } catch {
            print("❌ Failed to create transaction: \(error.localizedDescription)")
            throw TransactionError.creationFailed(error.localizedDescription)
        }
    }
}

// MARK: - TransactionError

/// Custom error types for transaction operations
enum TransactionError: LocalizedError {
    case fetchFailed(String)
    case creationFailed(String)
    case invalidDescription
    case invalidAmount(type: TransactionType, amount: Int)

    var errorDescription: String? {
        switch self {
        case .fetchFailed(let message):
            return "Failed to fetch transactions: \(message)"
        case .creationFailed(let message):
            return "Failed to create transaction: \(message)"
        case .invalidDescription:
            return
                "Transaction description must be 1-\(AppConstants.maxTransactionDescriptionLength) characters"
        case .invalidAmount(let type, let amount):
            return
                "Invalid amount \(amount) for \(type.rawValue) transaction. Earn must be positive, redeem must be negative."
        }
    }
}
