import SwiftUI

struct RootView: View {
    @EnvironmentObject var store: Store

    var body: some View {
        TabView {
            TodayView()
                .tabItem { Label("Today", systemImage: "checklist") }
            CalendarView()
                .tabItem { Label("Calendar", systemImage: "calendar") }
            GoalsView()
                .tabItem { Label("Goals", systemImage: "target") }
            GroceriesView()
                .tabItem { Label("Restock", systemImage: "cart.fill") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
    }
}
