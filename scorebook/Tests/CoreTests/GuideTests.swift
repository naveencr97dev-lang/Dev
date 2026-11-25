import XCTest
@testable import ScoreBookCore

final class GuideTests: XCTestCase {
    func testIdsUnique() {
        XCTAssertEqual(Set(Guide.robberies.map(\.id)).count, Guide.robberies.count)
        XCTAssertEqual(Set(Guide.money.map(\.id)).count, Guide.money.count)
        XCTAssertEqual(Set(Guide.rules.map(\.id)).count, Guide.rules.count)
    }

    func testEveryRobberyHasStepsAndEveryTierIsUsed() {
        for g in Guide.robberies { XCTAssertFalse(g.steps.isEmpty, g.id) }
        XCTAssertEqual(Set(Guide.robberies.map(\.tier)), Set(RobberyGuide.Tier.allCases))
    }

    func testPrepOnlyForWalkInTargets() {
        let store = Guide.robberies.first { $0.id == "convenience" }!
        XCTAssertEqual(Guide.stepsWithPrep(store).count, Guide.prep.count + store.steps.count)
        let safe = Guide.robberies.first { $0.id == "safes" }!
        XCTAssertEqual(Guide.stepsWithPrep(safe), safe.steps)
    }

    func testCleanChecklistExists() {
        XCTAssertNotNil(Guide.rules.first { $0.id == "clean" })
    }
}
