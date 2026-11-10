import SwiftUI

// Career look v3: clean and native.
//
// Guided by the "taste-mobile-app-skill" (github.com/orbitextechlab/taste-mobile-app-skill) list of
// generated-UI tells and Apple's HIG: iOS dark system colours, one accent (outfield green), a
// six-size type scale, flat grouped surfaces with hairlines, SF Symbols (no emoji as icons), no
// decorative gradients, borders or glows, native-feeling bars. Type names are kept from v1/v2 so
// every screen picks the new look up without changes.

enum CareerPalette {
    static let bgTop = Palette.ink
    static let bgBottom = Palette.ink
    static let panel = Palette.surface
    static let panelHi = Palette.surfaceHi
    static let frame = Palette.stroke
    static let bevel = Palette.surface
    static let stroke = Palette.stroke
    static let highlight = Color.clear
    static let plateTop = Palette.surfaceHi
    static let plateBottom = Palette.surfaceHi
    static let green = Palette.accent
    static let gold = Color(hex: "#FFD60A")
    static let ribbon = Palette.surfaceHi
    static let ribbonDark = Palette.surfaceHi
}

/// Career screens (kept for call sites; the look is now shared by the whole app).
struct CareerThemeKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var careerTheme: Bool {
        get { self[CareerThemeKey.self] }
        set { self[CareerThemeKey.self] = newValue }
    }
}

/// Landscape on a phone (about 440 pt tall): rows and cards tighten, layouts go two-column.
struct CompactLandscapeKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var compactLandscape: Bool {
        get { self[CompactLandscapeKey.self] }
        set { self[CompactLandscapeKey.self] = newValue }
    }
}

/// Two columns in landscape, each scrolling on its own (device feedback: they scrolled together);
/// one stacked column in portrait, inside the screen's scroll view.
struct AdaptiveColumns<Left: View, Right: View>: View {
    @Environment(\.compactLandscape) private var landscape
    /// false: the left column is fixed (e.g. the XI) and only the right one scrolls.
    var leftScrolls = true
    @ViewBuilder var left: Left
    @ViewBuilder var right: Right

    var body: some View {
        if landscape {
            HStack(alignment: .top, spacing: DS.Space.md) {
                if leftScrolls {
                    column { left }
                } else {
                    VStack(alignment: .leading, spacing: DS.Space.sm) { left }
                        .padding(.vertical, DS.Space.sm)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
                column { right }
            }
        } else {
            VStack(alignment: .leading, spacing: DS.Space.md) {
                left
                right
            }
        }
    }

    private func column<C: View>(@ViewBuilder _ content: () -> C) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Space.md) { content() }
                .padding(.vertical, DS.Space.sm)
                .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

struct ManagerBackground: View {
    var body: some View { Palette.ink.ignoresSafeArea() }
}

/// Flat grouped surface (API kept from the v2 kit).
struct GameFrame: ViewModifier {
    var radius: CGFloat = 12
    var face: [Color] = []
    var lip: CGFloat = 0

    func body(content: Content) -> some View {
        content.background(RoundedRectangle(cornerRadius: radius, style: .continuous).fill(Palette.surface))
    }
}

extension View {
    func gameFrame(radius: CGFloat = 12, face: [Color] = [], lip: CGFloat = 0) -> some View {
        modifier(GameFrame(radius: radius, face: face, lip: lip))
    }

    func gameText() -> some View { self.foregroundStyle(.white) }
}

/// One-pixel separator.
struct Hairline: View {
    var inset: CGFloat = 0
    var body: some View {
        Rectangle().fill(Palette.stroke).frame(height: 0.5).padding(.leading, inset)
    }
}

struct Panel<Content: View>: View {
    var title: String? = nil
    var icon: String? = nil
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let title { SectionLabel(text: title) }
            content
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .gameFrame()
        }
    }
}

