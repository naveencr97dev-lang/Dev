# Handoff: Auction XI (read this first in a new chat)

Last updated 2026-11-11 (after the table-format pass on every pushed screen) on branch `claude/ecstatic-feynman-6ve2uz`.

## 1. Where things are

- **Repo:** `naveencr97dev-lang/Dev`. Work on branch **`claude/ecstatic-feynman-6ve2uz`** (it continues
  `claude/gracious-davinci-yq0yej` from `17b9a6b`; point Codemagic at the new branch), then
  commit and push after every change.
  - The old branch `claude/beautiful-keller-qgp1vc` holds the same history up to `e505be7`.
  - The separate Streaklet app is on `claude/reverse-engineer-repo-rnfy93`.
- **App:** `ios/`, Auction XI, SwiftUI, iOS 16+, no dependencies. Two modes:
  - **Quick Auction:** pass-and-play auction, league, playoffs.
  - **Career:** a cricket manager in the style of football manager games.
- **Build:** there is no Mac. Codemagic workflow "Auction XI unsigned IPA" (`codemagic.yaml`)
  builds an unsigned IPA; the user signs it with **Signulous** and installs it on an
  **iPhone 17 Pro Max**. Landscape is about 830 × 420 pt and must fit with no scrolling, because
  the user casts matches.
- **After every change, tell the user to rebuild in Codemagic.**

## 2. User preferences

- **Reply format:** an "OPTIMIZED PROMPT" (CO-STAR) code block, then the results.
- **Voice:** terse, using the **caveman** skill (see §4). The user explicitly wants few tokens.
- **Workflow:**
  - Work in **layers (80/20)**: get it working first, fine-tune later.
  - The user tests on the device and sends feedback; fix that first.
  - Don't wait for playtests; generic first versions are fine.
- **Look:** clean, professional, native-feeling. **No "AI-made" look**: see `docs/MOBILE-DESIGN.md`.
  The user doesn't care about the exact colours.

## 3. Docs (the map)

| File | What |
|---|---|
| `docs/ARCHITECTURE.md` | **Read first.** Feature tree (paths like `Career › Market › Auction`), code layers L0 to L4, where each change goes, backlog by layer |
| `docs/MOBILE-DESIGN.md` | Design rules: tokens, components, screen archetypes, banned "AI tells" |
| `docs/career/GDD.md` | Game design of career mode |
| `docs/career/ROADMAP.md` | Milestones M0 to M7, layers, balance targets, known gaps |
| `ios/README.md` | What the app does, for players |
| `CLAUDE.md` | Short version of this file; loads automatically |

## 4. Skills

### Repo skills (in `.claude/skills/`, load automatically)

- **`caveman`**: terse reply voice. It's on by default every session (CLAUDE.md). "stop caveman"
  or "normal mode" turns it off. **Check it's active at the start of the new chat**: in the old
  chat it wasn't followed until the user asked.
- **`ultracave`**: maximum compression. Use it via `/ultracave` or `/caveman ultra`.

### External skill used as a design reference (not installed)

