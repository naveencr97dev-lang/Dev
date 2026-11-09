# Customer panel: rounds 2 and 3 (2026-11-09)

## The panel now plays like people do

`ios/Tests/EngineTests/CustomerPanelTests.swift` was rebuilt so each persona does what a person does
in the app, and writes its own complaints from what happened.

- **Habits:**
  - Auto-pick XI.
  - Following the staff advice at the auction.
  - Reading the news (assistant notes, retirement watch).
  - Acting on the assistant's advice when it speaks up.
  - Playing Right to Match cards.
  - Re-picking the XI after a signing.
- **Coverage:** each persona manages two clubs, KOL (an old, strong squad) and LKO (a mid-table squad),
  with the same seed. That's 12 careers of 4 seasons, about 1,750 user matches per run.
- **Rules:** complaints come from fixed rules (thresholds in `feedback(_:_:_:)`), and the panel
  counts how many players raised each one.

```
CUSTOMER_PANEL=1 swift test -c release -Xswiftc -enable-testing --filter CustomerPanelTests
# PANEL_DEBUG=1 also dumps the state when a losing run hits 10
```

## Round 2: what players said and what changed

| Complaint (players out of 12) | Cause found | Fix |
|---|---|---|
| "I lost 6-9 in a row and the game never told me why" (9) | Nothing explained defeats | **Assistant manager** (`CareerAssistant.swift`): after 3, 6 and 9 straight defeats it names the cause (batting vs par, bowling, form, a broken batting order, a tough run of opponents) and gives up to two concrete fixes. Shown in the news and as a Home card during the run. |
| "The board wanted U23 appearances when I had at most one U23" (6) | The youth objective ignored the squad | Youth target = 12 per U23 player (max 30). With fewer than 2 U23s, the board asks for **away wins** instead. |
| "₹200-300 Cr in the bank and nothing pushed me to spend it" (4) | No goal for money | **Invest objective** (start 2 facility upgrades) when the bank is at least ₹100 Cr at season start |
| "295 of 302 bids failed (overseas 210, bank 85)" (2) | Scout advice recommended overseas players with no overseas slot left, and fees beyond the bank | Scout advice checks squad size, overseas slots, bank and salary cap |
| "My stars retired; I only noticed in the news" (2) | No warning | **Retirement watch**: at season start, names the players likely to retire (chance ≥ 30%) |
| "The mega auction broke up my team" | Released players were gone for good | **Right to Match cards** (IPL rule): retentions + RTM = 6. Match the price the top AI club would pay for a player you released. The staff use them too when they're in charge. Your staff's auction bids favour players who walk into your XI. |

The panel also had its own bug: it measured the XI before the auction after retentions, when the XI
holds only 4 or so keepers. It now compares against last season's XI, relative to the AI clubs over
the same off-season.

## Round 3: deeper bugs the panel found

| Finding | Evidence | Fix |
|---|---|---|
| **Losing runs of 12-21 for players who never touch the squad** | `PANEL_DEBUG`: bowlers batting at 5-7 and specialist batters at 8-11, then collapses (65 all out, 115 all out) | `patchXI` (it fills the XI after retirements and transfers) appended the replacement by rating at the end of the order. Now it fills the missing role (keeper, then bowling options) and puts newcomers where they bat best, as Pick XI does. The assistant flags any batter out of position. |
| **CONTINUE-only players fielded a clearly weaker XI in 65 of 146 matches** | stale-XI metric | **"Assistant picks my XI"** setting (Career › Settings): on for new careers, off for existing saves. Picking the XI, the order or the bowling plan by hand turns it off. |
| "Rest X" advice made runs worse | Followers benched cold stars for much weaker reserves | Rest is only suggested when a same-role reserve is at least as good as the cold player is playing now; the panel acts once per assistant note |
| One-sided games (7 of 12) | Defending teams won by a median of 44 runs; easy chases lost almost no wickets | **Career-only `realisticChase`** in the engine: easy chases still lose wickets (only boundaries dry up), and hard chases collapse less. Median winning margin 44 → 29 runs; blowouts 46% → 40% of league games. The quick game is unchanged. |

## Before → after (12 careers × 4 seasons)

| Measure | Round 1 | Round 3 |
|---|---|---|
| Longest losing run, CONTINUE-only player | 12 / 21 | 6 / 8 |
| Stale-XI matches, CONTINUE-only player | 65 | 2 |
| Thrillers (last over, ≤8 runs, super over) | 11-15% | 17-27% |
| "Never told me why" complaints | 9 | 0 |
| Impossible objectives | 6 | 1 (a trader who sold his own youngsters) |
| Market bids failing on slots or money | 97% | under 20% (only "talks over") |

## Still open

- **KOL starts with an old squad.** Its first off-season costs 4-7 XI points more than the AI clubs
  lose (retirements). Next: an age-balanced opening draft.
- Blowouts are still about 40% by the panel's loose definition. Next lever: chase pacing for easy
  targets (winning chases end with a median of 15 balls left).
- Losing runs of 10-11 remain for 40-45% teams. That's statistically plausible over 144 matches, but
  watch the form spiral.
- Money: casual players ignore the invest objective. Consider an "owner invests" option.

## Round 4: roles and morale (from the SM26 recon)

- **First cut was too harsh.** Casual players, who never touch the squad, got 6–14 transfer requests
  in 4 seasons. Default roles came from rating rank (a second keeper ranked "First Team" but never
  plays), and rotation expected football-style playing time.
- **Fixes:**
  - Default roles come from the best XI.
  - Rotation expects 20% and backup 0%.
  - Unpromised roles are re-derived each season.
  - Unpromised players lose morale more slowly.
  - **Only broken promises end in transfer requests.**
- **Result:**
  - Casual transfer requests 6–14 → 0.
  - Average end morale 82–92.
  - The "unfair morale" complaint went from 4 to 0.
  - The trader who promises every signing a key role still gets requests ("promises backfired"):
    intended, and the bid screen now warns when you over-promise.
- Also found: the negotiation bar showed "close" at exactly the asking wage (floating-point rounding).
  Fixed. Objectives were met 85%+ on Normal by 5 players, so home-win targets went up a notch
  ("too easy" 5 → 2).
