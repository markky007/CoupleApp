import Supabase
import SwiftUI

/// Main dashboard view for authenticated users
/// Shows point balances, upcoming events, recent quests, and quick access to features
struct DashboardView: View {

    @StateObject private var authService = AuthService.shared
    @StateObject private var authViewModel = AuthViewModel()
    @StateObject private var viewModel = DashboardViewModel()
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.colorScheme) var systemColorScheme

    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient (adaptive to theme)
                AppTheme.backgroundGradient(
                    for: themeManager.currentTheme.rawValue, systemScheme: systemColorScheme
                )
                .ignoresSafeArea()

                if viewModel.isLoading {
                    DashboardSkeletonView()
                        .transition(.opacity)
                } else {
                    ScrollView {
                        VStack(spacing: 24) {
                            // Welcome section
                            welcomeSection

                            // Points section
                            pointsSection

                            // Upcoming event countdown
                            if viewModel.upcomingEvent != nil {
                                upcomingEventSection
                            }

                            // Recent quests
                            if !viewModel.recentQuests.isEmpty {
                                recentQuestsSection
                            }

                            // Rewards preview
                            if !viewModel.rewardsPreview.isEmpty {
                                rewardsPreviewSection
                            }

                            // Quick actions
                            quickActionsSection
                        }
                        .padding()
                    }
                    .refreshable {
                        await viewModel.refresh()
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }
            }
            .navigationTitle("Dashboard")
            .toolbar {
                #if os(iOS)
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            Task {
                                await authViewModel.signOut()
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
                                await authViewModel.signOut()
                            }
                        } label: {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                        }
                    }
                #endif
            }
            .task {
                await viewModel.loadDashboardData()
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK") {
                    viewModel.dismissError()
                }
            } message: {
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                }
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

            Text("Welcome, \(viewModel.userName)!")
                .font(.title2)
                .fontWeight(.bold)

            if viewModel.partnerProfile != nil {
                Text("Paired with \(viewModel.partnerName)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                Text("Not paired yet")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .cardStyleReactive(
            theme: themeManager.currentTheme.rawValue, systemScheme: systemColorScheme
        )
        .transition(.scale.combined(with: .opacity))
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

                    Text("\(viewModel.userPoints)")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.pointsGradient)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .cardStyleReactive(
                    theme: themeManager.currentTheme.rawValue, systemScheme: systemColorScheme)

                // Partner points
                VStack(spacing: 8) {
                    Text("Partner Points")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text("\(viewModel.partnerPoints)")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.partnerGradient)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .cardStyleReactive(
                    theme: themeManager.currentTheme.rawValue, systemScheme: systemColorScheme)
            }
        }
    }

    private var upcomingEventSection: some View {
        VStack(spacing: 16) {
            Text("Upcoming Event")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let event = viewModel.upcomingEvent, let daysUntil = viewModel.daysUntilEvent {
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: "calendar")
                            .font(.title2)
                            .foregroundStyle(AppTheme.secondaryGradient)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(event.title)
                                .font(.headline)

                            if daysUntil == 0 {
                                Text("Today!")
                                    .font(.subheadline)
                                    .foregroundColor(.green)
                            } else if daysUntil == 1 {
                                Text("Tomorrow")
                                    .font(.subheadline)
                                    .foregroundColor(.orange)
                            } else {
                                Text("\(daysUntil) days away")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }

                        Spacer()

                        // Countdown badge
                        ZStack {
                            Circle()
                                .fill(AppTheme.secondaryGradient)
                                .frame(width: 60, height: 60)

                            VStack(spacing: 2) {
                                Text("\(daysUntil)")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.white)
                                Text("days")
                                    .font(.caption2)
                                    .foregroundColor(.white)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .cardStyleReactive(
                    theme: themeManager.currentTheme.rawValue, systemScheme: systemColorScheme)
            }
        }
    }

    private var recentQuestsSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Recent Quests")
                    .font(.headline)

                Spacer()

                NavigationLink(destination: QuestBoardView()) {
                    Text("View All")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.primaryGradient)
                }
            }

            VStack(spacing: 12) {
                ForEach(viewModel.recentQuests) { quest in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(quest.title)
                                .font(.subheadline)
                                .fontWeight(.medium)

                            Text("\(quest.points) points")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Image(systemName: "checkmark.circle")
                            .foregroundStyle(AppTheme.successGradient)
                    }
                    .padding(.vertical, 8)

                    if quest.id != viewModel.recentQuests.last?.id {
                        Divider()
                    }
                }
            }
            .padding()
            .cardStyleReactive(
                theme: themeManager.currentTheme.rawValue, systemScheme: systemColorScheme)
        }
    }

    private var rewardsPreviewSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Available Rewards")
                    .font(.headline)

                Spacer()

                NavigationLink(destination: RewardShopView()) {
                    Text("View All")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.primaryGradient)
                }
            }

            VStack(spacing: 12) {
                ForEach(viewModel.rewardsPreview) { reward in
                    HStack {
                        Image(systemName: "gift.fill")
                            .foregroundStyle(AppTheme.warningGradient)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(reward.title)
                                .font(.subheadline)
                                .fontWeight(.medium)

                            Text("\(reward.pointsCost) points")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 8)

                    if reward.id != viewModel.rewardsPreview.last?.id {
                        Divider()
                    }
                }
            }
            .padding()
            .cardStyleReactive(
                theme: themeManager.currentTheme.rawValue, systemScheme: systemColorScheme)
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
                .onTapGesture {
                    HapticManager.shared.light()
                }

                NavigationLink(destination: RewardShopView()) {
                    QuickActionButtonContent(
                        icon: "gift",
                        title: "Rewards",
                        color: .orange
                    )
                }
                .buttonStyle(.plain)
                .onTapGesture {
                    HapticManager.shared.light()
                }

                NavigationLink(destination: EventListView()) {
                    QuickActionButtonContent(
                        icon: "calendar",
                        title: "Events",
                        color: .green
                    )
                }
                .buttonStyle(.plain)
                .onTapGesture {
                    HapticManager.shared.light()
                }

                NavigationLink(destination: TransactionHistoryView()) {
                    QuickActionButtonContent(
                        icon: "clock.arrow.circlepath",
                        title: "History",
                        color: .purple
                    )
                }
                .buttonStyle(.plain)
                .onTapGesture {
                    HapticManager.shared.light()
                }

                NavigationLink(destination: ProfileView()) {
                    QuickActionButtonContent(
                        icon: "person.circle",
                        title: "Profile",
                        color: .pink
                    )
                }
                .buttonStyle(.plain)
                .onTapGesture {
                    HapticManager.shared.light()
                }
            }
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

#Preview {
    DashboardView()
}
