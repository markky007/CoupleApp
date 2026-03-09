import SwiftUI

/// Reward shop view showing available rewards
/// Users can browse and redeem rewards using their earned points
struct RewardShopView: View {

    @StateObject private var viewModel = RewardViewModel()
    @StateObject private var onboardingManager = OnboardingManager.shared
    @State private var showCreateReward = false
    @State private var showApprovalQueue = false
    @State private var showTooltip = false

    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                AppTheme.backgroundGradient
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
            .navigationTitle("Reward Shop")
            .toolbar {
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
                    "Tap a reward to redeem it! Your partner must approve rewards before redemption.",
                isShowing: $showTooltip,
                onDismiss: {
                    onboardingManager.hasSeenRewardTooltip = true
                }
            )
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
                .fill(AppTheme.cardGradient)
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

            Text("No Rewards Available")
                .font(.title2)
                .fontWeight(.bold)

            Text(
                "Create rewards that you both can work towards! Rewards need partner approval before they can be redeemed."
            )
            .font(.body)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 32)

            Button {
                HapticManager.shared.medium()
                showCreateReward = true
            } label: {
                Label("Create Your First Reward", systemImage: "plus.circle.fill")
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
                    Text("Reward Ideas")
                        .font(.headline)
                }

                TipRow(icon: "fork.knife", text: "Dinner at favorite restaurant")
                TipRow(icon: "film", text: "Movie night of your choice")
                TipRow(icon: "gamecontroller", text: "Gaming session together")
                TipRow(icon: "bed.double", text: "Sleep in on weekend")
            }
            .padding()
            .cardStyle()
            .padding(.horizontal, 32)
            .padding(.top, 16)
        }
        .transition(.scale.combined(with: .opacity))
    }
}

#Preview {
    RewardShopView()
}
