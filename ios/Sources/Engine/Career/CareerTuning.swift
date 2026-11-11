import Foundation

/// Balance numbers for career mode. Defaults live here; `career_tuning.json` (generated from these
/// defaults and checked by a test) lets values be tuned without touching code.
struct CareerTuning: Codable, Hashable {
    // Season shape
    /// Times each pair of teams meets in the league (4 → 36 matches each with 10 teams).
    var meetings = 4
    /// League blocks: first day-of-year and number of rounds. International windows fall between them.
    var leagueBlocks: [[Int]] = [[10, 12], [125, 12], [244, 12]]
    /// Days between league rounds.
    var roundGap = 6
    /// Days of Qualifier 1, Eliminator, Qualifier 2 and the Final.
    var playoffDays = [316, 318, 320, 323]

    // Squads
    var minSquad = 18
    var maxSquad = 25
    var startSquad = 20
    var maxOverseasSquad = 8
    var maxOverseasXI = 4
    /// Starting squad shape: WK, BAT, AR, BOWL.
    var squadShape = [2, 6, 4, 8]
    /// Generated depth players in a new career.
    var depthPlayers = 160
    /// Rating ranges for depth players: batters/keepers, bowlers (all-rounders sit between).
    /// Batting depth is a little stronger because the curated bowlers are more elite than the batters.
    var depthBat = [58, 76]
    var depthBowl = [52, 70]
    /// Chance a generated player has a trait (and of a second one after that).
    var traitChance = 0.5
    var secondTraitChance = 0.25
    /// Batting points added inside the match engine only, so career XIs (deeper, with fewer
    /// trait-laden stars than the quick game) score like the quick game's calibrated pars.
    var engineBatBoost = 8
    /// Extra engine batting points per pitch (Pitch.allCases order: flat, seam, bounce, turner,
    /// slow), so bowler-friendly grounds land near real T20 pars (~155-170) instead of ~135.
    var pitchBatBoost = [0, 14, 15, 16, 11]

    // Development (per season, applied to the main skill)
    /// Growth range by age band: [maxAge, min, max].
    /// Owner's request: faster growth for young players (was 2-7, 1-5, 0-3, -1-1 up to 29).
    var growth: [[Int]] = [[20, 3, 8], [23, 2, 6], [26, 1, 5], [29, 0, 2], [32, -3, 0], [35, -5, -1], [99, -7, -2]]
    /// Players this age or younger with this many matches in a season gain an extra point.
    var matchGrowthAge = 25
    var matchGrowthMatches = 10
    /// Improving players this age or younger get a raise: this share of the rise in wage value.
    var raiseAge = 29
    var developmentRaise = 0.5
    /// Retirement: earliest age, base chance at that age, extra chance per year after.
    var retireAge = 35
    var retireBase = 0.3
    var retirePerYear = 0.2
    /// Pace bowlers retire a year earlier.
    var paceRetireOffset = 1
    /// Weak veterans (below this rating, 31+) retire more often.
    var weakVeteranRating = 56
    var youthIntake = 30
    var youthGemChance = 0.08

    // Money (lakhs; 100 = ₹1 Cr)
    /// Salary cap: a club's total wages (the IPL purse).
    var salaryCap = 12_000
    var startingBank = 2_500
    var minWage = 20
    /// Paid to every club after each season, plus prize money by finish. ₹65 Cr (was ₹80 Cr) so a
    /// mid-table season clears about ₹15 Cr after wages and a title about ₹50 Cr: one star a good
    /// season, never the whole market (owner's request).
    var seasonRevenue = 6_500
    /// Owner's request: ₹40 Cr to the champions (the rest scaled the same).
    var prizeMoney = [4_000, 2_600, 1_400, 1_300]   // champion, runner-up, lost Q2, lost Eliminator
    /// Mega auction every N seasons (up to `maxRetentions` kept); mini auctions in between.
    var megaAuctionEvery = 3
    var maxRetentions = 6
    /// Target squad size clubs bid towards at auction.
    var auctionSquadTarget = 21
    /// Transfer-market multipliers on market value.
    var askXIMultiplier = 1.5
    var askBenchMultiplier = 1.15
    var counterThreshold = 0.75
    var releaseCompensation = 0.5
    /// AI-to-AI transfers: money an AI club keeps in reserve, deals per club per window, and how
    /// much better (rating) a target must be than the XI player it replaces.
    var aiReserveBank = 2_500
    var aiDealsPerWindow = 2
    var aiUpgradeMargin = 3
    /// Largest gap (XI strength points) allowed between clubs after the opening draft.
    var draftBalance = 2
    /// Bank (lakhs) at season start above which the board sets an invest objective.
    var investObjectiveBank = 10_000

    // Training, scouting, academy (M3)
    var trainingSlots = 3
    /// Chance per week that a drilled attribute gains a point (before age and intensity).
    var drillChance = 0.05
    var focusMultiplier = 2.5
    var academyBoost = 1.3
    var academyMax = 8
    /// Width of the potential range for a player nobody has scouted.
    var unknownPotentialWidth = 20
    var scoutCap = 2
    /// Scouts file a report this often (in weeks = your matches).
    var scoutReportEveryWeeks = 2
    var scoutWage = 25

    // Club and manager (M4)
    /// Upgrade cost = this × the next level (linear), so a season of ticket sales pays for one
    /// upgrade of every facility at the stadium's level (owner's request; CareerEconomyTests).
    var facilityBaseCost = 30
    var facilityUpkeep = 5
    /// Gate per Stadium level: ₹50 L+ a home match at level 2 even in front of the smallest crowd.
    var gatePerLevel = 35
    var commercialPerLevel = 150
    /// Main sponsor, paid each month of the season (lakhs, at Commercial Hub level 1; +15% a level).
    var sponsorMonthly = 40
    /// Facility level assumed for AI clubs, and the user's starting level.
    var aiFacilityLevel = 2
    var startingGold = 100
    var goldPerLevel = 20
    var goldPerBuildWeek = 40
    var goldPerMatch = 2
    var goldForTitle = 200

    // Form
    /// Form drifts back towards 0 by this much a match (2 since panel round 5: 1 let spirals run).
    var formDecay = 2
    var formCap = 10

    static let standard = CareerTuning()

    func growthRange(age: Int) -> ClosedRange<Int> {
        let band = growth.first { age <= $0[0] } ?? growth.last!
        return band[1]...band[2]
    }

    /// Day-of-year for each league round (0-based).
    var roundDays: [Int] {
        leagueBlocks.flatMap { b in (0..<b[1]).map { b[0] + $0 * roundGap } }
    }
}

/// Day-of-year → "12 Mar".
enum CareerCalendar {
    static let monthLengths = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
    static let monthNames = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

    static func monthDay(_ dayOfYear: Int) -> (month: Int, day: Int) {
        var d = max(1, min(365, dayOfYear))
        for (m, len) in monthLengths.enumerated() {
            if d <= len { return (m, d) }
            d -= len
        }
        return (11, 31)
    }

    static func label(_ dayOfYear: Int) -> String {
        let md = monthDay(dayOfYear)
        return "\(md.day) \(monthNames[md.month])"
    }

    static func label(_ dayOfYear: Int, year: Int) -> String { "\(label(dayOfYear)) \(year)" }
}
