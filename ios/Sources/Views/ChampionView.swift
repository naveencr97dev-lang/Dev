import SwiftUI

struct ChampionView: View {
    @EnvironmentObject var store: GameStore
    @State private var confirmNew = false
    @State private var burst = 0

    var body: some View {
        ZStack {
            ScrollView {
                if let g = store.game, let champ = g.championId.flatMap({ g.team($0) }) {
                    let awards = g.awards()
                    VStack(spacing: DS.Space.lg) {
                        Text("🏆").font(.system(size: 110)).padding(.top, DS.Space.lg)
                        Text("CHAMPIONS").font(.display(16, weight: .heavy)).tracking(4).foregroundStyle(Palette.gold)
                        TeamBadge(team: champ, size: 86)
                        Text(champ.name).font(.display(32, weight: .heavy)).multilineTextAlignment(.center)
                        if let final = g.results.last(where: { $0.stage == .final }) {
                            Text("\(champ.short) \(final.margin) in the Final")
                                .font(.headline).foregroundStyle(.secondary)
                            NavigationLink { ResultScreen(resultId: final.id) } label: {
                                Label("Final scorecard", systemImage: "list.bullet.rectangle")
                            }
                            .buttonStyle(SecondaryButtonStyle())
                        }

                        VStack(alignment: .leading, spacing: DS.Space.sm) {
                            SectionLabel(text: "Season awards")
                            AppCard(padding: DS.Space.md) {
                                VStack(spacing: 12) {
                                    if let s = awards.orangeCap { award("🟠", "Orange Cap", s, "\(s.runs) runs") }
                                    if let s = awards.purpleCap { award("🟣", "Purple Cap", s, "\(s.wickets) wickets") }
                                    if let s = awards.mvp { award("⭐", "Most Valuable Player", s, "\(Int(s.mvpPoints)) pts") }
                                    if let s = awards.mostSixes { award("💥", "Most sixes", s, "\(s.sixes) sixes") }
                                    if let buy = awards.bestBuy { award("💰", "Best buy", buy.0, "bought for \(Money.format(buy.1))") }
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: DS.Space.sm) {
                            SectionLabel(text: "Final table")
                            PointsTableView()
                        }

                        Button("New Game") { confirmNew = true }
                            .buttonStyle(PrimaryButtonStyle())
                            .padding(.vertical, DS.Space.lg)
                    }
                    .padding(DS.Space.lg)
                }
            }
            ConfettiView().id(burst).ignoresSafeArea()
        }
        .background(AppBackground())
        .navigationTitle("Trophy")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { burst += 1; Haptics.success() } label: { Image(systemName: "sparkles") }
            }
        }
        .onAppear { Haptics.success() }
        .confirmationDialog("Start a new game? This season will be cleared.", isPresented: $confirmNew, titleVisibility: .visible) {
            Button("New Game") { store.reset(); store.newGame() }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func award(_ icon: String, _ title: String, _ s: PlayerSeason, _ stat: String) -> some View {
        HStack(spacing: 10) {
            Text(icon).font(.title2)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.caption.weight(.bold)).foregroundStyle(.secondary)
                Text(store.player(s.id)?.name ?? "").font(.subheadline.weight(.semibold))
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                if let t = store.team(s.teamId) { TeamBadge(team: t, size: 22) }
                Text(stat).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }
        }
    }
}
