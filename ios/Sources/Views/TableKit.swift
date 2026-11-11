import SwiftUI

// One format for every list screen (device feedback, landscape): the transfer market's.
//
// - TableScreen: a pinned header (a summary line, filter and action chips, column titles) above
//   one-line rows with fixed columns. Only the rows scroll.
// - PaneScreen: for screens of settings and cards, two panes side by side in landscape (like the
//   Squad tab's XI and bench), one column in portrait.
//
// Both read the size class themselves, so they work on pushed screens and in the quick game.

/// Column widths shared by headers and rows.
enum TCol {
    static let mark: CGFloat = 22
    static let num: CGFloat = 24
    static let ovr: CGFloat = 32
    static let stat: CGFloat = 34
    static let role: CGFloat = 38
    static let age: CGFloat = 28
    static let form: CGFloat = 34
    static let wide: CGFloat = 56
    static let money: CGFloat = 70
    static let action: CGFloat = 84
    /// Room a List's drag handle takes on the right (headers above a ReorderList pad by this).
    static let handle: CGFloat = 40
}

// MARK: - Screens

/// Pinned header, scrolling rows. `scrolls: false` when the rows bring their own scrolling (a List
/// that reorders).
struct TableScreen<Header: View, Rows: View>: View {
    let title: String
    var scrolls = true
    @ViewBuilder var header: Header
    @ViewBuilder var rows: Rows

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            header
            if scrolls {
                ScrollView {
                    LazyVStack(spacing: 4) { rows }
                        .padding(.bottom, DS.Space.md)
                }
            } else {
                rows
            }
        }
        .padding(.horizontal, DS.Space.md)
        .padding(.top, 6)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Palette.ink.ignoresSafeArea())
        .environment(\.careerTheme, true)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Two panes side by side in landscape, each scrolling on its own; one column in portrait.
struct PaneScreen<Left: View, Right: View>: View {
    let title: String
    @ViewBuilder var left: Left
    @ViewBuilder var right: Right
    @Environment(\.verticalSizeClass) private var vSize

    var body: some View {
        Group {
            if vSize == .compact {
                HStack(alignment: .top, spacing: DS.Space.md) {
                    pane { left }
                    pane { right }
                }
                .padding(.horizontal, DS.Space.md)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: DS.Space.md) {
                        left
                        right
                    }
                    .padding(DS.Space.lg)
                    .frame(maxWidth: 760)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Palette.ink.ignoresSafeArea())
        .environment(\.careerTheme, true)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func pane<C: View>(@ViewBuilder _ content: () -> C) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Space.sm) { content() }
                .padding(.vertical, DS.Space.sm)
                .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

/// A titled group on a pane: label, one surface, an optional short note.
struct PaneBox<Content: View>: View {
    let title: String
    var note: String? = nil
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title.uppercased())
                .font(.system(size: 10 * TextScale.factor, weight: .heavy))
                .foregroundStyle(Palette.muted)
                .padding(.leading, 2)
            VStack(alignment: .leading, spacing: 8) { content }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Palette.surface))
            if let note {
                Text(note)
                    .font(.system(size: 11 * TextScale.factor))
                    .foregroundStyle(Palette.muted)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 2)
            }
        }
    }
}

// MARK: - Header pieces

/// One cell of a summary line: a value and a short label, inline (like the market's purse line).
struct SummaryCell: Hashable {
    let value: String
    let label: String
    var color: Color = .white
}

/// Up to five numbers on one short line.
struct SummaryLine: View {
    let cells: [SummaryCell]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(cells, id: \.self) { cell in
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text(cell.value).font(.score(15)).foregroundStyle(cell.color).lineLimit(1).minimumScaleFactor(0.7)
                    Text(cell.label).font(.system(size: 11 * TextScale.factor, weight: .medium))
                        .foregroundStyle(Palette.muted).lineLimit(1)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Palette.surface))
    }
}

/// A filter that is on or off (role chips, "Free agents").
struct FilterChip: View {
    let title: String
    let on: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title).font(.system(size: 12 * TextScale.factor, weight: .semibold))
                .foregroundStyle(on ? Palette.ink : .white)
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(Capsule().fill(on ? Palette.accent : Palette.surface))
                .lineLimit(1)
        }
        .buttonStyle(.plain)
    }
}

/// A menu that picks one value (sort, category, intensity).
struct MenuChip<Items: View>: View {
    let title: String
    @ViewBuilder var items: Items

    var body: some View {
        Menu { items } label: {
            HStack(spacing: 3) {
                Text(title).lineLimit(1)
                Image(systemName: "chevron.up.chevron.down").font(.system(size: 9 * TextScale.factor, weight: .bold))
            }
            .font(.system(size: 12 * TextScale.factor, weight: .semibold))
            .foregroundStyle(Palette.accent)
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(Capsule().fill(Palette.surface))
        }
    }
}

/// A one-tap action in a header (Auto-pick, Best order, Accept). `primary` fills it green.
struct ActionChip: View {
    let icon: String
    let title: String
    var primary = false
    var destructive = false
    var disabled = false
    /// Icon only (narrow portrait rows); the title stays as the accessibility label.
    var iconOnly = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if iconOnly {
                    Image(systemName: icon).accessibilityLabel(title)
                } else {
                    Label(title, systemImage: icon)
                }
            }
                .font(.system(size: 12 * TextScale.factor, weight: .semibold))
                .foregroundStyle(primary ? Palette.ink : (destructive ? Palette.wicket : Palette.accent))
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(Capsule().fill(primary ? Palette.accent : Palette.surface))
                .lineLimit(1)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.45 : 1)
    }
}

/// One short line under the header: a warning (orange) or a hint (grey).
struct TableNote: View {
    let text: String
    var warning = false

