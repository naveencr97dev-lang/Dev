import SwiftUI

struct RootView: View {
    @EnvironmentObject var store: Store

    var body: some View {
        TabView {
            TodayView()
                .tabItem { Label("Today", systemImage: "checklist") }
            StatsView()
                .tabItem { Label("Reports", systemImage: "list.clipboard.fill") }
            MoodView()
                .tabItem { Label("Journal", systemImage: "face.smiling") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
    }
}
