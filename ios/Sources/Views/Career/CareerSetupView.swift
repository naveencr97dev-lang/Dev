import SwiftUI

/// New career: name the manager, draft the league, pick a franchise.
struct CareerSetupView: View {
    @EnvironmentObject var store: GameStore
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var legends = false
    @State private var draft: Career? = nil
    @State private var picked: Int? = nil

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("Your name", text: $name)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                    Toggle("Legends era", isOn: $legends)
                } header: {
                    Text("Manager")
                } footer: {
                    Text("10 franchises. Each pair meets four times: 36 league matches through the year, then IPL playoffs. No relegation. Players age, develop and retire; youngsters come through every season. Legends era adds retired greats to the pool.")
                }
                .listRowBackground(CareerPalette.panel)

                if let d = draft {
                    Section {
                        ForEach(clubsByStrength(d)) { club in
                            Button {
                                picked = club.id
                                Haptics.tap()
                            } label: {
                                ClubPickRow(career: d, club: club, selected: picked == club.id)
                            }
                            .buttonStyle(.plain)
                        }
                    } header: {
                        Text("Pick your franchise")
                    } footer: {
                        Text("Squads were drafted fairly (20 players, max 8 overseas). Your home ground's pitch is used for your home matches, so build a squad that suits it.")
                    }
                    .listRowBackground(CareerPalette.panel)
                }

                Section {
                    Button("🔄 Redraft squads") { redraft() }
                    Button("Start career ▶︎") { start() }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(picked == nil)
                        .opacity(picked == nil ? 0.5 : 1)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                }
                .listRowBackground(CareerPalette.panel)
            }
            .darkList()
            .navigationTitle("New career")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                if draft == nil { redraft() }
            }
            .onChange(of: legends) { _ in redraft() }
        }
    }

    private func clubsByStrength(_ d: Career) -> [Franchise] {
        d.clubs.sorted { d.strength($0.id) > d.strength($1.id) }
    }

    private func redraft() {
        draft = store.draftPreview(legendsEra: legends)
        picked = nil
    }

    private func start() {
        guard let d = draft, let id = picked else { return }
        store.startCareer(d, clubId: id, managerName: name)
        Haptics.success()
        dismiss()
    }
}

struct ClubPickRow: View {
    let career: Career
    let club: Franchise
    let selected: Bool

    var body: some View {
        let stars = club.squad.compactMap { career.players[$0] }.sorted { $0.rating > $1.rating }.prefix(3)
        let pitch = career.info(club.id)?.homePitch ?? .indianFlat
        HStack(spacing: 12) {
            TeamBadge(team: club, size: 44)
            VStack(alignment: .leading, spacing: 3) {
                Text(club.name).font(.headline)
                Text("\(pitch.icon) Home: \(pitch.label)").font(.caption).foregroundStyle(Palette.muted)
                Text(stars.map(\.name).joined(separator: " · ")).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 4)
            VStack(spacing: 0) {
                Text("\(career.strength(club.id))").font(.display(24)).foregroundStyle(Palette.accent)
                Text("STR").font(.display(10, weight: .heavy)).foregroundStyle(Palette.muted)
            }
            Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(selected ? Palette.accent : Palette.muted)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}
