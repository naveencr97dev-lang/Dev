# Handoff: Auction XI (read this first in a new chat)

Last updated 2026-11-09 (after customer-panel rounds 1-4 and the SM26 recon) on branch `claude/gracious-davinci-yq0yej`.

## 1. Where things are

- **Repo:** `naveencr97dev-lang/Dev`. Work on branch **`claude/gracious-davinci-yq0yej`**, then
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
- **Engine tests:** `cd ios && swift test` (80 tests, all green). Pipe the output to a file and
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
  round up in `docs/feedback/`. This replaces MiroFish, which needs paid
  LLM and Zep keys and can't play an app.
- **Tuning file:** after changing `CareerTuning` defaults, regenerate it with
  `WRITE_TUNING=1 swift test --filter CareerTests.testWriteTuningFile`.

## 6. What's built (career mode)

The engine is in `ios/Sources/Engine/Career/`, the screens in `ios/Sources/Views/Career/`, and the
store glue in `ios/Sources/Store/GameStore+Career.swift`. **Save schema 13**, with a JSON migration
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
  including who's in and out of form. Squad › Development (young players' progress)
  and Squad › Club stats (category leaders with match ratings). Match ratings (3-10) come from the
  scorecards (`Career.matchRating`); the player page shows the last 5.
- **Squad:** XI from about 20 players, batting order, bowling plan of 5, tactics.
- **Tactics:** field Defensive / Balanced / Aggressive and batting Block / Rotate / Attack, per phase.
- **Match day:**
  - Live view with a wagon wheel or 2D ground, highlights and **super overs**.
  - **⏸ Match centre:** scorecard so far; mid-match changes to tactics, batting order, the next
    over's bowler and the bowling plan.
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
  - Money: **weekly ticket sales** (ticket price Low / Normal / High) and **merchandise**, central
    revenue and prizes after the final, wages and upkeep. A Money screen breaks it down.
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

Customer-panel reports: `docs/feedback/ROUND1.md` (the SM26 reference) and `docs/feedback/ROUND2-3.md`.
Open from the panel: KOL starts too old (age-balance the opening draft); about 40% blowouts (easy-chase
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
