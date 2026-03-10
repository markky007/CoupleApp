import SwiftUI

/// View for displaying pending reward approvals
/// Partners can approve or reject custom reward proposals
struct ApprovalQueueView: View {

    @ObservedObject var viewModel: RewardViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.colorScheme) var systemColorScheme

    var body: some View {
        ZStack {
            // Background gradient (adaptive to theme)
            AppTheme.backgroundGradient(
                for: themeManager.currentTheme.rawValue, systemScheme: systemColorScheme
            )
            .ignoresSafeArea()

            if viewModel.isLoading && viewModel.pendingApprovals.isEmpty {
                ProgressView("Loading approvals...")
            } else if viewModel.pendingApprovals.isEmpty {
                emptyStateView
            } else {
                approvalListView
            }
        }
        .navigationTitle("Pending Approvals")
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
        .refreshable {
            await viewModel.loadPendingApprovals()
        }
        .task {
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
            Text(viewModel.successMessage ?? "")
        }
    }

    // MARK: - View Components

    private var approvalListView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(viewModel.pendingApprovals) { reward in
                    ApprovalRowView(reward: reward, viewModel: viewModel)
                }
            }
            .padding()
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(AppTheme.successGradient)
                    .frame(width: 100, height: 100)
                    .shadow(color: AppTheme.shadowColor, radius: 10, x: 0, y: 5)

                Image(systemName: "checkmark.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 50, height: 50)
                    .foregroundStyle(.white)
            }

            Text("No Pending Approvals")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Your partner hasn't created any rewards that need your approval")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }
}

/// Individual approval row component
struct ApprovalRowView: View {
    let reward: Reward
    @ObservedObject var viewModel: RewardViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Reward info
            VStack(alignment: .leading, spacing: 8) {
                Text(reward.title)
                    .font(.headline)
                    .foregroundColor(.primary)

                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.caption)
                    Text("\(reward.pointsCost) points")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .foregroundStyle(AppTheme.pointsGradient)

                if let createdAt = reward.createdAt {
                    Text("Created \(createdAt, style: .relative) ago")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Action buttons
            HStack(spacing: 12) {
                // Reject button
                Button {
                    Task {
                        await viewModel.rejectReward(reward)
                    }
                } label: {
                    HStack {
                        Image(systemName: "xmark.circle.fill")
                        Text("Reject")
                    }
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(
                            colors: [Color.red.opacity(0.8), Color.red],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(AppTheme.cornerRadiusMedium)
                }
                .disabled(viewModel.isLoading)

                // Approve button
                Button {
                    Task {
                        await viewModel.approveReward(reward)
                    }
                } label: {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Approve")
                    }
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(AppTheme.successGradient)
                    .cornerRadius(AppTheme.cornerRadiusMedium)
                }
                .disabled(viewModel.isLoading)
            }
        }
        .padding()
        .cardStyle()
    }
}

#Preview {
    NavigationStack {
        ApprovalQueueView(viewModel: RewardViewModel())
    }
}
