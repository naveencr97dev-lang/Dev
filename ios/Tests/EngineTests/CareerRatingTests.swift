import XCTest
@testable import AuctionEngine

/// Career › Stats: match ratings, the development report.
extension CareerTests {
    func testMatchRatingsAreCalibrated() {
        var c = newCareer(seed: 601)
        c.simToSeasonEnd()
        var all: [Double] = [], potm: [Double] = []
        for r in c.results {
            for inn in r.innings.prefix(2) {
                for b in inn.batters {
                    guard let x = Career.matchRating(b.id, in: r) else { continue }
                    all.append(x)
                    if b.id == r.potmId { potm.append(x) }
                }
            }
        }
        let mean = all.reduce(0, +) / Double(all.count)
        let sd = (all.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(all.count)).squareRoot()
        let potmMean = potm.reduce(0, +) / Double(potm.count)
        print("Match ratings: mean \(String(format: "%.2f", mean)) sd \(String(format: "%.2f", sd)) POTM \(String(format: "%.2f", potmMean)) 9+: \(all.filter { $0 >= 9 }.count * 100 / all.count)%")
        XCTAssertTrue((5.8...7.0).contains(mean), "mean \(mean)")
        XCTAssertGreaterThan(sd, 0.6, "ratings spread out")
        XCTAssertGreaterThan(potmMean, 8.0, "player of the match rates high")
        XCTAssertTrue(all.allSatisfy { (3...10).contains($0) })
    }

    func testDevelopmentWatchAndProgress() {
        var c = newCareer(seed: 602)
        let young = c.developmentWatch
        XCTAssertTrue(young.allSatisfy { $0.age(in: c.year) <= 23 })
        XCTAssertTrue(young.allSatisfy { c.seasonProgress($0) == 0 }, "nothing changed yet")
        c.simToSeasonEnd()
        XCTAssertTrue(c.developmentWatch.allSatisfy { c.seasonProgress($0) != nil })
        let star = c.userClub.xi[0]
        XCTAssertEqual(c.recentRatings(star).count, min(5, c.matchRatings(star).count))
    }
}