struct RibbonLabel: View {
    let text: String
    var body: some View { SectionLabel(text: text) }
}

/// Flat button styles by role.
struct GameButtonStyle: ButtonStyle {
    enum Kind { case primary, secondary, danger }
    var kind: Kind = .primary
    var fontSize: CGFloat = 16

    func makeBody(configuration: Configuration) -> some View {
        let fill: Color = kind == .primary ? Palette.accent : (kind == .danger ? Palette.wicket : Palette.surfaceHi)
        let text: Color = kind == .primary ? Palette.ink : (kind == .danger ? .white : Palette.accent)
        return configuration.label
            .font(.system(size: TypeScale.snap(fontSize) * TextScale.factor, weight: .semibold))
            .foregroundStyle(text)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(fill))
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}

/// Small value with an SF Symbol (money, gold, level).
struct ResourceChip: View {
    let icon: String
    let value: String
    var color: Color = Palette.muted

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 12 * TextScale.factor, weight: .semibold)).foregroundStyle(color)
            Text(value).font(.score(14)).foregroundStyle(.white).lineLimit(1)
        }
    }
}

/// Navigation row: naked SF Symbol, title, detail, optional count, chevron.
struct DashTile: View {
    @Environment(\.compactLandscape) private var compact
    let icon: String
    let title: String
    var subtitle: String = ""
    var badge: String? = nil

    var body: some View {
        HStack(spacing: compact ? 10 : 12) {
            Image(systemName: icon)
                .font(.system(size: (compact ? 15 : 17) * TextScale.factor, weight: .medium))
                .foregroundStyle(Palette.accent)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: (compact ? 15 : 16) * TextScale.factor, weight: .semibold)).foregroundStyle(.white)
                if !subtitle.isEmpty {
                    Text(subtitle).font(.system(size: (compact ? 12 : 14) * TextScale.factor)).foregroundStyle(Palette.muted).lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            if let badge {
                Text(badge).font(.system(size: 12 * TextScale.factor, weight: .bold)).foregroundStyle(.white)
                    .padding(.horizontal, 7).padding(.vertical, 2)
                    .background(Capsule().fill(Palette.wicket))
            }
            Image(systemName: "chevron.right").font(.system(size: 13 * TextScale.factor, weight: .semibold)).foregroundStyle(Palette.stroke)
        }
        .padding(.horizontal, compact ? 12 : 14)
        .padding(.vertical, compact ? 7 : 10)
        .contentShape(Rectangle())
    }
}

/// Large-title header: club, manager and date, then money, gold and level.
struct CareerTopBar: View {
    let career: Career

    var body: some View {
        let c = career
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                TeamBadge(team: c.userClub, size: 40)
                VStack(alignment: .leading, spacing: 1) {
                    Text(c.userClub.name).font(.system(size: 28 * TextScale.factor, weight: .bold)).foregroundStyle(.white)
                        .lineLimit(1).minimumScaleFactor(0.7)
                    Text("\(c.managerName) · \(c.phase == .offseason ? "Off-season \(String(c.year))" : "\(CareerCalendar.label(c.currentDay)) \(String(c.year))")")
                        .font(.system(size: 14 * TextScale.factor)).foregroundStyle(Palette.muted).lineLimit(1)
                }
            }
            HStack(spacing: 16) {
                ResourceChip(icon: "indianrupeesign.circle.fill", value: Money.format(c.bank(c.userClubId)), color: Palette.accent)
                ResourceChip(icon: "circle.hexagongrid.fill", value: "\(c.gold)", color: CareerPalette.gold)
                ResourceChip(icon: "star.fill", value: "Level \(c.manager.level)", color: Palette.four)
                Spacer(minLength: 0)
            }
        }
        .padding(.vertical, 4)
    }
}

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
        .background(Palette.ink)
        .environment(\.careerTheme, true)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// List-row background.
struct GameRowBackground: View {
    var body: some View { Palette.surface }
}
