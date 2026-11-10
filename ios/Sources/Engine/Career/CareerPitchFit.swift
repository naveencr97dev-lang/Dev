import Foundation

// Career › Squad building for the home pitch. Half of a club's league matches are at home, so a
// squad built for that surface (spinners on a turner, quicks on a seamer, flat-track hitters on a
// road) wins more there. `Pitch.fit` puts the match engine's pitch effects into rating points; AI
// clubs use it in the draft, retentions, auctions, transfers and their XI.

enum PitchFit {
    /// Points for a trait that comes alive on the pitch (the engine's odds change is worth about this).
    static let traitPoints = 6
    /// A flat-track bully on a seaming or turning pitch.
    static let bullyPenalty = -3
    /// "Suits the pitch" badge threshold, and the "struggles" one.
    static let suits = 6
    static let struggles = -4
    /// Share of the fit that counts in squad building (half the matches are at home).
    static let squadWeight = 0.5
    /// Every squad still wants this many bowlers of each kind (pace, spin) for away matches;
    /// the draft adds this many rating points until it has them.
    static let minPerBowlType = 2
    static let varietyPoints = 5.0
    /// Value change per fit point when an AI club prices a player, and its limits.
    static let valuePerPoint = 0.025
    static let valueRange = 0.75...1.4
}

extension Pitch {
    /// Batting points on this pitch over a neutral one: home conditions and batting traits.
    func batFit(country: String, traits: [Trait]) -> Int {
        var fit = homeCountries.contains(country) ? 5 : 0
        for t in traits where t.isBatting && t.pitches.contains(self) { fit += PitchFit.traitPoints }
        if traits.contains(.flatTrackBully) && (self == .englishSeam || self == .dustyTurner) { fit += PitchFit.bullyPenalty }
        return fit
    }

    /// Bowling points on this pitch over a neutral one: pace or spin, home conditions, bowling traits.
    func bowlFit(country: String, bowlType: BowlType, traits: [Trait]) -> Int {
        var fit = bonus(for: bowlType) + (homeCountries.contains(country) ? 5 : 0)
        for t in traits where !t.isBatting && t.pitches.contains(self) { fit += PitchFit.traitPoints }
        return fit
    }

    func batFit(_ p: Player) -> Int { batFit(country: p.country, traits: p.traits) }
    func bowlFit(_ p: Player) -> Int { bowlFit(country: p.country, bowlType: p.bowlType, traits: p.traits) }

    /// Rating points a player gains (or loses) on this pitch, in the skill he is picked for.
    func fit(_ p: CareerPlayer) -> Int {
        let bat = batFit(country: p.country, traits: p.traits)
        let bowl = bowlFit(country: p.country, bowlType: p.bowlType, traits: p.traits)
        switch p.role {
        case .BAT, .WK: return bat
        case .BOWL: return bowl
        case .AR: return (bat + bowl) / 2
        }
    }
}

extension Career {
    func homePitch(_ clubId: Int) -> Pitch { info(clubId)?.homePitch ?? .indianFlat }

    /// Pitch fit of a player at a club's home ground.
    func homeFit(_ p: CareerPlayer, clubId: Int) -> Int { homePitch(clubId).fit(p) }

    /// Rating as a club sees it for squad building: overall plus the home-pitch share.
    func pitchRating(_ p: CareerPlayer, clubId: Int) -> Double {
        Double(p.rating) + Double(homeFit(p, clubId: clubId)) * PitchFit.squadWeight
    }

    /// Multiplier on what a club will pay for a player, from his fit to their home pitch.
    func pitchValueFactor(_ p: CareerPlayer, clubId: Int) -> Double {
        let f = 1 + Double(homeFit(p, clubId: clubId)) * PitchFit.valuePerPoint
        return min(PitchFit.valueRange.upperBound, max(PitchFit.valueRange.lowerBound, f))
    }

    /// The badge on market and squad rows: does he suit the user's home pitch?
    /// true = suits, false = struggles, nil = neither.
    func suitsUserPitch(_ p: CareerPlayer) -> Bool? {
        let fit = homeFit(p, clubId: userClubId)
        return fit >= PitchFit.suits ? true : (fit <= PitchFit.struggles ? false : nil)
    }

    /// Average home-pitch fit of a club's XI.
    func xiHomeFit(_ clubId: Int) -> Double {
        let xi = club(clubId)?.xi.compactMap { players[$0] } ?? []
        guard !xi.isEmpty else { return 0 }
        return Double(xi.map { homeFit($0, clubId: clubId) }.reduce(0, +)) / Double(xi.count)
    }

    /// The squad report's line on the home pitch: your XI's fit against the rival clubs' fit to theirs.
    func homePitchVerdict() -> (text: String, good: Bool)? {
        let rivals = clubs.map(\.id).filter { $0 != userClubId }
        guard !rivals.isEmpty, !userClub.xi.isEmpty else { return nil }
        let mine = xiHomeFit(userClubId)
        let theirs = rivals.map { xiHomeFit($0) }.reduce(0, +) / Double(rivals.count)
        let pitch = homePitch(userClubId).label
        let n = userClub.xi.compactMap { players[$0] }.filter { suitsUserPitch($0) == true }.count
        if mine >= theirs + 1.5 { return ("The XI is built for your home pitch (\(pitch)): \(n) of 11 suit it.", true) }
        if mine <= theirs - 1.5 {
            return ("The XI doesn't suit your home pitch (\(pitch)): only \(n) of 11 suit it. Rivals pick for their grounds.", false)
        }
        return nil
    }
}
