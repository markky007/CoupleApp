import SwiftUI

/// Main app entry point
@main
struct CoupleQuestApp: App {

    // Initialize services on app launch
    @StateObject private var authService = AuthService.shared
    @StateObject private var errorManager = ErrorManager.shared
    @StateObject private var networkMonitor = NetworkMonitor.shared
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var localizationManager = LocalizationManager.shared

    var body: some Scene {
        WindowGroup {
            ThemeAwareContentView(
                themeManager: themeManager,
                authService: authService,
                errorManager: errorManager,
                networkMonitor: networkMonitor,
                localizationManager: localizationManager
            )
        }
    }
}

/// Wrapper view that applies theme and passes environment objects
struct ThemeAwareContentView: View {
    @StateObject var themeManager: ThemeManager
    let authService: AuthService
    let errorManager: ErrorManager
    let networkMonitor: NetworkMonitor
    let localizationManager: LocalizationManager

    var body: some View {
        ContentView()
            .environmentObject(authService)
            .environmentObject(errorManager)
            .environmentObject(networkMonitor)
            .environmentObject(themeManager)
            .environmentObject(localizationManager)
            .preferredColorScheme(themeManager.currentTheme.colorScheme)
    }
}
