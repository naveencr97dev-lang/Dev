import SwiftUI

/// "New Habit" screen: pick a starter habit by category, or make a custom one.
struct HabitTemplatePicker: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss

    @State private var category: TemplateCategory = .popular
    @State private var prefill: Habit? = nil
    @State private var showingCustom = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                categoryBar
                List {
                    ForEach(Templates.items(for: category)) { t in
                        Button {
                            prefill = t.makeHabit()
                        } label: {
                            HStack(spacing: 14) {
                                ZStack {
                                    Circle().fill(Color(hex: t.colorHex).opacity(0.18))
                                        .frame(width: 40, height: 40)
                                    Text(t.emoji)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(t.name).foregroundStyle(.primary)
                                    if let tt = t.goalTarget, let u = t.goalUnit {
                                        Text("\(tt) \(u)").font(.caption).foregroundStyle(.secondary)
                                    } else if t.kind == .quit {
                                        Text("Quit habit").font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                Image(systemName: "plus.circle.fill")
                                    .foregroundStyle(Color(hex: t.colorHex))
                                    .font(.title3)
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle("New Habit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Custom") { showingCustom = true }
                }
            }
            // Open the editor prefilled from a template.
            .sheet(item: $prefill) { habit in
                HabitEditView(habit: nil, prefill: habit, onSaved: { dismiss() })
            }
            // Open a blank custom editor.
            .sheet(isPresented: $showingCustom) {
                HabitEditView(habit: nil, onSaved: { dismiss() })
            }
        }
    }

    private var categoryBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(TemplateCategory.allCases) { cat in
                    let on = cat == category
                    Button {
                        category = cat
                    } label: {
                        Label(cat.rawValue, systemImage: cat.symbol)
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .background(
                                Capsule().fill(on ? Color.accentColor : Color.secondary.opacity(0.15))
                            )
                            .foregroundStyle(on ? .white : .primary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }
}
