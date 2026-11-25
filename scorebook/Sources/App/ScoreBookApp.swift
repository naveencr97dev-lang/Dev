import SwiftUI

@main
struct ScoreBookApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.dark)
        }
    }
}

struct RootView: View {
    var body: some View {
        TabView {
            RobListView()
                .tabItem { Label("Rob", systemImage: "bag") }
            MoneyView()
                .tabItem { Label("Money", systemImage: "dollarsign.circle") }
            RulesView()
                .tabItem { Label("Rules", systemImage: "list.bullet.rectangle") }
        }
    }
}

// MARK: Rob

struct RobListView: View {
    var body: some View {
        NavigationStack {
            List {
                ForEach(RobberyGuide.Tier.allCases, id: \.self) { tier in
                    Section(tier.title) {
                        ForEach(Guide.robberies.filter { $0.tier == tier }) { g in
                            NavigationLink(value: g) { RobRow(guide: g) }
                        }
                    }
                }
            }
            .navigationTitle("Robberies")
            .navigationDestination(for: RobberyGuide.self) { RobDetailView(guide: $0) }
        }
    }
}

struct RobRow: View {
    let guide: RobberyGuide
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: guide.symbol)
                .frame(width: 28)
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(guide.name).font(.body)
                Text(guide.take)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
    }
}

struct RobDetailView: View {
    let guide: RobberyGuide
    @State private var done: Set<Int> = []

    private var allSteps: [String] {
        Guide.stepsWithPrep(guide)
    }

    var body: some View {
        List {
            Section {
                InfoRow(label: "Unlocks", value: guide.unlock)
                InfoRow(label: "Take", value: guide.take)
                InfoRow(label: "Heat", value: guide.heat)
            }
            Section {
                ForEach(Array(allSteps.enumerated()), id: \.offset) { i, step in
                    Button {
                        if done.contains(i) { done.remove(i) } else { done.insert(i) }
                    } label: {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: done.contains(i) ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(done.contains(i) ? Color.green : Color.secondary)
                            Text(step)
                                .foregroundStyle(done.contains(i) ? Color.secondary : Color.primary)
                                .multilineTextAlignment(.leading)
                        }
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                HStack {
                    Text("Steps")
                    Spacer()
                    if !done.isEmpty {
                        Button("Reset") { done = [] }.font(.footnote)
                    }
                }
            }
            if !guide.watchOut.isEmpty {
                Section("Watch out") {
                    ForEach(guide.watchOut, id: \.self) { Text($0) }
                }
            }
            if let note = guide.note {
                Section { Text(note).font(.footnote).foregroundStyle(.secondary) }
            }
        }
        .navigationTitle(guide.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label).foregroundStyle(.secondary)
            Spacer(minLength: 16)
            Text(value).multilineTextAlignment(.trailing)
        }
    }
}

// MARK: Money

struct MoneyView: View {
    var body: some View {
        NavigationStack {
            List {
                ForEach(Guide.money) { m in
                    Section {
                        HStack(spacing: 12) {
                            Image(systemName: m.symbol).frame(width: 28).foregroundStyle(.tint)
                            Text(m.name).font(.headline)
                        }
                        InfoRow(label: "Unlocks", value: m.unlock)
                        InfoRow(label: "Pays", value: m.pay)
                        ForEach(m.how, id: \.self) { line in
                            Text(line).font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                }
                Section {
                    Text("Figures come from launch-week guides and can be off. Check the map's estimated take in game.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Money")
        }
    }
}

// MARK: Rules

struct RulesView: View {
    @State private var checked: Set<String> = []

    var body: some View {
        NavigationStack {
            List {
                ForEach(Guide.rules) { group in
                    Section {
                        ForEach(group.rules, id: \.self) { rule in
                            if group.id == "clean" {
                                Button {
                                    if checked.contains(rule) { checked.remove(rule) } else { checked.insert(rule) }
                                } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: checked.contains(rule) ? "checkmark.circle.fill" : "circle")
                                            .foregroundStyle(checked.contains(rule) ? Color.green : Color.secondary)
                                        Text(rule).foregroundStyle(Color.primary)
                                    }
                                }
                                .buttonStyle(.plain)
                            } else {
                                Text(rule)
                            }
                        }
                    } header: {
                        HStack {
                            Label(group.title, systemImage: group.symbol)
                            Spacer()
                            if group.id == "clean" && !checked.isEmpty {
                                Button("Reset") { checked = [] }.font(.footnote)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Rules")
        }
    }
}
