import SwiftUI

@main
struct StreakletApp: App {
    @StateObject private var store = Store()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .preferredColorScheme(store.appearance.colorScheme)
                .dynamicTypeSize(store.textSize.dynamicTypeSize)
        }
    }
}
