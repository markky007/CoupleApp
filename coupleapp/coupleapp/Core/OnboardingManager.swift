import Combine
import Foundation
import SwiftUI

/// Manages onboarding state and first-time user experience
@MainActor
class OnboardingManager: ObservableObject {

    // MARK: - Singleton

    static let shared = OnboardingManager()

    // MARK: - Published Properties

    @Published var hasCompletedOnboarding: Bool {
        didSet {
            UserDefaults.standard.set(hasCompletedOnboarding, forKey: Keys.hasCompletedOnboarding)
        }
    }

    @Published var hasSeenQuestTooltip: Bool {
        didSet {
            UserDefaults.standard.set(hasSeenQuestTooltip, forKey: Keys.hasSeenQuestTooltip)
        }
    }

    @Published var hasSeenRewardTooltip: Bool {
        didSet {
            UserDefaults.standard.set(hasSeenRewardTooltip, forKey: Keys.hasSeenRewardTooltip)
        }
    }

    @Published var hasSeenEventTooltip: Bool {
        didSet {
            UserDefaults.standard.set(hasSeenEventTooltip, forKey: Keys.hasSeenEventTooltip)
        }
    }

    @Published var hasSeenPairingTooltip: Bool {
        didSet {
            UserDefaults.standard.set(hasSeenPairingTooltip, forKey: Keys.hasSeenPairingTooltip)
        }
    }

    // MARK: - Private Keys

    private enum Keys {
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
        static let hasSeenQuestTooltip = "hasSeenQuestTooltip"
        static let hasSeenRewardTooltip = "hasSeenRewardTooltip"
        static let hasSeenEventTooltip = "hasSeenEventTooltip"
        static let hasSeenPairingTooltip = "hasSeenPairingTooltip"
    }

    // MARK: - Initialization

    private init() {
        self.hasCompletedOnboarding = UserDefaults.standard.bool(
            forKey: Keys.hasCompletedOnboarding)
        self.hasSeenQuestTooltip = UserDefaults.standard.bool(forKey: Keys.hasSeenQuestTooltip)
        self.hasSeenRewardTooltip = UserDefaults.standard.bool(forKey: Keys.hasSeenRewardTooltip)
        self.hasSeenEventTooltip = UserDefaults.standard.bool(forKey: Keys.hasSeenEventTooltip)
        self.hasSeenPairingTooltip = UserDefaults.standard.bool(forKey: Keys.hasSeenPairingTooltip)
    }

    // MARK: - Public Methods

    /// Mark onboarding as completed
    func completeOnboarding() {
        hasCompletedOnboarding = true
    }

    /// Reset all onboarding state (for testing)
    func resetOnboarding() {
        hasCompletedOnboarding = false
        hasSeenQuestTooltip = false
        hasSeenRewardTooltip = false
        hasSeenEventTooltip = false
        hasSeenPairingTooltip = false
    }

    /// Check if user should see onboarding
    var shouldShowOnboarding: Bool {
        !hasCompletedOnboarding
    }
}
