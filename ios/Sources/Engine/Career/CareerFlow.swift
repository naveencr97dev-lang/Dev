import Foundation

/// The one thing the CONTINUE button does next (manager-game style). The journey test drives the
/// career with the same logic, so the button can never lead to a dead end.
enum CareerAction: Equatable {
    case goToOffseason, openWindow, playIntl(Int), simWindow, retention, auction, startSeason
    case playMatch(Int), continueToMatch, watchOther(Int), none
}

extension Career {
    var nextAction: CareerAction {
        if phase == .seasonEnd { return .goToOffseason }
        if pendingWindow != nil {
            if intl.event?.key != pendingWindow { return .openWindow }
            if let f = nextIntlFixture, isUserNationFixture(f) { return .playIntl(f.id) }
            return .simWindow
        }
        if phase == .offseason {
            switch offseason?.stage ?? .window {
            case .retention: return .retention
            case .auction: return .auction
            case .window: return .startSeason
            }
        }
        guard let f = nextFixture else { return .none }
        if isUserFixture(f) { return .playMatch(f.id) }
        if nextUserFixture != nil { return .continueToMatch }
        return .watchOther(f.id)
    }

    /// Button title and a one-line detail for the next action.
    var nextActionLabel: (title: String, detail: String) {
        switch nextAction {
        case .goToOffseason: return ("Go to off-season", "Ageing, retirements, youth intake")
        case .openWindow: return ("International window", "The league pauses")
        case .playIntl(let id):
            let f = intl.fixtures.first { $0.id == id }
            let opp = f.flatMap { nationCode(teamId: isUserNationFixture($0) && $0.home == nationTeamId(intl.job ?? "") ? $0.away : $0.home) } ?? ""
            return ("Play \(f?.stage.label ?? "T20I")", "vs \(opp)")
        case .simWindow: return ("Continue", "Play out the international window")
        case .retention: return ("Retentions", "Choose who to keep")
        case .auction: return ("Auction room", "\(offseason?.auction.remaining ?? 0) lots left")
        case .startSeason: return ("Start season", "Season \(year) kicks off")
        case .playMatch(let id):
            let f = fixtures.first { $0.id == id }
            let opp = f.flatMap { club($0.home == userClubId ? $0.away : $0.home)?.short } ?? ""
            let when = f.map { CareerCalendar.label(day(of: $0)) } ?? ""
            return ("Play match", "\(f.flatMap { round(of: $0) }.map { "R\($0) · " } ?? "")vs \(opp) · \(when)")
        case .continueToMatch: return ("Continue", "Sim to your next match")
        case .watchOther(let id):
            let f = fixtures.first { $0.id == id }
            return ("Watch \(f?.stage.label ?? "match")", "You're out — watch or sim")
        case .none: return ("Continue", "")
        }
    }
}
