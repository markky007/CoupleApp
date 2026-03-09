import SwiftUI

/// Connection status indicator banner
/// Displays at the top of the screen when offline or connection issues occur
struct ConnectionStatusView: View {
    @ObservedObject var networkMonitor = NetworkMonitor.shared

    var body: some View {
        if !networkMonitor.isConnected {
            HStack(spacing: 12) {
                Image(systemName: "wifi.slash")
                    .font(.system(size: 16, weight: .semibold))

                Text(networkMonitor.statusMessage)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Spacer()

                // Pulsing indicator
                Circle()
                    .fill(Color.white.opacity(0.8))
                    .frame(width: 8, height: 8)
                    .scaleEffect(pulseAnimation ? 1.2 : 0.8)
                    .animation(
                        .easeInOut(duration: 1.0).repeatForever(autoreverses: true),
                        value: pulseAnimation
                    )
            }
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.red)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    @State private var pulseAnimation = false

    init() {
        _pulseAnimation = State(initialValue: true)
    }
}

/// View modifier to add connection status banner
struct ConnectionStatusModifier: ViewModifier {
    func body(content: Content) -> some View {
        VStack(spacing: 0) {
            ConnectionStatusView()
                .animation(.spring(response: 0.3), value: NetworkMonitor.shared.isConnected)

            content
        }
    }
}

extension View {
    /// Adds connection status banner to the view
    func connectionStatus() -> some View {
        modifier(ConnectionStatusModifier())
    }
}

#Preview("Offline") {
    VStack {
        ConnectionStatusView()

        Spacer()

        Text("Main Content")
            .font(.title)

        Spacer()
    }
}

#Preview("Online") {
    VStack {
        Text("Main Content")
            .font(.title)
    }
    .connectionStatus()
}
