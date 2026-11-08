import SwiftUI

extension Color {
    init(hex: String) {
        let s = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var rgb: UInt64 = 0
        Scanner(string: s).scanHexInt64(&rgb)
        let r, g, b: Double
        if s.count == 6 {
            r = Double((rgb & 0xFF0000) >> 16) / 255
            g = Double((rgb & 0x00FF00) >> 8) / 255
            b = Double(rgb & 0x0000FF) / 255
        } else {
            r = 0.31; g = 0.55; b = 1.0
        }
        self.init(red: r, green: g, blue: b)
    }
}

enum Palette {
    /// Curated, high-contrast habit colors (our own choices).
    static let habitColors: [String] = [
        "#4F8CFF", "#38BDF8", "#34D399", "#A78BFA",
        "#FB7185", "#F59E0B", "#F472B6", "#22D3EE",
        "#818CF8", "#2DD4BF", "#FBBF24", "#EF4444"
    ]

    static let emojis: [String] = [
        "✅","💧","📖","🧘","🏃","💪","🥗","😴","🧹","☀️",
        "🎯","🎸","✍️","🧠","🚭","🍫","💤","📵","🙏","🌱"
    ]
}

extension View {
    func cardStyle() -> some View {
        self
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
    }
}
