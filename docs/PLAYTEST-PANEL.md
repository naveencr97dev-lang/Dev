# Playtest panel, 2026-11-10

Three AI panelists (Fable) reviewed career mode. The app can't run here, so each walked the screens
from code; one also ran the headless journey test. The live match screen was out of scope.

| Panelist | Profile | Liked | Main problems |
|---|---|---|---|
| **Ravi** | Casual fan, 10-minute sessions, portrait | CONTINUE bar, Home summary, Auto-pick, auction room, club picker | Walls of text and symbols on batting order, bowling plan and training; Buy button buried at the bottom of the profile; auction drags; important results shown as tiny grey text; no first-session guidance |
| **Meera** | Manager-game veteran | Batting-order and bowling-plan numbers, perks with exact effects, training report, market rows with stats | Drill choice barely matters (the engine uses only overall bat/bowl); negotiation never beats the asking price; scouting reveals little; ticket price has one right answer; no yearly development report; facilities don't show their numbers |
| **Dan** | Designer, landscape on a TV | Home, Money, the Transfers player list | 13 sub-screens used a different list style; pinned bars ate 170 of 420 pt in landscape; single narrow column; primary actions below the fold (auction Bid, profile Buy); duplicate links on Club; emoji and text glyphs |

## Fixed in this pass (look and layout)

- Landscape: tabs and CONTINUE share one row; Home is two columns.
- Batting order, bowling plan, Pick XI: summary and actions beside the list in landscape; compact
  rows; one-line help; no emoji.
- Tactics: one column per phase in landscape.
- Every list sub-screen (Training, Academy, Scouting, Facilities, Manager, Store, Settings,
  Retentions, National squad): the same grouped style, capped width.
- Player profile: two columns in landscape; Buy / list / release directly under the header; one
  "Buy for X" button, negotiation behind a link.
- Auction room: player left, bidding right; Bid and Pass side by side; "Let my staff finish" is a
  full button; the lot shows potential and stats and opens the profile.
- Club tab: duplicate links removed. Action results shown as a readable card.
- Pick XI says "XI is full: drop a player first". Setup button says what to do.
- Emoji and arrow glyphs removed from career screens.

## Backlog from the panel

**Layout (L4)**
- Fixtures, results, offers: hairline rows instead of one card each.
- Off-season, season-end and window cards: restyle to the Home hero.
- First-session checklist on Home (check XI, run training, play).
- Training: collapse drills and focus under "Advanced".
- Setup: pin Start as a bottom bar.

**Depth (L1/L0, plan before building)**
1. Development report: per-player yearly and training changes, split by cause.
2. Make attributes matter in matches (death, new ball, vs pace/spin, fielding), or cut the drills.
3. Real negotiation: a hidden reservation price, reasons given, counter-offers when selling.
4. Money: projected wages, upkeep and year-end bank; fix or remove ticket price.
5. Auction: sales log, purse reserve shown.
6. Facilities: show "now → next" numbers; Analytics scaling; academy age-out.
7. Missing from the GDD: morale, fatigue, injuries, contract renewals.
