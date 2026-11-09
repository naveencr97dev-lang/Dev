# Career Mode: Roadmap

How this is built: the standard game-production pipeline used by most studios, scaled down to
one owner and one AI developer.

## Method

1. **GDD as the single source of truth** ([GDD.md](GDD.md)). Every feature points to a GDD section.
2. **Core loop first, then breadth.** Prove "play a season, then the next season" before adding
   any system around it.
3. **Milestone gates:** Pre-production → Vertical Slice → Alpha (feature-complete) → Beta
   (content-complete and balanced) → 1.0. Don't start a new milestone until the previous gate passes.
4. **A playable build every sprint.** Each sprint ends with a Codemagic IPA that you install
   with Signulous and play.
5. **Engine-first and test-driven.** Rules are pure Swift with `swift test` on Linux. The UI is a
   thin layer on top.
6. **Headless balance simulation.** A test harness simulates 20-season careers with AI managers
   and checks the balance targets below. Balance changes go in `career_tuning.json`, not code.
7. **Economy modelling.** Every source and drain of gold and cash is listed (§12 of the GDD) and
   checked by simulation, so there is no runaway money and no dead end.
8. **Scope control (MoSCoW).** Each milestone has Must, Should and Could items. Coulds slip first.
9. **Save versioning from day one.** Every schema change ships with a migration and a test that
   loads an old save.

## Layers (80/20)

Build in layers. The first 20% of effort makes the app run and every main system work; tuning
comes later, driven by playtests.

| Layer | Goal | Status |
|---|---|---|
| **1. Core systems** | One working, generic version of each system (M0–M6) | ✅ done |
| **2. Runs end to end** | Whole app type-checks; a player-journey test proves no dead ends across seasons; a Codemagic build installs and plays | ✅ type-check and journey test done · ⏳ device build by the user |
| **3. Fix from playtests** | Crashes, broken flows, confusing screens from the user's feedback | next |
| **4. Fine-tune** | Balance (scores, economy, AI spending), polish, landscape audit, onboarding | later |
| **5. Extras** | M7 ODIs, in-match changes, dew/DLS, loans, AI trades | later |

Rules for layers 3–5: fix what the user reports first, keep every change behind the existing
tests, and don't start a later layer while an earlier one has open breakages.

## Definition of done (every feature)

- [ ] The engine logic has unit tests, and `swift test` passes.
- [ ] `tools/typecheck/run.sh` passes. It type-checks **the whole app** on Linux against
      SwiftUI, UIKit and Charts stubs.
