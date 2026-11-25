# Score Book

A personal, spoiler-light GTA 6 companion for iPhone: a money guide and a clean robbery guide for
every robbable store type. Unofficial; not affiliated with Rockstar Games.

- **Rob:** each target type (convenience, gas, liquor, grocery, payday loans, pawn, jewelry, safes,
  towable ATMs, banks) with when it unlocks, the take, the heat, a tap-to-tick step checklist, and
  what to watch out for.
- **Money:** every money method with its unlock and pay.
- **Rules:** escaping, keeping your cash, what to buy first, and a clean-run checklist.

Content: `Sources/Core/Guide.swift` (no plot, no characters). It's drawn from launch-week guides
(GAMES.GG, GTABase, VGC, Nov 2026); where they disagree, the app shows both. Edit that file to
correct anything you see in game.

- Tests: `cd scorebook && swift test`
- Type-check: `TYPECHECK_SRC=scorebook/Sources tools/typecheck/run.sh`
- Build: Codemagic workflow "Score Book unsigned IPA", then sign with Signulous.
- Icon: `python3 make_icon.py`
