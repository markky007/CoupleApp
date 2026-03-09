import SwiftUI

/// View for displaying list of events with countdown
struct EventListView: View {

    // MARK: - Properties

    @StateObject private var viewModel = EventViewModel()
    @State private var showCreateSheet = false
    @State private var selectedEvent: Event?
    @State private var showEditSheet = false

    // MARK: - Body

    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient
                AppTheme.backgroundGradient
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
            .navigationTitle("Events")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showCreateSheet = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(AppTheme.primaryGradient)
                    }
                }
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
        }
    }

    // MARK: - Empty State View

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 60))
                .foregroundStyle(AppTheme.secondaryGradient)

            Text("No Events Yet")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Create your first event to start tracking special dates")
                .font(.body)
                .foregroundColor(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button {
                showCreateSheet = true
            } label: {
                Text("Create Event")
                    .fontWeight(.semibold)
            }
            .buttonStyle(GradientButtonStyle(gradient: AppTheme.primaryGradient))
            .padding(.horizontal, 40)
            .padding(.top, 10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Create Event View

struct CreateEventView: View {

    @ObservedObject var viewModel: EventViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var eventDate = Date()
    @State private var isRecurring = false

    var body: some View {
        NavigationView {
            Form {
                Section("Event Details") {
                    TextField("Event Title", text: $title)

                    DatePicker(
                        "Event Date",
                        selection: $eventDate,
                        displayedComponents: [.date]
                    )

                    Toggle("Recurring Annually", isOn: $isRecurring)
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
                        Text("Create Event")
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
            .navigationTitle("New Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Edit Event View

struct EditEventView: View {

    @ObservedObject var viewModel: EventViewModel
    let event: Event
    @Environment(\.dismiss) private var dismiss

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
                Section("Event Details") {
                    TextField("Event Title", text: $title)

                    DatePicker(
                        "Event Date",
                        selection: $eventDate,
                        displayedComponents: [.date]
                    )

                    Toggle("Recurring Annually", isOn: $isRecurring)
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
                        Text("Update Event")
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
            .navigationTitle("Edit Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    EventListView()
}
