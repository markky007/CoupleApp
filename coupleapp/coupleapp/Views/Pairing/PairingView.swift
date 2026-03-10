import SwiftUI

/// Partner pairing view for managing partner connections
/// Displays partner code, pending requests, and paired partner information
struct PartnerCodePairingView: View {

    @StateObject private var viewModel: PairingViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.colorScheme) var systemColorScheme
    @State private var showUnpairConfirmation = false
    @State private var partnerToUnpair: Profile?

    private let userId: UUID

    // MARK: - Initialization

    init(userId: UUID) {
        self.userId = userId
        _viewModel = StateObject(wrappedValue: PairingViewModel(userId: userId))
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient (adaptive to theme)
                AppTheme.backgroundGradient(
                    for: themeManager.currentTheme.rawValue, systemScheme: systemColorScheme
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Partner Code Section
                        partnerCodeSection

                        // Enter Code Section
                        enterCodeSection

                        // Pending Requests Section
                        pendingRequestsSection

                        // Paired Partner Section
                        pairedPartnerSection
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 32)
                }
            }
            .navigationTitle(LocalizationManager.shared.localized("pairing.title"))
            #if os(iOS)
                .navigationBarTitleDisplayMode(.large)
            #endif
            .disabled(viewModel.isLoading)
            .alert(
                LocalizationManager.shared.localized("error.title"),
                isPresented: $viewModel.showError
            ) {
                Button(LocalizationManager.shared.localized("button.ok")) {
                    viewModel.dismissError()
                }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .alert(
                LocalizationManager.shared.localized("success.title"),
                isPresented: $viewModel.showSuccess
            ) {
                Button(LocalizationManager.shared.localized("button.ok")) {
                    viewModel.dismissSuccess()
                }
            } message: {
                Text(viewModel.successMessage ?? "")
            }
            .alert(
                LocalizationManager.shared.localized("pairing.unpair.confirm.title"),
                isPresented: $showUnpairConfirmation
            ) {
                Button(LocalizationManager.shared.localized("button.cancel"), role: .cancel) {}
                Button(
                    LocalizationManager.shared.localized("pairing.unpair.button"),
                    role: .destructive
                ) {
                    Task {
                        await unpairPartner()
                    }
                }
            } message: {
                Text(LocalizationManager.shared.localized("pairing.unpair.confirm.message"))
            }
            .task {
                await viewModel.setUserId(userId)
            }
        }
    }

    // MARK: - View Components

    /// Partner code display section
    private var partnerCodeSection: some View {
        VStack(spacing: 16) {
            Text(LocalizationManager.shared.localized("pairing.your_code"))
                .font(AppTheme.headline())
                .foregroundColor(AppTheme.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 12) {
                // Large partner code display
                if let code = viewModel.partnerCode {
                    Text(code)
                        .font(.system(size: 48, weight: .bold, design: .monospaced))
                        .foregroundStyle(
                            themeManager.currentTheme.rawValue == "dark"
                                ? AppTheme.primaryGradientDark : AppTheme.partnerGradient
                        )
                        .padding(.vertical, 20)
                        .frame(maxWidth: .infinity)
                        .background(AppTheme.cardBackground)
                        .cornerRadius(AppTheme.cornerRadiusLarge)
                        .shadow(
                            color: AppTheme.shadowColor,
                            radius: AppTheme.shadowRadius,
                            x: AppTheme.shadowOffset.width,
                            y: AppTheme.shadowOffset.height
                        )
                } else if viewModel.isLoading {
                    ProgressView()
                        .frame(height: 100)
                } else {
                    Text(LocalizationManager.shared.localized("pairing.code.loading"))
                        .foregroundColor(AppTheme.secondaryText)
                        .frame(height: 100)
                }

                // Copy button
                Button {
                    #if os(iOS)
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.impactOccurred()
                    #endif
                    viewModel.copyPartnerCode()
                } label: {
                    HStack {
                        Image(systemName: "doc.on.doc.fill")
                        Text(LocalizationManager.shared.localized("pairing.copy_code"))
                            .fontWeight(.semibold)
                    }
                }
                .buttonStyle(
                    GradientButtonStyle(
                        gradient: themeManager.currentTheme.rawValue == "dark"
                            ? AppTheme.secondaryGradientDark : AppTheme.secondaryGradient,
                        isDisabled: viewModel.partnerCode == nil || viewModel.isLoading
                    )
                )
                .disabled(viewModel.partnerCode == nil || viewModel.isLoading)
            }
        }
    }

    /// Enter partner code section
    private var enterCodeSection: some View {
        VStack(spacing: 16) {
            Text(LocalizationManager.shared.localized("pairing.enter_code"))
                .font(AppTheme.headline())
                .foregroundColor(AppTheme.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 12) {
                // Text field for entering code
                TextField(
                    LocalizationManager.shared.localized("pairing.code.placeholder"),
                    text: $viewModel.partnerCodeInput
                )
                .padding()
                .background(AppTheme.cardBackground)
                .cornerRadius(AppTheme.cornerRadiusMedium)
                .shadow(
                    color: AppTheme.shadowColor,
                    radius: 4,
                    x: 0,
                    y: 2
                )
                #if os(iOS)
                    .textInputAutocapitalization(.characters)
                    .keyboardType(.asciiCapable)
                #endif
                .autocorrectionDisabled()
                .disabled(viewModel.isLoading)

                // Send request button
                Button {
                    #if os(iOS)
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.impactOccurred()
                    #endif
                    Task {
                        await viewModel.sendPairingRequest(code: viewModel.partnerCodeInput)
                    }
                } label: {
                    HStack {
                        if viewModel.isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "paperplane.fill")
                            Text(LocalizationManager.shared.localized("pairing.send_request"))
                                .fontWeight(.semibold)
                        }
                    }
                }
                .buttonStyle(
                    GradientButtonStyle(
                        gradient: themeManager.currentTheme.rawValue == "dark"
                            ? AppTheme.primaryGradientDark : AppTheme.primaryGradient,
                        isDisabled: viewModel.partnerCodeInput.isEmpty || viewModel.isLoading
                    )
                )
                .disabled(viewModel.partnerCodeInput.isEmpty || viewModel.isLoading)
            }
        }
    }

    /// Pending requests section
    private var pendingRequestsSection: some View {
        VStack(spacing: 16) {
            Text(LocalizationManager.shared.localized("pairing.pending_requests"))
                .font(AppTheme.headline())
                .foregroundColor(AppTheme.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)

            if viewModel.pendingRequests.isEmpty {
                // Empty state
                VStack(spacing: 12) {
                    Image(systemName: "tray")
                        .font(.system(size: 48))
                        .foregroundColor(AppTheme.tertiaryText)

                    Text(LocalizationManager.shared.localized("pairing.no_requests"))
                        .font(AppTheme.body())
                        .foregroundColor(AppTheme.secondaryText)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .background(AppTheme.cardBackground)
                .cornerRadius(AppTheme.cornerRadiusMedium)
                .shadow(
                    color: AppTheme.shadowColor,
                    radius: AppTheme.shadowRadius,
                    x: AppTheme.shadowOffset.width,
                    y: AppTheme.shadowOffset.height
                )
            } else {
                // List of requests
                VStack(spacing: 12) {
                    ForEach(viewModel.pendingRequests) { request in
                        requestCard(request)
                    }
                }
            }
        }
    }

    /// Individual request card
    private func requestCard(_ request: PairingRequest) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                // Profile picture or placeholder
                Circle()
                    .fill(
                        themeManager.currentTheme.rawValue == "dark"
                            ? AppTheme.primaryGradientDark : AppTheme.partnerGradient
                    )
                    .frame(width: 50, height: 50)
                    .overlay(
                        Image(systemName: "person.fill")
                            .foregroundColor(.white)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(
                        request.requesterProfile?.username
                            ?? LocalizationManager.shared.localized("pairing.unknown_user")
                    )
                    .font(AppTheme.headline())
                    .foregroundColor(AppTheme.primaryText)

                    Text(LocalizationManager.shared.localized("pairing.wants_to_pair"))
                        .font(AppTheme.caption())
                        .foregroundColor(AppTheme.secondaryText)
                }

                Spacer()
            }

            // Action buttons
            HStack(spacing: 12) {
                // Reject button
                Button {
                    #if os(iOS)
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                    #endif
                    Task {
                        await viewModel.rejectRequest(request)
                    }
                } label: {
                    Text(LocalizationManager.shared.localized("pairing.reject"))
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(AppTheme.tertiaryBackground)
                        .cornerRadius(AppTheme.cornerRadiusSmall)
                }
                .disabled(viewModel.isLoading)

                // Accept button
                Button {
                    #if os(iOS)
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.impactOccurred()
                    #endif
                    Task {
                        await viewModel.acceptRequest(request)
                    }
                } label: {
                    Text(LocalizationManager.shared.localized("pairing.accept"))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            themeManager.currentTheme.rawValue == "dark"
                                ? AppTheme.secondaryGradientDark : AppTheme.successGradient
                        )
                        .cornerRadius(AppTheme.cornerRadiusSmall)
                }
                .disabled(viewModel.isLoading)
            }
        }
        .padding()
        .background(AppTheme.cardBackground)
        .cornerRadius(AppTheme.cornerRadiusMedium)
        .shadow(
            color: AppTheme.shadowColor,
            radius: AppTheme.shadowRadius,
            x: AppTheme.shadowOffset.width,
            y: AppTheme.shadowOffset.height
        )
    }

    /// Paired partner section
    private var pairedPartnerSection: some View {
        VStack(spacing: 16) {
            Text(LocalizationManager.shared.localized("pairing.paired_partner"))
                .font(AppTheme.headline())
                .foregroundColor(AppTheme.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)

            // TODO: Fetch partner profile from ProfileService
            // For now, show empty state
            VStack(spacing: 12) {
                Image(systemName: "person.2")
                    .font(.system(size: 48))
                    .foregroundColor(AppTheme.tertiaryText)

                Text(LocalizationManager.shared.localized("pairing.no_partner"))
                    .font(AppTheme.body())
                    .foregroundColor(AppTheme.secondaryText)
                    .multilineTextAlignment(.center)

                Text(LocalizationManager.shared.localized("pairing.no_partner.hint"))
                    .font(AppTheme.caption())
                    .foregroundColor(AppTheme.tertiaryText)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
            .background(AppTheme.cardBackground)
            .cornerRadius(AppTheme.cornerRadiusMedium)
            .shadow(
                color: AppTheme.shadowColor,
                radius: AppTheme.shadowRadius,
                x: AppTheme.shadowOffset.width,
                y: AppTheme.shadowOffset.height
            )
        }
    }

    // MARK: - Helper Methods

    /// Unpairs the current partner
    private func unpairPartner() async {
        // TODO: Implement unpair functionality
        // This will be implemented when we have access to current user's profile
    }
}

#Preview {
    PartnerCodePairingView(userId: UUID())
}
