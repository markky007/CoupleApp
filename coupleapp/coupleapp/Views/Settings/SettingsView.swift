import SwiftUI

/// Settings view for managing app preferences
/// Allows users to change theme, language, and manage partner pairing
struct SettingsView: View {

    @StateObject private var viewModel = SettingsViewModel()
    @StateObject private var authViewModel = AuthViewModel()
    @StateObject private var authService = AuthService.shared
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.colorScheme) var systemColorScheme

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
                        // Theme section
                        themeSection

                        // Language section
                        languageSection

                        // Partner section
                        partnerSection

                        // Sign out section
                        signOutSection
                    }
                    .padding()
                }
            }
            .navigationTitle("Settings")
            #if os(iOS)
                .navigationBarTitleDisplayMode(.large)
            #endif
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
            .alert(
                "Unpair from Partner",
                isPresented: $viewModel.showUnpairConfirmation
            ) {
                Button("Cancel", role: .cancel) {
                    viewModel.cancelUnpair()
                }
                Button("Unpair", role: .destructive) {
                    Task {
                        await viewModel.unpairPartner()
                    }
                }
            } message: {
                Text(
                    "Are you sure you want to unpair from your partner? You can pair again anytime."
                )
            }
            .task {
                if let userId = authService.currentUserId {
                    await viewModel.loadProfile(userId: userId)
                }
            }
        }
    }

    // MARK: - View Components

    private var themeSection: some View {
        VStack(spacing: 16) {
            Text("Theme")
                .font(.headline)
                .foregroundColor(AppTheme.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 12) {
                ForEach(ThemeManager.ThemeMode.allCases, id: \.self) { mode in
                    Button {
                        viewModel.changeTheme(mode)
                    } label: {
                        HStack {
                            Image(systemName: mode.icon)
                                .font(.system(size: 18))
                                .foregroundColor(AppTheme.primary)
                                .frame(width: 30)

                            Text(mode.displayName)
                                .font(.subheadline)
                                .foregroundColor(AppTheme.primaryText)

                            Spacer()

                            if viewModel.currentTheme == mode {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(AppTheme.primaryGradient)
                            }
                        }
                        .padding()
                        .background(AppTheme.cardBackground)
                        .cornerRadius(AppTheme.cornerRadiusMedium)
                    }
                }
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

    private var languageSection: some View {
        VStack(spacing: 16) {
            Text("Language")
                .font(.headline)
                .foregroundColor(AppTheme.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 12) {
                ForEach(LocalizationManager.Language.allCases, id: \.self) { language in
                    Button {
                        viewModel.changeLanguage(language)
                    } label: {
                        HStack {
                            Image(systemName: language.icon)
                                .font(.system(size: 18))
                                .foregroundColor(AppTheme.primary)
                                .frame(width: 30)

                            Text(language.displayName)
                                .font(.subheadline)
                                .foregroundColor(AppTheme.primaryText)

                            Spacer()

                            if viewModel.currentLanguage == language {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(AppTheme.primaryGradient)
                            }
                        }
                        .padding()
                        .background(AppTheme.cardBackground)
                        .cornerRadius(AppTheme.cornerRadiusMedium)
                    }
                }
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

    private var partnerSection: some View {
        VStack(spacing: 16) {
            Text("Partner")
                .font(.headline)
                .foregroundColor(AppTheme.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let partner = viewModel.profile?.partnerId {
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 18))
                            .foregroundColor(AppTheme.primary)
                            .frame(width: 30)

                        Text("Paired")
                            .font(.subheadline)
                            .foregroundColor(AppTheme.primaryText)

                        Spacer()

                        Text(partner.uuidString.prefix(8) + "...")
                            .font(.caption)
                            .foregroundColor(AppTheme.secondaryText)
                    }
                    .padding()
                    .background(AppTheme.cardBackground)
                    .cornerRadius(AppTheme.cornerRadiusMedium)

                    Button(role: .destructive) {
                        viewModel.requestUnpair()
                    } label: {
                        HStack {
                            Image(systemName: "link.badge.minus")
                            Text("Unpair")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .foregroundColor(.red)
                        .cornerRadius(AppTheme.cornerRadiusMedium)
                    }
                }
            } else {
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: "person.2.slash")
                            .font(.system(size: 18))
                            .foregroundColor(AppTheme.tertiaryText)
                            .frame(width: 30)

                        Text("Not paired")
                            .font(.subheadline)
                            .foregroundColor(AppTheme.secondaryText)

                        Spacer()
                    }
                    .padding()
                    .background(AppTheme.cardBackground)
                    .cornerRadius(AppTheme.cornerRadiusMedium)
                }
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

    private var signOutSection: some View {
        Button(role: .destructive) {
            Task {
                await authViewModel.signOut()
            }
        } label: {
            HStack {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                Text("Sign Out")
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.red.opacity(0.1))
            .foregroundColor(.red)
            .cornerRadius(AppTheme.cornerRadiusMedium)
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
}

#Preview {
    SettingsView()
}
