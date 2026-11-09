# Auction XI: Career Mode, Game Design Document (GDD)

This document is the single source of truth for Career Mode. If code and the GDD disagree, fix
one of them in the same change. Build order is in [ROADMAP.md](ROADMAP.md).

> Status: **v0.2**, 2026-11-09 (M0 and M1 built; see ROADMAP).
> Earlier draft: v0.1, 2026-11-08. Owner: Naveen. The genre and mechanics follow football
> manager games (reference: Soccer Manager 2027). Names, art, UI and copy are all original.

---

## 1. Pitch

You are a T20 franchise manager. You run one fictional IPL-format franchise season after season.
You sign players at auctions and in a year-round transfer market, scout and develop talent, build
facilities, grow your manager skill tree and, once your reputation earns it, also coach a national
team at World Cups.

**Pillars**

1. **Every decision shows on the scorecard.** Signings, batting order, training, pitch and traits
   all feed the existing ball-by-ball engine.
2. **A year that never stops.** A 36-match league runs across the calendar, broken up by
   international windows, auctions and transfer deadlines.
3. **A long career.** Players age and develop, academies produce stars, facilities build up over
   many seasons.
4. **Phone-first and castable.** Everything fits on an iPhone 17 Pro Max in portrait and in
   landscape (about 830 × 420 pt safe area) with no scrolling in landscape.

**Not in scope:** 3D, relegation, real-money purchases (for now), online multiplayer.

---

## 2. Core loops

```
Moment-to-moment loop (one match)
  Pick XI and batting order → bowling plan and field settings → watch the match in 2D
  → make in-match changes → result

Weekly loop (one matchday round)
  Set training focus → check fitness and morale → scout reports → market offers → play the match

Season loop (one year)
  Retentions → auction → league (36 matches) with international windows in between → playoffs
  → awards → contracts, ageing, youth intake, facility work → next season

Career loop (many years)
  Manager XP → traits → reputation → national team job offers → World Cups → legacy
```

---

## 3. Competitions and calendar

### 3.1 The league (IPL format, extended)

| Rule | Value |
|---|---|
| Franchises | 10, all with fictional names. The user manages 1 and AI manages 9. |
| League | Quadruple round-robin: each pair meets 4 times (2 home, 2 away). That's **36 matches per team** and 180 in total. |
| Points | Win 2, no result 1, loss 0. Tiebreaks: points, then NRR, then wins, then head-to-head. |
| Playoffs | IPL style: Qualifier 1 (1st v 2nd), Eliminator (3rd v 4th), Qualifier 2, Final. |
| Relegation | **None.** Pressure comes from owner expectations (playoffs and finances). |
| Home ground | Every club has a home pitch (for example a dusty turner or an English seamer). Home league matches are played on it, so squads should suit it. Playoff venues are drawn at random. |
| Starting squads | A balanced snake draft of 20 players per club (2 WK, 6 BAT, 4 AR, 8 BOWL, max 8 overseas). You then pick a club, as in football manager games. Auctions take over from season 2 (M2). |
| Squad | 18–25 players, max 8 overseas. A playing XI has max 4 overseas. |
| Salary cap | Auction purse of ₹120 Cr. Wages count against it. |
| Impact player | Optional rule toggle, off by default. |

### 3.2 A year on the calendar (one season = one calendar year)

| When | What |
|---|---|
| Dec wk 1 | Retention deadline (up to 6 in a mega-auction year, 4 otherwise) |
| Dec wk 2 | **Auction**: a mega auction every 3rd season, a mini auction in the others |
| Dec–Jan | Main transfer window open |
| Jan–Mar | League rounds 1–12 |
| Apr | **International window A** (bilaterals; the T20 World Cup in even years) |
| May–Jul | League rounds 13–24 · mid-season transfer window in July |
| Aug | **International window B** (bilaterals; the ODI World Cup every 4th year, from M7) |
| Sep–Oct | League rounds 25–36 |
| Nov | Playoffs → awards → contract expiries → ageing and development tick → youth intake |

The league pauses during international windows, so franchises never lose players to clashes.

### 3.3 International

- **Nations:** 20 at launch: 12 full members plus 8 associates. Each has a player pool, a home
  pitch profile (it reuses the existing home-conditions table) and a ranking.
- **Formats:** T20I first. ODI arrives in M7, once the engine supports N-over innings.
- **Events:**
  - Bilateral series in every window.
  - **T20 World Cup** every 2 years: 20 teams, 4 groups of 5, Super 8, semi-finals, final.
  - **ODI World Cup** every 4 years (M7).
  - A Champions-style trophy in odd years (stretch goal).
