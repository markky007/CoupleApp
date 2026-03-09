import SwiftUI

/// App-wide theme configuration with gradient colors
/// Provides consistent, user-friendly color scheme throughout the app
struct AppTheme {

    // MARK: - Gradient Colors

    /// Primary gradient for main actions and highlights
    static let primaryGradient = LinearGradient(
        colors: [Color(hex: "FF6B9D"), Color(hex: "C06C84")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Secondary gradient for supporting elements
    static let secondaryGradient = LinearGradient(
        colors: [Color(hex: "A8E6CF"), Color(hex: "56CCF2")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Success gradient for completed actions
    static let successGradient = LinearGradient(
        colors: [Color(hex: "84FAB0"), Color(hex: "8FD3F4")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Warning gradient for alerts and important notices
    static let warningGradient = LinearGradient(
        colors: [Color(hex: "FFD89B"), Color(hex: "FF9A76")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Points gradient for point displays
    static let pointsGradient = LinearGradient(
        colors: [Color(hex: "FFD700"), Color(hex: "FFA500")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Partner gradient for partner-related elements
    static let partnerGradient = LinearGradient(
        colors: [Color(hex: "B06AB3"), Color(hex: "4568DC")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Background gradient for main screens
    static let backgroundGradient = LinearGradient(
        colors: [Color(hex: "FFEEF8"), Color(hex: "F3F4F6")],
        startPoint: .top,
        endPoint: .bottom
    )

    /// Card gradient for elevated content
    static let cardGradient = LinearGradient(
        colors: [Color.white.opacity(0.9), Color.white.opacity(0.7)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // MARK: - Solid Colors (for accessibility)

    /// Primary color (solid version)
    static let primary = Color(hex: "FF6B9D")

    /// Secondary color (solid version)
    static let secondary = Color(hex: "56CCF2")

    /// Success color (solid version)
    static let success = Color(hex: "84FAB0")

    /// Warning color (solid version)
    static let warning = Color(hex: "FFD89B")

    /// Points color (solid version)
    static let points = Color(hex: "FFD700")

    /// Partner color (solid version)
    static let partner = Color(hex: "B06AB3")

    // MARK: - Text Colors

    /// Primary text color
    static let textPrimary = Color.primary

    /// Secondary text color
    static let textSecondary = Color.secondary

    /// Text on gradient backgrounds
    static let textOnGradient = Color.white

    // MARK: - Background Colors

    /// Main background color
    static var background: Color {
        #if os(iOS)
            return Color(.systemBackground)
        #else
            return Color(NSColor.windowBackgroundColor)
        #endif
    }

    /// Secondary background color
    static var secondaryBackground: Color {
        #if os(iOS)
            return Color(.systemGray6)
        #else
            return Color(NSColor.controlBackgroundColor)
        #endif
    }

    // MARK: - Corner Radius

    static let cornerRadiusSmall: CGFloat = 8
    static let cornerRadiusMedium: CGFloat = 12
    static let cornerRadiusLarge: CGFloat = 16

    // MARK: - Shadows

    static let shadowColor = Color.black.opacity(0.1)
    static let shadowRadius: CGFloat = 8
    static let shadowOffset = CGSize(width: 0, height: 2)
}

// MARK: - Color Extension for Hex Support

extension Color {
    /// Initialize Color from hex string
    /// - Parameter hex: Hex color string (e.g., "FF6B9D" or "#FF6B9D")
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a: UInt64
        let r: UInt64
        let g: UInt64
        let b: UInt64
        switch hex.count {
        case 3:  // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:  // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:  // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - View Modifiers

extension View {
    /// Apply primary gradient background
    func primaryGradientBackground() -> some View {
        self.background(AppTheme.primaryGradient)
    }

    /// Apply card style with gradient
    func cardStyle() -> some View {
        self
            .background(AppTheme.cardGradient)
            .cornerRadius(AppTheme.cornerRadiusMedium)
            .shadow(
                color: AppTheme.shadowColor,
                radius: AppTheme.shadowRadius,
                x: AppTheme.shadowOffset.width,
                y: AppTheme.shadowOffset.height
            )
    }

    /// Apply gradient button style
    func gradientButton(gradient: LinearGradient = AppTheme.primaryGradient) -> some View {
        self
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(gradient)
            .foregroundColor(.white)
            .cornerRadius(AppTheme.cornerRadiusMedium)
            .shadow(
                color: AppTheme.shadowColor,
                radius: 4,
                x: 0,
                y: 2
            )
    }
}

// MARK: - Gradient Button Style

struct GradientButtonStyle: ButtonStyle {
    let gradient: LinearGradient
    let isDisabled: Bool

    init(gradient: LinearGradient = AppTheme.primaryGradient, isDisabled: Bool = false) {
        self.gradient = gradient
        self.isDisabled = isDisabled
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                isDisabled
                    ? LinearGradient(
                        colors: [Color.gray], startPoint: .leading, endPoint: .trailing) : gradient
            )
            .foregroundColor(.white)
            .cornerRadius(AppTheme.cornerRadiusMedium)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
            .shadow(
                color: AppTheme.shadowColor,
                radius: configuration.isPressed ? 2 : 4,
                x: 0,
                y: configuration.isPressed ? 1 : 2
            )
    }
}
