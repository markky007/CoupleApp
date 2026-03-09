import SwiftUI

/// Success animation view with confetti effect
/// Shows celebratory animation for quest completion and reward redemption
struct SuccessAnimationView: View {
    let title: String
    let message: String
    let onDismiss: () -> Void

    @State private var showCheckmark = false
    @State private var showText = false
    @State private var confettiPieces: [ConfettiPiece] = []

    var body: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    onDismiss()
                }

            VStack(spacing: 24) {
                // Animated checkmark
                ZStack {
                    Circle()
                        .fill(AppTheme.successGradient)
                        .frame(width: 120, height: 120)
                        .scaleEffect(showCheckmark ? 1.0 : 0.5)
                        .opacity(showCheckmark ? 1.0 : 0.0)

                    Image(systemName: "checkmark")
                        .font(.system(size: 60, weight: .bold))
                        .foregroundColor(.white)
                        .scaleEffect(showCheckmark ? 1.0 : 0.5)
                        .opacity(showCheckmark ? 1.0 : 0.0)
                }
                .shadow(color: AppTheme.shadowColor, radius: 20, x: 0, y: 10)

                // Success text
                VStack(spacing: 8) {
                    Text(title)
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)

                    Text(message)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                }
                .opacity(showText ? 1.0 : 0.0)
                .offset(y: showText ? 0 : 20)
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge)
                    .fill(.ultraThinMaterial)
            )
            .padding(32)

            // Confetti overlay
            ForEach(confettiPieces) { piece in
                ConfettiPieceView(piece: piece)
            }
        }
        .onAppear {
            // Trigger haptic feedback
            HapticManager.shared.success()

            // Animate checkmark
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                showCheckmark = true
            }

            // Animate text
            withAnimation(.easeOut(duration: 0.4).delay(0.2)) {
                showText = true
            }

            // Generate confetti
            generateConfetti()

            // Auto dismiss after 2 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                onDismiss()
            }
        }
    }

    private func generateConfetti() {
        let colors: [Color] = [
            AppTheme.primary,
            AppTheme.secondary,
            AppTheme.success,
            AppTheme.warning,
            AppTheme.points,
            AppTheme.partner,
        ]

        for i in 0..<50 {
            let piece = ConfettiPiece(
                id: i,
                color: colors.randomElement() ?? .blue,
                x: CGFloat.random(in: 0...UIScreen.main.bounds.width),
                y: -50,
                rotation: Double.random(in: 0...360),
                scale: CGFloat.random(in: 0.5...1.5)
            )
            confettiPieces.append(piece)
        }
    }
}

/// Individual confetti piece
struct ConfettiPiece: Identifiable {
    let id: Int
    let color: Color
    var x: CGFloat
    var y: CGFloat
    var rotation: Double
    var scale: CGFloat
}

/// Animated confetti piece view
struct ConfettiPieceView: View {
    let piece: ConfettiPiece
    @State private var yOffset: CGFloat = 0
    @State private var rotation: Double = 0

    var body: some View {
        Circle()
            .fill(piece.color)
            .frame(width: 10 * piece.scale, height: 10 * piece.scale)
            .position(x: piece.x, y: piece.y + yOffset)
            .rotationEffect(.degrees(rotation))
            .onAppear {
                withAnimation(
                    .easeIn(duration: Double.random(in: 1.5...2.5))
                ) {
                    yOffset = UIScreen.main.bounds.height + 100
                    rotation = Double.random(in: 360...720)
                }
            }
    }
}

/// Simple success checkmark animation (lighter version)
struct SimpleSuccessView: View {
    @State private var showCheckmark = false

    var body: some View {
        ZStack {
            Circle()
                .fill(AppTheme.successGradient)
                .frame(width: 60, height: 60)
                .scaleEffect(showCheckmark ? 1.0 : 0.5)
                .opacity(showCheckmark ? 1.0 : 0.0)

            Image(systemName: "checkmark")
                .font(.system(size: 30, weight: .bold))
                .foregroundColor(.white)
                .scaleEffect(showCheckmark ? 1.0 : 0.5)
                .opacity(showCheckmark ? 1.0 : 0.0)
        }
        .onAppear {
            HapticManager.shared.success()
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                showCheckmark = true
            }
        }
    }
}

#Preview("Success Animation") {
    SuccessAnimationView(
        title: "Quest Complete!",
        message: "You earned 10 points",
        onDismiss: {}
    )
}

#Preview("Simple Success") {
    SimpleSuccessView()
}
