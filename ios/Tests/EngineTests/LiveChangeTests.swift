import XCTest
@testable import AuctionEngine

/// Career › Match day: pause and change mid-match (L0 engine + L1 preview/commit).
extension CareerTests {
    func key(_ e: BallEvent) -> String { "\(e.innings).\(e.over).\(e.ballInOver).\(e.label).\(e.score).\(e.strikerId).\(e.bowlerId)" }

    func testLiveChangesKeepThePastAndChangeTheFuture() {
        var c = newCareer(seed: 91)
        c.simUntilUserMatch()
        let f = c.nextUserFixture!
        let me = c.userTeam(in: f.id)!
        let (r0, log0) = c.previewMatch(fixtureId: f.id, changes: [])!
        // Preview without changes == the committed match.
        var committed = c
        XCTAssertEqual(committed.play(fixtureId: f.id)!.0.id, r0.id)

        // Pause at the start of over 7 of the innings we bowl, and change things.
        let bowlInn = r0.innings[0].teamId == me ? 1 : 0
        let batInn = 1 - bowlInn
        let k = log0.firstIndex { $0.innings == bowlInn && $0.over == 6 }!
        let before = log0[k - 1]
        let fromBall = before.over * 6 + before.ballInOver
        let usedSoFar = Set(log0[..<k].filter { $0.innings == bowlInn }.map(\.bowlerId))
        let xi = r0.card(batInn).batters.map(\.id)   // our XI
        let fresh = xi.first { id in !usedSoFar.contains(id) && (c.players[id]?.bowl ?? 0) >= 25 && id != before.bowlerId }
            ?? xi.first { $0 != before.bowlerId }!
        var change = LiveChange(innings: bowlInn, fromBall: fromBall, teamId: me)
        change.nextOverBowler = fresh
        change.tactics = Tactics(field: [.attack, .attack, .attack], intent: [.attack, .attack, .attack])
        let reversed = Array(xi.reversed())
        change.battingOrder = reversed
        let (r1, log1) = c.previewMatch(fixtureId: f.id, changes: [change])!

        // Everything already shown is identical.
        XCTAssertEqual(log0[..<k].map(key), log1[..<k].map(key))
        // The next over is bowled by the chosen bowler.
        XCTAssertTrue(log1[k...].prefix { $0.innings == bowlInn && $0.over == 6 }.allSatisfy { $0.bowlerId == fresh })
        // Laws still hold: max 4 overs each, no consecutive overs.
        for inn in r1.innings {
            XCTAssertTrue(inn.bowlers.allSatisfy { $0.balls <= 24 }, "4-over limit")
        }
        var lastBowler: [Int: String] = [:]
        for e in log1 where e.innings < 2 && e.ballInOver == 1 && e.label != "wd" {
            XCTAssertNotEqual(lastBowler[e.innings], e.bowlerId, "same bowler in consecutive overs")
            lastBowler[e.innings] = e.bowlerId
        }
        // Our batting order changed for batters still to come (we bat later, so all of them).
        if batInn > bowlInn {
            XCTAssertEqual(r1.card(batInn).batters.map(\.id), reversed)
        }
        // Committing with the same changes gives the identical match.
        var c2 = c
        XCTAssertEqual(c2.play(fixtureId: f.id, changes: [change])!.0.id, r1.id)
        XCTAssertEqual(c2.results.last?.innings.map(\.runs), r1.innings.map(\.runs))
    }

    func testScorecardSoFar() {
        var c = newCareer(seed: 92)
        c.simUntilUserMatch()
        let f = c.nextUserFixture!
        let (r, log) = c.previewMatch(fixtureId: f.id, changes: [])!
        // At the end it matches the final scorecard.
        let full = MatchEngine.scorecardSoFar(result: r, log: log, upTo: log.count)
        for (i, card) in full.enumerated() {
            let final = r.card(i)
            XCTAssertEqual(card.runs, final.runs)
            XCTAssertEqual(card.wickets, final.wickets)
            XCTAssertEqual(card.balls, final.balls)
            for b in final.batters where b.batted {
                let mine = card.batters.first { $0.id == b.id }!
                XCTAssertEqual(mine.runs, b.runs, b.name)
                XCTAssertEqual(mine.balls, b.balls, b.name)
                XCTAssertEqual(mine.dismissal, b.dismissal, b.name)
            }
            for bw in final.bowlers where bw.balls > 0 {
                let mine = card.bowlers.first { $0.id == bw.id }!
                XCTAssertEqual(mine.balls, bw.balls); XCTAssertEqual(mine.runs, bw.runs); XCTAssertEqual(mine.wickets, bw.wickets)
            }
        }
        // Mid-way: no spoilers.
        let half = MatchEngine.scorecardSoFar(result: r, log: log, upTo: 40)
        XCTAssertEqual(half.count, 1)
        XCTAssertEqual(half[0].runs, log[39].score)
    }

    /// Taking a bowler off: he bowls no more overs that innings; the past is unchanged; laws hold.
    func testRestedBowlerDoesNotBowlAgain() {
        var c = newCareer(seed: 93)
        c.simUntilUserMatch()
        let f = c.nextUserFixture!
        let me = c.userTeam(in: f.id)!
        let (r0, log0) = c.previewMatch(fixtureId: f.id, changes: [])!
        let bowlInn = r0.innings[0].teamId == me ? 1 : 0
        // After over 4 of the innings we bowl: take off whoever bowled it.
        let k = log0.firstIndex { $0.innings == bowlInn && $0.over == 4 }!
        let before = log0[k - 1]
        let offender = before.bowlerId
        var change = LiveChange(innings: bowlInn, fromBall: before.over * 6 + before.ballInOver, teamId: me)
        change.restBowlers = [offender]
        let (r1, log1) = c.previewMatch(fixtureId: f.id, changes: [change])!
        XCTAssertEqual(log0[..<k].map(key), log1[..<k].map(key), "the past is unchanged")
        XCTAssertFalse(log1[k...].contains { $0.innings == bowlInn && $0.bowlerId == offender }, "he doesn't bowl again")
        XCTAssertTrue(r1.innings.allSatisfy { $0.bowlers.allSatisfy { $0.balls <= 24 } }, "4-over limit")
        var last: [Int: String] = [:]
        for e in log1 where e.innings < 2 && e.ballInOver == 1 && e.label != "wd" {
            XCTAssertNotEqual(last[e.innings], e.bowlerId, "no consecutive overs")
            last[e.innings] = e.bowlerId
        }
        // The innings still gets its 20 overs (or ends with all out / the target), bowled by others.
        let bowled = r1.card(bowlInn).bowlers.map(\.balls).reduce(0, +)
        XCTAssertEqual(bowled, r1.card(bowlInn).balls)
    }
}
