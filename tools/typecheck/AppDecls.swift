// Stand-ins for app views that the type-check harness doesn't compile (they use Charts/Timer etc.).
// Keep their signatures in step with the real files: MatchView.swift.
import SwiftUI

struct MatchView: View {
    @EnvironmentObject var store: GameStore
    let fixtureId: Int
    var body: some View { EmptyView() }
}

struct ResultScreen: View {
    @EnvironmentObject var store: GameStore
    let resultId: UUID
    var autoplay = false
    var body: some View { EmptyView() }
}
