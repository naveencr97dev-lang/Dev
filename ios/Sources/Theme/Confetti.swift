import SwiftUI

/// A confetti burst for the champion screen and big sales.
struct ConfettiView: View {
    var colors: [Color] = Palette.teamColors.map { Color(hex: $0) } + [Palette.gold]
    var count = 60
    @State private var animate = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(0..<count, id: \.self) { i in
                    let seed = Double((i * 9301 + 49297) % 233280) / 233280.0
                    let x = seed * geo.size.width
                    let drift = (seed - 0.5) * 120
                    let delay = seed * 0.6
                    let dur = 1.6 + seed * 1.4
                    let size = 6.0 + seed * 7.0
                    RoundedRectangle(cornerRadius: 2)
                        .fill(colors[i % colors.count])
                        .frame(width: size, height: size * 1.6)
                        .rotationEffect(.degrees(animate ? seed * 720 : 0))
                        .position(x: animate ? x + drift : x, y: animate ? geo.size.height + 40 : -40)
                        .opacity(animate ? 0.2 : 1)
                        .animation(.easeIn(duration: dur).delay(delay), value: animate)
                }
            }
        }
        .allowsHitTesting(false)
        .onAppear { animate = true }
    }
}