    var body: some View {
        Label(text, systemImage: warning ? "exclamationmark.triangle.fill" : "info.circle")
            .font(.system(size: 11 * TextScale.factor, weight: warning ? .semibold : .regular))
            .foregroundStyle(warning ? Color.orange : Palette.muted)
            .lineLimit(2)
    }
}

/// Column titles above a table.
struct TableHead<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        HStack(spacing: 8) { content }
            .font(.system(size: 10 * TextScale.factor, weight: .heavy))
            .foregroundStyle(Palette.muted)
            .lineLimit(1)
            .padding(.horizontal, 10)
    }
}

// MARK: - Rows

extension View {
    /// The market row look: one line, a rounded surface, tappable across its width.
    func tableRow(selected: Bool = false, dimmed: Bool = false) -> some View {
        self
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(minHeight: 34)
            .background(RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(selected ? Palette.accent.opacity(0.18) : Palette.surface))
            .opacity(dimmed ? 0.55 : 1)
            .contentShape(Rectangle())
    }
}

/// A number cell (ratings, ages, stats).
struct TNum: View {
    let text: String
    let width: CGFloat
    var color: Color = .white
    var align: Alignment = .trailing

    var body: some View {
        Text(text).font(.score(13)).foregroundStyle(color).lineLimit(1).minimumScaleFactor(0.7)
            .frame(width: width, alignment: align)
    }
}

/// A title cell that takes the free width.
struct TName: View {
    let text: String
    var overseas = false
    var legend = false
    var pitchFit: Bool? = nil
    var color: Color = .white
    var bold = true

    var body: some View {
        HStack(spacing: 4) {
            Text(text).font(.system(size: 14 * TextScale.factor, weight: bold ? .semibold : .regular))
                .foregroundStyle(color).lineLimit(1).minimumScaleFactor(0.8)
            if overseas { Image(systemName: "airplane").font(.system(size: 9 * TextScale.factor)).foregroundStyle(Palette.muted) }
            if legend { Image(systemName: "star.fill").font(.system(size: 9 * TextScale.factor)).foregroundStyle(CareerPalette.gold) }
            PitchFitMark(fit: pitchFit)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Role in its colour, as text (lighter than a chip in a dense table).
struct TRole: View {
    let role: Role

    var body: some View {
        Text(role.short).font(.system(size: 11 * TextScale.factor, weight: .heavy))
            .foregroundStyle(Palette.role(role)).lineLimit(1)
            .frame(width: TCol.role, alignment: .leading)
    }
}

/// Picked / not picked.
struct TCheck: View {
    let on: Bool

    var body: some View {
        Image(systemName: on ? "checkmark.circle.fill" : "circle")
            .font(.system(size: 16 * TextScale.factor))
            .foregroundStyle(on ? Palette.accent : Palette.muted)
            .frame(width: TCol.mark)
    }
}

// MARK: - Career squad table (Pick XI, retentions, national squad, other clubs, academy)

/// Column titles for `SquadTableRow`.
struct SquadTableHead: View {
    let count: Int
    var check = false
    var form = true
    var trailing: String? = nil
    @Environment(\.verticalSizeClass) private var vSize

    var body: some View {
        TableHead {
            if check { Text("").frame(width: TCol.mark) }
            Text("OVR").frame(width: TCol.ovr, alignment: .center)
            Text("PLAYER · \(count)").frame(maxWidth: .infinity, alignment: .leading)
            Text("ROLE").frame(width: TCol.role, alignment: .leading)
            if vSize == .compact { Text("AGE").frame(width: TCol.age, alignment: .trailing) }
            Text("BAT").frame(width: TCol.stat, alignment: .trailing)
            Text("BOWL").frame(width: TCol.stat, alignment: .trailing)
            if form && vSize == .compact { Text("FORM").frame(width: TCol.form, alignment: .trailing) }
            if let trailing { Text(trailing).frame(width: TCol.money, alignment: .trailing) }
            if vSize == .compact { Text("TYPE").frame(maxWidth: .infinity, alignment: .leading) }
        }
    }
}

/// One career player on one line: rating, name, role, age, batting, bowling, form, and an optional
/// value at the end (wage, potential, caps). The full role description follows in landscape.
struct SquadTableRow: View {
    let player: CareerPlayer
    let year: Int
    var check: Bool? = nil
    var form = true
    var pitchFit: Bool? = nil
    var trailing: String? = nil
    var trailingColor: Color = .white
    var selected = false
    @Environment(\.verticalSizeClass) private var vSize

    var body: some View {
        let p = player
        HStack(spacing: 8) {
            if let check { TCheck(on: check) }
            TNum(text: "\(p.rating)", width: TCol.ovr, color: strengthColor(p.rating), align: .center)
            TName(text: p.name, overseas: p.overseas, legend: p.legend, pitchFit: pitchFit)
            TRole(role: p.role)
            if vSize == .compact { TNum(text: "\(p.age(in: year))", width: TCol.age, color: Palette.muted) }
            TNum(text: "\(p.bat)", width: TCol.stat, color: p.primaryIsBat ? strengthColor(p.bat) : Palette.muted)
            TNum(text: p.bowl >= 25 ? "\(p.bowl)" : "–", width: TCol.stat,
                 color: p.bowl >= 40 && !p.primaryIsBat ? strengthColor(p.bowl) : Palette.muted)
            if form && vSize == .compact { TNum(text: CareerText.form(p.form), width: TCol.form, color: CareerText.formColor(p.form)) }
            if let trailing { TNum(text: trailing, width: TCol.money, color: trailingColor) }
            if vSize == .compact {
                Text(p.roleDescription).font(.system(size: 12 * TextScale.factor)).foregroundStyle(Palette.muted)
                    .lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .tableRow(selected: selected)
    }
}
