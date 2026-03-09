import SwiftUI

/// Quest board view showing all active quests
/// Users can view, create, and complete quests
struct QuestBoardView: View {

    @StateObject private var viewModel = QuestViewModel()
    @StateObject private var onboardingManager = OnboardingManager.shared
    @State private var showTooltip = false

    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                AppTheme.backgroundGradient
                    .ignoresSafeArea()

                if viewModel.isLoading && viewModel.quests.isEmpty {
                    QuestBoardSkeletonView()
                        .transition(.opacity)
                } else if viewModel.quests.isEmpty {
                    emptyStateView
                } else {
                    questListView
                }
            }
            .navigationTitle("Quest Board")
            .toolbar {
                #if os(iOS)
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            viewModel.showCreateSheet = true
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(AppTheme.primaryGradient)
                        }
                    }
                #else
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            viewModel.showCreateSheet = true
                        } label: {
                            Image(systemName: "plus.circle.fill")
                        }
                    }
                #endif
            }
            .sheet(isPresented: $viewModel.showCreateSheet) {
                CreateQuestView(viewModel: viewModel)
            }
            .refreshable {
                await viewModel.fetchQuests()
            }
            .task {
                await viewModel.fetchQuests()

                // Show tooltip for first-time users
                if !onboardingManager.hasSeenQuestTooltip && !viewModel.quests.isEmpty {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        showTooltip = true
                    }
                }
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
                    "Swipe left on a quest or tap the checkmark to complete it and earn points!",
                isShowing: $showTooltip,
                onDismiss: {
                    onboardingManager.hasSeenQuestTooltip = true
                }
            )
        }
    }

    // MARK: - View Components

    private var questListView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(viewModel.quests) { quest in
                    QuestRowView(quest: quest, viewModel: viewModel)
                        .transition(
                            .asymmetric(
                                insertion: .scale.combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            ))
                }
            }
            .padding()
            .animation(AppTheme.springAnimation, value: viewModel.quests.count)
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(AppTheme.secondaryGradient)
                    .frame(width: 120, height: 120)
                    .shadow(color: AppTheme.shadowColor, radius: 10, x: 0, y: 5)

                Image(systemName: "list.bullet.clipboard")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 60, height: 60)
                    .foregroundStyle(.white)
            }

            Text("No Active Quests")
                .font(.title2)
                .fontWeight(.bold)

            Text(
                "Create your first quest to start earning points together! Quests can be daily chores, special tasks, or anything you want to accomplish."
            )
            .font(.body)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 32)

            Button {
                HapticManager.shared.medium()
                viewModel.showCreateSheet = true
            } label: {
                Label("Create Your First Quest", systemImage: "plus.circle.fill")
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
                    Text("Tips")
                        .font(.headline)
                }

                TipRow(icon: "star.fill", text: "Assign points based on task difficulty")
                TipRow(icon: "clock", text: "Set expiration dates for time-sensitive tasks")
                TipRow(icon: "person.2.fill", text: "Both partners can complete quests")
            }
            .padding()
            .cardStyle()
            .padding(.horizontal, 32)
            .padding(.top, 16)
        }
        .transition(.scale.combined(with: .opacity))
    }
}

// MARK: - Quest Row View

struct QuestRowView: View {
    let quest: Quest
    @ObservedObject var viewModel: QuestViewModel
    @State private var showDeleteConfirmation = false
    @State private var offset: CGFloat = 0
    @State private var showSuccessAnimation = false

    private let swipeThreshold: CGFloat = 100

