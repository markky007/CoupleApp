import SwiftUI

/// Reusable tip row component for displaying tips with icon and text
struct TipRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(AppTheme.primary)
                .frame(width: 24)

            Text(text)
                .font(.subheadline)
                .foregroundColor(AppTheme.primaryText)

            Spacer()
        }
    }
}

#Preview {
    TipRow(icon: "fork.knife", text: "Dinner at favorite restaurant")
}