- **The national job:** offered when manager reputation is high enough and a job is open. It can
  be held at the same time as the franchise job. Rules:
  - You select a 15-player squad from eligible nationals. Caps are tracked.
  - The board sets a target per event, such as "reach the semi-finals".
  - Missing targets twice in a row gets you sacked. Sacking can be turned off in settings.
- **Rankings:** rating points from results weighted by opponent strength, updated after each series.

---

## 4. Players

### 4.1 Data model (extends `Player` in `Models.swift`)

| Group | Fields |
|---|---|
| Identity | id, name, nation, age, birth date, role, bat hand, bowl type, best bat slot |
| Batting | technique, power, vs pace, vs spin, temperament, running |
| Bowling | accuracy, pace or turn, variation, death skill, new-ball skill |
| Other | fielding, keeping, fitness, leadership |
| Hidden | **potential** (40–99), growth curve, injury proneness, consistency |
| Dynamic | form (−10…+10), morale, fatigue, sharpness, injury (days out) |
| Career | contract (wage, years, release fee), market value, caps, career stats, honours |
| Traits | the existing 22 traits. Potential new ones are listed in the backlog. |

The existing match ratings (bat and bowl overall) are **derived** from these attributes, so
`MatchEngine` keeps working unchanged. Form, fatigue and morale apply as small modifiers.

- **Form (M1):** each match moves form by −2…+4 from runs and wickets, decaying 1 per match. Up to
  ±3 bat and bowl.
- **Engine calibration:** career XIs have more depth players and fewer trait-laden stars than the
  quick game, so the engine adds `engineBatBoost` (tuning, default +8) to batting **inside matches
  only**. The ratings you see stay true.

### 4.2 Player database

- **Real stars:** the current 172 curated players. Retired legends move to an optional
  "Legends era" start, so a normal career begins with active players only.
- **Generated depth:** about 1,500 fictional players, built from per-nation name pools and rating
  bands. This fills franchise squads, national pools, free agents and youth intakes.
- **Licensing:** real names are fine for a private sideload build. A public App Store release
  needs either licences or a switch to fictional names. All franchise names stay fictional.

### 4.3 Development

- Each season, and as a smaller tick each month, attributes move towards potential. The growth
  rate comes from:
  - an age curve: fast up to 23, slow from 24–29, flat from 30–32, then decline;
  - the training focus;
  - the training facility level;
  - playing time;
  - manager traits.
- Retirement chance rises with age, from 35 onwards for batters and 34 for fast bowlers.

---

## 5. Squad building: auction and transfer market

### 5.1 Auction

- This reuses the `AuctionEngine` bidding, timers and AI.
- **Mega auction** every 3 seasons. Up to 6 retentions, with retention prices deducted from the purse.
- **Mini auction** in the other years. It covers released players, free agents and new generated talent.
- One **RTM (right to match) card** per mega auction.
- AI bidding valuations come from player value, squad needs, remaining purse and the pitch profile.

### 5.2 Transfer market (Soccer Manager style)

- **Buy:** search the market, then make an offer (fee, plus wage and years). The AI club accepts,
  rejects or counters, and you can go back and forth up to 3 rounds.
- **Sell:** list a player. AI clubs send bids over the following days, and you accept or reject.
- **Unsolicited offers:** AI clubs bid for your players, and rivals can top each other's bids.
- **Loans** (stretch): short-term loans with a share of the wages.
- Trades are allowed in transfer windows only. Squad and overseas limits are always enforced.
- **Free agents:** you can sign one at any time if you have a squad slot.

### 5.2b As built (M2)

- **Windows:** the off-season (after the auction), the first two league rounds, and the break before
  round 25.
- **Auction:** turn-based (no timer). AI limits come from value × squad need × personality × noise,
  capped by cap room minus a reserve to reach 18 players.
- **Asking prices:** value × 1.5 for an XI regular, × 1.15 for a bench player. Offers below 75% of the
  ask are rejected; anything closer gets a counter.
- **Wage demands:** the higher of the player's market value and 110% of his current wage.

### 5.3 Contracts

- Wage, length (1–3 years) and a release fee.
- Renewals open in the final year. The player asks for a wage based on value, morale and form,
  and Boardroom traits lower it.
- Player morale suffers if they're not playing, are underpaid, or a contract talk goes badly.

---

## 6. Scouting

- **Staff:** hire scouts, each with a skill rating (1–5★), a home region and a wage. The number of
  scouts you can hire is capped by the Scouting Network facility level.
