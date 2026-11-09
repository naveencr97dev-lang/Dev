# Auction XI: mobile design direction (v3, "clean native")

These rules decide the look; every screen follows them. They were derived with the
[taste-mobile-app-skill](https://github.com/orbitextechlab/taste-mobile-app-skill) "generated-UI
tells" checklist and Apple's Human Interface Guidelines. Implementation: `ios/Sources/Theme/Theme.swift`
(tokens, shared components) and `ios/Sources/Views/Career/CareerTheme.swift` (career pieces).

## Direction

The app is a manager's tool you check between matches. It should read like a well-made native iOS
app: calm, dense where data matters, fast to scan. The cricket is the content (scores, players,
tables), not the decoration.

## Tokens

| Token | Value | Use |
|---|---|---|
| Background | `#000000` | Every screen |
| Surface | `#1C1C1E` | Grouped sections, cards, list rows |
| Surface high | `#2C2C2E` | Secondary buttons, controls |
| Separator | `#38383A`, 0.5 pt | Between rows (`Hairline`) |
| Text | white / `#8E8E93` | Primary / secondary (labels lighter than values) |
| Accent | `#30D158` (iOS green: the outfield) | Primary action, selected tab, positive money |
| Danger / wicket | `#FF453A` | Wickets, losses, destructive actions, real-state badges |
| Info | `#0A84FF` fours, `#BF5AF2` sixes | Match data only |

- **One accent.** Club colours appear only in crests and charts.
- **Type:** SF Pro, upright. Six sizes: 12, 14, 16, 20, 28, 34. Hero numbers can be larger, one
  per screen. Hierarchy comes from weight and colour; `Font.display` and `Font.score` snap to this
  scale, and numbers use tabular digits.
- **Radius:** 12 for surfaces and buttons, about 24% of the size for crests.
- **Spacing:** 4 / 8 / 12 / 16 / 24. Inside a group is tighter than between groups, which is
  tighter than between sections.

## Components

| Component | What it is |
|---|---|
| `AppCard` | Flat surface, no border, gradient or shadow. A coloured edge bar reads as generated, so none is drawn. |
| `SectionLabel` | Small uppercase secondary label above a group, iOS style. |
| `PrimaryButtonStyle` / `SecondaryButtonStyle` | Filled accent with black text / tinted surface with accent text. Sentence case. Pressed state is opacity. |
| `DashTile` | A navigation row: naked SF Symbol, title, detail, optional red count, chevron. Rows sit in one surface separated by hairlines. |
| `HubTabBar` | Native-style bottom bar: hairline on top, SF Symbols, accent for the selected tab. |
| `CareerTopBar` | Large title (club), secondary line (manager and date), then money, gold and level as small values. |

## Banned (AI tells)

- Emoji as icons. Use SF Symbols; domain glyphs such as pitch and trait icons are allowed as content.
- Decorative gradients, glows, bevels, 3D buttons, glass on content.
- Card stacks used as decoration, and tinted icon chips on every row.
- More than six text sizes; black weights everywhere.
- A second accent colour, or acid-on-black.

## Not yet converted (backlog)

- Quick Auction screens use the new tokens but keep some older layouts (auction ticket and
  broadcast score bug).
- Pitch and trait emoji still appear as content glyphs.
