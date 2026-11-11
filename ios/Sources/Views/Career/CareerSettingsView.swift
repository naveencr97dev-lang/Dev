import SwiftUI

/// Career › Settings: difficulty, market test switch, text size.
struct CareerSettingsView: View {
    @EnvironmentObject var store: GameStore

    var body: some View {
        let c = store.career
        PaneScreen(title: "Settings") {
            PaneBox(title: "Difficulty", note: "Change it any time. It sets your players' match boost, prices and wages, your income, and how hard rivals bid.") {
                Picker("Difficulty", selection: Binding(get: { c?.settings.difficulty ?? .normal },
                                                        set: { store.careerSetDifficulty($0) })) {
                    ForEach(Difficulty.allCases) { d in Text(d.label).tag(d) }
                }
                .pickerStyle(.segmented)
                Text((c?.settings.difficulty ?? .normal).blurb).font(.system(size: 12 * TextScale.factor)).foregroundStyle(Palette.muted)
            }
            PaneBox(title: "Team selection", note: "On: your assistant fields the best XI and order for each match's pitch. Picking the XI yourself turns this off.") {
                Toggle("Assistant picks my XI", isOn: Binding(get: { c?.settings.assistantPicksXI ?? true },
                                                              set: { store.careerSetAssistantPicksXI($0) }))
                    .font(.system(size: 14 * TextScale.factor))
            }
        } right: {
            PaneBox(title: "Testing", note: "On: buy, sell and negotiate at any time. Off: real windows (off-season, rounds 1–2, before round 25).") {
                Toggle("Market always open", isOn: Binding(get: { c?.settings.marketAlwaysOpen ?? true },
                                                           set: { store.careerSetMarketAlwaysOpen($0) }))
                    .font(.system(size: 14 * TextScale.factor))
            }
            PaneBox(title: "Display") {
                HStack {
                    Text("Text size").font(.system(size: 14 * TextScale.factor))
                    Spacer()
                    TextSizePicker()
                }
            }
            PaneBox(title: "Sound", note: "Original music and match sounds. They follow the silent switch and play alongside your own music.") {
                SoundToggles()
            }
        }
    }
}
