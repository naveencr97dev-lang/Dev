import SwiftUI

struct CalendarView: View {
    @EnvironmentObject var store: Store
    private let calendar = Calendar.current

    @State private var selected = Calendar.current.startOfDay(for: Date())
    @State private var monthAnchor = Calendar.current.startOfDay(for: Date())
    @State private var mode: Mode = .agenda
    @State private var showAddEvent = false
    @State private var showAddTask = false

    enum Mode: String, CaseIterable, Identifiable { case agenda = "Day", tasks = "Tasks"; var id: String { rawValue } }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    monthCard.listRowInsets(EdgeInsets()).listRowBackground(Color.clear)
                }
                Section {
                    Picker("Mode", selection: $mode) {
                        ForEach(Mode.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                }
                if mode == .agenda { agendaSection } else { tasksSection }
            }
            .navigationTitle("Calendar")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button { showAddEvent = true } label: { Label("New event", systemImage: "calendar.badge.plus") }
                        Button { showAddTask = true } label: { Label("New task", systemImage: "checklist") }
                    } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $showAddEvent) { EventEditView(day: selected) }
            .sheet(isPresented: $showAddTask) { TaskEditView(day: selected) }
        }
    }

    // MARK: Month grid

    private var monthCard: some View {
        AppCard {
            VStack(spacing: DS.Space.md) {
                HStack {
                    Button { shiftMonth(-1) } label: { Image(systemName: "chevron.left") }
                    Spacer()
                    Text(monthAnchor.formatted(.dateTime.month(.wide).year()))
                        .font(.system(.headline, design: .rounded))
                    Spacer()
                    Button { shiftMonth(1) } label: { Image(systemName: "chevron.right") }
                }
                HStack(spacing: 0) {
                    ForEach(weekdaySymbols, id: \.self) { s in
                        Text(s).font(.caption2).foregroundStyle(.secondary).frame(maxWidth: .infinity)
                    }
                }
                ForEach(weeks, id: \.self) { week in
                    HStack(spacing: 0) {
                        ForEach(Array(week.enumerated()), id: \.offset) { _, day in
                            dayCell(day)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, DS.Space.lg)
        .padding(.vertical, DS.Space.sm)
    }

    @ViewBuilder
    private func dayCell(_ day: Date?) -> some View {
        if let day = day {
            let isSel = calendar.isDate(day, inSameDayAs: selected)
            let isToday = calendar.isDateInToday(day)
            Button {
                selected = day
            } label: {
                VStack(spacing: 3) {
                    Text("\(calendar.component(.day, from: day))")
                        .font(.footnote.weight(isToday ? .bold : .regular))
                        .foregroundStyle(isSel ? .white : (isToday ? Color.accentColor : .primary))
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(isSel ? Color.accentColor : .clear))
                    Circle()
                        .fill(store.hasPlannerItems(on: day) ? Color.accentColor : .clear)
                        .frame(width: 5, height: 5)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
        } else {
            Color.clear.frame(maxWidth: .infinity, minHeight: 40)
        }
    }

    // MARK: Agenda

    private enum AgendaRow: Identifiable {
        case habit(Habit), event(CalEvent), task(TaskItem)
        var id: String {
            switch self {
            case .habit(let h): return "h\(h.id)"
            case .event(let e): return "e\(e.id)"
            case .task(let t): return "t\(t.id)"
            }
        }
        var sort: Int {
            switch self {
            case .event(let e): return e.startMinutes ?? 990
            case .task(let t): return t.dueMinutes ?? 995
            case .habit(let h):
                switch h.timeOfDay {
                case .morning: return 480
                case .afternoon: return 840
                case .evening: return 1200
                case .anytime: return 1000
                }
            }
        }
    }

    private var agendaRows: [AgendaRow] {
        let hs = store.habitsScheduled(on: selected).map { AgendaRow.habit($0) }
        let es = store.eventsOn(selected).map { AgendaRow.event($0) }
        let ts = store.tasksOn(selected).map { AgendaRow.task($0) }
        return (hs + es + ts).sorted { $0.sort < $1.sort }
    }

    @ViewBuilder private var agendaSection: some View {
        let rows = agendaRows
        Section(selected.formatted(.dateTime.weekday(.wide).month().day())) {
            if rows.isEmpty {
                Text("Nothing planned. Tap + to add an event or task.")
                    .font(.subheadline).foregroundStyle(.secondary)
            } else {
                ForEach(rows) { row in
                    switch row {
                    case .habit(let h): HabitRow(habit: h, date: selected)
                    case .event(let e): eventRow(e)
                    case .task(let t): taskRow(t)
                    }
                }
            }
        }
    }

    private func eventRow(_ e: CalEvent) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 3).fill(Color(hex: e.colorHex)).frame(width: 4, height: 34)
            Text(e.emoji)
            VStack(alignment: .leading, spacing: 2) {
                Text(e.title).font(.body.weight(.medium))
                if let s = e.startMinutes {
                    Text(e.endMinutes != nil ? "\(timeLabel(s)) – \(timeLabel(e.endMinutes!))" : timeLabel(s))
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    Text("All day").font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .swipeActions { Button(role: .destructive) { store.deleteEvent(e) } label: { Label("Delete", systemImage: "trash") } }
    }

    private func taskRow(_ t: TaskItem, showDate: Bool = false) -> some View {
        HStack(spacing: 12) {
            Button { withAnimation { store.toggleTask(t) } } label: {
                Image(systemName: t.done ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(t.done ? Color.accentColor : Color.secondary.opacity(0.5))
                    .font(.title3)
            }
            .buttonStyle(.plain)
            VStack(alignment: .leading, spacing: 2) {
                Text(t.title).strikethrough(t.done).foregroundStyle(t.done ? .secondary : .primary)
                HStack(spacing: 6) {
                    if showDate { Text(t.dueDay.formatted(.dateTime.month().day())) }
                    if let m = t.dueMinutes { Text(timeLabel(m)) }
                    if t.repeatRule != nil { Image(systemName: "repeat") }
                    if t.remind { Image(systemName: "bell") }
                }
                .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .swipeActions { Button(role: .destructive) { store.deleteTask(t) } label: { Label("Delete", systemImage: "trash") } }
    }

    // MARK: Tasks mode

    @ViewBuilder private var tasksSection: some View {
        let open = store.openTasks
        if open.isEmpty {
            Section { Text("No open tasks. Nice and clear 🎉").font(.subheadline).foregroundStyle(.secondary) }
        } else {
            Section("Open tasks") {
                ForEach(open) { t in taskRow(t, showDate: true) }
            }
        }
    }

    // MARK: Helpers

    private var weekdaySymbols: [String] {
        // Monday-first single letters
        let base = calendar.veryShortStandaloneWeekdaySymbols // [Sun..Sat]
        return Array(base[1...6]) + [base[0]]
    }

    private func shiftMonth(_ delta: Int) {
        if let d = calendar.date(byAdding: .month, value: delta, to: monthAnchor) {
            monthAnchor = d
        }
    }

    /// Weeks (each 7 cells, nil = padding) for the displayed month.
    private var weeks: [[Date?]] {
        let comps = calendar.dateComponents([.year, .month], from: monthAnchor)
        guard let first = calendar.date(from: comps),
              let range = calendar.range(of: .day, in: .month, for: first) else { return [] }
        let weekdayOfFirst = calendar.component(.weekday, from: first) // 1=Sun
        let leading = (weekdayOfFirst + 5) % 7                          // days before Monday
        var cells: [Date?] = Array(repeating: nil, count: leading)
        for d in range {
            cells.append(calendar.date(byAdding: .day, value: d - 1, to: first))
        }
        while cells.count % 7 != 0 { cells.append(nil) }
        return stride(from: 0, to: cells.count, by: 7).map { Array(cells[$0..<$0 + 7]) }
    }
}
