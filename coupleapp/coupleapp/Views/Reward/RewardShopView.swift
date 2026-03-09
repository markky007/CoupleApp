import SwiftUI

/// Reward shop view showing available rewards
/// Users can browse and redeem rewards using their earned points
struct RewardShopView: View {

    @StateObject private var viewModel = RewardViewModel()
    @State private var showCreateReward = false
    @State private var showApprovalQueue = false

    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                AppTheme.backgroundGradient
                    .ignoresSafeArea()

                if viewModel.isLoading && viewModel.rewards.isEmpty {
                    ProgressView("Loading rewards...")
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
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK") {
                    viewModel.dismissError()
                }
            } message: {
                Text(viewModel.errorMessage ?? "An error occurred")
            }
            .alert("Success", isPresented: $viewModel.showSuccess) {
                Button("OK") {
                    viewModel.dismissSuccess()
                }
            } message: {
                Text(viewModel.successMessage ?? "Reward redeemed successfully!")
            }
            .confirmationDialog(
                "Redeem Reward",
                isPresented: $viewModel.showRedemptionConfirmation,
                presenting: viewModel.selectedReward
            ) { reward in
                Button("Redeem for \(reward.pointsCost) points") {
                    Task {
                        await viewModel.redeemSelectedReward()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: { reward in
                Text(
                    "Are you sure you want to redeem '\(reward.title)' for \(reward.pointsCost) points?"
                )
            }
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
                    }
                }
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
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(AppTheme.secondaryGradient)
                    .frame(width: 100, height: 100)
                    .shadow(color: AppTheme.shadowColor, radius: 10, x: 0, y: 5)

                Image(systemName: "gift")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 50, height: 50)
                    .foregroundStyle(.white)
            }

            Text("No Rewards Available")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Check back later for exciting rewards to redeem!")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }
}

#Preview {
    RewardShopView()
}
