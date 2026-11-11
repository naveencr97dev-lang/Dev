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

**Start every new chat by reading `docs/HANDOFF.md`.** It covers the full state, skills, tools, what's
built, and the next steps. Key points:

- **Branch:** `claude/ecstatic-feynman-6ve2uz` (continues `claude/gracious-davinci-yq0yej`). Commit and push every change; tell the user to rebuild in Codemagic.
- **Build:** no Mac. Codemagic builds an unsigned IPA, then Signulous installs it on an iPhone 17 Pro Max.
  Landscape (about 830 × 420 pt) must fit with no scrolling.
- **Checks:** run `tools/typecheck/run.sh` (whole app, SwiftUI stubs) and `cd ios && swift test`
  (107 tests). Install Swift 6.0.3 into /opt/swift if it's missing (command in HANDOFF.md).
- **Docs:** `docs/ARCHITECTURE.md` (feature tree and layers; fix in the lowest-risk layer),
  `docs/MOBILE-DESIGN.md` (clean native look, banned AI tells), `docs/career/GDD.md`,
  `docs/career/ROADMAP.md`.
- **Skills:** repo skills `caveman` (on by default; check it's active) and `ultracave`. The design
  reference is taste-mobile-app-skill (github.com/orbitextechlab/taste-mobile-app-skill).
- **Career save schema:** 15, with a JSON migration per version.
- **User preferences:**
  - Replies use the "OPTIMIZED PROMPT (CO-STAR) + results" format, in the terse caveman voice.
  - Work in layers (80/20); generic first versions are fine; fix the user's device feedback first.
  - Clean, professional look, never "AI-made".
- **Done last:** home-pitch squad building (`CareerPitchFit.swift`) and customer panel 2
  (`docs/feedback/PANEL2-HOME-CROWD.md`). **Next:** the user's device feedback (HANDOFF.md §7).
