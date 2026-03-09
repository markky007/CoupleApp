import SwiftUI

/// Tooltip view for showing contextual hints to users
struct TooltipView: View {
    let message: String
    let onDismiss: () -> Void

    @State private var isVisible = false

    var body: some View {
        VStack {
            HStack(spacing: 12) {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.yellow)
                    .font(.title3)

                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.leading)

                Spacer()

                Button {
                    dismissTooltip()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.white.opacity(0.7))
                        .font(.title3)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium)
                    .fill(
                        LinearGradient(
                            colors: [Color.blue, Color.purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
            )
            .padding(.horizontal)
            .offset(y: isVisible ? 0 : -100)
            .opacity(isVisible ? 1 : 0)

            Spacer()
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                isVisible = true
            }

            // Auto-dismiss after 5 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                dismissTooltip()
            }
        }
    }

    private func dismissTooltip() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            isVisible = false
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onDismiss()
        }
    }
}

// MARK: - Tooltip Modifier

struct TooltipModifier: ViewModifier {
    let message: String
    @Binding var isShowing: Bool
    let onDismiss: () -> Void

    func body(content: Content) -> some View {
        ZStack {
            content

            if isShowing {
                TooltipView(message: message) {
                    onDismiss()
                    isShowing = false
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(1000)
            }
        }
    }
}

extension View {
    /// Show a tooltip with a message
    func tooltip(message: String, isShowing: Binding<Bool>, onDismiss: @escaping () -> Void)
        -> some View
    {
        self.modifier(TooltipModifier(message: message, isShowing: isShowing, onDismiss: onDismiss))
    }
}

#Preview {
    ZStack {
        AppTheme.backgroundGradient
            .ignoresSafeArea()

        TooltipView(message: "Swipe left on a quest to quickly complete it!") {
            print("Dismissed")
        }
    }
}
