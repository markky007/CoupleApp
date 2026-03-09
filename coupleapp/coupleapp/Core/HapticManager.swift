import SwiftUI

#if os(iOS)
    import UIKit

    /// Manages haptic feedback throughout the app
    /// Provides consistent haptic responses for user interactions
    class HapticManager {
        static let shared = HapticManager()

        private init() {}

        /// Light impact for button taps
        func light() {
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
        }

        /// Medium impact for standard interactions
        func medium() {
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
        }

        /// Heavy impact for important actions
        func heavy() {
            let generator = UIImpactFeedbackGenerator(style: .heavy)
            generator.impactOccurred()
        }

        /// Success notification for completed actions
        func success() {
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        }

        /// Warning notification for alerts
        func warning() {
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.warning)
        }

        /// Error notification for failures
        func error() {
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.error)
        }

        /// Selection feedback for picker changes
        func selection() {
            let generator = UISelectionFeedbackGenerator()
            generator.selectionChanged()
        }
    }
#else
    /// Haptic manager stub for non-iOS platforms
    class HapticManager {
        static let shared = HapticManager()
        private init() {}

        func light() {}
        func medium() {}
        func heavy() {}
        func success() {}
        func warning() {}
        func error() {}
        func selection() {}
    }
#endif
