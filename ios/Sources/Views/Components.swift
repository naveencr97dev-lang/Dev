import SwiftUI

struct TeamBadge: View {
    let team: Franchise
    var size: CGFloat = 40

    var body: some View {
        Text(team.short)
            .font(.display(size * 0.32, weight: .heavy))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(Circle().fill(Color(hex: team.colorHex)))
            .overlay(Circle().stroke(Color.white.opacity(0.25), lineWidth: 1))
    }
}

struct Chip: View {
    let text: String
    var color: Color = .white.opacity(0.15)
    var body: some View {
        Text(text)
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Capsule().fill(color))
    }
}

struct RatingBar: View {
    let label: String
    let value: Int
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Text(label).font(.caption2.weight(.bold)).foregroundStyle(.secondary).frame(width: 34, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.08))
                    Capsule().fill(color).frame(width: geo.size.width * CGFloat(value) / 100)
                }
            }
            .frame(height: 7)
            Text("\(value)").font(.caption.monospacedDigit().weight(.semibold)).frame(width: 26, alignment: .trailing)
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
                    if player.overseas { Image(systemName: "airplane").font(.caption2).foregroundStyle(.secondary) }
                }
                HStack(spacing: 6) {
                    Chip(text: player.role.short)
                    Text("BAT \(player.bat) · BOWL \(player.bowl)").font(.caption2).foregroundStyle(.secondary)
                }
            }
            Spacer()
            if let price { Text(Money.format(price)).font(.subheadline.monospacedDigit().weight(.semibold)) }
            if let trailing { Text(trailing).font(.subheadline.weight(.semibold)).foregroundStyle(.secondary) }
        }
        .padding(.vertical, 2)
    }
}

/// Quit-game confirmation used in several toolbars.
struct QuitMenuItem: View {
    @EnvironmentObject var store: GameStore
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
}
