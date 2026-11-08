import SwiftUI

/// Central design tokens. Inspired by token-based SwiftUI systems
/// (ShadKit, ChunUI) — values are our own.
enum DS {
    // Spacing scale (4-pt base).
    enum Space {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
    }
    // Corner radii.
    enum Radius {
        static let sm: CGFloat = 10
        static let md: CGFloat = 16
        static let lg: CGFloat = 22
        static let pill: CGFloat = 999
    }
    // Brand gradient (violet).
    static let brand = LinearGradient(
        colors: [Color(hex: "#9B8CFF"), Color(hex: "#6D5EF6")],
        startPoint: .topLeading, endPoint: .bottomTrailing)
}

extension Font {
    /// Friendly rounded display face (SF Rounded) used for titles and numerals.
    static func display(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

/// A soft, rounded surface used for grouped content.
struct AppCard<Content: View>: View {
    var padding: CGFloat = DS.Space.lg
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                    .stroke(Color.primary.opacity(0.04), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
    }
}

/// A small uppercase section label.
struct SectionLabel: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .tracking(0.5)
    }
}

/// Rounded numeric display (for stats/streaks).
extension Text {
    func numeral(_ size: CGFloat) -> some View {
        self.font(.system(size: size, weight: .bold, design: .rounded))
    }
}

extension View {
    /// App background that adapts to light/dark.
    func screenBackground() -> some View {
        self.background(Color(.systemGroupedBackground).ignoresSafeArea())
    }
}
