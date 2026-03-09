import Foundation

/// Transaction type enumeration
enum TransactionType: String, Codable {
    case earn = "earn"
    case redeem = "redeem"
}

/// Transaction model representing a point change record
/// Provides audit trail for all point operations (earning and redeeming)
struct Transaction: Identifiable, Codable, Equatable {

    // MARK: - Properties

    /// Unique identifier
    let id: UUID

    /// User ID who performed the transaction
    let userId: UUID

    /// Type of transaction (earn or redeem)
    let type: TransactionType

    /// Point amount (positive for earn, negative for redeem)
    let amount: Int

    /// Description of the transaction
    let description: String

    /// Transaction creation timestamp
    let createdAt: Date

    // MARK: - Coding Keys

    /// Maps Swift property names to database column names (snake_case)
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case type
        case amount
        case description
        case createdAt = "created_at"
    }

    // MARK: - Computed Properties

    /// Whether this is an earn transaction
    var isEarn: Bool {
        type == .earn
    }

    /// Whether this is a redeem transaction
    var isRedeem: Bool {
        type == .redeem
    }

    /// Absolute value of the amount
    var absoluteAmount: Int {
        abs(amount)
    }

    // MARK: - Validation

    /// Validates transaction description length
    /// - Parameter description: Description to validate
    /// - Returns: True if valid, false otherwise
    static func isValidDescription(_ description: String) -> Bool {
        !description.isEmpty && description.count <= AppConstants.maxTransactionDescriptionLength
    }

    /// Validates transaction amount based on type
    /// - Parameters:
    ///   - amount: Amount to validate
    ///   - type: Transaction type
    /// - Returns: True if valid, false otherwise
    static func isValidAmount(_ amount: Int, for type: TransactionType) -> Bool {
        switch type {
        case .earn:
            return amount > 0
        case .redeem:
            return amount < 0
        }
    }

    /// Validates the transaction instance
    var isValid: Bool {
        Self.isValidDescription(description) && Self.isValidAmount(amount, for: type)
    }
}

// MARK: - Transaction Extensions

extension Transaction {

    /// Creates a new earn transaction
    /// - Parameters:
    ///   - userId: User ID who earned points
    ///   - amount: Points earned (must be positive)
    ///   - description: Transaction description
    /// - Returns: New transaction instance
    static func earn(
        userId: UUID,
        amount: Int,
        description: String
    ) -> Transaction {
        Transaction(
            id: UUID(),
            userId: userId,
            type: .earn,
            amount: abs(amount),  // Ensure positive
            description: description,
            createdAt: Date()
        )
    }

    /// Creates a new redeem transaction
    /// - Parameters:
    ///   - userId: User ID who redeemed points
    ///   - amount: Points redeemed (will be made negative)
    ///   - description: Transaction description
    /// - Returns: New transaction instance
    static func redeem(
        userId: UUID,
        amount: Int,
        description: String
    ) -> Transaction {
        Transaction(
            id: UUID(),
            userId: userId,
            type: .redeem,
            amount: -abs(amount),  // Ensure negative
            description: description,
            createdAt: Date()
        )
    }

    /// Formats the amount with sign for display
    /// - Returns: Formatted string (e.g., "+50" or "-30")
    func formattedAmount() -> String {
        let sign = amount >= 0 ? "+" : ""
        return "\(sign)\(amount)"
    }
}

// MARK: - Transaction Validation Rules

/*
 Validation Rules (from design document):

 1. id is auto-generated UUID
 2. userId must reference valid profile
 3. type must be 'earn' or 'redeem'
 4. amount must be non-zero integer (positive for earn, negative for redeem)
 5. description is required, non-empty string (max 200 characters)
 6. createdAt is auto-set to current timestamp
 7. Transactions are immutable once created

 Database Constraints:
 - id: PRIMARY KEY
 - user_id: NOT NULL, REFERENCES profiles(id) ON DELETE CASCADE
 - type: NOT NULL, CHECK (type IN ('earn', 'redeem'))
 - amount: NOT NULL, CHECK (amount != 0)
 - description: NOT NULL, CHECK (length(description) > 0 AND length(description) <= 200)
 - created_at: NOT NULL, DEFAULT now()

 Invariants:
 - Transactions are never deleted or modified
 - Every point change has corresponding transaction record
 - Earn transactions have positive amounts
 - Redeem transactions have negative amounts
 */
