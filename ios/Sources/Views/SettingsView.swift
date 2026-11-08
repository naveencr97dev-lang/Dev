import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var store: Store
    @State private var showingReset = false

    var body: some View {
        NavigationStack {
            List {
                Section("Appearance") {
                    Picker("Theme", selection: $store.appearance) {
                        ForEach(AppearanceMode.allCases) { Text($0.label).tag($0) }
                    }
                    .onChange(of: store.appearance) { _ in store.save() }
                }

                Section("Notifications") {
                    Button("Enable reminders") {
                        Reminders.requestAuthorization { Reminders.sync(store: store) }
                    }
                    Text("Habits with a daily reminder time will notify you.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Data") {
                    Button("Load sample habits") { store.seedDemoIfEmpty() }
                    Button("Reset all data", role: .destructive) { showingReset = true }
                }

                Section("About") {
                    row("App", "Streaklet")
                    row("Version", "1.0.0")
                    Text("An original habit tracker. Build routines, keep streaks, track your mood.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
            .alert("Reset all data?", isPresented: $showingReset) {
                Button("Cancel", role: .cancel) {}
                Button("Reset", role: .destructive) { store.resetAll() }
            } message: {
                Text("This permanently deletes all habits, check-ins and journal entries.")
            }
        }
    }

    private func row(_ k: String, _ v: String) -> some View {
        HStack { Text(k); Spacer(); Text(v).foregroundStyle(.secondary) }
    }
}
