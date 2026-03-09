import SwiftUI

/// Main content view that handles navigation based on authentication state
/// Shows LoginView for unauthenticated users, DashboardView for authenticated users
struct ContentView: View {
    
    @StateObject private var authService = AuthService.shared
    
    var body: some View {
        Group {
            if authService.isAuthenticated {
                // Authenticated: Show main app
                DashboardView()
            } else {
                // Not authenticated: Show login
                LoginView()
            }
        }
        .animation(.easeInOut, value: authService.isAuthenticated)
    }
}

#Preview("Authenticated") {
    ContentView()
}

#Preview("Not Authenticated") {
    ContentView()
}

