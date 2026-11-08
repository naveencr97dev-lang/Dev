import SwiftUI

struct HomeView: View {
    @EnvironmentObject var store: GameStore

    var body: some View {
        VStack(spacing: DS.Space.xl) {
            Spacer()
            ZStack {
                Circle().fill(Palette.gold.opacity(0.15)).frame(width: 150, height: 150)
                Text("🏏").font(.system(size: 76))
                Text("🔨").font(.system(size: 40)).offset(x: 48, y: 42)
            }
            VStack(spacing: 8) {
                Text("Auction XI").font(.display(44, weight: .heavy))
                Text("Bid for your squad. Survive the league.\nLift the trophy.")
                    .font(.body).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
            VStack(alignment: .leading, spacing: 12) {
                step("1", "Live auction", "Pass the phone around and tap your team to bid.")
                step("2", "League season", "Every team plays everyone, with results after each match.")
                step("3", "Playoffs & Final", "The top 4 fight it out for the trophy.")
            }
            .padding(.horizontal, DS.Space.xl)
            Spacer()
            Button("New Game") { store.newGame() }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, DS.Space.xl)
            Text("For 3+ players on one phone · CPU teams fill the league")
                .font(.footnote).foregroundStyle(.secondary)
                .padding(.bottom, DS.Space.lg)
        }
    }

    private func step(_ n: String, _ title: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(n).font(.display(15, weight: .heavy)).foregroundStyle(.black)
                .frame(width: 26, height: 26).background(Circle().fill(Palette.gold))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(text).font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }
}
