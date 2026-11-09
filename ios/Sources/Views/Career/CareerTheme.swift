import SwiftUI

// Game UI kit for career mode (and the home screen).
//
// Style reference: the CC0 (public-domain) game UI packs by Kenney (kenney.nl): framed panels
// with a darker bevel "lip", chunky 3D buttons that press down, ribbon headers and pill-shaped
// resource counters, as in mobile sports-manager games. Rebuilt here with SwiftUI shapes (no
// bitmap assets), so it stays sharp at every size and follows the text-size setting.

enum CareerPalette {
    // Stadium-at-night background
    static let bgTop = Color(hex: "#0C1E45")
    static let bgBottom = Color(hex: "#040A18")
    // Panels: face gradient, frame and bevel
    static let panel = Color(hex: "#12295A")
    static let panelHi = Color(hex: "#1D3F80")
    static let frame = Color(hex: "#050D22")
    static let bevel = Color(hex: "#0A1838")
    static let stroke = Color(hex: "#2E5BB0")
    static let highlight = Color.white.opacity(0.16)
    // Header plates and accents
    static let plateTop = Color(hex: "#2F6BD6")
    static let plateBottom = Color(hex: "#1B4497")
    static let green = Color(hex: "#3DDC6B")
    static let gold = Color(hex: "#FFC93C")
    static let ribbon = Color(hex: "#E8A21C")
    static let ribbonDark = Color(hex: "#9C6608")
}

/// Tells shared components (AppCard, SectionLabel, button styles, lists) to use the game kit.
struct CareerThemeKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var careerTheme: Bool {
        get { self[CareerThemeKey.self] }
        set { self[CareerThemeKey.self] = newValue }
    }
}

// MARK: - Background

/// Night stadium: deep blue, two floodlight glows, mowed-pitch stripes fading in at the bottom.
struct ManagerBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [CareerPalette.bgTop, CareerPalette.bgBottom], startPoint: .top, endPoint: .bottom)
            RadialGradient(colors: [Color.white.opacity(0.13), .clear], center: .topLeading, startRadius: 5, endRadius: 360)
            RadialGradient(colors: [Color.white.opacity(0.10), .clear], center: .topTrailing, startRadius: 5, endRadius: 320)
            GeometryReader { geo in
                HStack(spacing: 0) {
                    ForEach(0..<10, id: \.self) { i in
                        Rectangle().fill(Color(hex: "#1E7A3C").opacity(i % 2 == 0 ? 0.10 : 0.05))
                    }
                }
                .frame(height: geo.size.height * 0.35)
                .mask(LinearGradient(colors: [.clear, .white], startPoint: .top, endPoint: .bottom))
                .frame(maxHeight: .infinity, alignment: .bottom)
            }
            RadialGradient(colors: [.clear, Color.black.opacity(0.45)], center: .center, startRadius: 200, endRadius: 700)
        }
        .ignoresSafeArea()
    }
}

// MARK: - Frame (the kit's basic shape)

/// Dark outer frame, gradient face, inner highlight line and a darker bottom bevel.
struct GameFrame: ViewModifier {
    var radius: CGFloat = 12
    var face: [Color] = [CareerPalette.panelHi, CareerPalette.panel]
    var lip: CGFloat = 4

    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: radius, style: .continuous).fill(CareerPalette.bevel)
                        .offset(y: lip)
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill(LinearGradient(colors: face, startPoint: .top, endPoint: .bottom))
                    RoundedRectangle(cornerRadius: radius - 2, style: .continuous)
                        .stroke(CareerPalette.highlight, lineWidth: 1)
                        .padding(2)
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(CareerPalette.frame, lineWidth: 2)
            )
            .padding(.bottom, lip)
            .shadow(color: Color.black.opacity(0.45), radius: 6, y: 4)
    }
}

extension View {
    func gameFrame(radius: CGFloat = 12, face: [Color] = [CareerPalette.panelHi, CareerPalette.panel], lip: CGFloat = 4) -> some View {
        modifier(GameFrame(radius: radius, face: face, lip: lip))
    }

    /// Bold white game text with a dark drop edge.
    func gameText() -> some View {
        self.foregroundStyle(.white).shadow(color: Color.black.opacity(0.7), radius: 0, x: 0, y: 1.5)
    }
}

