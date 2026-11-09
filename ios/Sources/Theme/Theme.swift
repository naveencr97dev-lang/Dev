import SwiftUI
import UIKit

// Night-match broadcast look: near-black, one electric accent, compressed italic type,
// slanted "score bug" shapes and springy motion (inspired by motion patterns on 60fps.design:
// counters, card flips, ticket pops, pulses, staggered lists).

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
            self.init(red: 0.84, green: 1, blue: 0.23)
        }
    }
}

enum Palette {
    static let accent = Color(hex: "#D7FF3A")      // floodlight lime
    static let ink = Color(hex: "#07080B")
    static let surface = Color(hex: "#12151C")
    static let surfaceHi = Color(hex: "#1B1F29")
    static let stroke = Color(hex: "#272B36")
    static let muted = Color(hex: "#8B90A0")
    static let four = Color(hex: "#38BDF8")
    static let six = Color(hex: "#E879F9")
    static let wicket = Color(hex: "#FF4D4D")
    static let card = surface
    static let cardStroke = stroke

    static let teamColors = ["#2563EB", "#EAB308", "#DC2626", "#7C3AED", "#0EA5E9",
                             "#F97316", "#E11D48", "#EC4899", "#06B6D4", "#14B8A6",
                             "#84CC16", "#64748B"]

    static func role(_ r: Role) -> Color {
        switch r {
        case .BAT: return Color(hex: "#F59E0B")
        case .WK: return Color(hex: "#22D3EE")
        case .AR: return Color(hex: "#A78BFA")
        case .BOWL: return Color(hex: "#F43F5E")
        }
    }
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
        static let sm: CGFloat = 6
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
    }
}

/// App-wide text size (Settings → Text size). Scales the custom display/score fonts; system text
/// styles follow through `dynamicTypeSize` at the root.
enum TextScale {
    static let storageKey = "textScaleV1"
    /// Default is Small: the standard sizes felt too big on the phone.
    static let defaultValue = 0.9
    static let options: [(label: String, value: Double)] = [("Extra small", 0.8), ("Small", 0.9), ("Standard", 1.0), ("Large", 1.1)]
    static var factor: CGFloat = CGFloat(defaultValue)

    static func dynamicType(_ v: Double) -> DynamicTypeSize {
        v <= 0.8 ? .xSmall : (v <= 0.9 ? .small : (v <= 1.0 ? .large : .xLarge))
    }
}

/// Picker for the text size, used inside menus.
struct TextSizePicker: View {
    @AppStorage(TextScale.storageKey) private var scale = TextScale.defaultValue

    var body: some View {
        Picker(selection: $scale) {
            ForEach(TextScale.options, id: \.value) { o in
                Text(o.label).tag(o.value)
            }
        } label: {
            Label("Text size", systemImage: "textformat.size")
        }
        .pickerStyle(.menu)
    }
}

extension Font {
    /// Broadcast headline: heavy, compressed, italic.
    static func display(_ size: CGFloat, weight: Font.Weight = .black) -> Font {
        .system(size: size * TextScale.factor, weight: weight).width(.compressed).italic()
    }
    /// Scoreboard numerals: condensed, tabular.
    static func score(_ size: CGFloat, weight: Font.Weight = .heavy) -> Font {
        .system(size: size * TextScale.factor, weight: weight).width(.condensed).monospacedDigit()
    }
}

struct AppBackground: View {
    var body: some View {
        ZStack {
            Palette.ink
            RadialGradient(colors: [Palette.accent.opacity(0.10), .clear], center: .topLeading, startRadius: 10, endRadius: 520)
            RadialGradient(colors: [Color(hex: "#2563EB").opacity(0.10), .clear], center: .bottomTrailing, startRadius: 10, endRadius: 600)
            // Mowed-pitch stripes, barely visible.
            GeometryReader { geo in
                HStack(spacing: 0) {
                    ForEach(0..<8, id: \.self) { i in
                        Rectangle().fill(Color.white.opacity(i % 2 == 0 ? 0.012 : 0))
                    }
                }
                .frame(width: geo.size.width * 1.4)
                .rotationEffect(.degrees(-12))
            }
        }
        .ignoresSafeArea()
    }
}

/// Surface with an optional team-colour edge bar.
struct AppCard<Content: View>: View {
    var padding: CGFloat = DS.Space.lg
    var tint: Color? = nil
    @ViewBuilder var content: Content
    /// Career screens use navy panels.
    @Environment(\.careerTheme) private var careerTheme