- **taste-mobile-app-skill**:
  [github.com/orbitextechlab/taste-mobile-app-skill](https://github.com/orbitextechlab/taste-mobile-app-skill).
  - Its "AI tells" list (`references/tells-mobile.md`) and screen archetypes
    (`references/screen-archetypes.md`) drove the v3 redesign. The rules are copied into
    `docs/MOBILE-DESIGN.md`.
  - To read it again: `git clone --depth 1 https://github.com/orbitextechlab/taste-mobile-app-skill`.
  - Another candidate found but not used:
    [noumanzindani/mobile-app-uiux-pro-max-skill](https://github.com/noumanzindani/mobile-app-uiux-pro-max-skill)
    (Apple HIG and WCAG rules).
- **Design kit reference (v2, replaced):** the Kenney CC0 UI packs (kenney.nl).

### Session skills available in Claude Code (built in; not repo files)

- **Used:** `artifact-*`, `dataviz`, `docs`, `run`, `code-review`, `simplify`,
  `session-start-hook`, `update-config`, and the **replica-\*** pack (recon, architect, design,
  build, backend, test, diff, entrepreneur, brand, launch, deploy). The replica pack was used
  earlier for the Streaklet clone.
- **Other built-ins:** `claude-api`, `loop`, `init`, `security-review`, and `anthropic-skills:*`
  (docx, pdf, pptx, xlsx and others).

### Question left open at the end: "What's MiroFish?"

- `666ghj/MiroFish` (about 85k stars) is a multi-agent "swarm intelligence" prediction engine
  (simulates scenarios with many AI agents). Forks: MiroFish-Offline, mirofish-cli, MiroShark.
- It's a standalone app, not a Claude skill. A search for a "MiroFish skill" was interrupted.

## 5. Tools and checks (no Mac)

- **Swift toolchain:** if `/opt/swift` is missing, install it with
  `curl -sSfL https://download.swift.org/swift-6.0.3-release/ubuntu2404/swift-6.0.3-RELEASE/swift-6.0.3-RELEASE-ubuntu24.04.tar.gz | tar xz --strip-components=1 -C /opt/swift`
  (run `mkdir -p /opt/swift` first). Then `export PATH=/opt/swift/usr/bin:$PATH`.
- **Engine tests:** `cd ios && swift test` (107 tests, all green). Pipe the output to a file and
  check the "Executed … with 0 failures" line before committing. One push once went out red because
  a grep in a command chain hid the failure.
- **Whole-app type-check:** `tools/typecheck/run.sh`. It checks all 48 files against SwiftUI, UIKit
  and Charts stubs in `tools/typecheck/`. When a view uses a new Apple API, add a stub with Apple's
  exact signature. This is not a real Xcode build: if Codemagic fails, ask for the error.
- **Balance harness:** `CAREER_SEASONS=20 CAREER_VERBOSE=1 swift test -c release -Xswiftc -enable-testing --filter CareerTests.testMultiSeasonBalance`.
- **Journey test:** `CareerTests.testPlayerJourneyHasNoDeadEnds` presses CONTINUE (`Career.nextAction`)
  for 3+ seasons.
- **`ArchitectureTests`:** no UI imports in the engine, views never mutate the career, every save
  schema has a migration.
- **Customer panel:** `CUSTOMER_PANEL=1 CUSTOMER_SEASONS=4 swift test -c release -Xswiftc -enable-testing --filter CustomerPanelTests`.
  Six personas (caster, tinkerer, trader, bidder, veteran, rookie) play KOL and LKO the way people
  do (Auto-pick, auction advice, the assistant's tips, Right to Match) and write their own complaints,
  counted across players at the end. `PANEL_DEBUG=1` dumps the state on a 10-loss run. Write each
  round up in `docs/feedback/`. **Panel 2, "the home crowd"** (`CUSTOMER_PANEL=2`, filter
  `CustomerPanelTests/testHomeCrowdPanel`): groundsman, purist, homeFan, setAndForget, collector and
  developer manage a turner, a seamer and a road, with home and away records and a same-club
  comparison. `CUSTOMER_PANEL=table` (filter `testPitchTable`) prints league-wide win % by home
  pitch. Write-up: `docs/feedback/PANEL2-HOME-CROWD.md`. This replaces MiroFish, which needs paid
  LLM and Zep keys and can't play an app.
- **UI tour (see the real app, no Mac needed):** `.github/workflows/ui-tour.yml` runs
  `ios/UITests/TourTests.swift` on a GitHub Mac (free: the repo is public) on the largest iPhone
  simulator. The app starts a fixed career with the DEBUG launch argument `-UITour`; the test taps
  through every tab and the screens they open, in landscape and portrait, plays two matches with the
  ⏸ match centre, and saves numbered screenshots. Trigger: push to a `claude/**` branch with
  `[tour]` in the commit message. Results (PNGs, `tour.mp4`, `notes.txt` listing buttons it
  couldn't find, `test-summary.txt`, `RUN.md`) land on the `ui-tour-shots` branch:
  `git fetch origin ui-tour-shots && git worktree add /tmp/shots origin/ui-tour-shots`, then look at
  the PNGs. Tap targets use accessibility identifiers (`tab.<Name>`, `continue`, `pause`,
  `centre.<Tab>`, `marketRow`); add one when a new screen joins the tour.
- **Tuning file:** after changing `CareerTuning` defaults, regenerate it with
  `WRITE_TUNING=1 swift test --filter CareerTests.testWriteTuningFile`.

## 6. What's built (career mode)

The engine is in `ios/Sources/Engine/Career/`, the screens in `ios/Sources/Views/Career/`, and the
store glue in `ios/Sources/Store/GameStore+Career.swift`. **Save schema 15**, with a JSON migration
for each version in `CareerSave.migrations`.

- **Season:** 10 fictional clubs, 36 league matches each, home pitches, IPL playoffs, awards,
  history, news.
- **Calendar:** international windows pause the league before rounds 13 and 25.
- **Flow:** one **CONTINUE** button (`CareerFlow.swift`). One press sims the rest of the round and
  opens your match.
- **Board** (`CareerBoard.swift`, modelled on Soccer Manager 2026): season objectives (finish, home
  wins, U23 appearances) with XP and gold rewards, board confidence, and Player and Manager of the
  Month. Shown on Home.
- **Pitches:** per-pitch career batting calibration (`pitchBatBoost`), so pars are near real ones.
  Career matches use `realisticChase` (chase pacing; the quick game is unchanged).
- **Assistant manager** (`CareerAssistant.swift`): explains losing runs with fixes, and a retirement
  watch at season start. Settings › **Assistant picks my XI** (on for new careers; manual picks turn it off).
- **Mega auction:** **Right to Match** cards (retentions + RTM = 6).
- **Form, not morale** (`CareerSquadReport.swift`): the owner chose form over SM26-style morale, so
  squad roles and morale were removed in schema 13. The player page has a Form card (form label and
  value, trend from match ratings, last 5 ratings); transfer bids show the player's form and a
  negotiation bar (offer vs demand, talks left). Squad › Squad report lists strengths and weak spots,
  including who's in and out of form.
- **Home-pitch squad building** (`CareerPitchFit.swift`): `Pitch.fit` puts the match engine's pitch
  effects (pace or spin bonus, home country, pitch traits) into rating points. AI clubs use it in the
  opening draft (each squad takes five spinners and five quicks), retentions (`keepScore`),
  auction bids (`pitchValueFactor`), free-agent signings, AI-to-AI transfers, and the XI, which is
  picked for the day's pitch (`autoPickXI(clubIndex:pitch:)`; the assistant and Auto-pick XI do the
  same for the user). Since panel 2, clubs value a player over the whole season (`seasonFit`: home
  pitch half, the other grounds half), and Auto-pick fills the places after the keeper and five
  bowlers by batting. Home sides win about 53% (50% before). UI: a house mark on squad,
  market, retention and auction rows (filled green = suits your home pitch, orange outline =
  struggles), a line on the player page and auction lot, and a squad-report line that compares your
  XI's fit with the rivals'. Tuning constants are in `PitchFit` (code, not `career_tuning.json`, so
  no schema change). Tests: `CareerPitchFitTests.swift`.
- **Squad planner** (`CareerPlanner.swift`, Squad › Squad planner): a depth chart for 7 cricket jobs
  (11 starters, up to 4 deep), auto-fill, scout's target per job, a succession warning, and "Use as
  my XI". Schema 14 adds the optional `plan`.
- **Landscape shell** (`CareerHubView`): in landscape (vertical size class compact) the hub shows a
  44 pt top bar (club, money, ⋯, compact Continue) and a left tab rail, hides the navigation bar, and
  lays Home, Squad and Club out in two columns (`AdaptiveColumns`). Rows tighten through the
  `compactLandscape` environment value. Portrait is unchanged.
  Since the screen-recording review (round 7), landscape screens fit without page scrolling: Home
  (fixed boxes; only News scrolls), Squad (the XI fills the left; bench scrolls in its box; squad
  tools grid), Club (office tiles left; squad development tiles and a finance grid right), League
  (Table first, Fixtures, Stats as one top-10 table with a category menu, Leaders 2x2, World),
  the player page (three compact columns, Negotiate in a sheet) and the post-match board.
  Fixed columns use `AdaptiveColumns(leftScrolls:rightScrolls:)` and the `fillRows` environment
  value to stretch rows.
  **Pushed screens (device feedback, 2026-11-11) use one format, `ios/Sources/Views/TableKit.swift`:**
  `TableScreen` (the transfer market's layout: a pinned summary line, filter and action chips, column
  titles, then one-line rows; only the rows scroll) for lists (Pick XI, Batting order, Bowling plan,
  Retentions, National squad, other clubs, Academy, Facilities, Offers, Club stats, Development,
  Squad planner, match centre Batting and Bowling), and `PaneScreen` (two panes side by side in
  landscape, like the Squad tab) for settings and cards (Tactics, Training, Scouting, Settings,
  Manager, Store, Squad report, a planner job, Auction, Money, History). Actions (Save, Auto-pick,
  Best order, Accept) are `ActionChip`s in the header, not the navigation bar. Rows use
  `.tableRow()` and fixed `TCol` widths; reorderable lists use `ReorderList` + `.reorderRow()`. In
  portrait the wide tables drop secondary columns (age, form, slot, overs) and action chips go
  icon-only. New list screens should use these, not `List` or `CareerScreen`. Open: the Legend veteran can still lose 19-21 in a row.
- **Music and sound** (`ios/Sources/Audio/GameAudio.swift`): original audio generated by
  `tools/audio/make_audio.py` (numpy + ffmpeg; rerun it to change a sound) into
  `ios/Resources/Audio/*.m4a`, about 1.2 MB. Hub theme (40 s loop, 96 bpm, D major, drone + pluck +
  tabla-style taps), match-day crowd loop, and effects for runs, fours, sixes, wickets and a win.
  Ambient session: follows the silent switch and mixes with the user's music. Music and Sound effects
  switches sit in every ⋯ menu and in career Settings. The type-check has an AVFoundation stub.
- **Tactics** (`CareerStrategy.swift`, `CareerTacticsView`): game plans with a Defence ↔ Attack bar
  and a "suits this pitch" badge (from simulation), phase settings, toss call, captain (+1) and
  batting roles (Anchor / Normal / Hitter). Tactic risk is pitch-aware since the probe found
  All-out attack best on every pitch. New optional fields on `Tactics`, so no schema change. Squad › Development (young players' progress)
  and Squad › Club stats (category leaders with match ratings). Match ratings (3-10) come from the
  scorecards (`Career.matchRating`); the player page shows the last 5.
- **Squad:** XI from about 20 players, batting order, bowling plan of 5, tactics.
- **Tactics:** field Defensive / Balanced / Aggressive and batting Block / Rotate / Attack, per phase.
- **Match day:**
  - Live view with a wagon wheel or 2D ground, highlights and **super overs**.
  - **⏸ Match centre** (modelled on Soccer Manager's in-match panel, from the owner's screen
    recordings): a tab rail in landscape (chips in portrait). **Overview**: score, a runs-v-target
    (or overs) bar, run rate, required rate or projection, last 5 overs, partnership, 4s/6s, dot
    balls, and the **assistant's live advice** (1-3 lines, `LiveReport.advice`). **Ratings**: live
    match ratings for both XIs side by side (`LiveReport.rating`, the same formula as the
    end-of-match rating). **Around the league**: the round's other results and the matches still to
    play (`Career.roundFixtures`). Then the scorecard so far and mid-match changes to tactics,
    batting order, the next over's bowler and the bowling plan.
  - Matches are previewed and only recorded at the end. Changes re-simulate with the same seed, so
    balls already shown never change.
- **Market:**
  - Contracts run to the next mega auction, under a ₹120 Cr salary cap.
  - Mega auction every 3 years with up to 6 retentions; mini auctions in between. The auction is
    turn-based.
  - Transfers: offers and counters, Pay asking price, every player listed with their owner.
  - AI clubs buy from each other each window. Auction lots show staff advice.
  - Filters by role, batting slot and pace/spin; sort by stats.
  - Settings → **market always open** (on for testing).
- **Development:**
  - Ageing and potential.
  - Training: drills, intensity, focus, and a **Start this week's session** button.
  - Scouts: a report every 2 weeks.
  - Academy.
- **Club:**
  - 7 facilities.
  - Money: **weekly ticket sales** (ticket price Low / Normal / High; ₹50 L+ a home match at a
    level-2 stadium), **merchandise**, a **main sponsor paid each month** of the season (Jan-Nov,
    ₹40 L+ a month, more with the Commercial Hub; schema 15 adds `sponsorMonthPaid`), central
    revenue and prizes after the final (₹40 Cr to the champions), wages and upkeep. Facility
    upgrades cost ₹30 L × the next level, so a season of tickets pays for one upgrade of every
    facility (`CareerEconomyTests`). A Money screen breaks it down; League › Table shows the prizes.
- **Manager:** XP, levels, 24 perks in 3 trees. **Gold**, with a test-mode store where the Tester
  Pack (1,000,000 gold) is free and unlimited, and a gold→cash exchange.
- **International:** 20 nations, rankings, bilateral series, the T20 World Cup in even years, the
  national job, a board, and the national squad.
- **Stats:** this season, all-time and season by season; leaderboards.
- **Settings:** difficulty Easy / Normal / Hard / Legend, market always open, **Text size**.
- **Look:**
  - v3 "clean native": iOS dark system colours, a green accent, a 6-size type scale, flat grouped
    lists, SF Symbols.
  - Home is a hero plus one grouped list. Bottom tabs: Home, Squad, Transfers, League, Club.

## 7. Next steps and known gaps

### Next task

Nothing is queued: start with the user's device feedback on the table-format build (every pushed
screen moved to `TableScreen` / `PaneScreen`; checked by the type-check only, never rendered).
Open from panel 2 (`docs/feedback/PANEL2-HOME-CROWD.md`): turner clubs win 58% and bounce grounds
give no home edge (a layer-0 pitch-bonus question); the user's auction results trail the AI clubs';
the invest objective rarely triggers. Panel 1 and the 20-season balance harness were not re-run.

Older playtest notes (three personas): `docs/PLAYTEST-PANEL.md`.

Customer-panel reports: `docs/feedback/ROUND1.md` (the SM26 reference) and `docs/feedback/ROUND2-3.md`.
Open from the panel: youth growth is low for some seeds (check potential headroom, round 6); KOL starts too old (age-balance the opening draft); about 40% blowouts (easy-chase
pacing); casual players ignore the invest objective.


The full backlog is in `docs/ARCHITECTURE.md` §4.

1. **The user's device test of the latest build:** fix anything reported first (layer 3).
2. **Design:** Quick Auction screens (auction ticket, broadcast score strip) still use older
   layouts. Pitch and trait emoji are still used as content glyphs.
3. **Balance:**
   - About 45% of games are blowouts (chase pacing, L0).
   - Flat-pitch scores may drift down over many seasons.
   - KOL was strong in the harness.
4. **Systems:** loans, contract talks with a patience bar, a squad planner (SM26 ideas), an
   international stats screen, mid-match changes in Quick Auction.
5. **M7:** ODIs and the ODI World Cup (needs an N-over engine option).
6. **Before any public release:** the real StoreKit store (`StoreConfig.testerStore` off),
   fictional player names (licensing), and the market always-open setting off by default.
