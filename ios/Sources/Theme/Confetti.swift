import SwiftUI
import UIKit

/// A short, original confetti burst shown when a day is fully complete.
struct ConfettiView: View {
    private let colors = Palette.habitColors.map { Color(hex: $0) }
    private let count = 26
    @State private var animate = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(0..<count, id: \.self) { i in
                    let seed = Double((i * 9301 + 49297) % 233280) / 233280.0
                    let x = seed * geo.size.width
                    let delay = seed * 0.3
                    let dur = 1.1 + seed * 0.9
                    let size = 6.0 + seed * 6.0
                    RoundedRectangle(cornerRadius: 2)
                        .fill(colors[i % colors.count])
                        .frame(width: size, height: size * 1.6)
                        .rotationEffect(.degrees(seed * 360))
                        .position(x: x, y: animate ? geo.size.height + 40 : -40)
                        .opacity(animate ? 0 : 1)
                        .animation(.easeIn(duration: dur).delay(delay), value: animate)
                }
            }
        }
        .allowsHitTesting(false)
        .onAppear { animate = true }
    }
}

/// Light haptic feedback for taps.
enum Haptics {
    static func tap() {
        let g = UIImpactFeedbackGenerator(style: .light)
        g.impactOccurred()
    }
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}
