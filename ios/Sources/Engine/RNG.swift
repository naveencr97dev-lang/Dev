import Foundation

/// Small, fast, seedable generator (SplitMix64) so games can be saved and tests are repeatable.
struct SeededRNG: RandomNumberGenerator, Codable, Hashable {
    var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    mutating func unit() -> Double { Double.random(in: 0..<1, using: &self) }

    mutating func range(_ lo: Double, _ hi: Double) -> Double { Double.random(in: lo..<hi, using: &self) }

    /// Index chosen in proportion to its weight.
    mutating func weighted(_ weights: [Double]) -> Int {
        let total = weights.reduce(0, +)
        guard total > 0 else { return 0 }
        var r = unit() * total
        for (i, w) in weights.enumerated() {
            r -= w
            if r < 0 { return i }
        }
        return weights.count - 1
    }
}
