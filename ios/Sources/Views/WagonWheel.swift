import SwiftUI

/// Top-down ground showing where each scoring shot of the innings went.
/// Shot directions are illustrative (the engine decides runs, not angles), but repeatable per ball.
struct WagonWheel: View {
    struct Shot: Identifiable {
        let id: Int
        let runs: Int
        let wicket: Bool
        let caught: Bool
        /// Radians clockwise from straight back past the bowler (up the screen).
        let angle: Double
        /// Fraction of the boundary radius.
        let dist: Double

        init(index: Int, event e: BallEvent) {
            id = index
            wicket = e.label == "W"
            runs = Int(e.label) ?? 0
            caught = wicket && (e.text.contains(" c ") || e.text.contains("c & b") || e.text.contains("run out"))
            var rng = SeededRNG(seed: UInt64(index + 1) &* 0x9E37_79B9 &+ UInt64(e.score) &* 131 &+ UInt64(e.innings) &* 7)
            // Scoring zones: (centre°, spread°, weight for 1-3, weight for 4/6)
            let zones: [(Double, Double, Double, Double)] = [
                (0, 15, 1.0, 2.0),     // straight
                (50, 25, 3.0, 2.5),    // cover / extra cover
                (95, 15, 1.5, 1.2),    // point
                (150, 20, 1.0, 0.8),   // third man
                (210, 20, 1.2, 1.0),   // fine leg
                (265, 15, 1.5, 1.5),   // square leg
                (300, 20, 3.0, 3.5),   // midwicket / cow corner
                (335, 15, 1.5, 2.5),   // long-on
            ]
            let big = runs >= 4
            let z = zones[rng.weighted(zones.map { big ? $0.3 : $0.2 })]
            let deg = z.0 + rng.range(-z.1, z.1)
            angle = deg * .pi / 180
            switch (wicket, runs) {
            case (true, _): dist = caught ? rng.range(0.55, 0.95) : 0
            case (_, 1): dist = rng.range(0.32, 0.55)
            case (_, 2): dist = rng.range(0.6, 0.8)
            case (_, 3): dist = rng.range(0.82, 0.95)
            case (_, 4): dist = 1.0
            case (_, 6): dist = rng.range(1.12, 1.2)
            default: dist = 0
            }
        }

        var color: Color {
            switch runs {
            case 6: return Palette.six
            case 4: return Palette.four
            default: return .white
            }
        }
    }

    let shots: [Shot]
    /// Index (into the ball log) of the ball just revealed; animates if it's in `shots`.
    let latest: Int

    var body: some View {
        GeometryReader { geo in
            let R = min(geo.size.width, geo.size.height) * 0.42
            let c = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let bat = CGPoint(x: c.x, y: c.y + R * 0.13)
            let point = { (s: Shot) -> CGPoint in
                CGPoint(x: c.x + sin(s.angle) * s.dist * R, y: c.y - cos(s.angle) * s.dist * R)
            }
            ZStack {
                // Stands, outfield, rope, 30-yard circle, pitch.
                Circle().fill(Color(hex: "#0C2A18")).frame(width: R * 2.5, height: R * 2.5).position(c)
                Circle()
                    .fill(RadialGradient(colors: [Color(hex: "#2E8B4E"), Color(hex: "#1B5E34")], center: .center, startRadius: 0, endRadius: R))
                    .frame(width: R * 2, height: R * 2).position(c)
                Circle().stroke(Color.white.opacity(0.75), lineWidth: 2).frame(width: R * 2, height: R * 2).position(c)
                Circle().stroke(Color.white.opacity(0.25), style: StrokeStyle(lineWidth: 1, dash: [4, 5]))
                    .frame(width: R * 1.1, height: R * 1.1).position(c)
                RoundedRectangle(cornerRadius: 2).fill(Color(hex: "#C9B38A"))
                    .frame(width: R * 0.08, height: R * 0.36).position(c)

                // Earlier shots.
                ForEach(shots.filter { $0.id != latest }) { s in
                    if s.runs > 0 {
                        Path { p in p.move(to: bat); p.addLine(to: point(s)) }
                            .stroke(s.color.opacity(s.runs >= 4 ? 0.75 : 0.4), lineWidth: s.runs >= 4 ? 2 : 1.2)
                    } else if s.wicket {
                        Text("✕").font(.system(size: 13, weight: .black)).foregroundStyle(Palette.wicket)
                            .position(s.caught ? point(s) : CGPoint(x: bat.x, y: bat.y + 6))
                    }
                }

                // The ball just played, drawn out from the bat.
                if let s = shots.first(where: { $0.id == latest }) {
                    if s.runs > 0 {
                        LatestShot(from: bat, to: point(s), color: s.color, width: s.runs >= 4 ? 3.5 : 2.5)
                            .id(latest)
                    } else if s.wicket {
                        WicketMark(at: s.caught ? point(s) : CGPoint(x: bat.x, y: bat.y + 6)).id(latest)
                    }
                }
                Circle().fill(Color.white).frame(width: 7, height: 7).position(bat)
            }
            .overlay(alignment: .topLeading) {
                let fours = shots.filter { $0.runs == 4 }.count
                let sixes = shots.filter { $0.runs == 6 }.count
                VStack(alignment: .leading, spacing: 2) {
                    legend(Palette.four, "4s · \(fours)")
                    legend(Palette.six, "6s · \(sixes)")
                    legend(.white, "1–3")
                }
                .padding(8)
            }
        }
    }

