import Supabase
import SwiftUI

/// Main dashboard view for authenticated users
/// Shows point balances, upcoming events, and quick access to features
struct DashboardView: View {

    @StateObject private var authService = AuthService.shared
    @StateObject private var viewModel = AuthViewModel()

    // Helper for platform-specific background color
    private var backgroundColor: Color {
        #if os(iOS)
            return Color(.systemGray6)
        #else
            return Color(NSColor.controlBackgroundColor)
        #endif
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                AppTheme.backgroundGradient
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Welcome section
                        welcomeSection

                        // Points section (placeholder)
                        pointsSection

                        // Quick actions (placeholder)
                        quickActionsSection

                        // Upcoming events (placeholder)
                        upcomingEventsSection
                    }
                    .padding()
                }
            }
            .navigationTitle("Dashboard")
            .toolbar {
                #if os(iOS)
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            Task {
                                await viewModel.signOut()
                            }
                        } label: {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .foregroundStyle(AppTheme.primaryGradient)
                        }
                    }
                #else
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            Task {
                                await viewModel.signOut()
                            }
                        } label: {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                        }
                    }
                #endif
            }
        }
    }

    // MARK: - View Components

    private var welcomeSection: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(AppTheme.primaryGradient)
                    .frame(width: 70, height: 70)
                    .shadow(color: AppTheme.shadowColor, radius: 8, x: 0, y: 4)

                Image(systemName: "heart.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 35, height: 35)
                    .foregroundStyle(.white)
            }

            Text("Welcome to Couple Quest!")
                .font(.title2)
                .fontWeight(.bold)

            if let userId = authService.currentUser?.id {
                Text("User ID: \(userId.uuidString.prefix(8))...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .cardStyle()
    }

    private var pointsSection: some View {
        VStack(spacing: 16) {
            Text("Points")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 16) {
                // Your points
                VStack(spacing: 8) {
                    Text("Your Points")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text("0")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.pointsGradient)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .cardStyle()

                // Partner points
                VStack(spacing: 8) {
                    Text("Partner Points")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text("0")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.partnerGradient)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .cardStyle()
            }
        }
    }

    private var quickActionsSection: some View {
        VStack(spacing: 16) {
            Text("Quick Actions")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                NavigationLink(destination: QuestBoardView()) {
                    QuickActionButtonContent(
                        icon: "list.bullet.clipboard",
                        title: "Quests",
                        color: .blue
                    )
                }
                .buttonStyle(.plain)

                QuickActionButton(
                    icon: "gift",
                    title: "Rewards",
                    color: .orange
                )

                QuickActionButton(
                    icon: "calendar",
                    title: "Events",
                    color: .green
                )

                QuickActionButton(
                    icon: "clock.arrow.circlepath",
                    title: "History",
                    color: .purple
                )
            }
        }
    }

    private var upcomingEventsSection: some View {
        VStack(spacing: 16) {
            Text("Upcoming Events")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 12) {
                Text("No upcoming events")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Button("Create Event") {
                    // TODO: Navigate to create event
                }
                .buttonStyle(GradientButtonStyle(gradient: AppTheme.secondaryGradient))
            }
            .frame(maxWidth: .infinity)
            .padding()
            .cardStyle()
        }
    }
}

// MARK: - Quick Action Button

struct QuickActionButtonContent: View {
    let icon: String
    let title: String
    let color: Color

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: 50, height: 50)

                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(color)
            }

            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .cardStyle()
    }
}

struct QuickActionButton: View {
    let icon: String
    let title: String
    let color: Color

    var body: some View {
        Button {
            // TODO: Navigate to respective screen
        } label: {
            QuickActionButtonContent(icon: icon, title: title, color: color)
        }
    }
}

#Preview {
    DashboardView()
}
