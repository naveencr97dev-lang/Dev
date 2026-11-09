import SwiftUI

/// Career › Settings: difficulty, market test switch, text size.
struct CareerSettingsView: View {
    @EnvironmentObject var store: GameStore

    var body: some View {
        let c = store.career
        List {
            Section {
                Picker("Difficulty", selection: Binding(get: { c?.settings.difficulty ?? .normal },
                                                        set: { store.careerSetDifficulty($0) })) {
                    ForEach(Difficulty.allCases) { d in Text(d.label).tag(d) }
                }
                .pickerStyle(.segmented)
                Text((c?.settings.difficulty ?? .normal).blurb).font(.caption).foregroundStyle(Palette.muted)
            } header: {
                Text("Difficulty")
            } footer: {
                Text("Change it any time. It sets your players' match boost, transfer prices and wages, your club's income, and how hard rival clubs bid.")
            }
            .listRowBackground(GameRowBackground())

            Section {
                Toggle("Assistant picks my XI", isOn: Binding(get: { c?.settings.assistantPicksXI ?? true },
                                                              set: { store.careerSetAssistantPicksXI($0) }))
            } header: {
                Text("Team selection")
            } footer: {
                Text("On: your assistant fields the best XI and batting order before every match. Picking the XI yourself turns this off.")
            }
            .listRowBackground(GameRowBackground())

            Section {
                Toggle("Market always open", isOn: Binding(get: { c?.settings.marketAlwaysOpen ?? true },
                                                           set: { store.careerSetMarketAlwaysOpen($0) }))
            } header: {
                Text("Testing")
            } footer: {
                Text("On: buy, sell and negotiate at any time. Off: real windows (off-season, rounds 1–2, before round 25).")
            }
            .listRowBackground(GameRowBackground())

            Section("Display") {
                TextSizePicker()
            }
            .listRowBackground(GameRowBackground())

            Section {
                SoundToggles()
            } header: {
                Text("Sound")
            } footer: {
                Text("Original music and match sounds. They follow your iPhone's silent switch and play alongside your own music.")
            }
            .listRowBackground(GameRowBackground())
        }
        .darkList()
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}
