import SwiftUI
import UIKit

extension Color {
    init(hex: String) {
        let s = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var rgb: UInt64 = 0
        Scanner(string: s).scanHexInt64(&rgb)
        if s.count == 6 {
            self.init(red: Double((rgb & 0xFF0000) >> 16) / 255,
                      green: Double((rgb & 0x00FF00) >> 8) / 255,
                      blue: Double(rgb & 0x0000FF) / 255)
        } else {
            self.init(red: 0.98, green: 0.75, blue: 0.14)
        }
    }
}

/// Night-match stadium palette.
enum Palette {
    static let gold = Color(hex: "#FBBF24")
    static let bgTop = Color(hex: "#0B1230")
    static let bgBottom = Color(hex: "#05070F")
    static let card = Color.white.opacity(0.07)
    static let cardStroke = Color.white.opacity(0.10)
    static let six = Color(hex: "#A855F7")
    static let four = Color(hex: "#22C55E")
    static let wicket = Color(hex: "#EF4444")

    static let teamColors = ["#2563EB", "#EAB308", "#DC2626", "#7C3AED", "#0EA5E9",
                             "#F97316", "#E11D48", "#EC4899", "#06B6D4", "#14B8A6",
                             "#84CC16", "#64748B"]
}

enum DS {
    enum Space {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
    }
    enum Radius {
        static let sm: CGFloat = 10
        static let md: CGFloat = 16
        static let lg: CGFloat = 22
    }
}

extension Font {
    static func display(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

struct AppBackground: View {
    var body: some View {
        LinearGradient(colors: [Palette.bgTop, Palette.bgBottom], startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
    }
}

struct AppCard<Content: View>: View {
    var padding: CGFloat = DS.Space.lg
    var tint: Color? = nil
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                    .fill(tint.map { $0.opacity(0.18) } ?? Palette.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                    .stroke(tint.map { $0.opacity(0.45) } ?? Palette.cardStroke, lineWidth: 1)
            )
    }
}

struct SectionLabel: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .tracking(0.6)
    }
}

/// Big primary call-to-action.
struct PrimaryButtonStyle: ButtonStyle {
    var color: Color = Palette.gold
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.display(18))
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous).fill(color))
            .opacity(configuration.isPressed ? 0.8 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.display(16, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous).fill(Color.white.opacity(0.10)))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

enum Haptics {
    static func tap() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func heavy() { UIImpactFeedbackGenerator(style: .heavy).impactOccurred() }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func warning() { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
}

/// Keeps the screen on during the auction and live matches.
struct KeepAwake: ViewModifier {
    func body(content: Content) -> some View {
        content
            .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
            .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
    }
}

extension View {
    func keepAwake() -> some View { modifier(KeepAwake()) }
}