    private func legend(_ color: Color, _ text: String) -> some View {
        HStack(spacing: 5) {
            Capsule().fill(color).frame(width: 12, height: 3)
            Text(text).font(.score(11, weight: .semibold)).foregroundStyle(Palette.muted)
        }
    }
}

private struct ShotLine: Shape {
    let from: CGPoint
    let to: CGPoint
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: from)
        p.addLine(to: to)
        return p
    }
}

/// The latest shot races from the bat to where it went.
private struct LatestShot: View {
    let from: CGPoint
    let to: CGPoint
    let color: Color
    let width: CGFloat
    @State private var t: CGFloat = 0

    var body: some View {
        ZStack {
            ShotLine(from: from, to: to)
                .trim(from: 0, to: t)
                .stroke(color, style: StrokeStyle(lineWidth: width, lineCap: .round))
                .shadow(color: color.opacity(0.8), radius: 6)
            Circle().fill(color).frame(width: 11, height: 11)
                .shadow(color: color, radius: 6)
                .position(x: from.x + (to.x - from.x) * t, y: from.y + (to.y - from.y) * t)
        }
        .onAppear { withAnimation(.easeOut(duration: 0.7)) { t = 1 } }
    }
}

private struct WicketMark: View {
    let at: CGPoint
    @State private var pop = false
    var body: some View {
        Text("✕")
            .font(.system(size: 30, weight: .black))
            .foregroundStyle(Palette.wicket)
            .shadow(color: Palette.wicket, radius: 8)
            .scaleEffect(pop ? 1 : 2.5)
            .opacity(pop ? 1 : 0)
            .position(at)
            .onAppear { withAnimation(.spring(response: 0.35, dampingFraction: 0.5)) { pop = true } }
    }
}

/// Shown between the innings: the total, the chase equation and the stars so far.
struct InningsBreakCard: View {
    @EnvironmentObject var store: GameStore
    let result: MatchResult
    let onContinue: () -> Void

    var body: some View {
        let first = result.innings[0]
        let batting = store.team(first.teamId)
        let chasing = store.team(result.innings[1].teamId)
        let topBat = first.batters.filter(\.batted).max { $0.runs < $1.runs }
        let topBowl = first.bowlers.max { ($0.wickets, -$0.runs) < ($1.wickets, -$1.runs) }
        ZStack {
            Color.black.opacity(0.65).ignoresSafeArea()
            VStack(spacing: 14) {
                Text("INNINGS BREAK").font(.display(16, weight: .heavy)).tracking(3).foregroundStyle(Palette.accent)
                HStack(spacing: 12) {
                    if let batting { TeamBadge(team: batting, size: 46) }
                    VStack(alignment: .leading, spacing: 0) {
                        Text(batting?.name.uppercased() ?? "").font(.display(18, weight: .heavy)).lineLimit(1)
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text(first.score).font(.score(40))
                            Text("(\(first.overs))").font(.score(16, weight: .regular)).foregroundStyle(Palette.muted)
                        }
                    }
                }
                if let topBat {
                    Text("⭐ \(topBat.name) \(topBat.runs) (\(topBat.balls))").font(.subheadline.weight(.semibold))
                }
                if let topBowl, topBowl.balls > 0 {
                    Text("🎯 \(topBowl.name) \(topBowl.wickets)/\(topBowl.runs)").font(.subheadline.weight(.semibold))
                }
                Text("\(chasing?.short ?? "") need \(first.runs + 1) from 120 · RRR \(String(format: "%.2f", Double(first.runs + 1) / 20))")
                    .font(.display(18, weight: .heavy)).foregroundStyle(Palette.accent)
                    .multilineTextAlignment(.center)
                Button("Start the chase", action: onContinue)
                    .buttonStyle(PrimaryButtonStyle())
            }
            .padding(24)
            .frame(maxWidth: 420)
            .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Palette.surface))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Palette.stroke))
            .padding(24)
        }
    }
}
