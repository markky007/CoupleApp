import SwiftUI

/// Skeleton loading view for content placeholders
/// Provides animated shimmer effect while content loads
struct SkeletonView: View {
    @State private var isAnimating = false

    let width: CGFloat?
    let height: CGFloat
    let cornerRadius: CGFloat

    init(
        width: CGFloat? = nil,
        height: CGFloat = 20,
        cornerRadius: CGFloat = AppTheme.cornerRadiusSmall
    ) {
        self.width = width
        self.height = height
        self.cornerRadius = cornerRadius
    }

    var body: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [
                        Color.gray.opacity(0.3),
                        Color.gray.opacity(0.15),
                        Color.gray.opacity(0.3),
                    ],
                    startPoint: isAnimating ? .leading : .trailing,
                    endPoint: isAnimating ? .trailing : .leading
                )
            )
            .frame(width: width, height: height)
            .cornerRadius(cornerRadius)
            .onAppear {
                withAnimation(
                    .easeInOut(duration: 1.5)
                        .repeatForever(autoreverses: false)
                ) {
                    isAnimating = true
                }
            }
    }
}

/// Skeleton card for dashboard and list items
struct SkeletonCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SkeletonView(width: 150, height: 20)
                Spacer()
                SkeletonView(width: 60, height: 20)
            }

            SkeletonView(width: 100, height: 16)

            HStack {
                SkeletonView(width: 80, height: 14)
                Spacer()
            }
        }
        .padding()
        .cardStyle()
    }
}

/// Skeleton loading for dashboard
struct DashboardSkeletonView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Welcome section skeleton
                VStack(spacing: 8) {
                    SkeletonView(width: 70, height: 70, cornerRadius: 35)
                    SkeletonView(width: 200, height: 24)
                    SkeletonView(width: 150, height: 16)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .cardStyle()

                // Points section skeleton
                HStack(spacing: 16) {
                    VStack(spacing: 8) {
                        SkeletonView(width: 100, height: 16)
                        SkeletonView(width: 80, height: 36)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .cardStyle()

                    VStack(spacing: 8) {
                        SkeletonView(width: 100, height: 16)
                        SkeletonView(width: 80, height: 36)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .cardStyle()
                }

                // Recent items skeleton
                VStack(spacing: 12) {
                    ForEach(0..<3, id: \.self) { _ in
                        SkeletonCard()
                    }
                }
            }
            .padding()
        }
    }
}

/// Skeleton loading for quest board
struct QuestBoardSkeletonView: View {
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(0..<5, id: \.self) { _ in
                    SkeletonCard()
                }
            }
            .padding()
        }
    }
}

/// Skeleton loading for reward shop
struct RewardShopSkeletonView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Point balance skeleton
                VStack(spacing: 8) {
                    SkeletonView(width: 100, height: 16)
                    SkeletonView(width: 120, height: 36)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .cardStyle()

                // Reward items skeleton
                LazyVStack(spacing: 12) {
                    ForEach(0..<4, id: \.self) { _ in
                        SkeletonCard()
                    }
                }
            }
            .padding()
        }
    }
}

#Preview("Skeleton View") {
    VStack(spacing: 20) {
        SkeletonView(width: 200, height: 20)
        SkeletonView(width: 150, height: 16)
        SkeletonView(width: 100, height: 14)
    }
    .padding()
}

#Preview("Skeleton Card") {
    SkeletonCard()
        .padding()
}

#Preview("Dashboard Skeleton") {
    ZStack {
        AppTheme.backgroundGradient
            .ignoresSafeArea()
        DashboardSkeletonView()
    }
}
