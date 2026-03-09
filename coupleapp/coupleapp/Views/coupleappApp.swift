import SwiftUI

/// Main app entry point
@main
struct CoupleQuestApp: App {

    // Initialize services on app launch
    @StateObject private var authService = AuthService.shared
    @StateObject private var errorManager = ErrorManager.shared
    @StateObject private var networkMonitor = NetworkMonitor.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authService)
                .environmentObject(errorManager)
                .environmentObject(networkMonitor)
        }
    }
}
