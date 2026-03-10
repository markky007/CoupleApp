import SwiftUI

/// View for displaying list of events with countdown
struct EventListView: View {

    // MARK: - Properties

    @StateObject private var viewModel = EventViewModel()
    @StateObject private var onboardingManager = OnboardingManager.shared
    @State private var showCreateSheet = false
    @State private var selectedEvent: Event?
    @State private var showEditSheet = false
    @State private var showTooltip = false
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var localizationManager: LocalizationManager
    @Environment(\.colorScheme) var systemColorScheme

    // MARK: - Body

    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient (adaptive to theme)
                AppTheme.backgroundGradient(
                    for: themeManager.currentTheme.rawValue, systemScheme: systemColorScheme
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    if viewModel.isLoading && viewModel.events.isEmpty {
                        // Loading state
                        ProgressView("Loading events...")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if viewModel.events.isEmpty {
                        // Empty state
                        emptyStateView
                    } else {
                        // Events list
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(viewModel.events) { event in
                                    EventRowView(
                                        event: event,
                                        countdownText: viewModel.countdownText(for: event)
                                    )
                                    .contextMenu {
                                        Button {
                                            selectedEvent = event
                                            showEditSheet = true
                                        } label: {
                                            Label("Edit", systemImage: "pencil")
                                        }

                                        Button(role: .destructive) {
                                            Task {
                                                await viewModel.deleteEvent(eventId: event.id)
                                            }
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                                }
                            }
                            .padding()
                        }
                        .refreshable {
                            await viewModel.loadEvents()
                        }
                    }
                }
            }
            .navigationTitle(localizationManager.localized("event.title"))
            .toolbar {
                #if os(iOS)
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            showCreateSheet = true
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                                .foregroundStyle(AppTheme.primaryGradient)
                        }
                    }
                #else
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            showCreateSheet = true
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                                .foregroundStyle(AppTheme.primaryGradient)
                        }
                    }
                #endif
            }
            .sheet(isPresented: $showCreateSheet) {
                CreateEventView(viewModel: viewModel)
            }
            .sheet(isPresented: $showEditSheet) {
                if let event = selectedEvent {
                    EditEventView(viewModel: viewModel, event: event)
                }
            }
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") {
                    viewModel.errorMessage = nil
                }
            } message: {
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                }
            }
            .overlay(alignment: .top) {
                if viewModel.showSuccessMessage, let message = viewModel.successMessage {
                    Text(message)
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .padding()
                        .background(AppTheme.successGradient)
                        .cornerRadius(AppTheme.cornerRadiusMedium)
                        .padding()
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .tooltip(
                message:
                    localizationManager.localized("event.idea.reminder"),
                isShowing: $showTooltip,
                onDismiss: {
                    onboardingManager.hasSeenEventTooltip = true
                }
            )
            .task {
                // Show tooltip for first-time users
                if !onboardingManager.hasSeenEventTooltip && !viewModel.events.isEmpty {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        showTooltip = true
                    }
                }
            }
            // Force view update when language changes
            .id(localizationManager.currentLanguage)
        }
    }

    // MARK: - Empty State View

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(AppTheme.secondaryGradient)
                    .frame(width: 120, height: 120)
                    .shadow(color: AppTheme.shadowColor, radius: 10, x: 0, y: 5)

                Image(systemName: "calendar.badge.plus")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 60, height: 60)
                    .foregroundStyle(.white)
            }

            Text(localizationManager.localized("event.empty.title"))
                .font(.title2)
                .fontWeight(.bold)

            Text(localizationManager.localized("event.empty.description"))
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button {
                HapticManager.shared.medium()
                showCreateSheet = true
            } label: {
                Label(
                    localizationManager.localized("event.empty.button"),
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
                    Text(localizationManager.localized("event.ideas"))
                        .font(.headline)
                }

                TipRow(
                    icon: "heart.fill",
                    text: localizationManager.localized("event.idea.anniversary"))
                TipRow(
                    icon: "birthday.cake",
                    text: localizationManager.localized("event.idea.birthday"))
                TipRow(icon: "airplane", text: localizationManager.localized("event.idea.vacation"))
                TipRow(icon: "bell", text: localizationManager.localized("event.idea.reminder"))
            }
            .padding()
            .cardStyle()
            .padding(.horizontal, 32)
            .padding(.top, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Create Event View

struct CreateEventView: View {

    @ObservedObject var viewModel: EventViewModel
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var localizationManager: LocalizationManager

    @State private var title = ""
    @State private var eventDate = Date()
    @State private var isRecurring = false

    var body: some View {
        NavigationView {
            Form {
                Section(localizationManager.localized("event.details")) {
                    TextField(
                        localizationManager.localized("event.title.placeholder"), text: $title)

                    DatePicker(
                        localizationManager.localized("event.date"),
                        selection: $eventDate,
                        displayedComponents: [.date]
                    )

                    Toggle(localizationManager.localized("event.recurring"), isOn: $isRecurring)
                }

                Section {
                    Button {
                        Task {
                            await viewModel.createEvent(
                                title: title,
                                eventDate: eventDate,
                                isRecurring: isRecurring
                            )
                            dismiss()
                        }
                    } label: {
                        Text(localizationManager.localized("event.create"))
                            .frame(maxWidth: .infinity)
                            .fontWeight(.semibold)
                    }
                    .buttonStyle(
                        GradientButtonStyle(
                            gradient: AppTheme.primaryGradient,
                            isDisabled: title.isEmpty
                        )
                    )
                    .disabled(title.isEmpty)
                }
            }
            .navigationTitle(localizationManager.localized("event.create"))
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
        }
    }
}

// MARK: - Edit Event View

struct EditEventView: View {

    @ObservedObject var viewModel: EventViewModel
    let event: Event
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var localizationManager: LocalizationManager

    @State private var title: String
    @State private var eventDate: Date
    @State private var isRecurring: Bool

    init(viewModel: EventViewModel, event: Event) {
        self.viewModel = viewModel
        self.event = event
        _title = State(initialValue: event.title)
        _eventDate = State(initialValue: event.eventDate)
        _isRecurring = State(initialValue: event.isRecurring)
    }

    var body: some View {
        NavigationView {
            Form {
                Section(localizationManager.localized("event.details")) {
                    TextField(
                        localizationManager.localized("event.title.placeholder"), text: $title)

                    DatePicker(
                        localizationManager.localized("event.date"),
                        selection: $eventDate,
                        displayedComponents: [.date]
                    )

                    Toggle(localizationManager.localized("event.recurring"), isOn: $isRecurring)
                }

                Section {
                    Button {
                        Task {
                            await viewModel.updateEvent(
                                eventId: event.id,
                                title: title,
                                eventDate: eventDate,
                                isRecurring: isRecurring
                            )
                            dismiss()
                        }
                    } label: {
                        Text(localizationManager.localized("event.update"))
                            .frame(maxWidth: .infinity)
                            .fontWeight(.semibold)
                    }
                    .buttonStyle(
                        GradientButtonStyle(
                            gradient: AppTheme.primaryGradient,
                            isDisabled: title.isEmpty
                        )
                    )
                    .disabled(title.isEmpty)
                }
            }
            .navigationTitle(localizationManager.localized("event.update"))
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
        }
    }
}

// MARK: - Preview

#Preview {
    EventListView()
}
