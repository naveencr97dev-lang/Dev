import SwiftUI

/// Weekly restock list. Staples persist; each week starts unreviewed so you
/// re-check what's in the fridge and see what to order.
struct GroceriesView: View {
    @EnvironmentObject var store: Store
    @State private var showingAdd = false
    @State private var showingList = false

    private var categories: [String] {
        Array(Set(store.groceryItems.map { $0.category })).sorted()
    }

    var body: some View {
        NavigationStack {
            Group {
                if store.groceryItems.isEmpty {
                    emptyState
                } else {
                    List {
                        Section {
                            summaryCard
                                .listRowInsets(EdgeInsets())
                                .listRowBackground(Color.clear)
                        }
                        ForEach(categories, id: \.self) { cat in
                            Section(cat) {
                                ForEach(itemsIn(cat)) { item in
                                    row(item)
                                }
                                .onDelete { idx in delete(cat, idx) }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Restock")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showingList = true } label: { Image(systemName: "cart") }
                        .disabled(store.shoppingList.isEmpty)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingAdd = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $showingAdd) { AddGroceryView() }
            .sheet(isPresented: $showingList) { ShoppingListView() }
        }
    }

    private var summaryCard: some View {
        AppCard {
            VStack(alignment: .leading, spacing: DS.Space.md) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("This week").font(.headline)
                        Text(weekLabel).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if store.shoppingList.isEmpty {
                        Label("\(store.uncheckedCount) to check", systemImage: "checklist")
                            .font(.subheadline).foregroundStyle(.secondary)
                    } else {
                        Button { showingList = true } label: {
                            Label("\(store.shoppingList.count) to order", systemImage: "cart.fill")
                                .font(.subheadline.weight(.semibold))
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color(hex: "#FB7185"))
                    }
                }
                Text("Tap an item to cycle: In fridge → Need to order → clear. The list resets every Monday.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, DS.Space.lg)
        .padding(.vertical, DS.Space.sm)
    }

    private func row(_ item: GroceryItem) -> some View {
        let status = store.status(for: item)
        return Button {
            withAnimation { store.cycleStatus(for: item) }
        } label: {
            HStack(spacing: DS.Space.md) {
                Text(item.emoji).font(.title3)
                Text(item.name)
                    .foregroundStyle(.primary)
                Spacer()
                statusChip(status)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func statusChip(_ status: StockStatus) -> some View {
        let (text, color, icon): (String, Color, String)
        switch status {
        case .unchecked: (text, color, icon) = ("Check", .secondary, "circle")
        case .inStock: (text, color, icon) = ("In fridge", Color(hex: "#34D399"), "checkmark.circle.fill")
        case .needOrder: (text, color, icon) = ("Order", Color(hex: "#FB7185"), "cart.fill")
        }
        return Label(text, systemImage: icon)
            .font(.caption.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(Capsule().fill(color.opacity(0.14)))
    }

    private var emptyState: some View {
        VStack(spacing: DS.Space.md) {
            Image(systemName: "cart.badge.plus").font(.system(size: 42)).foregroundStyle(.tint)
            Text("No staples yet").font(.headline)
            Text("Add the things you buy regularly. Each week they come back so you can check the fridge and order what's missing.")
                .font(.subheadline).foregroundStyle(.secondary)
                .multilineTextAlignment(.center).padding(.horizontal, DS.Space.xl)
            Button { showingAdd = true } label: { Text("Add item").fontWeight(.semibold) }
                .buttonStyle(.borderedProminent)
            Button("Load sample staples") { store.seedGroceriesIfEmpty() }
                .font(.subheadline)
        }
        .padding()
    }

    private var weekLabel: String {
        let start = store.weekStart()
        let end = Calendar.current.date(byAdding: .day, value: 6, to: start)!
        return "\(start.formatted(.dateTime.month().day())) – \(end.formatted(.dateTime.month().day()))"
    }

    private func itemsIn(_ cat: String) -> [GroceryItem] {
        store.sortedGroceryItems.filter { $0.category == cat }
    }

    private func delete(_ cat: String, _ offsets: IndexSet) {
        let items = itemsIn(cat)
        for i in offsets { store.deleteGroceryItem(items[i]) }
    }
}

struct AddGroceryView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var category = "Produce"

    var body: some View {
        NavigationStack {
            Form {
                Section("Item") {
                    TextField("Name (e.g. Milk)", text: $name)
                    Picker("Category", selection: $category) {
                        ForEach(GroceryCategory.all, id: \.self) { Text($0).tag($0) }
                    }
                }
            }
            .navigationTitle("New Staple")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let trimmed = name.trimmingCharacters(in: .whitespaces)
                        guard !trimmed.isEmpty else { return }
                        store.addGroceryItem(GroceryItem(
                            name: trimmed,
                            emoji: GroceryCategory.emoji(for: category),
                            category: category))
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

struct ShoppingListView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if store.shoppingList.isEmpty {
                    Text("Nothing to order. You're stocked up 🎉")
                        .foregroundStyle(.secondary)
                } else {
                    Section("Order this week") {
                        ForEach(store.shoppingList) { item in
                            HStack {
                                Text(item.emoji)
                                Text(item.name)
                                Spacer()
                                Button {
                                    withAnimation { store.setStatus(.inStock, for: item) }
                                } label: { Image(systemName: "checkmark.circle") }
                                    .buttonStyle(.plain)
                                    .foregroundStyle(Color(hex: "#34D399"))
                            }
                        }
                    }
                }
            }
            .navigationTitle("Shopping List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
    }
}
