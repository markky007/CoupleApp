import SwiftUI

/// Quest board view showing all active quests
/// Users can view, create, and complete quests
struct QuestBoardView: View {

    @StateObject private var viewModel = QuestViewModel()
    @StateObject private var onboardingManager = OnboardingManager.shared
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

                if viewModel.isLoading && viewModel.quests.isEmpty {
                    QuestBoardSkeletonView()
                        .transition(.opacity)
                } else if viewModel.quests.isEmpty {
                    emptyStateView
                } else {
                    questListView
                }
            }
            .navigationTitle(localizationManager.localized("quest.title"))
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
                    localizationManager.localized("quest.swipe_instruction"),
                isShowing: $showTooltip,
                onDismiss: {
                    onboardingManager.hasSeenQuestTooltip = true
                }
            )
            // Force view update when language changes
            .id(localizationManager.currentLanguage)
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

            Text(localizationManager.localized("quest.empty.title"))
                .font(.title2)
                .fontWeight(.bold)

            Text(localizationManager.localized("quest.empty.description"))
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button {
                HapticManager.shared.medium()
                viewModel.showCreateSheet = true
            } label: {
                Label(
                    localizationManager.localized("quest.empty.button"),
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
                    Text(localizationManager.localized("quest.tips"))
                        .font(.headline)
                }

                TipRow(icon: "star.fill", text: localizationManager.localized("quest.tip.points"))
                TipRow(icon: "clock", text: localizationManager.localized("quest.tip.expiration"))
                TipRow(
                    icon: "person.2.fill", text: localizationManager.localized("quest.tip.partners")
                )
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

// MARK: - Quest Row View

struct QuestRowView: View {
    let quest: Quest
    @ObservedObject var viewModel: QuestViewModel
    @State private var showDeleteConfirmation = false
    @State private var offset: CGFloat = 0
    @State private var showSuccessAnimation = false
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var localizationManager: LocalizationManager
    @Environment(\.colorScheme) var systemColorScheme

    private let swipeThreshold: CGFloat = 100

    var body: some View {
        ZStack {
            // Background complete button (revealed on swipe)
            HStack {
                Spacer()

                Text(localizationManager.localized("quest.complete"))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)

                Spacer()
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
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(AppTheme.successGradient)
                        .shadow(color: AppTheme.shadowColor, radius: 4, x: 0, y: 2)
                }
                .disabled(viewModel.isLoading)
            }
        }
        .padding()
        .cardStyleReactive(
            theme: themeManager.currentTheme.rawValue, systemScheme: systemColorScheme
        )
        .contextMenu {
            Button(role: .destructive) {
                HapticManager.shared.light()
                showDeleteConfirmation = true
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .confirmationDialog(
            localizationManager.localized("quest.delete.confirm"),
            isPresented: $showDeleteConfirmation
        ) {
            Button(localizationManager.localized("button.cancel"), role: .cancel) {
                HapticManager.shared.light()
            }
            Button("Delete", role: .destructive) {
                HapticManager.shared.medium()
                Task {
                    await viewModel.deleteQuest(quest)
                }
            }
        } message: {
            Text(localizationManager.localized("quest.delete.confirm"))
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
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var localizationManager: LocalizationManager
    @Environment(\.colorScheme) var systemColorScheme

    @State private var title = ""
    @State private var points = 10
    @FocusState private var isTitleFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient (adaptive to theme)
                AppTheme.backgroundGradient(
                    for: themeManager.currentTheme.rawValue, systemScheme: systemColorScheme
                )
                .ignoresSafeArea()

                Form {
                    Section(localizationManager.localized("quest.details")) {
                        TextField(
                            localizationManager.localized("quest.title.placeholder"), text: $title
                        )
                        .focused($isTitleFocused)

                        Stepper(
                            localizationManager.localized("quest.points", points), value: $points,
                            in: 1...100, step: 5)
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
                                    Text(localizationManager.localized("quest.create"))
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
            .navigationTitle(localizationManager.localized("quest.create"))
            #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                #if os(iOS)
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(localizationManager.localized("button.cancel")) {
                            dismiss()
                        }
                    }
                #else
                    ToolbarItem(placement: .cancellationAction) {
                        Button(localizationManager.localized("button.cancel")) {
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

#Preview {
    QuestBoardView()
}
