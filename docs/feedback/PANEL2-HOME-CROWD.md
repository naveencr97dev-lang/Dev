# Customer panel 2, "the home crowd": rounds 1 to 3 (2026-11-11)

A second panel, built to judge home-pitch squad building. It lives beside panel 1 in
`ios/Tests/EngineTests/CustomerPanelTests.swift` and reuses its play loop and complaint rules.

```
CUSTOMER_PANEL=2 swift test -c release -Xswiftc -enable-testing --filter CustomerPanelTests/testHomeCrowdPanel
CUSTOMER_PANEL=table CUSTOMER_SEASONS=4 swift test -c release -Xswiftc -enable-testing --filter CustomerPanelTests/testPitchTable
```

- **Personas:** groundsman (buys, bids and picks for his pitch), purist (ratings only, never looks at
  the pitch), homeFan (CONTINUE only, judges the home record), setAndForget (picks an XI once a
  season), collector (buys the best-rated player he can afford), developer (trains weekly, plays U23s).
- **Coverage:** each manages a turner (CHE), a seamer (DEL) and a road (MUM): 18 careers of 4 seasons,
  about 2,600 user matches a run, seed 900 (`CUSTOMER_SEED`, `CUSTOMER_CLUBS`, `CUSTOMER_SEASONS`).
- **New measures:** home and away record, the XI's fit to the home pitch against the visitors', suited
  signings and auction lots, and a same-club comparison of the personas.
- **`testPitchTable`:** league-wide win % by the club's home pitch (6 seeds, `CUSTOMER_SEEDS`).

## Round 1: what players said and what changed

| Complaint | Cause found | Fix |
|---|---|---|
| "We win 22% away" (every manager at the seam ground); pace-ground clubs won 43% overall, turner clubs 56% | AI clubs built for the home pitch alone. Pace-ground squads had about 1.5 spinners, so they could not pick for turning grounds | Clubs now value a player over the **whole season** (`seasonFit`: home pitch half, the other nine grounds half) in the draft, retentions, signings and transfers. Every squad drafts **five spinners and five quicks**, and a club short of one kind pays 20% more for him |
| "Building for my pitch didn't beat ignoring it" (groundsman 47% at home, purist 75%, at the seam ground) | Suited players went for up to 1.4× value at auction, so the groundsman's budget went on a few of them | Bid factor per fit point reduced and capped at 0.8 to 1.25 (was 0.75 to 1.4) |
| "110 of 131 bids failed (overseas)" (collector) | Panel bug: the persona kept bidding with no overseas slot | Persona fixed (the app already refuses these bids with a message) |
| "A better XI sat on my bench" (developer) | By design: he benches seniors for U23s | Complaint no longer raised for this persona |

## Round 2: a deeper bug the panel found

With stronger bowlers in every squad, a test caught a tail-ender batting in the top six. Cause:
**Auto-pick filled the spare places by main skill**, so a sixth and seventh bowler were picked while
batters rated 72 to 77 sat on the bench. This was in the selector before the home-pitch work.

- `TeamSelector.autoXI`: after the keeper and five bowlers, the remaining places are filled by batting.
- `patchXI` (XI repair after a sale): the same rule.

## Round 3: where it stands (final code)

Same club, different managers (win %: home / away / all):

| Club (pitch) | groundsman | purist | homeFan | setAndForget | collector | developer |
|---|---|---|---|---|---|---|
| CHE (turner) | 69 / 48 / 59 | 61 / 62 / 61 | 47 / 44 / 45 | 38 / 45 / 42 | 45 / 47 / 47 | 47 / 52 / 51 |
| DEL (seamer) | 66 / 52 / 60 | 59 / 54 / 59 | 68 / 33 / 50 | 62 / 38 / 51 | 69 / 59 / 64 | 51 / 26 / 38 |
| MUM (road) | 55 / 51 / 53 | 52 / 50 / 50 | 59 / 36 / 47 | 48 / 31 / 40 | 68 / 61 / 65 | 48 / 31 / 39 |

- The groundsman now has the best home record of the two traders at all three clubs. Overall he and
  the purist are level at the turner (59 against 61).
- "One-sided games" fell from 5 or 6 players to 2.

League-wide (6 seeds × 4 seasons), win % by the club's home pitch:

| Pitch | Round 1 (home / away / all) | Round 3 |
|---|---|---|
| Flat | 52 / 46 / 49 | 50 / 45 / 48 |
| Seam | 52 / 33 / 43 | 55 / 43 / 49 |
| Bounce | 50 / 35 / 43 | 49 / 41 / 45 |
| Turner | 65 / 48 / 56 | 62 / 54 / 58 |
| Slow | 57 / 50 / 53 | 54 / 44 / 49 |

Home sides win about 53% (`CareerTests.testHomeSidesWinMoreThanHalf`: 480 of 900).

## Still open

- **Turner clubs still win 58%.** Spinners are worth more than quicks across the ten grounds
  (pitch bonuses sum to +34 for spin, -4 for pace), and turner clubs get the best ones. Fixing it
  properly is a layer-0 change to the pitch bonuses, which also moves the quick game.
- **Bounce grounds give no home edge (49%).** Every visitor has plenty of quicks.
- **"Off-seasons left my XI weaker" (9 of 18)** and **"outbid for pitch players" (3 of 3 groundsmen)**:
  the user's auction results trail the AI clubs'. Not investigated.
- **"₹150+ Cr and nothing pushed me to spend" (6):** the invest objective triggers on the bank after
  wages at season start; these managers were below ₹100 Cr then. Check the threshold.
- **"U23 objective when I had one U23" (6):** traders sell the youngsters after the objective is set.
- Results are from one seed per career, so single cells in the table above move by several points.
- Panel 1 and the 20-season balance harness were not re-run on the final code.
