import SwiftUI

/// View for creating custom reward proposals
/// Users can create rewards that require partner approval
struct CreateRewardView: View {

    @ObservedObject var viewModel: RewardViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var title: String = ""
    @State private var pointsCostText: String = ""
    @State private var showValidationError: Bool = false
    @State private var validationErrorMessage: String = ""

    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                AppTheme.backgroundGradient
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        headerSection

                        // Form
                        formSection

                        // Create button
                        createButton
                    }
                    .padding()
                }
            }
            .navigationTitle("Create Reward")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Validation Error", isPresented: $showValidationError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(validationErrorMessage)
            }
            .alert("Success", isPresented: $viewModel.showSuccess) {
                Button("OK") {
                    viewModel.dismissSuccess()
                    dismiss()
                }
            } message: {
                Text(viewModel.successMessage ?? "Reward created successfully!")
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

    private var headerSection: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(AppTheme.secondaryGradient)
                    .frame(width: 80, height: 80)
                    .shadow(color: AppTheme.shadowColor, radius: 10, x: 0, y: 5)

                Image(systemName: "gift.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 40, height: 40)
                    .foregroundStyle(.white)
            }

            Text("Create Custom Reward")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Your partner will need to approve this reward before it becomes available")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }

    private var formSection: some View {
        VStack(spacing: 16) {
            // Title field
            VStack(alignment: .leading, spacing: 8) {
                Text("Reward Title")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)

                TextField("e.g., Movie Night, Spa Day", text: $title)
                    .textFieldStyle(.plain)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium)
                            .fill(Color(.systemBackground))
                            .shadow(
                                color: AppTheme.shadowColor,
                                radius: 4,
                                x: 0,
                                y: 2
                            )
                    )

                Text("\(title.count)/100 characters")
                    .font(.caption)
                    .foregroundColor(title.count > 100 ? .red : .secondary)
            }

            // Points cost field
            VStack(alignment: .leading, spacing: 8) {
                Text("Points Cost")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)

                HStack {
                    Image(systemName: "star.fill")
                        .foregroundStyle(AppTheme.pointsGradient)

                    TextField("100", text: $pointsCostText)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.plain)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium)
                        .fill(Color(.systemBackground))
                        .shadow(
                            color: AppTheme.shadowColor,
                            radius: 4,
                            x: 0,
                            y: 2
                        )
                )

                Text("Between 1 and 10,000 points")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .cardStyle()
    }

    private var createButton: some View {
        Button {
            createReward()
        } label: {
            HStack {
                if viewModel.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Create Reward")
                }
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(AppTheme.primaryGradient)
            .cornerRadius(AppTheme.cornerRadiusLarge)
            .shadow(
                color: AppTheme.shadowColor,
                radius: AppTheme.shadowRadius,
                x: AppTheme.shadowOffset.width,
                y: AppTheme.shadowOffset.height
            )
        }
        .disabled(viewModel.isLoading || !isFormValid)
        .opacity(isFormValid ? 1.0 : 0.6)
    }

    // MARK: - Validation

    private var isFormValid: Bool {
        !title.isEmpty && title.count <= 100 && !pointsCostText.isEmpty
            && (Int(pointsCostText) ?? 0) > 0
    }

    private func createReward() {
        // Validate title
        guard !title.isEmpty, title.count <= 100 else {
            validationErrorMessage = "Title must be between 1 and 100 characters"
            showValidationError = true
            return
        }

        // Validate points cost
        guard let pointsCost = Int(pointsCostText), pointsCost >= 1, pointsCost <= 10000 else {
            validationErrorMessage = "Points cost must be between 1 and 10,000"
            showValidationError = true
            return
        }

        // Create reward
        Task {
            await viewModel.createRewardProposal(title: title, pointsCost: pointsCost)
        }
    }
}

#Preview {
    CreateRewardView(viewModel: RewardViewModel())
}