- [ ] `CareerTests.testPlayerJourneyHasNoDeadEnds` passes (3 seasons driven by the Home screen's actions).
- [ ] Portrait fits, and landscape fits the 830 × 420 pt safe area with no scrolling.
- [ ] Old saves still load.
- [ ] The GDD is updated if behaviour changed.
- [ ] The change is committed and pushed, and the user is told to rebuild in Codemagic.

## Milestones

### M0: Pre-production (1 sprint) ✅ done
- **Spike results (recorded 2026-11-09):**
  - Quick-sim: a full 184-match season takes **0.25 s** in a release build on Linux (budget 2 s). The
    debug test build takes about 2 s.
  - Save size: **1.3 MB** at the end of a season (all results kept), about 0.35 MB after rollover. Budget 5 MB.
  - Determinism: same seed and same choices give the same career (`testDeterministic`). Dictionary
    iteration is randomised in Swift, so every rng-consuming loop iterates sorted ids.
  - Store: `MockStore` deferred to M4 with the rest of the economy.
  - 2D ground prototype: deferred to M6 (the wagon wheel already proves the drawing approach).
- **Built:** `Career` save root with `schemaVersion` and JSON migrations (`CareerSave`),
  `career_tuning.json` generated from `CareerTuning` defaults (and checked by a test), and
  `career_meta.json` birth years.

### M0 plan (original)
- **Must:**
  - This GDD and roadmap.
  - The `Career` save schema and `career_tuning.json` skeleton.
  - A save-migration harness.
- **Spikes:**
  - Quick-sim speed: 180 matches in under 2 s.
  - A 2D ground prototype.
  - The `MockStore` flow.
- **Gate:** spike numbers recorded here, and the schema reviewed.

### M1: Vertical slice, the core loop (2 sprints) ✅ built, waiting for an on-device playtest
- **Built:** Career / Quick Auction choice on the home screen. Create a manager and draft the league
  (a balanced snake draft, not an auction, so you pick a club like in football manager games).
  36-match calendar with home pitches, quick-sim of AI matches, the live view for your own matches,
  table, playoffs, awards and history. Rollover: ageing, development, retirements, youth intake,
  squad top-ups. Save and load.
- **Balance (20-season harness):** 9 different champions, nobody above 40% of titles. Average first
  innings: flat 187, bouncy 149, slow 141, turner 135, seam 126 (quick-game pars: 200 / 171 / 149 /
  152 / 147). Seam and bounce homes are still about 20 runs low; tune in Beta.
- **Gate still open:** play 2 seasons on the phone.

### M1 plan (original)
- **Must:**
  - A Career / Quick Auction mode picker.
  - Create a manager and pick 1 of 10 franchises.
  - Starting squads built by an initial auction (reusing `AuctionEngine`).
  - The 36-match calendar and quick-sim for AI matches.
  - The user plays their own matches with the existing live view.
  - Table, playoffs and awards.
  - Season rollover: ageing, a simple development tick, retirements, the next year's fixtures.
  - Save and load.
- **Gate:** play 2 full seasons end to end on the phone. The balance test passes with
  par scores in range.

### M2: Squad and market (2 sprints) ✅ built (generic first pass, waiting for feedback)
- **Built:**
  - Contracts: the wage is the auction price, and contracts run to the next mega auction.
  - A ₹120 Cr salary cap, and banks with a ledger. Season revenue and prize money are paid after the final.
  - The off-season flow: retentions (mega years), then the auction, then the transfer window.
  - The auction is turn-based and fits the phone: you bid, the AI answers at once, Pass lets the AI
    settle the lot. "Sim rest" can let your staff bid for you.
  - The Market tab: search, offers with a fee and wage, counter-offers, 3 talks per player per window,
    free agents, transfer list with AI bids, unsolicited bids, release with 50% compensation.
  - AI clubs strengthen from free agents each window.
  - Save schema 2, with a tested v1 migration.
- **Windows:** the off-season (after the auction), rounds 1–2, and before round 25.
- **20-season harness:** 8 different champions, payrolls under the cap, the user club stays
  competitive when staff auto-bid.
- **Known gaps:**
  - Banks only grow, because wages aren't charged to the bank yet (M4 finances).
  - Long-run attacks out-rate batting, and flat scores drift from about 180 to about 160 after
    10+ seasons (Beta tuning).
  - No AI-to-AI trades, and no loans.

### M2 plan (original)
- **Must:**
  - Contracts and wages, and the squad rules (18–25 players, 8 overseas).
  - Retentions.
  - Mega and mini auction cadence, plus the RTM card.
  - Transfer market: buy, sell, AI bids, counter-offers, free agents.
  - Transfer windows.
  - A basic finance ledger.
- **Should:** player morale.
- **Could:** loans.
- **Gate:** the AI keeps all 10 squads legal and competitive over a 20-season simulation.

### M3: Scouting, training, youth (2 sprints) ✅ built (generic first pass)
- **Built:**
  - **Training:** a weekly plan of 3 drill slots from 10 drills, intensity (light, normal, hard
    trading growth against form), and an individual focus per player. It ticks after each of your
    matches, and AI clubs train too. Growth depends on age and is capped at potential.
  - **Scouting:** you start with a 2★ chief scout and can hire up to 2 scouts (1–5★) from candidates
    refreshed each off-season. Wages come from the bank. Assign each scout a nation, a role and an
    optional U21-only brief. Knowledge narrows potential ranges (unscouted players show a ±10
    range), and reports appear in the Scouting screen.
  - **Academy:** 2–4 local kids each off-season (max 8). They train 1.3× faster, sit outside the
    squad and cap, and can be promoted on a minimum contract or released.
  - Save schema 3, with a tested v2 migration.
- **20-season harness:** 8 different champions, at most 25% of titles. Flat average 187. The AI's
  personality now nudges auction bids by only ±10%; it used to let one club buy the stars every time.
- **Cap rule:** minimum-wage signings needed to reach 18 players may go up to ₹0.8 Cr over the cap.

### M3 plan (original)
- **Must:**
  - Scout staff, assignments and fog-of-war ranges.
  - Attribute search and a shortlist.
  - The weekly drill schedule, individual focus and intensity.
  - The full development model.
  - The youth academy intake.
- **Gate:** development curves hit their targets in the simulation.

### M4: Club and manager (2 sprints) ✅ built (generic first pass)
- **Built:**
  - **7 facilities**, levels 1–10, starting at 2. One build at a time, measured in your matches
    (4 weeks pass each off-season). Cost is 40 L × level², upkeep 5 L × level² per facility.
  - **Facility effects:** Stadium = gate money. Training Ground = speed plus slots at levels 3/6/9.
    Academy = more gems. Medical = longer careers and less form lost. Scouting Network = scouts at
    levels 4/7/10 and more knowledge per report. Analytics = rating lift in matches.
    Commercial = sponsor money.
  - **Full season accounts:** wages are charged, plus upkeep, gate, sponsors, central revenue
    (₹95 Cr) and prize money. A debt warning appears if the bank goes negative.
  - **Manager:** XP (wins, playoffs, titles, profit, builds), levels to 100, 1 point plus gold per
    level. 24 perks in 3 trees with tier gates, all wired into the engine.
  - **Gold:** earned from matches, levels and titles. Spent on finishing builds, a training boost,
    an instant scout report, or fresh legs.
  - **Store:** test mode, with every pack free and the **Tester Pack (1,000,000 gold) unlimited**,
    behind `StoreConfig.testerStore`.
  - Save schema 4, with a tested v3 migration.
- **Known gaps:**
  - AI clubs don't spend their banks: low-payroll clubs pile up cash (up to about ₹700 Cr over 20
    seasons).
  - AI facilities are fixed at level 2.

