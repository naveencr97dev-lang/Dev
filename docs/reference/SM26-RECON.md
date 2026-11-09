# Soccer Manager 2026: design recon (from the owner's screenshots)

These notes are design-level only: what each screen shows, and the mechanic behind it. No code, art,
names or data was taken. Auction XI rebuilds mechanics in its own cricket form and its own clean,
native look (`docs/MOBILE-DESIGN.md`). Source: 16 screenshots the owner took of their own save,
2026-11-09.

## Screen map

| SM26 screen | What it shows | The mechanic | Auction XI |
|---|---|---|---|
| **Hub** | Top bar: menu, back, club, shop, help, three currencies, **Continue** (date and time). A news ticker. A hero carousel (Player of the Year). Team and Tactics shortcuts. Tiles: Inbox, Manager (level, XP), Competitions (a mini table around your position), Transfers (big deals league-wide), Facilities (stadium, rating gauge), Spotlight (a featured player), International. | One button drives time; everything else is a glanceable tile | ✅ CONTINUE, news, objectives card, assistant card, monthly awards. To do: the mini table around your position, a league-wide transfers tile, a spotlight |
| **Squad list** | Tabs First team / Reserve / Loaned out; a column-set switcher: General (rating, potential range, age, value, fitness, morale, chemistry), Contract (wages, value, squad status, length, expiry), Stats (apps, goals, assists, MoM, average rating, cards) | One list, several column sets | Partial: XI and bench lists. To do: a column-set switcher |
| **Profile** | Card (age, rating, position); role label; key facts; **Morale / Fitness / Chemistry / Suspensions** cards (paid boosts); club and international stats; **Form** (last 5 match ratings); **Squad Status**; **Future** ("Happy at the club"); transfer status; **interested clubs**; squad number | Morale and status are first-class | ✅ Role and morale card (role, morale, future, playing time). Boosts: we have gold actions |
| **Attributes** | Overall + potential range ("Developing"); Technical / Physical / Mental groups with bars | Grouped attributes | ✅ Batting / bowling / fielding bars |
| **Stats** | Per season, per competition: apps, goals, assists, MoM, minutes, average rating, cards | Season × competition table | ✅ Season stats. To do: per competition (league, playoffs, internationals) |
| **Compare** | Same-position players with a Compare button | Side-by-side | To do |
| **Contract tab** | Personality sentences (loyal, handles pressure, ambitious); importance; years left; the expected wage and signing fee; a **Squad Status** picker (Key / First Team / Rotation / Backup / Not Needed) | The status is a promise of playing time | ✅ The role picker; demotion costs morale |
| **Actions** | Move to reserves, Block bids, Transfer list, Loan list, Offer new contract, Release | Per-player action sheet | Partial: list, release. To do: block bids, loans |
| **Toast** | "Does not want to discuss a new contract at this time" | Renewal timing gates | n/a: IPL contracts run to the mega auction |
| **Reports › Contracts** | Expiring contracts | A watch list | ✅ The retirement watch (the cricket version of "expiring") |
| **Reports › Overview** | Average rating, squad size, average age, average and total value; 3 best players; ✓ strengths / ✗ weaknesses ("Defence is a weak area", "Too many attacking players") | Squad analysis in plain sentences | ✅ **Squad report** (batting and bowling vs league, spin and pace options for the home pitch, keeper backup, age, size, morale) |
| **Negotiation** | Expectations (status, years, wage) with a **sad-to-happy bar**; your offer: status, years, wage keypad, signing fee | The offer's distance from the demand, made visible; a role changes the price | ✅ **Promise** picker (a bigger role buys a cheaper wage), **mood bar**, talks left |

### Batch 2: the Team section (Reports › Youth, Stats)

| SM26 screen | What it shows | The mechanic | Auction XI |
|---|---|---|---|
| **Reports › Youth** | Each youngster: base rating, progress bar to the next point, a "Developing" arrow, potential range | Visible growth for young players | ✅ **Development** report: rating at season start → now, trend arrow, potential range (U23s and academy) |
| **Stats (club)** | One category at a time from a dropdown: Goals (apps, minutes per goal, total), Assists, Average Performance | Club leaderboards with a rate column | ✅ **Club stats**: Runs (SR), Wickets (economy), Match rating, Sixes (balls per six), Strike rate, Economy, Player of the match |
| Average Performance / Form "9 10 9 8 5 7" | A 1–10 rating every match | Match ratings | ✅ **Match ratings** 3.0–10.0 from the scorecard (runs and SR, wickets and economy, duck, result, POTM), soft-capped: mean 6.3, POTM 8.8, 9+ only 2%. The player page shows the last 5 and the average. Computed from results: no save change. |

The SM26 Team section is a left rail: Squad / Reports / Stats / Opposition / Squad Planner. Auction
XI's Squad tab now has Development, Club stats and Squad report tiles. Still to do: Opposition (a
scouting report on the next opponent) and Squad Planner.

### Batch 3: Squad Planner

| SM26 element | Mechanic | Auction XI |
|---|---|---|
| Pitch with a formation; each position holds a stack of players with a count badge | A depth chart per position | ✅ **Squad planner**: 7 cricket jobs (Openers 2, Top order 2, Finishers 2, Keeper 1, All-rounder 1, Spinner 1, Seamers 2 = 11), up to 4 deep, as a grid of cards (no pitch art) |
| Slot panel: ▲▼ reorder, delete, Add Players, Clear, sort | Edit a depth chart | ✅ Job screen: reorder, remove, add from eligible squad players (ranked by job score), clear |
| Summary: position, rating gauge, age gauge | Slot health | ✅ Starters' job rating and age, plus a **succession warning** (a starter 33+ with no backup 28 or under) |
| Suggested signing card with a gold price | A target for the slot | ✅ **Scout's target**: the best affordable player who'd start in that job (no gold shortcut) |
| Magic wand | Auto-fill | ✅ Auto-fill (scarce jobs first, overseas cap respected, always 11), plus **Use as my XI** (batting order from slot fit) |

Panel: a tinkerer who runs the team through the planner won 66% / 62% of matches, against 61% / 52%
with Auto-pick. It had 0 illegal plans and 0 weaker-XI matches. The job-aware XI (openers open,
finishers finish) beats Auto-pick.

## Built from this recon

> **Update (schema 13):** the owner chose to replace morale with **form**. Squad roles, morale and
> transfer requests were removed; form (with match ratings) fills that slot on the player page, in
> transfer bids and in the squad report. The notes below record what was built first.

### First build (schema 12)

- `CareerMorale.swift`:
  - Squad roles (promises), morale 0–100.
  - Playing time vs the role moves morale.
  - Only a **broken promise** ends in a transfer request. Casual managers are never punished (panel
    round 4).
  - Happy players +1 and miserable players −2 in matches.
  - Promising a bigger role lowers the wage asked.
  - The squad report.
- Screens:
  - Player page: role and morale card.
  - Squad: Squad report.
  - Transfer bid: Promise picker, mood bar and a warning when you over-promise key roles.

## Next from the recon

0. Consider making the assistant's XI pick use the planner's job logic (it beat Auto-pick in the
   panel). This changes balance for casual players, so run the 20-season harness and the panel first.
1. Opposition report (next opponent: form, best players, home pitch, how to beat them).
2. Squad list column switcher (General / Contract / Stats).
2. Hub tiles: a mini table around your position; league-wide big transfers; a spotlight player.
3. Compare two players.
4. Block bids and loans.
5. Per-competition stats.
