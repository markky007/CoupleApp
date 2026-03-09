import SwiftUI

/// Quest board view showing all active quests
/// Users can view, create, and complete quests
struct QuestBoardView: View {

    @StateObject private var viewModel = QuestViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                AppTheme.backgroundGradient
                    .ignoresSafeArea()

                if viewModel.isLoading && viewModel.quests.isEmpty {
                    ProgressView("Loading quests...")
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
                Text(viewModel.successMessage ?? "Operation successful")
            }
        }
    }

    // MARK: - View Components

    private var questListView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(viewModel.quests) { quest in
                    QuestRowView(quest: quest, viewModel: viewModel)
                }
            }
            .padding()
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(AppTheme.secondaryGradient)
                    .frame(width: 100, height: 100)
                    .shadow(color: AppTheme.shadowColor, radius: 10, x: 0, y: 5)

                Image(systemName: "list.bullet.clipboard")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 50, height: 50)
                    .foregroundStyle(.white)
            }

            Text("No Active Quests")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Create your first quest to start earning points together!")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button {
                viewModel.showCreateSheet = true
            } label: {
                Label("Create Quest", systemImage: "plus.circle.fill")
                    .fontWeight(.semibold)
            }
            .buttonStyle(GradientButtonStyle(gradient: AppTheme.primaryGradient))
            .padding(.horizontal, 32)
        }
    }
}

// MARK: - Quest Row View

struct QuestRowView: View {
    let quest: Quest
    @ObservedObject var viewModel: QuestViewModel
    @State private var showDeleteConfirmation = false

    var body: some View {
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
                    Task {
                        await viewModel.completeQuest(quest)
                    }
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
                showDeleteConfirmation = true
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .confirmationDialog("Delete Quest", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                Task {
                    await viewModel.deleteQuest(quest)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete this quest?")
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

#Preview {
    QuestBoardView()
}