### M4 plan (original)
- **Must:**
  - The 7 facilities with builds and maintenance.
  - Full finances and owner budget.
  - Manager XP, levels and the 3 trait trees (24 perks).
  - Gold faucets and sinks.
  - The store with the **Tester Pack: 1,000,000 Gold, free and unlimited**.
- **Gate:** the economy simulation shows no insolvency spiral and no runaway cash, both
  without gold.

### M5: International (2 sprints) ✅ built (generic first pass)
- **Built:**
  - **20 nations** (12 full members, 8 associates) with Elo ranking points. Nations without enough
    real players get generated pools (at least 16 each).
  - **Windows** pause the league before rounds 13 and 25. The April window of even years is the
    **T20 World Cup**: 4 groups of 5 drawn by ranking (snake), a Super 8, semi-finals and a final,
    at a random full-member host. Every other window is a round of 3-match bilateral series
    between neighbouring nations in the rankings.
  - **National job:** offers each off-season by reputation (manager level, titles, World Cups).
    Small nations are open from day one. You pick a 15-man squad (the XI is auto-picked).
  - **Board:** a target per event (rank-based). Two misses in a row and you're sacked (on by default).
  - **Screens:** a World tab (job and offers, squad picker, current event with group tables and
    results, rankings, history) and an international window card on Home. Live internationals use
    the normal match screen.
  - Save schema 5, with a tested v4 migration.
- **Harness:** 20 seasons simulate at 0.65 s per season (release build), with 7 different champions.
- **Known gaps:** no ODIs (M7). Caps are counted, but international stats aren't shown yet.

### M5 plan (original)
- **Must:**
  - 20 nations and their player pools.
  - Rankings.
  - The international windows on the calendar.
  - The national job (offers, squad selection, board targets).
  - Bilaterals and the T20 World Cup.
- **Gate:** a 20-season simulation produces sensible rankings and World Cup winners.

### M6: Match day+ and 2D view (2 sprints) ✅ built (generic first pass)
- **Built:**
  - **Tactics** per phase (powerplay, middle, death). Field: attack, balanced or defend, trading
    wickets for boundaries. Batting intent: block, rotate or attack (attack = +25% sixes, +12% fours,
    +12% wickets).
  - Tactics are applied to your club and your national side. Neutral or absent tactics give
    exactly the old engine, so Quick Auction is unchanged (tested).
  - **2D ground view:** a top-down field with the setting's placements, bowler, keeper and batter,
    the ball's path, and the nearest fielder chasing it. A 2D/WHEEL toggle on the live match is
    remembered.
  - Save schema 6, with a tested v5 migration.
- **Not yet:** in-match changes (the engine simulates a whole match before replaying it, so
  mid-match changes need a resumable engine), dew, and rain/DLS. The 2D view always shows a
  balanced field for now.

### M6 plan (original)
- **Must:**
  - Field settings, batting intent and in-match changes.
  - The 2D top-down ground view in portrait and landscape.
- **Should:** dew.
- **Could:** rain and DLS.
- **Gate:** reaches **Alpha**, meaning every system in the GDD is in.

### M7: Formats (1–2 sprints)
- **Must:**
  - The engine generalised to N-over innings.
  - ODIs and the ODI World Cup every 4 years.
- **Could:** a Champions-style trophy.

### Beta (2 sprints)
- **Balance:**
  - 20-season simulations with tuning passes.
  - Dynasty check: no franchise wins more than 40% of titles.
  - The money curve.
- **Polish:** landscape audit on every screen, performance, save stress tests, onboarding and tooltips.
- **Content:** name pools, generated player quality, achievements.
- **Gate:** reaches **1.0** for the sideload build.

## Balance targets (checked by `CareerBalanceTests`)

| Metric | Target |
|---|---|
| Average first-innings score by pitch | Within ±8 of the quick-game par (measured: 200 / 147 / 171 / 152 / 149 for flat / seam / bounce / turner / slow) |
| Champions over 20 seasons | At least 6 different franchises, none with more than 40% of titles |
| Potential-80 player at 18 | Overall rating 74–82 by age 24 with normal training |
| Player who has peaked, aged 33 | Loses 2–5 overall per year |
| Club cash after 10 seasons (AI average) | Between 0.5× and 3× the starting budget |
| Youth intake (Academy level 5) | About 1 in 6 has potential 80+ |
| Season quick-sim | Under 2 s on device, under 5 s in `swift test` on Linux |

## Risks

| Risk | Mitigation |
|---|---|
| Scope is huge | Milestone gates, MoSCoW, vertical slice first |
| No Mac, so UI bugs only show on the phone | Engine-first tests, `swiftc -parse`, a playable build each sprint, landscape checklist |
| Save corruption across versions | `schemaVersion`, migrations and old-save fixtures in tests |
| Sim performance with about 1,700 players | Quick-sim path, a perf test in CI |
| Licensing of real names | Fine for a sideload. Switch to fictional names before any App Store release. |
| Real IAP isn't possible when sideloaded | `MockStore` now, StoreKit 2 behind the `StoreService` protocol later |
