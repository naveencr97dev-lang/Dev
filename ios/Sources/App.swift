import SwiftUI

@main
struct AuctionXIApp: App {
    @StateObject private var store = GameStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .preferredColorScheme(.dark)
                .tint(Palette.accent)
        }
        .onChange(of: scenePhase) { phase in
            if phase != .active {
                store.paused = true
                store.save()
            }
        }
    }
}

struct RootView: View {
    @EnvironmentObject var store: GameStore

    var body: some View {
        ZStack {
            AppBackground()
            if let phase = store.game?.phase {
                switch phase {
                case .setup: NavigationStack { SetupView() }
                case .auction: AuctionView()
                case .squads: NavigationStack { SquadsView(preseason: true) }
                case .season: SeasonView()
                case .champion: NavigationStack { ChampionView() }
                }
            } else {
                HomeView()
            }
        }
        .animation(.easeInOut(duration: 0.25), value: store.game?.phase)
    }
}
