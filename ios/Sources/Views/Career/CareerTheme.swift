import SwiftUI

/// Manager-game look for career mode: deep navy desk, panels with header strips, a dashboard of
/// tiles and one big CONTINUE button.
enum CareerPalette {
    static let bgTop = Color(hex: "#0B1B3A")
    static let bgBottom = Color(hex: "#050C1C")
    static let panel = Color(hex: "#10264A")
    static let panelHi = Color(hex: "#18356A")
    static let stroke = Color(hex: "#284A86")
    static let green = Color(hex: "#22C55E")
    static let gold = Color(hex: "#FACC15")
}

/// Tells shared components (AppCard) to use career panel colours.
struct CareerThemeKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var careerTheme: Bool {
        get { self[CareerThemeKey.self] }
        set { self[CareerThemeKey.self] = newValue }
    }
}

struct ManagerBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [CareerPalette.bgTop, CareerPalette.bgBottom], startPoint: .top, endPoint: .bottom)
            RadialGradient(colors: [Color(hex: "#2563EB").opacity(0.18), .clear], center: .topTrailing, startRadius: 10, endRadius: 520)
        }
        .ignoresSafeArea()
    }
}

/// Panel with a header strip, the genre's basic building block.
struct Panel<Content: View>: View {
    var title: String? = nil
    var icon: String? = nil
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let title {
                HStack(spacing: 6) {
                    if let icon { Image(systemName: icon).font(.caption.weight(.bold)) }
                    Text(title.uppercased()).font(.display(13, weight: .heavy)).tracking(0.8)
                    Spacer()
                }
                .foregroundStyle(Color.white.opacity(0.85))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(CareerPalette.panelHi)
            }
            content
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(CareerPalette.panel)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(CareerPalette.stroke, lineWidth: 1))
    }
}

/// Dashboard tile.
struct DashTile: View {
    let icon: String
    let title: String
    var subtitle: String = ""
    var badge: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: icon).font(.title3).foregroundStyle(Palette.accent)
                Spacer()
                if let badge {
                    Text(badge).font(.display(11, weight: .heavy)).foregroundStyle(Palette.ink)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Capsule().fill(Palette.accent))
                }
            }
            Text(title.uppercased()).font(.display(16, weight: .heavy)).foregroundStyle(.white)
            Text(subtitle).font(.caption2).foregroundStyle(Color.white.opacity(0.6)).lineLimit(2)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 96, alignment: .topLeading)
        .background(LinearGradient(colors: [CareerPalette.panelHi, CareerPalette.panel], startPoint: .topLeading, endPoint: .bottomTrailing))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(CareerPalette.stroke, lineWidth: 1))
        .contentShape(Rectangle())
    }
}

/// Club, manager, date and money, always on top.
struct CareerTopBar: View {
    let career: Career

    var body: some View {
        let c = career
        HStack(spacing: 10) {
            TeamBadge(team: c.userClub, size: 38)
            VStack(alignment: .leading, spacing: 1) {
                Text(c.userClub.name.uppercased()).font(.display(17)).lineLimit(1).minimumScaleFactor(0.7)
                Text("\(c.managerName) · Lv \(c.manager.level)\(c.intl.job.map { " · \($0) coach" } ?? "")")
                    .font(.caption2).foregroundStyle(Color.white.opacity(0.6)).lineLimit(1)
            }
            Spacer(minLength: 4)
            VStack(alignment: .trailing, spacing: 1) {
                Text(c.phase == .offseason ? "OFF-SEASON \(String(c.year))" : "\(CareerCalendar.label(c.currentDay)) \(String(c.year))")
                    .font(.score(14))
                HStack(spacing: 8) {
                    Text(Money.format(c.bank(c.userClubId))).font(.score(12)).foregroundStyle(CareerPalette.green)
                    Text("🪙\(c.gold)").font(.score(12)).foregroundStyle(CareerPalette.gold)
                }
            }
        }
        .padding(10)
        .background(CareerPalette.panel)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(CareerPalette.stroke, lineWidth: 1))
    }
}

/// A pushed career screen: navy background, scrolling content.
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
