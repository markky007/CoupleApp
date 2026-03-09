import Foundation

/// Application-wide constants
/// Centralizes all magic numbers and configuration values
enum AppConstants {
    
    // MARK: - Validation
    
    /// Minimum password length for authentication
    static let minPasswordLength = 6
    
    /// Maximum display name length
    static let maxDisplayNameLength = 50
    
    /// Maximum quest title length
    static let maxQuestTitleLength = 200
    
    /// Maximum reward title length
    static let maxRewardTitleLength = 100
    
    /// Maximum event title length
    static let maxEventTitleLength = 100
    
    /// Maximum transaction description length
    static let maxTransactionDescriptionLength = 200
    
    // MARK: - Points
    
    /// Minimum points for a quest
    static let minQuestPoints = 1
    
    /// Maximum points for a quest
    static let maxQuestPoints = 1000
    
    /// Minimum points cost for a reward
    static let minRewardCost = 1
    
    /// Maximum points cost for a reward
    static let maxRewardCost = 10000
    
    // MARK: - Notifications
    
    /// Days before event to send first reminder
    static let eventReminderDays: [Int] = [3, 1]
    
    /// Hour of day to send notifications (9:00 AM)
    static let notificationHour = 9
    
    /// Minute of hour to send notifications
    static let notificationMinute = 0
    
    // MARK: - UI
    
    /// Default transaction history limit
    static let defaultTransactionLimit = 20
    
    /// Maximum transaction history limit
    static let maxTransactionLimit = 100
    
    /// Pull-to-refresh debounce time (seconds)
    static let refreshDebounceTime: TimeInterval = 1.0
    
    // MARK: - Performance
    
    /// Cache TTL for quest list (seconds)
    static let questCacheTTL: TimeInterval = 30
    
    /// Cache TTL for reward catalog (seconds)
    static let rewardCacheTTL: TimeInterval = 300
    
    /// Realtime update target latency (milliseconds)
    static let realtimeTargetLatency = 100
    
    /// Maximum concurrent network requests
    static let maxConcurrentRequests = 3
    
    // MARK: - Database
    
    /// Quest status values
    enum QuestStatus {
        static let pending = "pending"
        static let completed = "completed"
    }
    
    /// Transaction type values
    enum TransactionType {
        static let earn = "earn"
        static let redeem = "redeem"
    }
}
