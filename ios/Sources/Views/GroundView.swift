import SwiftUI

/// Top-down 2D ground: fielders placed by the field setting, the latest ball's path, and the nearest
/// fielder chasing it. Shot directions come from `WagonWheel.Shot` (illustrative but repeatable).
struct GroundView: View {
    let shots: [WagonWheel.Shot]
    let latest: Int
    var field: FieldSetting = .balanced

    /// (degrees clockwise from straight, fraction of the boundary radius)
    static func positions(_ f: FieldSetting) -> [(Double, Double)] {
        switch f {
        case .attack:
            return [(170, 0.2), (140, 0.26), (95, 0.42), (55, 0.42), (15, 0.4), (345, 0.4), (295, 0.42), (262, 0.45), (205, 0.9)]
        case .balanced:
            return [(170, 0.2), (95, 0.45), (55, 0.45), (15, 0.42), (345, 0.42), (300, 0.45), (265, 0.9), (205, 0.9), (150, 0.9)]
        case .defend:
            return [(95, 0.45), (50, 0.45), (20, 0.94), (340, 0.94), (60, 0.93), (300, 0.93), (265, 0.92), (205, 0.92), (150, 0.92)]
        }
    }

    var body: some View {
        GeometryReader { geo in
            let r = min(geo.size.width, geo.size.height) / 2 * 0.9
            let c = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2 + r * 0.05)
            let shot = shots.first { $0.id == latest }
            let spots = Self.positions(field).map { point(c, r, $0.0, $0.1) }
            let chaser = shot.flatMap { s in nearest(spots, to: point(c, r, s.angle * 180 / .pi, min(s.dist, 1.0))) }
            ZStack {
                Circle().fill(Color(hex: "#166534")).frame(width: r * 2, height: r * 2).position(c)
                Circle().stroke(Color.white.opacity(0.55), lineWidth: 2).frame(width: r * 2, height: r * 2).position(c)
                Circle().stroke(Color.white.opacity(0.2), lineWidth: 1).frame(width: r * 0.9, height: r * 0.9).position(c)
                Rectangle().fill(Color(hex: "#C2A878")).frame(width: r * 0.07, height: r * 0.34)
                    .position(x: c.x, y: c.y - r * 0.15)
                // Bowler, keeper, batter.
                dot(point(c, r, 0, 0.36), Palette.wicket, 9)
                dot(point(c, r, 180, 0.08), Palette.four, 8)
                dot(c, Palette.accent, 9)
                ForEach(Array(spots.enumerated()), id: \.offset) { i, p in
                    let target = (i == chaser && shot != nil) ? chasePoint(c, r, shot!) : p
                    dot(target, .white, 8)
                        .animation(.easeOut(duration: 0.7), value: latest)
                }
                if let s = shot, s.runs > 0 || s.caught {
                    let end = point(c, r, s.angle * 180 / .pi, s.dist)
                    Path { path in
                        path.move(to: c)
                        path.addLine(to: end)
                    }
                    .stroke(s.color.opacity(0.7), lineWidth: 2)
                    dot(end, s.wicket ? Palette.wicket : s.color, 10)
                }
                Text(field.label.uppercased() + " FIELD").font(.display(10, weight: .heavy)).foregroundStyle(Palette.muted)
                    .position(x: c.x, y: c.y + r + 10)
            }
        }
    }

    private func dot(_ p: CGPoint, _ color: Color, _ size: CGFloat) -> some View {
        Circle().fill(color).frame(width: size, height: size).position(p)
    }

    private func point(_ c: CGPoint, _ r: CGFloat, _ deg: Double, _ dist: Double) -> CGPoint {
        let a = deg * .pi / 180
        return CGPoint(x: c.x + CGFloat(sin(a) * dist) * r, y: c.y - CGFloat(cos(a) * dist) * r)
    }

    private func chasePoint(_ c: CGPoint, _ r: CGFloat, _ s: WagonWheel.Shot) -> CGPoint {
        point(c, r, s.angle * 180 / .pi, min(s.dist, 0.97))
    }

    private func nearest(_ spots: [CGPoint], to p: CGPoint) -> Int? {
        spots.indices.min { hypot(spots[$0].x - p.x, spots[$0].y - p.y) < hypot(spots[$1].x - p.x, spots[$1].y - p.y) }
    }
}

/// The live match's ground panel: wagon wheel or 2D ground (remembered).
struct FieldOrWheel: View {
    let shots: [WagonWheel.Shot]
    let latest: Int
    @AppStorage("groundView2D") private var ground = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            if ground {
                GroundView(shots: shots, latest: latest)
            } else {
                WagonWheel(shots: shots, latest: latest)
            }
            Button {
                ground.toggle()
                Haptics.tap()
            } label: {
                Text(ground ? "WHEEL" : "2D").font(.display(11, weight: .heavy))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Palette.surfaceHi))
            }
            .buttonStyle(.plain)
        }
    }
}
