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
            Image(systemName: "heart.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 50, height: 50)
                .foregroundStyle(.pink.gradient)

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
        .background(backgroundColor)
        .cornerRadius(12)
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
                        .foregroundColor(.pink)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(backgroundColor)
                .cornerRadius(12)

                // Partner points
                VStack(spacing: 8) {
                    Text("Partner Points")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text("0")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(.purple)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(backgroundColor)
                .cornerRadius(12)
            }
        }
    }

    private var quickActionsSection: some View {
        VStack(spacing: 16) {
            Text("Quick Actions")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                QuickActionButton(
                    icon: "list.bullet.clipboard",
                    title: "Quests",
                    color: .blue
                )

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
                .buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(backgroundColor)
            .cornerRadius(12)
        }
    }
}

// MARK: - Quick Action Button

struct QuickActionButton: View {
    let icon: String
    let title: String
    let color: Color

    // Helper for platform-specific background color
    private var backgroundColor: Color {
        #if os(iOS)
            return Color(.systemGray6)
        #else
            return Color(NSColor.controlBackgroundColor)
        #endif
    }

    var body: some View {
        Button {
            // TODO: Navigate to respective screen
        } label: {
            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 32))
                    .foregroundColor(color)

                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(backgroundColor)
            .cornerRadius(12)
        }
    }
}

#Preview {
    DashboardView()
}
