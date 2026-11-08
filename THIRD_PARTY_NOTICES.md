# Third-party notices

## Crick Auction: player data

`ios/Resources/players.json` is derived from `src/data/players.js` in
https://github.com/Shaurya01836/ipl-auction (Crick Auction), licensed under the
Apache License, Version 2.0 (https://www.apache.org/licenses/LICENSE-2.0).

Changes: image URLs removed; roles normalised; separate batting and bowling
ratings derived from the career stats by `tools/build_players.py`; auction pools
regrouped. No code from that project is included.

Player names and statistics are factual information. Franchise names in this app
are fictional and not affiliated with any real league or team.

## Streaklet

Theme helpers (hex colours, confetti, haptics) and the Codemagic build pipeline
are reused from this repository's own Streaklet app.

## caveman skills

`.claude/skills/caveman/` and `.claude/skills/ultracave/` are copied unchanged
from https://github.com/JuliusBrussee/caveman (v4.1.0, commit 1e91f13), MIT
licensed (see the LICENSE file in each folder). Only the Markdown skills are
included: none of that project's hooks, scripts or proxy.
