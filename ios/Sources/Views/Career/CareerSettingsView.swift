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
            .listRowBackground(CareerPalette.panel)

            Section {
                Toggle("Market always open", isOn: Binding(get: { c?.settings.marketAlwaysOpen ?? true },
                                                           set: { store.careerSetMarketAlwaysOpen($0) }))
            } header: {
                Text("Testing")
            } footer: {
                Text("On: buy, sell and negotiate at any time. Off: real windows (off-season, rounds 1–2, before round 25).")
            }
            .listRowBackground(CareerPalette.panel)

            Section("Display") {
                TextSizePicker()
            }
            .listRowBackground(CareerPalette.panel)
        }
        .darkList()
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}
