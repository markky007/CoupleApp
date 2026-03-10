import Combine
import Foundation
import SwiftUI

/// ViewModel for partner pairing operations
/// Handles partner code management, pairing requests, and real-time updates
/// Follows MVVM pattern with @MainActor for UI thread safety
@MainActor
class PairingViewModel: ObservableObject {

    // MARK: - Published Properties

    /// User's partner code for sharing
    @Published var partnerCode: String?

    /// List of pending pairing requests
    @Published var pendingRequests: [PairingRequest] = []

    /// Loading state for async operations
    @Published var isLoading = false

    /// Error message to display
    @Published var errorMessage: String?

    /// Success message to display
    @Published var successMessage: String?

    /// Show error alert
    @Published var showError = false

    /// Show success alert
    @Published var showSuccess = false

    /// Partner code input field
    @Published var partnerCodeInput = ""

    // MARK: - Dependencies

    private let pairingService = PairingService.shared
    private let profileService = ProfileService.shared

    // MARK: - Private Properties

    /// Current user ID (injected or from auth)
    private var currentUserId: UUID?

    // MARK: - Initialization

    /// Initializes the view model
    /// - Parameter userId: Current user's ID (optional, can be set later)
    init(userId: UUID? = nil) {
        self.currentUserId = userId
    }

    deinit {
        // Clean up realtime subscription
        Task {
            await pairingService.unsubscribeFromRequests()
        }
    }

    // MARK: - Setup

    /// Sets the current user ID and loads initial data
    /// - Parameter userId: Current user's ID
    func setUserId(_ userId: UUID) async {
        self.currentUserId = userId
        await loadPartnerCode()
        await loadPendingRequests()
        await subscribeToRequests()
    }

    // MARK: - Partner Code Management

    /// Loads or generates the user's partner code
    func loadPartnerCode() async {
        guard let userId = currentUserId else {
            showErrorMessage("No authenticated user")
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            // Fetch user's profile to check for existing partner code
            let profile = try await profileService.fetchProfile(userId: userId)

            if let existingCode = profile.partnerCode {
                // User already has a partner code
                partnerCode = existingCode
                print("✅ Loaded existing partner code: \(existingCode)")
            } else {
                // Generate new partner code
                let newCode = try await pairingService.generatePartnerCode(userId: userId)
                partnerCode = newCode
                print("✅ Generated new partner code: \(newCode)")
            }
        } catch {
            showErrorMessage("Failed to load partner code: \(error.localizedDescription)")
        }

        isLoading = false
    }

    /// Copies the partner code to clipboard
    func copyPartnerCode() {
        guard let code = partnerCode else {
            showErrorMessage("No partner code available")
            return
        }

        #if os(iOS)
            UIPasteboard.general.string = code
        #elseif os(macOS)
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(code, forType: .string)
        #endif

        showSuccessMessage("Partner code copied to clipboard!")
    }

    // MARK: - Pairing Request Management

    /// Sends a pairing request to another user using their partner code
    /// - Parameter code: Partner code of the recipient
    func sendPairingRequest(code: String) async {
        guard let userId = currentUserId else {
            showErrorMessage("No authenticated user")
            return
        }

        // Validate code format
        let trimmedCode = code.trimmingCharacters(in: .whitespaces).uppercased()
        guard !trimmedCode.isEmpty else {
            showErrorMessage("Please enter a partner code")
            return
        }

        guard Profile.isValidPartnerCode(trimmedCode) else {
            showErrorMessage(
                "Invalid partner code format. Code must be 6-8 alphanumeric characters.")
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let request = try await pairingService.createPairingRequest(
                from: userId,
                to: trimmedCode
            )

            showSuccessMessage("Pairing request sent successfully!")
            partnerCodeInput = ""  // Clear input field

            print("✅ Pairing request sent: \(request.id)")
        } catch let error as PairingError {
            showErrorMessage(error.localizedDescription)
        } catch {
            showErrorMessage("Failed to send pairing request: \(error.localizedDescription)")
        }

        isLoading = false
    }

    /// Loads all pending pairing requests for the current user
    func loadPendingRequests() async {
        guard let userId = currentUserId else {
            showErrorMessage("No authenticated user")
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let requests = try await pairingService.fetchPendingRequests(userId: userId)
            pendingRequests = requests

            print("✅ Loaded \(requests.count) pending requests")
        } catch {
            showErrorMessage("Failed to load pending requests: \(error.localizedDescription)")
        }

        isLoading = false
    }

    /// Accepts a pairing request
    /// - Parameter request: The pairing request to accept
    func acceptRequest(_ request: PairingRequest) async {
        guard currentUserId != nil else {
            showErrorMessage("No authenticated user")
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            try await pairingService.acceptPairingRequest(requestId: request.id)

            // Remove the accepted request from pending list
            pendingRequests.removeAll { $0.id == request.id }

            showSuccessMessage("Pairing request accepted! You are now paired.")

            print("✅ Pairing request accepted: \(request.id)")
        } catch let error as PairingError {
            showErrorMessage(error.localizedDescription)
        } catch {
            showErrorMessage("Failed to accept pairing request: \(error.localizedDescription)")
        }

        isLoading = false
    }

    /// Rejects a pairing request
    /// - Parameter request: The pairing request to reject
    func rejectRequest(_ request: PairingRequest) async {
        guard currentUserId != nil else {
            showErrorMessage("No authenticated user")
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            try await pairingService.rejectPairingRequest(requestId: request.id)

            // Remove the rejected request from pending list
            pendingRequests.removeAll { $0.id == request.id }

            showSuccessMessage("Pairing request rejected")

            print("✅ Pairing request rejected: \(request.id)")
        } catch let error as PairingError {
            showErrorMessage(error.localizedDescription)
        } catch {
            showErrorMessage("Failed to reject pairing request: \(error.localizedDescription)")
        }

        isLoading = false
    }

    // MARK: - Real-time Subscriptions

    /// Subscribes to real-time pairing request updates
    func subscribeToRequests() async {
        guard let userId = currentUserId else {
            print("⚠️ Cannot subscribe: No user ID")
            return
        }

        do {
            try await pairingService.subscribeToRequests(userId: userId) { [weak self] requests in
                guard let self = self else { return }

                // Update pending requests on main thread
                self.pendingRequests = requests

                print("📡 Received \(requests.count) pending requests via realtime")
            }

            print("✅ Subscribed to pairing request updates")
        } catch {
            print("❌ Failed to subscribe to pairing requests: \(error.localizedDescription)")
            // Don't show error to user - subscription is optional enhancement
        }
    }

    /// Unsubscribes from real-time pairing request updates
    func unsubscribeFromRequests() async {
        await pairingService.unsubscribeFromRequests()
        print("✅ Unsubscribed from pairing request updates")
    }

    // MARK: - Helper Methods

    /// Shows error message with alert
    private func showErrorMessage(_ message: String) {
        errorMessage = message
        showError = true
    }

    /// Shows success message with alert
    private func showSuccessMessage(_ message: String) {
        successMessage = message
        showSuccess = true
    }

    /// Dismisses error alert
    func dismissError() {
        showError = false
        errorMessage = nil
    }

    /// Dismisses success alert
    func dismissSuccess() {
        showSuccess = false
        successMessage = nil
    }

    /// Refreshes all data (partner code and pending requests)
    func refresh() async {
        await loadPartnerCode()
        await loadPendingRequests()
    }
}
