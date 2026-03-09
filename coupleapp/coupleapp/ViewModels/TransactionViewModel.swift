import Combine
import Foundation
import SwiftUI

/// Filter options for transaction history
enum TransactionFilter: String, CaseIterable {
    case all = "All"
    case earn = "Earn"
    case redeem = "Redeem"
}

/// ViewModel for managing transaction history state and operations
/// Handles transaction fetching, filtering, and combined partner history
@MainActor
class TransactionViewModel: ObservableObject {

    // MARK: - Published Properties

    /// Array of all transactions
    @Published var transactions: [Transaction] = []

    /// Current filter selection
    @Published var selectedFilter: TransactionFilter = .all

    /// Loading state
    @Published var isLoading = false

    /// Error state
    @Published var showError = false
    @Published var errorMessage: String?

    // MARK: - Private Properties

    private let transactionService = TransactionService.shared
    private let profileService = ProfileService.shared
    private let authService = AuthService.shared

    // MARK: - Computed Properties

    /// Filtered transactions based on selected filter
    var filteredTransactions: [Transaction] {
        switch selectedFilter {
        case .all:
            return transactions
        case .earn:
            return transactions.filter { $0.type == .earn }
        case .redeem:
            return transactions.filter { $0.type == .redeem }
        }
    }

    // MARK: - Initialization

    init() {}

    // MARK: - Public Methods

    /// Fetches transaction history for current user and their partner
    func fetchTransactions() async {
        isLoading = true
        defer { isLoading = false }

        guard let userId = authService.currentUserId else {
            errorMessage = "User not authenticated"
            showError = true
            return
        }

        do {
            // Fetch user's profile to check for partner
            let profile: Profile
            do {
                profile = try await profileService.fetchProfile(userId: userId)
            } catch {
                // If profile doesn't exist, create it with default values
                print("⚠️ Profile not found, creating new profile...")
                profile = try await profileService.createProfile(
                    userId: userId,
                    displayName: "User"
                )
            }

            // Fetch combined history if partner exists, otherwise just user's history
            if let partnerId = profile.partnerId {
                transactions = try await transactionService.fetchPartnerTransactions(
                    userId: userId,
                    partnerId: partnerId,
                    limit: 100
                )
            } else {
                transactions = try await transactionService.fetchUserTransactions(
                    userId: userId,
                    limit: 100
                )
            }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    /// Fetches only the current user's transactions
    func fetchUserTransactions() async {
        isLoading = true
        defer { isLoading = false }

        guard let userId = authService.currentUserId else {
            errorMessage = "User not authenticated"
            showError = true
            return
        }

        do {
            transactions = try await transactionService.fetchUserTransactions(
                userId: userId,
                limit: 100
            )
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    /// Fetches partner's transactions only
    func fetchPartnerTransactions() async {
        isLoading = true
        defer { isLoading = false }

        guard let userId = authService.currentUserId else {
            errorMessage = "User not authenticated"
            showError = true
            return
        }

        do {
            let profile = try await profileService.fetchProfile(userId: userId)

            guard let partnerId = profile.partnerId else {
                errorMessage = "No partner linked"
                showError = true
                return
            }

            transactions = try await transactionService.fetchUserTransactions(
                userId: partnerId,
                limit: 100
            )
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    /// Dismisses error alert
    func dismissError() {
        showError = false
        errorMessage = nil
    }

    /// Changes the filter and updates the view
    /// - Parameter filter: New filter to apply
    func setFilter(_ filter: TransactionFilter) {
        selectedFilter = filter
    }
}