- **Assignments:** send a scout to a region (a nation or group of nations) with a brief, such as
  "U21 spinners, potential 80+". Reports arrive over the following days.
- **Fog of war:** attributes and potential of players you haven't scouted show as ranges
  (for example 62–78). More scouting and better scouts narrow the range to an exact number.
- **Search:** filter by attribute (as in Soccer Manager), role, age, nation, trait, value, wage and
  contract expiry. Results show only what your scouting knowledge reveals.
- **Shortlist:** shortlisted players appear on the auction prep screen and in the transfer market.

---

## 7. Training (Soccer Manager style)

- A **weekly schedule** of drill slots. You get 3 slots at the start; Training facility levels and
  traits add up to 6.
- **Team drills** (pick one per slot):
  - Power hitting
  - Rotation and running
  - Pace batting
  - Spin batting
  - Death bowling
  - New-ball swing
  - Spin variations
  - Fielding and catching
  - Fitness
  - Match simulation
- **Individual focus:** give each player one attribute focus with extra growth.
- **Intensity** (light, normal, hard) trades growth against fatigue and injury risk.
- **Match prep:** a drill aimed at the next opponent or pitch gives a small one-match bonus.
- **Youth:** academy players train on their own schedule.

---

## 8. Facilities (Soccer Manager style)

Each facility has levels 1–10. Upgrades cost cash and build time, and each level adds yearly
maintenance. Gold can speed up a build.

| Facility | Effect per level |
|---|---|
| **Stadium** | Capacity, which drives gate revenue. It also boosts home advantage a little. |
| **Training Ground** | Development speed and drill slots (+1 at levels 3, 6 and 9) |
| **Youth Academy** | Number of players and potential range in each yearly intake |
| **Medical Centre** | Injury risk and recovery time |
| **Scouting Network** | Scout cap, regions you can cover, and report speed |
| **Analytics Room** | Opponent insights before a match and accuracy of the match-prep bonus |
| **Commercial Hub** | Merchandise and sponsor revenue |

---

## 9. Finances

- **Income:** gate receipts (stadium × form × opponent), TV central money (fixed), sponsors
  (reputation), merchandise, prize money, transfer sales.
- **Spending:** wages, transfer fees, staff wages, facility maintenance, upgrades.
- **Owner:** sets a budget each season and expects the club to stay solvent. Running a deficit for
  2 seasons in a row cuts the transfer budget.
- **Screens:** a monthly ledger and a season projection.

---

## 10. Manager: XP, levels and traits

- **XP sources:**
  - each match won;
  - each trophy;
  - a player you trained gaining +5 overall;
  - finishing a season in profit;
  - international results.
- **Levels:** capped at 100 at launch. Each level gives 1 trait point plus some gold. Points
  apply to that save only.
- **Three trait trees** (8 perks each, tiered: cost 1, 2 or 3 points, with tier gates):

| Training tree | Boardroom tree | Tactical tree |
|---|---|---|
| Drill Master: drill effect +10% | Negotiator: renewal wages −10% | Captain's Call: in-match changes act faster |
| Extra Session: +1 drill slot | Dealmaker: sale fees +10% | Powerplay Plan: +powerplay batting and bowling |
| Youth Mentor: U21 growth +15% | Star Magnet: players are keener to sign | Death Plan: +death-over skill |
| Veteran Care: decline from 30+ is slower | Auction Shark: shows a hint of rival max bids | Spin Doctor: spinners do better on turners |
| Fitness Guru: fatigue −15% | Sponsor Friend: commercial income +10% | Chemistry: team chemistry builds faster |
| Injury Prevention: injury risk −15% | Crowd Puller: gate revenue +10% | Youth Faith: academy potential +3 |
| Specialist Coach: individual focus +20% | Lean Build: facility costs −10% | Home Fortress: home advantage increases |
| Net Program: bowler growth +10% | Global Network: +1 scouting region | Big-Match Temperament: playoff bonus |

- **Reputation** (separate from XP) unlocks better national-team offers and makes free agents
  keener to sign.
- **Awards:** Manager of the Month and Manager of the Year.

---

## 11. Match day

- **Before the match:** XI, batting order (the existing slot-fit system), bowling plan (existing)
  and a **field setting** per phase (attack, balanced or defend). The field changes boundary rate
  against wicket chance.
- **During the match:** pause to change the bowler order, batting order (for players not yet in),
  field setting or batting intent (block, rotate, attack).
- **Engine:** the existing deterministic `MatchEngine`, extended with form, fatigue, morale,
  field and intent modifiers.
