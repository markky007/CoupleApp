import SwiftUI

/// Quest board view showing all active quests
/// Users can view, create, and complete quests
struct QuestBoardView: View {

    @StateObject private var viewModel = QuestViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
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
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        viewModel.showCreateSheet = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                }
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
            Image(systemName: "list.bullet.clipboard")
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
                .foregroundStyle(.secondary)

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
            .buttonStyle(.borderedProminent)
            .tint(.pink)
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
                            .foregroundColor(.orange)

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
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.green)
                }
                .disabled(viewModel.isLoading)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
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
                    .listRowBackground(title.isEmpty ? Color.gray : Color.pink)
                    .foregroundColor(.white)
                }
            }
            .navigationTitle("New Quest")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
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
