import SwiftUI

/// Team crest: rounded tile in team colour with a diagonal sash.
struct TeamBadge: View {
    let team: Franchise
    var size: CGFloat = 40

    var body: some View {
        let color = Color(hex: team.colorHex)
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous).fill(color)
            Slant(skew: 0.6)
                .fill(Color.white.opacity(0.16))
                .frame(width: size * 0.42)
                .offset(x: size * 0.18)
            Text(team.short)
                .font(.display(size * 0.36))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .padding(.horizontal, 3)
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.28, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: size * 0.28, style: .continuous).stroke(Color.white.opacity(0.18), lineWidth: 1))
    }
}

struct Chip: View {
    let text: String
    var color: Color = Palette.surfaceHi
    var textColor: Color = .white
    var body: some View {
        Text(text.uppercased())
            .font(.display(12, weight: .heavy))
            .foregroundStyle(textColor)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(RoundedRectangle(cornerRadius: 4, style: .continuous).fill(color))
    }
}

struct RoleChip: View {
    let role: Role
    var body: some View {
        Chip(text: role.short, color: Palette.role(role).opacity(0.22), textColor: Palette.role(role))
    }
}

struct RatingBar: View {
    let label: String
    let value: Int
    let color: Color
    @State private var fill: CGFloat = 0

    var body: some View {
        HStack(spacing: 8) {
            Text(label).font(.display(13, weight: .heavy)).foregroundStyle(Palette.muted).frame(width: 36, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.07))
                    Capsule().fill(color).frame(width: geo.size.width * fill)
                }
            }
            .frame(height: 6)
            Text("\(value)").font(.score(15)).frame(width: 28, alignment: .trailing)
        }
        .onAppear { withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) { fill = CGFloat(value) / 100 } }
        .onChange(of: value) { v in withAnimation(.spring()) { fill = CGFloat(v) / 100 } }
    }
}

/// Legend trait badges.
struct TraitChips: View {
    let traits: [Trait]
    var showBlurb = false
    /// One row (landscape): labels if they fit, otherwise icons only.
    var inline = false

    private func color(_ t: Trait) -> Color { t.isBatting ? Color(hex: "#F59E0B") : Color(hex: "#F43F5E") }

    var body: some View {
        if inline && !traits.isEmpty {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) {
                    ForEach(traits, id: \.self) { t in
                        Text("\(t.icon) \(t.label.uppercased())").font(.display(12, weight: .heavy))
                            .foregroundStyle(color(t)).fixedSize()
                    }
                }
                HStack(spacing: 8) {
                    ForEach(traits, id: \.self) { t in
                        Text("\(t.icon) \(t.label.split(separator: " ").first.map(String.init)?.uppercased() ?? "")")
                            .font(.display(11, weight: .heavy)).foregroundStyle(color(t)).fixedSize()
                    }
                }
                HStack(spacing: 6) {
                    ForEach(traits, id: \.self) { t in Text(t.icon) }
                }
            }
        } else if !traits.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(traits, id: \.self) { t in
                    HStack(spacing: 6) {
                        Text(t.icon)
                        Text(t.label.uppercased()).font(.display(13, weight: .heavy))
                            .foregroundStyle(t.isBatting ? Color(hex: "#F59E0B") : Color(hex: "#F43F5E"))
                            .fixedSize()
                        if showBlurb {
                            Text(t.blurb).font(.caption).foregroundStyle(Palette.muted).lineLimit(1)
                        }
                    }
                    .lineLimit(1)
                }
            }
        }
    }
}

struct PlayerRow: View {
    let player: Player
    var price: Int? = nil
    var trailing: String? = nil

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Text(player.name).font(.body.weight(.semibold)).lineLimit(1)
                    if player.overseas { Image(systemName: "airplane").font(.caption2).foregroundStyle(Palette.muted) }
                    if player.legend { Text("★").font(.caption).foregroundStyle(Palette.accent) }
                    if !player.traits.isEmpty { Text(player.traits.map(\.icon).joined()).font(.caption) }
                }
                HStack(spacing: 6) {
                    RoleChip(role: player.role)
                    Text("BAT \(player.bat) · BOWL \(player.bowl)\(player.bowl >= 40 ? " " + (player.bowlType == .spin ? "spin" : "pace") : "")")
                        .font(.caption2).foregroundStyle(Palette.muted)
                }
            }
            Spacer()
            if let price { Text(Money.format(price)).font(.score(16)) }
            if let trailing { Text(trailing).font(.subheadline.weight(.semibold)).foregroundStyle(Palette.muted) }
        }
        .padding(.vertical, 2)
    }
}

/// Quit-game menu item used in several toolbars.
struct QuitMenuItem: View {
    @Binding var confirm: Bool
    var body: some View {
        Button(role: .destructive) { confirm = true } label: { Label("Quit game", systemImage: "xmark.circle") }
    }
}

extension View {
    func quitConfirmation(_ isPresented: Binding<Bool>, store: GameStore) -> some View {
        confirmationDialog("Quit this game? Progress will be lost.", isPresented: isPresented, titleVisibility: .visible) {
            Button("Quit game", role: .destructive) { store.reset() }
            Button("Keep playing", role: .cancel) {}
        }
    }

    /// Standard list styling on the dark background (navy in career mode).
    func darkList() -> some View { modifier(DarkListBackground()) }
}

struct DarkListBackground: ViewModifier {
    @Environment(\.careerTheme) private var careerTheme

    func body(content: Content) -> some View {
        content
            .scrollContentBackground(.hidden)
            .background(Group {
                if careerTheme { ManagerBackground() } else { AppBackground() }
            })
    }
}

/// Segmented speed control: ¼× ½× 1× 2× 4×.
struct SpeedPicker: View {
    @Binding var speed: Double
    let options: [Double]
    /// Optional custom labels, one per option.
    var labels: [String]? = nil

    var body: some View {
        Picker("Speed", selection: $speed) {
            ForEach(Array(options.enumerated()), id: \.offset) { i, v in
                Text(labels.map { $0[i] } ?? SpeedPicker.label(v)).tag(v)
            }
        }
        .pickerStyle(.segmented)
        .onAppear {
            // A remembered speed this control doesn't offer falls back to the first option.
            if !options.contains(speed), let first = options.first { speed = first }
        }
    }

    static func label(_ v: Double) -> String {
        switch v {
        case 0.25: return "¼×"
        case 0.5: return "½×"
        default: return "\(Int(v))×"
        }
    }
}
