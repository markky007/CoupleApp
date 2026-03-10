import SwiftUI

/// Individual reward card component
/// Displays reward information and redeem button
struct RewardRowView: View {
    let reward: Reward
    @ObservedObject var viewModel: RewardViewModel
    @State private var isPressed = false
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var localizationManager: LocalizationManager
    @Environment(\.colorScheme) var systemColorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(reward.title)
                            .font(.headline)
                            .foregroundColor(.primary)

                        // Badge to distinguish reward type
                        if reward.isSystemReward {
                            Text("SYSTEM")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule()
                                        .fill(AppTheme.secondaryGradient)
                                )
                        } else {
                            Text("CUSTOM")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule()
                                        .fill(AppTheme.partnerGradient)
                                )
                        }
                    }

                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.caption)
                        Text("\(reward.pointsCost) points")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .foregroundStyle(AppTheme.pointsGradient)
                }

                Spacer()

                Button {
                    HapticManager.shared.medium()
                    withAnimation(AppTheme.springAnimation) {
                        isPressed = true
                    }

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation(AppTheme.springAnimation) {
                            isPressed = false
                        }
                        viewModel.confirmRedemption(for: reward)
                    }
                } label: {
                    Text(localizationManager.localized("reward.redeem", reward.pointsCost))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(
                            viewModel.canAfford(reward)
                                ? AppTheme.primaryGradient
                                : LinearGradient(
                                    colors: [Color.gray],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                        )
                        .cornerRadius(AppTheme.cornerRadiusMedium)
                        .shadow(
                            color: AppTheme.shadowColor,
                            radius: isPressed ? 2 : 4,
                            x: 0,
                            y: isPressed ? 1 : 2
                        )
                        .scaleEffect(isPressed ? 0.95 : 1.0)
                }
                .disabled(!viewModel.canAfford(reward) || viewModel.isLoading)
            }
        }
        .padding()
        .cardStyleReactive(
            theme: themeManager.currentTheme.rawValue, systemScheme: systemColorScheme)
    }
}
