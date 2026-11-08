import SwiftUI

struct RootView: View {
    @EnvironmentObject var store: Store

    var body: some View {
        TabView {
            TodayView()
                .tabItem { Label("Today", systemImage: "checklist") }
            GoalsView()
                .tabItem { Label("Goals", systemImage: "target") }
            GroceriesView()
                .tabItem { Label("Restock", systemImage: "cart.fill") }
            StatsView()
                .tabItem { Label("Reports", systemImage: "list.clipboard.fill") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
    }
}
