import SwiftUI

/// Field settings and batting intent for each phase (your club and your national side).
struct TacticsView: View {
    @EnvironmentObject var store: GameStore
    @State private var t = Tactics()
    @State private var loaded = false

    var body: some View {
        List {
            ForEach(0..<3, id: \.self) { i in
                Section(Tactics.phases[i]) {
                    Picker("Field", selection: fieldBinding(i)) {
                        ForEach(FieldSetting.allCases, id: \.self) { f in Text(f.label).tag(f) }
                    }
                    .pickerStyle(.segmented)
                    Text(t.field[i].blurb).font(.caption).foregroundStyle(Palette.muted)
                    Picker("Batting", selection: intentBinding(i)) {
                        ForEach(BatIntent.allCases, id: \.self) { b in Text(b.label).tag(b) }
                    }
                    .pickerStyle(.segmented)
                    Text(t.intent[i].blurb).font(.caption).foregroundStyle(Palette.muted)
                }
                .listRowBackground(CareerPalette.panel)
            }
            Section {
                Button("Reset to balanced / rotate") { t = Tactics() }
            } footer: {
                Text("Field = when you bowl, batting = when you bat. Applies to every match until you change it, including your national side's.")
            }
            .listRowBackground(CareerPalette.panel)
        }
        .darkList()
        .navigationTitle("Tactics")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if !loaded, let c = store.career {
                t = c.tactics
                loaded = true
            }
        }
        .onChange(of: t) { v in
            if loaded { store.careerSetTactics(v) }
        }
    }

    private func fieldBinding(_ i: Int) -> Binding<FieldSetting> {
        Binding(get: { t.field[i] }, set: { t.field[i] = $0 })
    }

    private func intentBinding(_ i: Int) -> Binding<BatIntent> {
        Binding(get: { t.intent[i] }, set: { t.intent[i] = $0 })
    }
}
