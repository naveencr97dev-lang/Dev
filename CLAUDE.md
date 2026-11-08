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