- **Quick sim:** AI-vs-AI matches run through the same engine without commentary. Performance
  budget: one full season of 180 matches simulates in under 2 seconds on device.
- **Weather** (stretch): dew in night matches helps the chasing team, and rain brings DLS.

### 11.0 Career look (manager-game style)

- Navy "manager's desk" theme for career screens (`CareerTheme.swift`): panels with header strips.
  Shared cards switch to navy through the `careerTheme` environment value.
- **Top bar:** club crest, club, manager, level, national job, date, bank and gold.
- **Home:** the desk (status, next match, recent results, news), then a dashboard of tiles grouped
  as Club, Competition and Office. Each tile pushes its screen.
- **CONTINUE:** one big button pinned to the bottom always does the next thing (`Career.nextAction`):
  play your match, sim to it, open an international window, retentions, the auction room, start
  the season, or go to the off-season. The journey test presses the same button.
- These are genre conventions only. All art, names and layout details are original.

### 11.1 2D match view

- A top-down ground showing 11 fielders placed by the field setting, the batter and the bowler.
  It animates the ball path for each delivery and builds on `WagonWheel.swift`.
- **Landscape:** the ground fills the right half and the score strip and controls sit on the
  left, the same split as the current live match.
- **Portrait:** the ground on top, with the score and runs-per-over bars below.

---

## 12. Gold and store

- **Earn gold from:** level-ups, trophies, achievements and a daily login bonus.
- **Spend gold on:**
  - finishing a facility build instantly;
  - an instant scout report;
  - re-rolling a youth intake once a season;
  - a training boost (+50% for 1 week);
  - healing an injury faster;
  - an extra RTM card.
- **Store packs:**

| Pack | Price shown | Notes |
|---|---|---|
| 400 Gold | display only | |
| 1,200 Gold | display only | |
| 6,000 Gold | display only | |
| **Tester Pack: 1,000,000 Gold** | **Free** | **Unlimited purchases.** Behind the `testerStore` flag, which is on by default in this build. |

- **As built (M4):** `StorePack` and `StoreConfig.testerStore` in `CareerClub.swift`. In test mode
  every pack is granted free. The cap exemption for minimum-wage fillers (up to 8, to reach 18
  players) is documented in ROADMAP M3.
- **Implementation:**
  - A `StoreService` protocol with a `MockStore` implementation that grants gold instantly with
    no charge.
  - Real StoreKit 2 needs an App Store Connect product setup and an App Store or TestFlight
    install. It can't charge money in a sideloaded (Signulous) build.
  - Before any public release: turn off `testerStore` and swap in `StoreKitStore`.

---

## 13. Technical design

- **Engine-first:** all rules live in `ios/Sources/Engine` (pure Swift, no SwiftUI) and are unit
  tested on Linux with `swift test`.
- **New modules:**

| Module | Job |
|---|---|
| `Career` | Save root: date, clubs, players, manager |
| `Calendar` | Day-by-day events and windows |
| `LeagueEngine` | 36-match fixtures, table, playoffs. Generalises `SeasonEngine`. |
| `InternationalEngine` | Nations, rankings, series, World Cups |
| `TransferMarket` | Offers, AI bids, negotiation |
| `ContractEngine` | Contracts and renewals |
| `Scouting` | Scouts, assignments, fog-of-war ranges |
| `Training` | Drills, individual focus, intensity |
| `Development` | Monthly and yearly attribute ticks, ageing, retirement |
| `YouthAcademy` | Yearly intake |
| `Facilities` | Levels, builds, maintenance |
| `Finance` | Income, spending, ledger, owner budget |
| `ManagerProfile` | XP, levels, traits, reputation |
| `Economy` | Gold faucets and sinks |
| `StoreService` | `MockStore` now, `StoreKitStore` later |
| `PlayerGen` | Generated players from name pools and rating bands |

- **Determinism:** one seeded `RNG` per save. The same seed and the same choices always give the
  same career. This makes bugs reproducible and keeps balance tests stable.
- **Data-driven tuning:** balance numbers (growth rates, prices, drill effects) live in
  `ios/Resources/career_tuning.json`, not in code.
- **Saves:** Codable JSON with `schemaVersion` and step-by-step migrations. 3 save slots plus
  autosave after every match day. Target save size is under 5 MB.
- **Feature flags:** `testerStore`, `legendsEra`, `impactPlayer`, `sacking`, `odiFormat`.
- **Modes:** Quick Auction (the current pass-and-play game, unchanged) and Career.
