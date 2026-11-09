# Auction XI: Game hierarchy and layers

Read this before changing anything. The game is organised as a **tree of features**, built on
**layers of code**. Main things live in the top and bottom layers and change rarely. Day-to-day
fixes go into the sub-layers, so they can't break the main game.

---

## 1. The game as a tree (features)

Read top-down: each level is a part of the one above. The path (for example
`Career › Market › Auction`) is how backlog items and commits refer to a feature.

```
Auction XI
├── Shared core ................................. Engine/ (MatchEngine, Models, RNG)
│   ├── Match engine: ball-by-ball T20, traits, pitches, batting slots, bowling plans,
│   │   tactics, super overs ................... MatchEngine.swift
│   ├── Players and conditions ................. Models.swift, players.json
│   └── Determinism (seeded RNG) ............... RNG.swift
│
├── Quick Auction mode (pass-and-play) .......... Game.swift, AuctionEngine, SeasonEngine, TeamSelector
│   └── Setup › Auction › Squads › Season › Playoffs › Champion
│
└── Career mode ................................. Engine/Career/
    ├── Flow: the CONTINUE button .............. CareerFlow.swift (nextAction)
    ├── Season ................................. Career.swift
    │   ├── League (36 matches each, 10 clubs), home pitches, IPL playoffs
    │   ├── Calendar and international windows
    │   ├── Awards, history, news, form
    │   └── Stats: season, all-time, season log, leaders . CareerStatsBook.swift
    ├── Squad .................................. Career.swift (XI, order, plan), MatchEngine (Tactics)
    │   └── Pick XI › Batting order › Bowling plan › Tactics
    ├── Market ................................. CareerMarket.swift
    │   ├── Contracts and salary cap, bank and ledger
    │   ├── Off-season: retentions › auction (mega every 3rd season) › window
    │   └── Transfers: offers, counters, free agents, release, AI bids, AI windows
    ├── Development ............................ CareerDevelopment.swift, Career.develop()
    │   ├── Ageing, growth to potential, retirement, youth pool
    │   ├── Training: drills, intensity, focus
    │   ├── Scouting: scouts, knowledge, potential ranges
    │   └── Academy: intake, promote, release
    ├── Club and manager ....................... CareerClub.swift
    │   ├── Facilities (7) and season accounts
    │   ├── Manager XP, levels, 24 perks
    │   └── Gold and the store (tester pack)
    ├── International .......................... CareerInternational.swift
    │   ├── Nations, pools, rankings
    │   ├── Windows: series, T20 World Cup
    │   └── National job, squad, board
    └── People ................................. CareerPlayer.swift, PlayerGen.swift
        └── Attributes, potential, value, contracts, generated players
```

**Screens mirror the tree.** Quick-game screens are in `Views/`. Career screens are in
`Views/Career/`, one file per branch:

| Branch | Screen file |
|---|---|
| Hub and Flow | CareerHubView |
| Squad | CareerSquadViews and CareerTacticsView |
| Market | CareerMarketViews |
| Development | CareerDevelopmentViews |
| Club | CareerClubViews |
| International | CareerWorldViews |
| Stats (profile, market, leaderboards) | CareerStatsViews |
| Look | CareerTheme |

---

## 2. The layers (code)

```
 L4  Presentation      Views/, Theme/, text size            change freely
        │ calls
 L3  App glue          Store/ (GameStore, GameStore+Career) thin, no rules
        │ calls
 L1  Game systems      Engine/Career/*, Game.swift, AuctionEngine, SeasonEngine
        │ uses                      ▲ reads
 L0  Foundation        MatchEngine, Models, RNG,     L2  Content & balance
                       save format + migrations           career_tuning.json, players.json,
                                                          career_meta.json, name pools,
                                                          perk/facility/drill numbers
```

| Layer | What it holds | How stable | Rules |
|---|---|---|---|
| **L0 Foundation** | Match engine, player model, RNG, save format | Most stable. Main game. | Change only with tests. Never change it to fix a screen. Neutral options must leave the quick game unchanged (tested). Any save-format change needs a schema bump **and** a migration. |
| **L1 Game systems** | One file per career branch, plus the quick-game engines | Stable | A system talks to other systems only through `Career`'s functions. One branch per file. Every system has tests and is covered by the journey test. |
| **L2 Content and balance** | Numbers and data | Tweak freely | Fix balance here first. Defaults live in `CareerTuning`. Regenerate `career_tuning.json` (`WRITE_TUNING=1`) and run the 20-season harness. |
| **L3 App glue** | `GameStore` routing, saving, mode switch | Stable, small | No game rules. Each action is a one-line call into L1, followed by a save. |
| **L4 Presentation** | Screens, theme, components, text size | Change freely | No game rules in views. Read `store.career` and call `store.career…` actions only. The whole app must type-check. |

**Dependencies point down only:**
- Views call the store. The store calls the engine. The engine never imports SwiftUI or UIKit.
- Content is read by the systems.
- `ArchitectureTests` enforces the critical rules.

---

## 3. How to make a change without breaking the main game

1. **Place it in the tree:** which node is it (for example `Career › Market › Auction`)?
2. **Fix it in the lowest-risk layer that can solve it**, in this order:
   1. **L2 content.** A number is off: change it in `CareerTuning` or the data file.
   2. **L4 presentation.** It looks or reads wrong: change the screen in that branch's file.
   3. **L1 system.** A rule is wrong: change only that branch's engine file, and add or extend its test.
   4. **L0 foundation.** Last resort. You need tests, the quick game must stay unchanged, and a save
      change needs a schema bump and migration.
3. **Run the guardrails for that layer:**

| Layer touched | Must pass |
|---|---|
| L2 | `swift test` (includes the tuning-file check), plus the 20-season harness for balance changes |
| L4 | `tools/typecheck/run.sh` (whole app) |
| L3 / L1 | `swift test`, including `testPlayerJourneyHasNoDeadEnds` |
| L0 | All of the above, plus the save migration tests |

4. **Record it:** the commit message names the tree path, and the backlog below gets updated.

New features are **new leaves**: a new file in the right branch, behind a flag or a new action,
wired in by one call. Existing leaves aren't rewritten.

---

## 4. Backlog by layer

Open items from playtests and the roadmap's known gaps. Fix the top layers' breakages first.

### L4 Presentation
- `Career › Match day › 2D ground`: always shows a balanced field. Pass the bowling side's tactic in.
- `Career › Hub`: the desk and the tiles duplicate some info; trim it after playtests.
- Landscape audit of every career screen (casting).

### L2 Balance
- `Shared core › Match engine`: seam and bounce home grounds score about 20 below the quick-game par.
  Flat-pitch scores drift down after 10+ seasons.
- `Career › Season`: KOL won 7 of 20 titles in the harness. Check auction personality and home pitch.
- `Career › Club`: AI banks pile up cash. Needs an AI spending rule (an L1 change, small).

### L1 Systems
- `Career › Market`: AI-to-AI trades, loans.
- `Career › Match day`: in-match changes (needs a resumable engine: an L0 change, plan first).
- `Career › International`: international stats screen.

### L5 Extras (new leaves)
- `Career › International › ODIs` (M7): N-over engine option, then the ODI World Cup.
- Dew, rain and DLS. The real StoreKit store (`StoreConfig.testerStore` off).