    private var surface: Color { careerTheme ? Color(hex: "#10264A") : Palette.surface }
    private var edge: Color { careerTheme ? Color(hex: "#284A86") : Palette.stroke }

    var body: some View {
        content
            .padding(padding)
            .padding(.leading, tint == nil ? 0 : 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous).fill(surface)
                    if let tint {
                        RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                            .fill(LinearGradient(colors: [tint.opacity(0.28), tint.opacity(0.02)], startPoint: .leading, endPoint: .trailing))
                        Rectangle().fill(tint).frame(width: 5)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
            )
            .overlay(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous).stroke(edge, lineWidth: 1))
    }
}

/// Section header with a lime slash.
struct SectionLabel: View {
    let text: String
    var body: some View {
        HStack(spacing: 6) {
            Slant().fill(Palette.accent).frame(width: 7, height: 14)
            Text(text.uppercased())
                .font(.display(15, weight: .heavy))
                .foregroundStyle(Palette.muted)
                .tracking(0.8)
        }
    }
}

/// Parallelogram — the broadcast score-bug shape.
struct Slant: Shape {
    var skew: CGFloat = 0.28
    func path(in r: CGRect) -> Path {
        let dx = r.height * skew
        var p = Path()
        p.move(to: CGPoint(x: r.minX + dx, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX - dx, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX, y: r.maxY))
        p.closeSubpath()
        return p
    }
}

/// Ticket with punched notches on both sides.
struct TicketShape: Shape {
    var notch: CGFloat = 14
    var radius: CGFloat = 18
    func path(in r: CGRect) -> Path {
        var p = Path(roundedRect: r, cornerRadius: radius, style: .continuous)
        let y = r.midY
        p.addEllipse(in: CGRect(x: r.minX - notch, y: y - notch, width: notch * 2, height: notch * 2))
        p.addEllipse(in: CGRect(x: r.maxX - notch, y: y - notch, width: notch * 2, height: notch * 2))
        return p
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    var color: Color = Palette.accent
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.display(21))
            .textCase(.uppercase)
            .foregroundStyle(Palette.ink)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous).fill(color))
            .shadow(color: color.opacity(configuration.isPressed ? 0.2 : 0.45), radius: configuration.isPressed ? 4 : 14, y: 4)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.display(17, weight: .heavy))
            .textCase(.uppercase)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous).fill(Palette.surfaceHi))
            .overlay(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous).stroke(Palette.stroke, lineWidth: 1))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
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

/// Rows slide up and fade in one after another.
struct Staggered: ViewModifier {
    let index: Int
    @State private var shown = false
    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : 14)
            .onAppear {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.8).delay(Double(min(index, 12)) * 0.04)) { shown = true }
            }
    }
}

/// Soft breathing glow, for the leading bidder.
struct Pulse: ViewModifier {
    let color: Color
    let active: Bool
    @State private var on = false
    func body(content: Content) -> some View {
        content
            .shadow(color: color.opacity(active ? (on ? 0.85 : 0.3) : 0), radius: active ? (on ? 16 : 6) : 0)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) { on = true }
            }
    }
}

/// Landscape: two fixed-width scrolling columns that can never push past the screen edges.
struct TwoColumns<Left: View, Right: View>: View {
    @ViewBuilder var left: Left
    @ViewBuilder var right: Right

    var body: some View {
        GeometryReader { geo in
            let gap = DS.Space.md
            let col = max(0, (geo.size.width - gap) / 2)
            HStack(alignment: .top, spacing: gap) {
                // Each column is centred vertically when it fits, and scrolls when it doesn't.
                ScrollView(showsIndicators: false) {
                    VStack(spacing: DS.Space.sm) { left }
                        .frame(width: col)
                        .padding(.vertical, DS.Space.sm)
                        .frame(minHeight: geo.size.height)
                }
                .frame(width: col)
                ScrollView(showsIndicators: false) {
                    VStack(spacing: DS.Space.sm) { right }
                        .frame(width: col)
                        .padding(.vertical, DS.Space.sm)
                        .frame(minHeight: geo.size.height)
                }
                .frame(width: col)
            }
            .frame(width: geo.size.width, alignment: .top)
        }
        .padding(.horizontal, DS.Space.md)
    }
}

extension View {
    func keepAwake() -> some View { modifier(KeepAwake()) }
    func staggered(_ index: Int) -> some View { modifier(Staggered(index: index)) }
    func pulse(_ color: Color, active: Bool) -> some View { modifier(Pulse(color: color, active: active)) }
}
