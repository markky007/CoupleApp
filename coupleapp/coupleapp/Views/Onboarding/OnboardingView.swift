import SwiftUI

/// Onboarding view for first-time users
/// Explains key features and how to use the app
struct OnboardingView: View {

    @StateObject private var onboardingManager = OnboardingManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var currentPage = 0

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "heart.fill",
            title: "Welcome to Couple Quest",
            description: "Turn everyday tasks into adventures and earn rewards together!",
            color: .pink
        ),
        OnboardingPage(
            icon: "list.bullet.clipboard",
            title: "Complete Quests",
            description: "Create daily tasks and chores. Complete them to earn points!",
            color: .blue
        ),
        OnboardingPage(
            icon: "gift.fill",
            title: "Redeem Rewards",
            description: "Use your points to redeem exciting rewards you both agree on.",
            color: .orange
        ),
        OnboardingPage(
            icon: "calendar.badge.clock",
            title: "Track Events",
            description: "Never forget special dates! Track anniversaries and important events.",
            color: .green
        ),
        OnboardingPage(
            icon: "person.2.fill",
            title: "Pair with Partner",
            description:
                "Connect with your partner to share quests, rewards, and celebrate together!",
            color: .purple
        ),
    ]

    var body: some View {
        ZStack {
            // Background gradient
            AppTheme.backgroundGradient
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Skip button
                HStack {
                    Spacer()
                    Button("Skip") {
                        completeOnboarding()
                    }
                    .foregroundColor(.secondary)
                    .padding()
                }

                // Page content
                TabView(selection: $currentPage) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        OnboardingPageView(page: pages[index])
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .always))

                // Navigation buttons
                HStack(spacing: 16) {
                    if currentPage > 0 {
                        Button {
                            withAnimation {
                                currentPage -= 1
                            }
                        } label: {
                            Text("Back")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(SecondaryButtonStyle())
                    }

                    Button {
                        if currentPage < pages.count - 1 {
                            withAnimation {
                                currentPage += 1
                            }
                        } else {
                            completeOnboarding()
                        }
                    } label: {
                        Text(currentPage < pages.count - 1 ? "Next" : "Get Started")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(GradientButtonStyle(gradient: AppTheme.primaryGradient))
                }
                .padding()
            }
        }
    }

    private func completeOnboarding() {
        HapticManager.shared.success()
        onboardingManager.completeOnboarding()
        dismiss()
    }
}

// MARK: - Onboarding Page Model

struct OnboardingPage {
    let icon: String
    let title: String
    let description: String
    let color: Color
}

// MARK: - Onboarding Page View

struct OnboardingPageView: View {
    let page: OnboardingPage

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [page.color.opacity(0.8), page.color],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)
                    .shadow(color: page.color.opacity(0.3), radius: 20, x: 0, y: 10)

                Image(systemName: page.icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 60, height: 60)
                    .foregroundStyle(.white)
            }

            // Title
            Text(page.title)
                .font(.system(size: 28, weight: .bold))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            // Description
            Text(page.description)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 48)

            Spacer()
        }
    }
}

// MARK: - Secondary Button Style

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding()
            .background(Color.secondary.opacity(0.2))
            .foregroundColor(.primary)
            .cornerRadius(AppTheme.cornerRadiusMedium)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(AppTheme.springAnimation, value: configuration.isPressed)
    }
}

#Preview {
    OnboardingView()
}
