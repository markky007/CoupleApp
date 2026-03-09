import SwiftUI

/// Profile view showing user info and partner pairing
struct ProfileView: View {

    @StateObject private var viewModel = ProfileViewModel()
    @State private var showPairingSheet = false
    @State private var showEditNameSheet = false

    // Platform-specific background color
    private var backgroundColor: Color {
        #if os(iOS)
            return Color(.systemGray6)
        #else
            return Color(NSColor.controlBackgroundColor)
        #endif
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    if viewModel.profile != nil {
                        // User profile section
                        userProfileSection

                        // Partner section
                        partnerSection

                        // Actions section
                        actionsSection
                    } else {
                        // Create profile prompt
                        createProfileSection
                    }
                }
                .padding()
            }
            .navigationTitle("Profile")
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task {
                            await viewModel.loadProfile()
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                #else
                ToolbarItem(placement: .automatic) {
                    Button {
                        Task {
                            await viewModel.loadProfile()
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                #endif
            }
            .task {
                await viewModel.loadProfile()
                await viewModel.subscribeToUpdates()
            }
            .onDisappear {
                Task {
                    await viewModel.unsubscribeFromUpdates()
                }
            }
            .disabled(viewModel.isLoading)
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
                Text(viewModel.successMessage ?? "Success")
            }
            .sheet(isPresented: $showPairingSheet) {
                PairingView(viewModel: viewModel)
            }
            .sheet(isPresented: $showEditNameSheet) {
                EditNameView(viewModel: viewModel)
            }
        }
    }

    // MARK: - View Components

    private var userProfileSection: some View {
        VStack(spacing: 16) {
            // Avatar
            Image(systemName: "person.circle.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
                .foregroundStyle(.pink.gradient)

            // Display name
            if let displayName = viewModel.profile?.displayName {
                Text(displayName)
                    .font(.title2)
                    .fontWeight(.bold)
            } else {
                Text("No display name")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }

            // User ID
            if let userId = viewModel.currentUserId {
                HStack {
                    Text("ID: \(userId.uuidString.prefix(8))...")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Button {
                        viewModel.copyUserIdToClipboard()
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .font(.caption)
                    }
                }
            }

            // Points
            if let points = viewModel.profile?.totalPoints {
                HStack(spacing: 8) {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                    Text("\(points) points")
                        .font(.headline)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(backgroundColor)
                .cornerRadius(20)
            }

            // Edit name button
            Button {
                showEditNameSheet = true
            } label: {
                Label("Edit Name", systemImage: "pencil")
                    .font(.subheadline)
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(backgroundColor)
        .cornerRadius(12)
    }

    private var partnerSection: some View {
        VStack(spacing: 16) {
            Text("Partner")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let partner = viewModel.partnerProfile {
                // Partner info
                HStack(spacing: 16) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.purple.gradient)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(partner.displayName ?? "Partner")
                            .font(.headline)

                        HStack(spacing: 8) {
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                                .font(.caption)
                            Text("\(partner.totalPoints) points")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()
                }
                .padding()
                .background(backgroundColor)
                .cornerRadius(12)

                // Unpair button
                Button(role: .destructive) {
                    Task {
                        await viewModel.unpairFromPartner()
                    }
                } label: {
                    Label("Unpair", systemImage: "link.badge.minus")
                        .font(.subheadline)
                }
                .buttonStyle(.bordered)
            } else {
                // No partner - show pairing button
                VStack(spacing: 12) {
                    Image(systemName: "person.2.slash")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)

                    Text("No partner yet")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Button {
                        showPairingSheet = true
                    } label: {
                        Label("Pair with Partner", systemImage: "link.badge.plus")
                            .font(.subheadline)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(backgroundColor)
                .cornerRadius(12)
            }
        }
    }

    private var actionsSection: some View {
        VStack(spacing: 12) {
            Text("Actions")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                // TODO: Navigate to transaction history
            } label: {
                HStack {
                    Image(systemName: "clock.arrow.circlepath")
                    Text("Transaction History")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(backgroundColor)
                .cornerRadius(12)
            }
            .foregroundColor(.primary)
        }
    }

    private var createProfileSection: some View {
        VStack(spacing: 24) {
            Image(systemName: "person.crop.circle.badge.plus")
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
                .foregroundStyle(.pink.gradient)

            Text("Create Your Profile")
                .font(.title2)
                .fontWeight(.bold)

            Text(
                "Set up your profile to start tracking chores and earning points with your partner"
            )
            .font(.subheadline)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)

            Button {
                showEditNameSheet = true
            } label: {
                Text("Get Started")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.pink)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
        }
        .padding()
    }
}

// MARK: - Pairing View

struct PairingView: View {
    @ObservedObject var viewModel: ProfileViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Partner's User ID", text: $viewModel.partnerIdInput)
                        #if os(iOS)
                            .textInputAutocapitalization(.never)
                        #endif
                        .autocorrectionDisabled()

                    if !viewModel.partnerIdInput.isEmpty && !viewModel.isPartnerIdValid {
                        Label("Invalid UUID format", systemImage: "exclamationmark.circle")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                } header: {
                    Text("Partner Information")
                } footer: {
                    Text("Ask your partner to share their User ID from their profile")
                }

                Section {
                    Button {
                        Task {
                            await viewModel.pairWithPartner()
                            if viewModel.hasPart {
                                dismiss()
                            }
                        }
                    } label: {
                        HStack {
                            if viewModel.isLoading {
                                ProgressView()
                            } else {
                                Text("Pair with Partner")
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .disabled(!viewModel.isPartnerIdValid || viewModel.isLoading)
                }
            }
            .navigationTitle("Pair with Partner")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Edit Name View

struct EditNameView: View {
    @ObservedObject var viewModel: ProfileViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Display Name", text: $viewModel.displayName)
                        #if os(iOS)
                            .textInputAutocapitalization(.words)
                        #endif

                    if !viewModel.displayName.isEmpty && !viewModel.isDisplayNameValid {
                        Label(
                            "Name must be 1-\(AppConstants.maxDisplayNameLength) characters",
                            systemImage: "exclamationmark.circle"
                        )
                        .font(.caption)
                        .foregroundColor(.red)
                    }
                } header: {
                    Text("Your Name")
                } footer: {
                    Text("This name will be visible to your partner")
                }

                Section {
                    Button {
                        Task {
                            if viewModel.profile != nil {
                                await viewModel.updateDisplayName()
                            } else {
                                await viewModel.createProfile(name: viewModel.displayName)
                            }
                            if viewModel.profile != nil {
                                dismiss()
                            }
                        }
                    } label: {
                        HStack {
                            if viewModel.isLoading {
                                ProgressView()
                            } else {
                                Text(viewModel.profile != nil ? "Update Name" : "Create Profile")
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .disabled(!viewModel.isDisplayNameValid || viewModel.isLoading)
                }
            }
            .navigationTitle(viewModel.profile != nil ? "Edit Name" : "Create Profile")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    ProfileView()
}
