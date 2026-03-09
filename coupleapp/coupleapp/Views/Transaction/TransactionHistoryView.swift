import SwiftUI

/// Transaction history view showing point transaction history
/// Users can view and filter their transaction history (earn/redeem)
struct TransactionHistoryView: View {

    @StateObject private var viewModel = TransactionViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                AppTheme.backgroundGradient
                    .ignoresSafeArea()

                if viewModel.isLoading && viewModel.transactions.isEmpty {
                    ProgressView("Loading transactions...")
                } else if viewModel.filteredTransactions.isEmpty {
                    emptyStateView
                } else {
                    transactionListView
                }
            }
            .navigationTitle("Transaction History")
            .toolbar {
                ToolbarItem(placement: .principal) {
                    filterPicker
                }
            }
            .refreshable {
                await viewModel.fetchTransactions()
            }
            .task {
                await viewModel.fetchTransactions()
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK") {
                    viewModel.dismissError()
                }
            } message: {
                Text(viewModel.errorMessage ?? "An error occurred")
            }
        }
    }

    // MARK: - View Components

    private var filterPicker: some View {
        Picker("Filter", selection: $viewModel.selectedFilter) {
            ForEach(TransactionFilter.allCases, id: \.self) { filter in
                Text(filter.rawValue).tag(filter)
            }
        }
        .pickerStyle(.segmented)
        .frame(maxWidth: 300)
    }

    private var transactionListView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(viewModel.filteredTransactions) { transaction in
                    TransactionRowView(transaction: transaction)
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

                Image(systemName: "list.bullet.rectangle")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 50, height: 50)
                    .foregroundStyle(.white)
            }

            Text("No Transactions")
                .font(.title2)
                .fontWeight(.semibold)

            Text(emptyStateMessage)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }

    private var emptyStateMessage: String {
        switch viewModel.selectedFilter {
        case .all:
            return "Complete quests or redeem rewards to see your transaction history!"
        case .earn:
            return "Complete quests to start earning points!"
        case .redeem:
            return "Redeem rewards to see your redemption history!"
        }
    }
}

// MARK: - Transaction Row View

struct TransactionRowView: View {
    let transaction: Transaction

    var body: some View {
        HStack(spacing: 12) {
            // Transaction type icon
            ZStack {
                Circle()
                    .fill(iconGradient)
                    .frame(width: 44, height: 44)
                    .shadow(color: AppTheme.shadowColor, radius: 4, x: 0, y: 2)

                Image(systemName: iconName)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
            }

            // Transaction details
            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.description)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .lineLimit(2)

                Text(formattedDate)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Transaction amount
            Text(transaction.formattedAmount())
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(amountGradient)
        }
        .padding()
        .cardStyle()
    }

    // MARK: - Computed Properties

    private var iconName: String {
        transaction.type == .earn ? "arrow.up" : "arrow.down"
    }

    private var iconGradient: LinearGradient {
        transaction.type == .earn ? AppTheme.successGradient : AppTheme.warningGradient
    }

    private var amountGradient: LinearGradient {
        transaction.type == .earn ? AppTheme.successGradient : AppTheme.warningGradient
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: transaction.createdAt)
    }
}

#Preview {
    TransactionHistoryView()
}