    var body: some View {
        ZStack {
            // Background complete button (revealed on swipe)
            HStack {
                Spacer()

                VStack {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title)
                        .foregroundColor(.white)
                    Text("Complete")
                        .font(.caption)
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 30)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppTheme.successGradient)
            .cornerRadius(AppTheme.cornerRadiusMedium)

            // Main quest card
            questCard
                .offset(x: offset)
                .gesture(
                    DragGesture()
                        .onChanged { gesture in
                            // Only allow left swipe
                            if gesture.translation.width < 0 {
                                offset = gesture.translation.width
                            }
                        }
                        .onEnded { gesture in
                            if gesture.translation.width < -swipeThreshold {
                                // Complete quest
                                completeQuestWithAnimation()
                            } else {
                                // Snap back
                                withAnimation(AppTheme.springAnimation) {
                                    offset = 0
                                }
                            }
                        }
                )
        }
        .overlay(
            Group {
                if showSuccessAnimation {
                    SimpleSuccessView()
                }
            }
        )
    }

    private var questCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(quest.title)
                        .font(.headline)
                        .foregroundColor(.primary)

                    HStack(spacing: 8) {
                        Label("\(quest.points) pts", systemImage: "star.fill")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.pointsGradient)

                        if let expireAt = quest.expireAt {
                            Label(
                                expireAt.formatted(date: .abbreviated, time: .omitted),
                                systemImage: "clock"
                            )
                            .font(.caption)
                            .foregroundColor(.secondary)
                        }
                    }
                }

                Spacer()

                Button {
                    HapticManager.shared.light()
                    completeQuestWithAnimation()
                } label: {
                    ZStack {
                        Circle()
                            .fill(AppTheme.successGradient)
                            .frame(width: 44, height: 44)
                            .shadow(color: AppTheme.shadowColor, radius: 4, x: 0, y: 2)

                        Image(systemName: "checkmark")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }
                }
                .disabled(viewModel.isLoading)
            }
        }
        .padding()
        .cardStyle()
        .contextMenu {
            Button(role: .destructive) {
                HapticManager.shared.light()
                showDeleteConfirmation = true
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .confirmationDialog("Delete Quest", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                HapticManager.shared.medium()
                Task {
                    await viewModel.deleteQuest(quest)
                }
            }
            Button("Cancel", role: .cancel) {
                HapticManager.shared.light()
            }
        } message: {
            Text("Are you sure you want to delete this quest?")
        }
    }

    private func completeQuestWithAnimation() {
        // Show success animation
        showSuccessAnimation = true

        // Complete quest after brief delay
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000)  // 0.5 seconds
            await viewModel.completeQuest(quest)
            showSuccessAnimation = false
        }
    }
}

// MARK: - Create Quest View

struct CreateQuestView: View {
    @ObservedObject var viewModel: QuestViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var points = 10
    @FocusState private var isTitleFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                AppTheme.backgroundGradient
                    .ignoresSafeArea()

                Form {
                    Section("Quest Details") {
                        TextField("Quest title", text: $title)
                            .focused($isTitleFocused)

                        Stepper("Points: \(points)", value: $points, in: 1...100, step: 5)
                    }

                    Section {
                        Button {
                            HapticManager.shared.medium()
                            Task {
                                await viewModel.createQuest(title: title, points: points)
                            }
                        } label: {
                            HStack {
                                Spacer()
                                if viewModel.isLoading {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Text("Create Quest")
                                        .fontWeight(.semibold)
                                }
                                Spacer()
                            }
                        }
                        .disabled(title.isEmpty || viewModel.isLoading)
                        .listRowBackground(
                            Group {
                                if title.isEmpty {
                                    Color.gray
                                } else {
                                    AppTheme.primaryGradient
                                }
                            }
                        )
                        .foregroundColor(.white)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("New Quest")
            #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                #if os(iOS)
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") {
                            dismiss()
                        }
                    }
                #else
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            dismiss()
                        }
                    }
                #endif
            }
            .onAppear {
                isTitleFocused = true
            }
        }
    }
}

// MARK: - Tip Row Component

struct TipRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(AppTheme.primaryGradient)
                .frame(width: 20)

            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer()
        }
    }
}

#Preview {
    QuestBoardView()
}
