import SwiftUI

/// Row view for displaying a single event with countdown
struct EventRowView: View {

    // MARK: - Properties

    let event: Event
    let countdownText: String

    // MARK: - Body

    var body: some View {
        HStack(spacing: 16) {
            // Event icon
            ZStack {
                Circle()
                    .fill(AppTheme.secondaryGradient)
                    .frame(width: 50, height: 50)

                Image(systemName: event.isRecurring ? "arrow.clockwise" : "calendar")
                    .font(.title3)
                    .foregroundColor(.white)
            }

            // Event details
            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(.headline)
                    .foregroundColor(AppTheme.textPrimary)

                Text(formatDate(event.eventDate))
                    .font(.subheadline)
                    .foregroundColor(AppTheme.textSecondary)
            }

            Spacer()

            // Countdown
            VStack(alignment: .trailing, spacing: 4) {
                Text(countdownText)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(event.daysUntil == 0 ? AppTheme.success : AppTheme.primary)

                if event.isRecurring {
                    Image(systemName: "repeat")
                        .font(.caption2)
                        .foregroundColor(AppTheme.textSecondary)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium)
                .fill(AppTheme.cardGradient)
                .shadow(
                    color: AppTheme.shadowColor,
                    radius: AppTheme.shadowRadius,
                    x: AppTheme.shadowOffset.width,
                    y: AppTheme.shadowOffset.height
                )
        )
    }

    // MARK: - Helper Methods

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 16) {
        EventRowView(
            event: Event.new(
                title: "Anniversary",
                eventDate: Date().addingTimeInterval(86400 * 30),
                isRecurring: true,
                createdBy: UUID()
            ),
            countdownText: "In 30 days"
        )

        EventRowView(
            event: Event.new(
                title: "Birthday",
                eventDate: Date(),
                isRecurring: false,
                createdBy: UUID()
            ),
            countdownText: "Today!"
        )
    }
    .padding()
}
