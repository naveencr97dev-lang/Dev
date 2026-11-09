# Auction XI (iOS)

A pass-and-play T20 franchise auction game for 3+ friends on one iPhone.
Bid for real cricketers with a ₹100 Cr purse, then watch your squad play a
simulated league with a result screen after every match, followed by
Qualifier 1, Eliminator, Qualifier 2 and the Final.

SwiftUI, iOS 16+, no third-party dependencies, works fully offline.
Franchise names are fictional; the app is not affiliated with any real league.

## Career mode

Run one franchise season after season. The design is in `docs/career/GDD.md` and the build order in
`docs/career/ROADMAP.md`.

- **Start:** name yourself, then pick one of 10 clubs from a fair draft (20-player squads). The
  Legends era option adds retired greats to the pool.
- **Season:** each pair meets 4 times, so 36 league matches each and 180 in total, from January to
  November. The league pauses in April and August for international windows (from M5). Home
  matches use your club's home pitch. IPL playoffs follow.
- **Hub tabs:**
  - Home: next match, Continue (sims other games to yours), news, form.
  - Squad: pick the XI from the squad, batting order, bowling plan, player profiles with full attributes.
  - Fixtures.
  - Table: standings, playoffs, cap races.
  - Club: history and roll of honour.
- **Between seasons:**
  - Players age a year and develop towards their potential, or decline.
  - Veterans retire.
  - A youth intake joins the pool.
  - Squads are topped back up to 18.
- **M2, contracts and market:**
  - Wages count against a ₹120 Cr salary cap.
  - A mega auction every 3rd season, with up to 6 retentions; a mini auction in the other years.
  - The auction is turn-based: Bid, or Pass to let the AI settle the lot. You can sim the rest, with
    or without your staff bidding for you.
  - Market tab: fee and wage offers with counter-offers, free agents, a transfer list, AI bids for
    your players, releases.
  - Windows: the off-season, rounds 1–2, and before round 25.
- **M3, development:**
  - Training: weekly drills, intensity and an individual focus per player.
  - Scouts: give them a nation, role or U21 brief to reveal potential.
  - Youth academy: a yearly intake of local kids, promoted on a minimum contract.
- **M4, club and manager:**
  - 7 facilities (levels 1–10).
  - Full season accounts.
  - Manager XP, levels and 24 perks in 3 trees.
  - Gold, and a store in test mode where every pack is free and the 1,000,000-gold Tester Pack is
    unlimited.
- **M5, international:**
  - 20 nations with world rankings.
  - The league pauses for international windows: 3-match series, or the T20 World Cup in April of
    even years.
  - National job offers by reputation, a 15-man squad, board targets and sacking.
- **M6, match day:**
  - Tactics per phase: field (attack, balanced, defend) and batting intent (block, rotate, attack).
  - A 2D ground view on the live match (toggle 2D/WHEEL).
- **Coming next:** ODIs and the ODI World Cup (M7), then the Beta balance and polish pass.

## How a game goes

1. **Setup**: 3–10 franchises (default is 4). Mark each one 👤 Human or 🤖 CPU. Pick the purse,
   the bid timer (5/8/12/30 s), the pitches (mixed venues or one type) and the season length.
2. **Auction**: each team buys **exactly 11** (max 4 overseas). The pool is one XI per
   team plus 12 extras (4 batters + 1 keeper, 2 all-rounders, 5 bowlers). With 4 teams
   that's 56 players. The auction **stops as soon as every XI is full**.
   - Order: Marquee → Batters & Keepers → All-rounders → Bowlers. Unsold players return in an accelerated round.
   - Tap your crest to bid. The timer resets on every bid.
   - **Skip** settles a lot instantly (CPU teams decide, no waiting). **Sold/Unsold** drops the hammer now.
   - Each bid tile shows what your XI still needs (WK, bowlers, batters).
   - Bid raise: IPL-style (+₹5 L under ₹1 Cr, +₹10 L to ₹2 Cr, +₹20 L to ₹5 Cr, +₹25 L above)
     or a fixed +₹25 L / ₹50 L / ₹1 Cr / ₹2 Cr per bid for a quicker auction. Set it in Setup
     or change it mid-auction from the ••• menu.
