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

## Definition of done (every feature)

- [ ] The engine logic has unit tests, and `swift test` passes.
- [ ] `swiftc -parse` is clean on all views.
- [ ] Portrait fits, and landscape fits the 830 × 420 pt safe area with no scrolling.
- [ ] Old saves still load.
- [ ] The GDD is updated if behaviour changed.
- [ ] The change is committed and pushed, and the user is told to rebuild in Codemagic.

## Milestones

### M0: Pre-production (1 sprint)
- **Must:**
  - This GDD and roadmap.
  - The `Career` save schema and `career_tuning.json` skeleton.
  - A save-migration harness.
- **Spikes:**
  - Quick-sim speed: 180 matches in under 2 s.
  - A 2D ground prototype.
  - The `MockStore` flow.
- **Gate:** spike numbers recorded here, and the schema reviewed.

### M1: Vertical slice, the core loop (2 sprints)
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

### M2: Squad and market (2 sprints)
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

### M3: Scouting, training, youth (2 sprints)
- **Must:**
  - Scout staff, assignments and fog-of-war ranges.
  - Attribute search and a shortlist.
  - The weekly drill schedule, individual focus and intensity.
  - The full development model.
  - The youth academy intake.
- **Gate:** development curves hit their targets in the simulation.

### M4: Club and manager (2 sprints)
- **Must:**
  - The 7 facilities with builds and maintenance.
  - Full finances and owner budget.
  - Manager XP, levels and the 3 trait trees (24 perks).
  - Gold faucets and sinks.
  - The store with the **Tester Pack: 1,000,000 Gold, free and unlimited**.
- **Gate:** the economy simulation shows no insolvency spiral and no runaway cash, both
  without gold.

### M5: International (2 sprints)
- **Must:**
  - 20 nations and their player pools.
  - Rankings.
  - The international windows on the calendar.
  - The national job (offers, squad selection, board targets).
  - Bilaterals and the T20 World Cup.
- **Gate:** a 20-season simulation produces sensible rankings and World Cup winners.

### M6: Match day+ and 2D view (2 sprints)
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
| Average first-innings score by pitch | Within ±8 of the par in the README |
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