// MARK: - Panel

/// Framed panel with a header plate.
struct Panel<Content: View>: View {
    var title: String? = nil
    var icon: String? = nil
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let title {
                HStack(spacing: 6) {
                    if let icon { Image(systemName: icon).font(.caption.weight(.black)) }
                    Text(title.uppercased()).font(.display(14, weight: .heavy)).tracking(0.8)
                    Spacer()
                }
                .gameText()
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(LinearGradient(colors: [CareerPalette.plateTop, CareerPalette.plateBottom], startPoint: .top, endPoint: .bottom))
                .overlay(Rectangle().fill(Color.white.opacity(0.25)).frame(height: 1), alignment: .top)
                .overlay(Rectangle().fill(CareerPalette.frame).frame(height: 2), alignment: .bottom)
            }
            content
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .gameFrame()
    }
}

// MARK: - Ribbon section header

/// Gold ribbon with notched tail, for section titles.
struct RibbonLabel: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(.display(14, weight: .heavy))
            .tracking(0.8)
            .gameText()
            .padding(.leading, 12)
            .padding(.trailing, 22)
            .padding(.vertical, 5)
            .background(
                RibbonShape()
                    .fill(LinearGradient(colors: [CareerPalette.ribbon, CareerPalette.ribbonDark], startPoint: .top, endPoint: .bottom))
                    .overlay(RibbonShape().stroke(CareerPalette.frame, lineWidth: 2))
            )
            .padding(.top, 4)
    }
}

struct RibbonShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        let notch = r.height * 0.4
        p.move(to: CGPoint(x: r.minX + 4, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX - notch, y: r.midY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX + 4, y: r.maxY))
        p.addQuadCurve(to: CGPoint(x: r.minX + 4, y: r.minY), control: CGPoint(x: r.minX - 2, y: r.midY))
        p.closeSubpath()
        return p
    }
}

// MARK: - 3D buttons

/// Chunky button: coloured face on a darker base, pressing down when tapped.
struct GameButtonStyle: ButtonStyle {
    enum Kind { case primary, secondary, danger }
    var kind: Kind = .primary
    var fontSize: CGFloat = 20

    private var colors: (top: Color, bottom: Color, base: Color, text: Color) {
        switch kind {
        case .primary: return (Color(hex: "#8CF04A"), Color(hex: "#3CB81E"), Color(hex: "#1F6E0C"), Color(hex: "#062006"))
        case .secondary: return (Color(hex: "#4C86F0"), Color(hex: "#2456C2"), Color(hex: "#122E6E"), .white)
        case .danger: return (Color(hex: "#FF6B5E"), Color(hex: "#D7332A"), Color(hex: "#7E1512"), .white)
        }
    }

    func makeBody(configuration: Configuration) -> some View {
        let c = colors
        let pressed = configuration.isPressed
        return configuration.label
            .font(.display(fontSize))
            .textCase(.uppercase)
            .foregroundStyle(c.text)
            .shadow(color: kind == .primary ? Color.white.opacity(0.5) : Color.black.opacity(0.6), radius: 0, y: kind == .primary ? 1 : 1.5)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous).fill(c.base).offset(y: pressed ? 1 : 5)
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(LinearGradient(colors: [c.top, c.bottom], startPoint: .top, endPoint: .bottom))
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(LinearGradient(colors: [Color.white.opacity(0.35), .clear], startPoint: .top, endPoint: .center))
                        .padding(3)
                }
            )
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(CareerPalette.frame, lineWidth: 2))
            .offset(y: pressed ? 4 : 0)
            .padding(.bottom, 5)
            .animation(.spring(response: 0.18, dampingFraction: 0.6), value: pressed)
    }
}

// MARK: - HUD pieces