3. **Players**: 172 hand-picked players, today's stars plus retired IPL legends (★), all rated
   70+, from Sachin, Gayle, ABD, Malinga and Dhoni to Kohli, Bumrah, Rashid and Head.
   22 traits change match-ups ball by ball. Batting: Power Hitter, Anchor, Finisher,
   Spin/Pace Basher, Powerplay Blitz, Chase Master, 360°, Flat-Track Bully, Technician,
   Short-Ball King. Bowling: Death Specialist, New-Ball Swing, Mystery Spin, Miser,
   Wicket Taker, Express Pace, Slower-Ball Master, Bounce Merchant, Turner Terror,
   Middle-Overs Boss. Big-Match Player lifts in the playoffs.
   - **Conditions**: players get +5 at "home" (India on flat tracks and turners, England/NZ on
     seamers, Australia/SA on bouncers, West Indies on slow pitches, SL/AFG/BAN on turners), plus
     trait effects such as Turner Terror on dust and Bounce Merchant in Australia.
   - **Batting order**: every player has a best slot (opener, top order, middle, finisher, lower).
     In slot +6, close +2, out of position −8 to −26 plus more wickets and fewer boundaries.
     A tail-ender in the top six is "exposed" (a bowler opening averages under 1). New batters
     are vulnerable for 6 balls, set batters cash in, and 3 early wickets force a rebuild.
     "✨ Best order" optimises it; the ORDER % shows how close you are.
   - **Bowling plan**: choose the five bowlers. Slots 1–2 bowl the new ball and the death, 3–5 the
     middle. Swing and death specialists gain at the ends, spinners in the middle. Auto picks per pitch.
4. **Pitches**: 🛣️ Indian Flat (about 205 par) · 🌧️ English Seamer (about 140, swing) ·
   🦘 Aussie Bouncer (pace) · 🏜️ Dusty Turner (spin) · 🌴 Caribbean Slow (low and slow).
   Captains pick the five bowlers that suit the pitch.
5. **Season**: matches play ball by ball at a followable pace: 1× gives about 2 s
   for big moments (dots and singles go by fast, about 7 minutes a match), 2× and 4× for
   quicker games, plus pause. Before each ball,
   "🏃 Bumrah runs in to Kohli…", then the result. A **wagon wheel** shows the ground, with every
   scoring shot of the innings drawn from the bat (1–3 white, 4s blue to the rope, 6s purple
   beyond it, wickets ✕) and the latest shot racing out. A TV-style score strip shows both
   batters, the bowler's figures and the chase equation. There's a short pause and summary at
   the end of each over, and an **innings break** card with the target. You can also skip to
   the scorecard. Points table with NRR, plus Orange and Purple Cap leaderboards. Batting order
   can be changed between matches.
   After every match: **scorecard**, then **runs per over** (bar chart for both teams, red dots
   for wickets), then **highlights**: up to 12 key
   moments (wickets, sixes, fifties/hundreds, big overs, the winning runs) with a ▶︎ Watch
   button for the story-style reel.
6. **Playoffs → Final → Trophy ceremony** with awards. Afterwards, **Back to season**
   lets you browse every match, the table and stats.

Portrait and landscape both work. Landscape uses a two-column layout that suits
screen casting. The game saves automatically.

## Code layout

- `project.yml`: [XcodeGen](https://github.com/yonaskolb/XcodeGen) spec (the
  `.xcodeproj` is generated, not committed).
- `Sources/Engine/`: game rules, Foundation only: auction, CPU bidding,
  ball-by-ball match engine, season/NRR/playoffs, save state.
- `Sources/Store/GameStore.swift`: auction clock, CPU pacing, save file.
- `Sources/Views/`: SwiftUI screens.
- `Resources/players.json`: 172 curated players, generated by
  `../tools/players_curated.py`.
- `Package.swift` + `Tests/`: lets the engine be tested without Xcode.

### Engine tests

```bash
cd ios && swift test
```

Tests cover the auction rules, valid squads for 3/8/10 teams, a 1,000-match
calibration run per pitch, trait match-up checks
and a full game from setup to champion.

## Getting an installable IPA (no Mac needed)

### Codemagic → Signulous (same as Streaklet)

1. Open **https://codemagic.io**. The `naveencr97dev-lang/Dev` app is already
   connected from Streaklet.
2. **Start new build** → branch **`claude/beautiful-keller-qgp1vc`** →
   workflow **"Auction XI unsigned IPA"** (from `codemagic.yaml` at the repo root).
3. Download **`AuctionXI-unsigned.ipa`** from the build artifacts.
4. Upload it to **Signulous**, sign and install.

> Bundle id: `com.auctionxi.app` (set in `project.yml`). Change it there if
> Signulous needs a different id, then rebuild.

### On a Mac

```bash
brew install xcodegen
cd ios && xcodegen generate && open AuctionXI.xcodeproj
```

## Credits

Player list, ratings and traits: `../tools/players_curated.py`.
See `../THIRD_PARTY_NOTICES.md`.
