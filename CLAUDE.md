# Working in this repo

## Reply style

Chat replies use the caveman skill (`.claude/skills/caveman/SKILL.md`) from the
first message, every session, to save tokens. It only changes chat prose: code,
commits, docs and READMEs stay normal. Say "stop caveman" or "normal mode" to turn
it off for a session, or `/ultracave` for maximum compression.

## Project

- `ios/`: Auction XI, a SwiftUI T20 auction game (see `ios/README.md`).
- Engine tests (no Mac needed): `cd ios && swift test`.
- iOS builds: Codemagic workflow "Auction XI unsigned IPA" (`codemagic.yaml`),
  then sign with Signulous.

## Handoff: where things stand

- Auction XI lives on branch `claude/gracious-davinci-yq0yej` (continued from
  `claude/beautiful-keller-qgp1vc`, which holds the same history up to `e505be7`). Streaklet is on
  `claude/reverse-engineer-repo-rnfy93`; both apps use `ios/`.
- Build: no Mac. Codemagic builds an unsigned IPA (workflow in `codemagic.yaml`) → the user
  signs and installs it with Signulous. SwiftUI can't be compiled here: parse-check with
  `swiftc -parse`, type-check the WHOLE app with `tools/typecheck/run.sh` (SwiftUI/UIKit/Charts stubs
  in tools/typecheck; add stub APIs as views need them, matching Apple's signatures), and unit-test the
  engine with `swift test` (Swift toolchain for Linux: download swift-6.0.3 for ubuntu24.04 into
  /opt/swift if it's missing). Fast career balance run:
  `CAREER_SEASONS=20 swift test -c release -Xswiftc -enable-testing --filter CareerTests`.
- Target device: iPhone 17 Pro Max, portrait and landscape (landscape is about 830 × 420 pt inside
  the safe area). It's used for casting, so landscape must fit with no scrolling.
- Game rules: 11-player squads (max 4 overseas), pool = 11 × teams + 12, configurable bid
  raise, 5 pitch types, 22 traits, home conditions, batting-slot fit, bowling plans.
- Players: `tools/players_curated.py` → `ios/Resources/players.json` (172 stars and legends).
- Live match: per-ball pacing by excitement, wagon wheel, runs-per-over bars, innings break,
  post-match scorecard → runs per over → highlights.
- **Next big project: Career Mode** (a cricket manager in the style of football manager games).
  Design: `docs/career/GDD.md`. Build order and milestone gates: `docs/career/ROADMAP.md`.
  Work milestone by milestone and keep the GDD in sync with the code. M0–M6 are built as a generic
  first pass (engine in `ios/Sources/Engine/Career`, screens in `ios/Sources/Views/Career`, save
  schema 6 with a migration per version). The user tests on device and sends feedback; fix that
  first. Work in layers (ROADMAP "Layers (80/20)"): layer 2 (runs end to end) is done apart
  from the user's device build. Next is layer 3 (fix from playtests), then tuning, then M7 (ODIs).
- User preferences: replies in the "OPTIMIZED PROMPT (CO-STAR) + results" format, terse
  (caveman). Commit and push every change to the working branch. Tell the user to rebuild in Codemagic.
