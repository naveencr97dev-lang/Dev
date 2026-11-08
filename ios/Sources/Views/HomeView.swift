import SwiftUI

struct HomeView: View {
    @EnvironmentObject var store: GameStore
    @Environment(\.verticalSizeClass) private var vSize
    @State private var appear = false

    var body: some View {
        let wide = vSize == .compact
        let layout = wide ? AnyLayout(HStackLayout(spacing: 40)) : AnyLayout(VStackLayout(spacing: DS.Space.xl))
        layout {
            VStack(alignment: .leading, spacing: 10) {
                Text("SEASON 2026").font(.display(16, weight: .heavy)).foregroundStyle(Palette.accent).tracking(2)
                Text("AUCTION\nXI").font(.display(wide ? 64 : 84)).lineSpacing(-14)
                    .offset(x: appear ? 0 : -30).opacity(appear ? 1 : 0)
                Text("Build an XI under the hammer. Survive the league. Lift the trophy.")
                    .font(.body).foregroundStyle(Palette.muted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: DS.Space.md) {
                step("01", "Live auction", "Pass the phone. Tap your crest to bid.")
                step("02", "League", "Ball-by-ball sims on five kinds of pitch.")
                step("03", "Playoffs", "Q1, Eliminator, Q2 — then the Final.")
                Button("New Game") { store.newGame() }
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.top, DS.Space.sm)
            }
            .frame(maxWidth: 420)
        }
        .padding(DS.Space.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { withAnimation(.spring(response: 0.6, dampingFraction: 0.75)) { appear = true } }
    }

    private func step(_ n: String, _ title: String, _ text: String) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Text(n).font(.display(24)).foregroundStyle(Palette.accent).frame(width: 34, alignment: .leading)
            VStack(alignment: .leading, spacing: 1) {
                Text(title.uppercased()).font(.display(18, weight: .heavy))
                Text(text).font(.subheadline).foregroundStyle(Palette.muted)
            }
        }
    }
}