/// Pill-shaped resource counter with an icon badge (cash, gold, level…).
struct ResourceChip: View {
    let icon: String
    let value: String
    var color: Color = CareerPalette.gold

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11 * TextScale.factor, weight: .black))
                .foregroundStyle(CareerPalette.frame)
                .frame(width: 22, height: 22)
                .background(Circle().fill(LinearGradient(colors: [color, color.opacity(0.7)], startPoint: .top, endPoint: .bottom)))
                .overlay(Circle().stroke(CareerPalette.frame, lineWidth: 1.5))
            Text(value).font(.score(14)).gameText().lineLimit(1).minimumScaleFactor(0.7)
        }
        .padding(.leading, 3)
        .padding(.trailing, 10)
        .padding(.vertical, 3)
        .background(Capsule().fill(Color.black.opacity(0.45)))
        .overlay(Capsule().stroke(CareerPalette.stroke.opacity(0.8), lineWidth: 1.5))
    }
}

/// Dashboard tile: glossy icon badge, title plate, frame and bevel.
struct DashTile: View {
    let icon: String
    let title: String
    var subtitle: String = ""
    var badge: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                Image(systemName: icon)
                    .font(.system(size: 18 * TextScale.factor, weight: .black))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(
                        Circle().fill(LinearGradient(colors: [CareerPalette.plateTop, CareerPalette.plateBottom], startPoint: .top, endPoint: .bottom))
                    )
                    .overlay(Circle().fill(LinearGradient(colors: [Color.white.opacity(0.4), .clear], startPoint: .top, endPoint: .center)).padding(3))
                    .overlay(Circle().stroke(CareerPalette.frame, lineWidth: 2))
                Spacer()
                if let badge {
                    Text(badge).font(.display(12, weight: .heavy)).foregroundStyle(.white)
                        .padding(.horizontal, 7).padding(.vertical, 2)
                        .background(Capsule().fill(Color(hex: "#E5322D")))
                        .overlay(Capsule().stroke(CareerPalette.frame, lineWidth: 1.5))
                }
            }
            Text(title.uppercased()).font(.display(17, weight: .heavy)).gameText().lineLimit(1).minimumScaleFactor(0.7)
            Text(subtitle).font(.caption2.weight(.semibold)).foregroundStyle(Color.white.opacity(0.7)).lineLimit(2)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 112, alignment: .topLeading)
        .gameFrame()
        .contentShape(Rectangle())
    }
}

/// Club crest, name and manager, then the resource counters.
struct CareerTopBar: View {
    let career: Career

    var body: some View {
        let c = career
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                TeamBadge(team: c.userClub, size: 44)
                VStack(alignment: .leading, spacing: 1) {
                    Text(c.userClub.name.uppercased()).font(.display(19)).gameText().lineLimit(1).minimumScaleFactor(0.7)
                    Text("\(c.managerName)\(c.intl.job.map { " · \($0) coach" } ?? "")")
                        .font(.caption2.weight(.semibold)).foregroundStyle(Color.white.opacity(0.7)).lineLimit(1)
                }
                Spacer(minLength: 4)
                Text(c.phase == .offseason ? "OFF-SEASON" : CareerCalendar.label(c.currentDay).uppercased())
                    .font(.display(14, weight: .heavy)).gameText()
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Capsule().fill(Color.black.opacity(0.4)))
            }
            HStack(spacing: 6) {
                ResourceChip(icon: "indianrupeesign", value: Money.format(c.bank(c.userClubId)), color: CareerPalette.green)
                ResourceChip(icon: "circle.hexagongrid.fill", value: "\(c.gold)", color: CareerPalette.gold)
                ResourceChip(icon: "star.fill", value: "Lv \(c.manager.level)", color: Color(hex: "#7CC4FF"))
                Spacer(minLength: 0)
            }
        }
        .padding(10)
        .gameFrame(face: [Color(hex: "#244C9A"), Color(hex: "#132C61")])
    }
}

// MARK: - Screens and rows

/// A pushed career screen: stadium background, scrolling content.
struct CareerScreen<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            content
                .padding(DS.Space.lg)
                .frame(maxWidth: 760)
                .frame(maxWidth: .infinity)
        }
        .background(ManagerBackground())
        .environment(\.careerTheme, true)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Framed list-row background for career lists.
struct GameRowBackground: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(LinearGradient(colors: [CareerPalette.panelHi, CareerPalette.panel], startPoint: .top, endPoint: .bottom))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(CareerPalette.frame, lineWidth: 2))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(CareerPalette.highlight, lineWidth: 1).padding(2))
            .padding(.vertical, 2)
    }
}
