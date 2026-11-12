import XCTest
@testable import AuctionEngine

/// Owner's request: the assistant at the innings break.
extension CareerTests {
    func testBreakAdviceReadsTheTotalAgainstPar() {
        var first = InningsCard(teamId: 1)
        first.runs = 210
        let flat = Pitch.indianFlat
        // The user chasing an above-par total: go hard early.
        let chase = LiveReport.breakAdvice(first: first, pitch: flat, userTeam: 2, tactics: GamePlan.buildAndLaunch.apply(to: Tactics()))
        XCTAssertTrue(chase[0].contains("211"))
        XCTAssertTrue(chase[0].contains("powerplay"))
        XCTAssertEqual(chase.count, 1, "already on the plan that suits a flat pitch")
        // The user defending a below-par total on a seamer: wickets, and the plan that suits.
        first.runs = 110
        let defend = LiveReport.breakAdvice(first: first, pitch: .englishSeam, userTeam: 1, tactics: Tactics())
        XCTAssertTrue(defend[0].contains("below par"))
        XCTAssertTrue(defend[1].contains(GamePlan.suggested(for: .englishSeam).label))
    }
}
