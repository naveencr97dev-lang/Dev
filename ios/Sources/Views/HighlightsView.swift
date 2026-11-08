import SwiftUI

extension Highlight.Kind {
    var title: String {
        switch self {
        case .six: return "SIX!"
        case .four: return "FOUR!"
        case .wicket: return "WICKET!"
        case .fifty: return "FIFTY!"
        case .hundred: return "HUNDRED!"
        case .bigOver: return "BIG OVER"
        case .winningRuns: return "WINNING RUNS"
        case .defended: return "DEFENDED!"
        case .superOver: return "SUPER OVER"
        }
    }

    var icon: String {
        switch self {
        case .six: return "💥"
        case .four: return "🏏"
        case .wicket: return "🎯"
        case .fifty: return "🙌"
        case .hundred: return "💯"
        case .bigOver: return "🔥"
        case .winningRuns, .defended, .superOver: return "🏆"
        }
    }

    var color: Color {
        switch self {
        case .six: return Palette.six
        case .four: return Palette.four
        case .wicket: return Palette.wicket
        case .fifty, .hundred: return Palette.accent
        case .bigOver: return Color(hex: "#F97316")
        case .winningRuns, .defended, .superOver: return Palette.accent
        }
    }
}

/// Story-style reel of a match's key moments: auto-advances, tap to skip ahead.
struct HighlightsReel: View {
    @EnvironmentObject var store: GameStore
    @Environment(\.verticalSizeClass) private var vSize
    let result: MatchResult
    var onDone: () -> Void

    @State private var index = 0
    @State private var progress: Double = 0
    @State private var paused = false
    @AppStorage("reelSpeed") private var speed: Double = 1
    private let tick = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()
    /// Seconds per moment at 1×.
    private let perMoment = 2.8

    private var moments: [Highlight] { result.highlights ?? [] }

    var body: some View {
        let compact = vSize == .compact
        VStack(spacing: compact ? DS.Space.sm : DS.Space.lg) {
            // Segmented progress, one bar per moment.
            HStack(spacing: 4) {
                ForEach(moments.indices, id: \.self) { i in
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.15))
                            Capsule().fill(Palette.accent)
                                .frame(width: geo.size.width * (i < index ? 1 : (i == index ? progress : 0)))
                        }
                    }
                    .frame(height: 4)
                }
            }

            HStack {
                SectionLabel(text: "Highlights")
                Spacer()
                if let a = store.team(result.teamA), let b = store.team(result.teamB) {
                    TeamBadge(team: a, size: 24)
                    Text("v").font(.display(14, weight: .heavy)).foregroundStyle(Palette.muted)
                    TeamBadge(team: b, size: 24)
                }
                Text(result.pitch.icon)
            }

            Spacer(minLength: 0)
            if index < moments.count {
                HighlightCard(moment: moments[index], compact: compact)
                    .id(index)
                    .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                            removal: .move(edge: .leading).combined(with: .opacity)))
            }
            Spacer(minLength: 0)

            SpeedPicker(speed: $speed, options: [0.5, 1, 2])
            HStack(spacing: 10) {
                Button { go(index - 1) } label: { Image(systemName: "backward.fill") }
                    .buttonStyle(SecondaryButtonStyle()).frame(width: 70)
                    .disabled(index == 0)
                Button("Scorecard ▸") { onDone() }
                    .buttonStyle(PrimaryButtonStyle())
                Button { paused.toggle() } label: { Image(systemName: paused ? "play.fill" : "pause.fill") }
                    .buttonStyle(SecondaryButtonStyle()).frame(width: 70)
            }
        }
        .padding(compact ? DS.Space.md : DS.Space.lg)
        .background(AppBackground())
        .contentShape(Rectangle())
        .onTapGesture { go(index + 1) }
        .onReceive(tick) { _ in
            guard !paused, !moments.isEmpty else { return }
            progress += 0.05 * speed / perMoment
            if progress >= 1 { go(index + 1) }
        }
        .onAppear { feedback() }
        .keepAwake()
    }

    private func go(_ i: Int) {
        guard i >= 0 else { return }
        if i >= moments.count {
            onDone()
            return
        }
        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
            index = i
            progress = 0
        }
        feedback()
    }

    private func feedback() {
        guard index < moments.count else { return }
        switch moments[index].kind {
        case .wicket: Haptics.heavy()
        case .six, .bigOver: Haptics.tap()
        case .winningRuns, .defended, .superOver, .hundred: Haptics.success()
        default: break
        }
    }
}

struct HighlightCard: View {
    @EnvironmentObject var store: GameStore
    let moment: Highlight
    var compact = false
    @State private var pop = false

    var body: some View {
        let team = store.team(moment.teamId)
        let color = moment.kind.color
        VStack(alignment: .leading, spacing: compact ? 8 : 14) {
            HStack(alignment: .center, spacing: 10) {
                Text(moment.kind.icon).font(.system(size: compact ? 34 : 48))
                Text(moment.kind.title)
                    .font(.display(compact ? 44 : 64))
                    .foregroundStyle(color)
                    .lineLimit(1).minimumScaleFactor(0.4)
                    .scaleEffect(pop ? 1 : 0.6, anchor: .leading)
                    .opacity(pop ? 1 : 0)
            }
            Text(moment.text)
                .font(.system(size: compact ? 18 : 22, weight: .semibold))
                .lineLimit(3).minimumScaleFactor(0.7)
            HStack(spacing: 8) {
                if let team { TeamBadge(team: team, size: 28) }
                Text(team?.name.uppercased() ?? "").font(.display(15, weight: .heavy)).lineLimit(1)
                Spacer(minLength: 4)
                Text(moment.score).font(.score(20))
                Text("\(moment.over) OV").font(.score(13, weight: .regular)).foregroundStyle(Palette.muted)
            }
            Text(moment.innings == 0 ? "1ST INNINGS" : "2ND INNINGS")
                .font(.display(12, weight: .heavy)).foregroundStyle(Palette.muted)
        }
        .padding(compact ? DS.Space.md : DS.Space.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(LinearGradient(colors: [color.opacity(0.28), Palette.surface], startPoint: .topLeading, endPoint: .bottomTrailing))
        )
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(color.opacity(0.6), lineWidth: 1.5))
        .shadow(color: color.opacity(0.35), radius: 24)
        .onAppear { withAnimation(.spring(response: 0.4, dampingFraction: 0.55).delay(0.1)) { pop = true } }
    }
}

/// Compact list of moments for the scorecard screen.
struct HighlightsList: View {
    @EnvironmentObject var store: GameStore
    let moments: [Highlight]

    var body: some View {
        AppCard(padding: DS.Space.md) {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(moments.enumerated()), id: \.offset) { i, m in
                    HStack(alignment: .top, spacing: 10) {
                        Text(m.over).font(.score(13)).foregroundStyle(Palette.muted).frame(width: 36, alignment: .leading)
                        Text(m.kind.icon)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(m.kind.title).font(.display(14, weight: .heavy)).foregroundStyle(m.kind.color)
                            Text(m.text).font(.subheadline).lineLimit(2)
                        }
                        Spacer(minLength: 4)
                        Text(m.score).font(.score(14)).foregroundStyle(Palette.muted)
                    }
                    .staggered(i)
                }
            }
        }
    }
}
