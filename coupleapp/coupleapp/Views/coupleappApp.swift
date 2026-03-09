import SwiftUI

/// Main app entry point
@main
struct CoupleQuestApp: App {
    
    // Initialize auth service on app launch
    @StateObject private var authService = AuthService.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authService)
        }
    }
}
