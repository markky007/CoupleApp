import SwiftUI

/// Reward shop view showing available rewards
/// Users can browse and redeem rewards using their earned points
struct RewardShopView: View {

    @StateObject private var viewModel = RewardViewModel()
    @StateObject private var onboardingManager = OnboardingManager.shared
    @State private var showCreateReward = false
    @State private var showApprovalQueue = false
    @State private var showTooltip = false
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var localizationManager: LocalizationManager
    @Environment(\.colorScheme) var systemColorScheme

    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient (adaptive to theme)
                AppTheme.backgroundGradient(
                    for: themeManager.currentTheme.rawValue, systemScheme: systemColorScheme
                )
                .ignoresSafeArea()

                if viewModel.isLoading && viewModel.rewards.isEmpty {
                    RewardShopSkeletonView()
                        .transition(.opacity)
                } else if viewModel.rewards.isEmpty {
                    emptyStateView
                } else {
                    rewardListView
                }
            }
            .navigationTitle(localizationManager.localized("reward.title"))
            .toolbar {
                #if os(iOS)
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button {
                            showApprovalQueue = true
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "bell.badge.fill")
                                if !viewModel.pendingApprovals.isEmpty {
                                    Text("\(viewModel.pendingApprovals.count)")
                                        .font(.caption2)
                                        .fontWeight(.bold)
                                }
                            }
                            .foregroundStyle(AppTheme.secondaryGradient)
                        }
                    }
                #else
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            showApprovalQueue = true
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "bell.badge.fill")
                                if !viewModel.pendingApprovals.isEmpty {
                                    Text("\(viewModel.pendingApprovals.count)")
                                        .font(.caption2)
                                        .fontWeight(.bold)
                                }
                            }
                            .foregroundStyle(AppTheme.secondaryGradient)
                        }
                    }
                #endif

                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showCreateReward = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundStyle(AppTheme.primaryGradient)
                    }
                }
            }
            .sheet(isPresented: $showCreateReward) {
                CreateRewardView(viewModel: viewModel)
            }
            .sheet(isPresented: $showApprovalQueue) {
                NavigationStack {
                    ApprovalQueueView(viewModel: viewModel)
                }
            }
            .refreshable {
                await viewModel.fetchRewards()
                await viewModel.loadPendingApprovals()
            }
            .task {
                await viewModel.fetchRewards()
                await viewModel.loadPendingApprovals()

                // Show tooltip for first-time users
                if !onboardingManager.hasSeenRewardTooltip && !viewModel.rewards.isEmpty {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        showTooltip = true
                    }
                }
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK") {
                    viewModel.dismissError()
                }
            } message: {
                Text(viewModel.errorMessage ?? "An error occurred")
            }
            .confirmationDialog(
                "Redeem Reward",
                isPresented: $viewModel.showRedemptionConfirmation,
                presenting: viewModel.selectedReward
            ) { reward in
                Button("Redeem for \(reward.pointsCost) points") {
                    HapticManager.shared.medium()
                    Task {
                        await viewModel.redeemSelectedReward()
                    }
                }
                Button("Cancel", role: .cancel) {
                    HapticManager.shared.light()
                }
            } message: { reward in
                Text(
                    "Are you sure you want to redeem '\(reward.title)' for \(reward.pointsCost) points?"
                )
            }
            .overlay(
                Group {
                    if viewModel.showSuccessAnimation,
                        let title = viewModel.successAnimationTitle,
                        let message = viewModel.successAnimationMessage
                    {
                        SuccessAnimationView(
                            title: title,
                            message: message,
                            onDismiss: {
                                viewModel.showSuccessAnimation = false
                            }
                        )
                    }
                }
            )
            .tooltip(
                message:
                    localizationManager.localized("reward.instruction"),
                isShowing: $showTooltip,
                onDismiss: {
                    onboardingManager.hasSeenRewardTooltip = true
                }
            )
            // Force view update when language changes
            .id(localizationManager.currentLanguage)
        }
    }

    // MARK: - View Components

    private var rewardListView: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Point balance card
                pointBalanceCard

                // Reward list
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.rewards) { reward in
                        RewardRowView(reward: reward, viewModel: viewModel)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .animation(AppTheme.springAnimation, value: viewModel.rewards.count)
            }
            .padding()
        }
    }

    private var pointBalanceCard: some View {
        VStack(spacing: 8) {
            Text("Your Points")
                .font(.subheadline)
                .foregroundColor(.secondary)

            HStack(spacing: 8) {
                Image(systemName: "star.fill")
                    .font(.title2)
                Text("\(viewModel.userPoints)")
                    .font(.system(size: 36, weight: .bold))
            }
            .foregroundStyle(AppTheme.pointsGradient)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge)
                .fill(
                    AppTheme.cardGradient(
                        for: themeManager.currentTheme.rawValue, systemScheme: systemColorScheme)
                )
                .shadow(
                    color: AppTheme.shadowColor,
                    radius: AppTheme.shadowRadius,
                    x: AppTheme.shadowOffset.width,
                    y: AppTheme.shadowOffset.height
                )
        )
    }

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(AppTheme.secondaryGradient)
                    .frame(width: 120, height: 120)
                    .shadow(color: AppTheme.shadowColor, radius: 10, x: 0, y: 5)

                Image(systemName: "gift")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 60, height: 60)
                    .foregroundStyle(.white)
            }

            Text(localizationManager.localized("reward.empty.title"))
                .font(.title2)
                .fontWeight(.bold)

            Text(localizationManager.localized("reward.empty.description"))
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button {
                HapticManager.shared.medium()
                showCreateReward = true
            } label: {
                Label(
                    localizationManager.localized("reward.empty.button"),
                    systemImage: "plus.circle.fill"
                )
                .fontWeight(.semibold)
            }
            .buttonStyle(GradientButtonStyle(gradient: AppTheme.primaryGradient))
            .padding(.horizontal, 32)
            .padding(.top, 8)

            // Tips section
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundColor(.yellow)
                    Text(localizationManager.localized("reward.ideas"))
                        .font(.headline)
                }

                TipRow(
                    icon: "fork.knife", text: localizationManager.localized("reward.idea.dinner"))
                TipRow(icon: "film", text: localizationManager.localized("reward.idea.movie"))
                TipRow(
                    icon: "gamecontroller",
                    text: localizationManager.localized("reward.idea.gaming"))
                TipRow(icon: "bed.double", text: localizationManager.localized("reward.idea.sleep"))
            }
            .padding()
            .cardStyleReactive(
                theme: themeManager.currentTheme.rawValue, systemScheme: systemColorScheme
            )
            .padding(.horizontal, 32)
            .padding(.top, 16)
        }
        .transition(.scale.combined(with: .opacity))
    }
}

#Preview {
    RewardShopView()
}
