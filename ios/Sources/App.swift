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
                .onAppear { GameAudio.shared.play(.theme) }
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active { GameAudio.shared.resume() }
            if phase != .active {
                store.paused = true
                store.save()
            }
        }
    }
}

struct RootView: View {
    @EnvironmentObject var store: GameStore
    @AppStorage(TextScale.storageKey) private var textScale = TextScale.defaultValue

    var body: some View {
        let _ = (TextScale.factor = CGFloat(textScale))
        ZStack {
            AppBackground()
            if store.inCareer && store.career != nil {
                CareerHubView()
                    .environment(\.careerTheme, true)
            } else if let phase = store.game?.phase {
                switch phase {
                case .setup: NavigationStack { SetupView() }
                case .auction: AuctionView()
                case .squads: NavigationStack { SquadsView(preseason: true) }
                case .season: SeasonView()
                case .champion: NavigationStack { ChampionView() }
                }
            } else {
                ZStack {
                    ManagerBackground()
                    HomeView()
                }
                .environment(\.careerTheme, true)
            }
        }
        // Rebuild everything when the text size changes, so every font picks up the new scale.
        .id(textScale)
        .dynamicTypeSize(TextScale.dynamicType(textScale))
        .animation(.easeInOut(duration: 0.25), value: store.game?.phase)
        .animation(.easeInOut(duration: 0.25), value: store.inCareer)
    }
}
