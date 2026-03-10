import SwiftUI

/// Main content view that handles navigation based on authentication state
/// Shows LoginView for unauthenticated users, DashboardView for authenticated users
struct ContentView: View {

    @StateObject private var authService = AuthService.shared
    @StateObject private var onboardingManager = OnboardingManager.shared
    @EnvironmentObject var localizationManager: LocalizationManager
    @State private var showOnboarding = false

    var body: some View {
        Group {
            if authService.isAuthenticated {
                // Authenticated: Show main app
                DashboardView()
                    .sheet(isPresented: $showOnboarding) {
                        OnboardingView()
                    }
                    .onAppear {
                        // Show onboarding for first-time users
                        if onboardingManager.shouldShowOnboarding {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                showOnboarding = true
                            }
                        }
                    }
            } else {
                // Not authenticated: Show login
                LoginView()
            }
        }
        .animation(.easeInOut, value: authService.isAuthenticated)
        // Force view update when language changes
        .id(localizationManager.currentLanguage)
    }
}

#Preview("Authenticated") {
    ContentView()
}

#Preview("Not Authenticated") {
    ContentView()
}
