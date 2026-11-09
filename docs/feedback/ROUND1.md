# Customer panel: round 1 (2026-11-09)

## How the panel works

MiroFish (`666ghj/MiroFish`) was the requested tool. It needs a paid LLM key and a Zep memory key, and
it simulates social-media opinion from a seed document. It can't play an app. So the panel was built
in the same spirit but against the real game: `ios/Tests/EngineTests/CustomerPanelTests.swift`.

Six simulated players ("personas") play full careers through the real engine, pressing CONTINUE the
way the app does. They all manage the same club with the same seed, so differences come from how they
play, not from luck of the draw.

```
CUSTOMER_PANEL=1 CUSTOMER_SEASONS=4 swift test -c release -Xswiftc -enable-testing --filter CustomerPanelTests
```

| Persona | Quote | Plays like |
|---|---|---|
| caster | "I cast matches to the TV and just want a story." | Presses CONTINUE, nothing else |
| tinkerer | "I want every lever to matter." | Training every week, perks, facilities, aggressive tactics |
| trader | "The market is the game for me." | Buys upgrades, lists the bench, accepts bids |
| bidder | "The auction is why I play IPL games." | Bids on every lot it can afford |
| veteran | "Give me Legend and make me earn it." | Legend difficulty, sensible management |
| rookie | "First manager game, Easy mode." | Easy difficulty, presses CONTINUE |

## Reference: Soccer Manager 2026 (Invincibles Studio)

Taken from its App Store listing, the developer's posts and review aggregators:

- **Manager traits:** three trees (Training, Suit, Tactical), points from levelling, kept per save.
  We already have this as 24 perks in 3 trees.
- **Objectives:** club objectives and daily rewards. **Missing here.**
- **Awards:** monthly and seasonal manager awards (Manager of the Month, World Player of the Year).
  **Missing here.**
- **Transfers:** AI clubs bid on and buy players from each other, and players can be poached with a
  higher offer. **AI-to-AI deals were missing here.**
- **Other:** contract talks with a patience bar, free-agent scouting filters, a squad planner, live
  scores, an inbox, and weather in the match engine.
- **What its users complain about:** pushy in-app purchases; free agents that still ask for a fee;
  facilities too costly in small leagues; "a much stronger team should win by more"; poor youth
  development; ratings that don't reflect form.

## What the panel said (before the fixes)

| # | Finding | Evidence | Who felt it |
|---|---|---|---|
| 1 | **Half the presses do nothing.** Each match takes 2 presses: Continue (sim the round), then Play. | 46% of 366 presses per 4 seasons had no decision | caster, rookie |
| 2 | **Bowler-friendly grounds are dull.** Average first innings: seam 128-132, turner 135-138, slow 134-143, bounce 142-145, flat 188-190. Real T20 pars are about 155-170. | 4,320 league matches | everyone |
| 3 | **Too many one-sided games.** About 50% of the user's games were blowouts, and only 11-15% were thrillers. | Margin buckets | caster |
| 4 | **Money stops mattering.** Every bank grows about 30 Cr a season: AI 123→218 Cr, a casual user 142→244 Cr. AI clubs never spend. | Banks per season | trader, caster |
| 5 | **Nothing to aim for between matches.** No objectives and no monthly milestones, only the final table. (Compared against SM26.) | No goal state in the save | caster, rookie |
| 6 | **The auction lets you wreck your squad.** The bidder won 7 lots and its XI fell from 79 to 67-68. Nothing warned it. | XI strength | bidder |
| 7 | The market is static: AI clubs only sign free agents. | No AI-to-AI deals | trader |

## What changed

| # | Fix | Layer | Result in round 2 |
|---|---|---|---|
| 1 | CONTINUE sims the round and opens your match in one press. The button reads "Play match · vs X · other games sim first". | L4 + label | Presses 366 → 225 per 4 seasons; idle 46% → 10% |
| 2 | Per-pitch batting calibration `pitchBatBoost` (career only; the quick game is unchanged) | L2 | seam 152, turner 156, slow 161, bounce 169, flat 189 |
| 3 | Follows from #2 (pars near real ones mean closer chases) | L2 | thrillers 11-15% → 16-21%; blowouts 50% → 40-53% |
| 4 | AI-to-AI transfers each window (`aiTransfers`, reserve 25 Cr, up to 2 deals); central revenue 95 → 80 Cr | L1 + L2 | AI bank growth about +30 → +15 Cr a season; transfer news between AI clubs |
| 5 | **Board objectives** (SM26-style): finish, home wins, U23 appearances, with XP and gold rewards and a board confidence %. **Player and Manager of the Month.** Shown on Home. | L1 (new leaf `CareerBoard.swift`) + L4 | Objectives met: Easy about 10/12, Normal 7-10/12, Legend 3/12. Manager of the Month 1-9 times per 4 seasons |
| 6 | Staff advice on each auction lot ("Walks into your XI…", "Fills a gap…", "Depth only…") | L1 helper + L4 | Visible on every lot |
| 7 | = #4 | | |

## Guardrails after the changes

- `swift test`: 66 tests, 0 failures (7 new: objectives, monthly awards, AI transfers, pitch
  calibration, scout advice, the v9→v10 migration, and the panel itself, which is off by default).
- 20-season harness: champions spread across 8 clubs, the pool is stable, and saves are 1 MB. Seam
  drifts to 140 over 20 seasons. Club 3 won 8 of 20, right at the 40% dynasty limit, so watch KOL.
- `tools/typecheck/run.sh`: the whole app type-checks.

## Still open (next rounds)

- Blowouts are still about 45% (by the panel's loose definition). Look at chase pacing in the engine:
  that's an L0 change, so it needs care.
- User XIs fade over 4 seasons (79 → 72-77). Development and youth may need a lift (SM26 users
  complain about this too).
- SM26 ideas not done yet: contract talks with a patience bar, a squad planner, live scores of other
  games, weather and dew, loans.
