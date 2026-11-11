import XCTest
@testable import AuctionEngine

/// The match centre's live reads: numbers, ratings, advice and the round's other results.
extension CareerTests {
    private func playedMatch(seed: UInt64) -> (Career, Fixture, MatchResult, [BallEvent]) {
        let c = newCareer(seed: seed)
        let f = c.fixtures.first { $0.stage == .league }!
        let (r, log, _) = c.simulate(f, changes: [])
        return (c, f, r, log)
    }

    func testLiveNumbersFollowTheBallLog() {
        let (_, _, r, log) = playedMatch(seed: 1201)
        // Halfway through the chase.
        let chase = log.indices.filter { log[$0].innings == 1 }
        let shown = chase[chase.count / 2] + 1
        let cards = MatchEngine.scorecardSoFar(result: r, log: log, upTo: shown)
        let n = LiveReport.numbers(cards: cards, log: log, upTo: shown)!
        XCTAssertEqual(n.innings, 1)
        XCTAssertEqual(n.runs, log[shown - 1].score)
        XCTAssertEqual(n.wickets, log[shown - 1].wickets)
        XCTAssertEqual(n.target, r.innings[0].runs + 1)
        XCTAssertNotNil(n.requiredRate)
        XCTAssertNil(n.projected)
        XCTAssertLessThanOrEqual(n.partnershipRuns, n.runs)
        XCTAssertLessThanOrEqual(n.lastFive, n.runs)
        XCTAssertTrue((0...100).contains(n.dotPercent))
        // First innings: a projection, no target.
        let first = LiveReport.numbers(cards: MatchEngine.scorecardSoFar(result: r, log: log, upTo: 40), log: log, upTo: 40)!
        XCTAssertEqual(first.innings, 0)
        XCTAssertNil(first.target)
        XCTAssertNotNil(first.projected)
        XCTAssertNil(LiveReport.numbers(cards: [], log: log, upTo: 0))
    }

    func testLiveRatingsMatchTheEndOfMatchRating() {
        let (_, _, r, log) = playedMatch(seed: 1202)
        let cards = MatchEngine.scorecardSoFar(result: r, log: log, upTo: log.count)
        for b in r.innings[0].batters + r.innings[1].batters {
            let live = LiveReport.rating(b.id, cards: cards, winnerId: r.winnerId, potmId: r.potmId)
            XCTAssertEqual(live, Career.matchRating(b.id, in: r), b.name)
        }
        // Nobody has done anything before the first ball.
        let none = MatchEngine.scorecardSoFar(result: r, log: log, upTo: 0)
        XCTAssertFalse(r.innings[0].batters.contains { LiveReport.involved($0.id, cards: none) })
    }

    func testAssistantAlwaysSaysSomethingShortForBothSides() {
        let (_, _, r, log) = playedMatch(seed: 1203)
        for shown in stride(from: 0, through: log.count, by: 17) {
            let cards = MatchEngine.scorecardSoFar(result: r, log: log, upTo: shown)
            for team in [r.teamA, r.teamB] {
                let lines = LiveReport.advice(cards: cards, log: log, upTo: shown, userTeam: team)
                XCTAssertFalse(lines.isEmpty)
                XCTAssertLessThanOrEqual(lines.count, 3)
            }
        }
    }

    func testAssistantPushesAChaseThatIsFallingBehind() {
        // A made-up chase: 30 for 1 off 6 overs, chasing 201.
        let first = InningsCard(teamId: 1, runs: 200, wickets: 5, balls: 120)
        let chase = InningsCard(teamId: 0, runs: 30, wickets: 1, balls: 36)
        let log = (0..<36).map { i in
            BallEvent(innings: 1, over: i / 6, ballInOver: i % 6 + 1, label: "1", text: "", score: (i + 1) * 30 / 36,
                      wickets: 1, batters: [], bowler: LiveBowler(name: "B", balls: 0, runs: 0, wickets: 0))
        }
        let lines = LiveReport.advice(cards: [first, chase], log: log, upTo: 36, userTeam: 0, intent: .rotate)
        XCTAssertTrue(lines.first?.contains("Attack") == true, "\(lines)")
        XCTAssertFalse(LiveReport.advice(cards: [first, chase], log: log, upTo: 36, userTeam: 0, intent: .attack)
            .contains { $0.contains("Switch batting to Attack") }, "no advice to do what we already do")
    }

    func testRoundResultsAreTheOtherMatchesOfTheDay() {
        var c = newCareer(seed: 1204)
        c.simUntilUserMatch()
        guard let f = c.nextUserFixture else { return XCTFail("no user fixture") }
        let all = c.roundFixtures(around: f.id)
        XCTAssertEqual(all.count, c.clubs.count / 2 - 1, "the other four matches of the round")
        XCTAssertFalse(all.contains { $0.involves(c.userClubId) })
        let played = c.roundResults(around: f.id)
        XCTAssertEqual(played.count, all.filter(\.played).count)
        XCTAssertFalse(played.isEmpty && f.id > all.map(\.id).min()!, "matches before the user's are already played")
    }
}

/// The player card's last five matches.
extension CareerTests {
    func testRecentMatchesAreTheLastFiveWithRatings() {
        var c = newCareer(seed: 1205)
        for _ in 0..<7 {
            c.simUntilUserMatch()
            guard let f = c.nextUserFixture else { break }
            c.play(fixtureId: f.id)
        }
        let xi = c.userClub.xi
        guard let id = xi.first else { return XCTFail("no XI") }
        let lines = c.recentMatches(id)
        XCTAssertEqual(lines.count, 5)
        XCTAssertEqual(lines.map(\.rating), Array(c.matchRatings(id).suffix(5).reversed()), "newest first, same ratings")
        XCTAssertTrue(lines.allSatisfy { $0.opponent != c.userClubId && $0.day != nil })
        XCTAssertTrue(c.recentMatches("nobody").isEmpty)
    }
}
