# Streaklet (iOS)

An original SwiftUI habit tracker — build routines, keep streaks, track mood.
Built clean-room: original code, design, name and icon. No third-party
dependencies.

## What's inside

- `project.yml` — [XcodeGen](https://github.com/yonaskolb/XcodeGen) spec (the
  `.xcodeproj` is generated, not committed).
- `Sources/` — the app (SwiftUI). Models, views, components, theme.
- `Resources/Assets.xcassets` — app icon + accent color.
- `../.github/workflows/ios.yml` — CI that builds an **unsigned IPA**.

## Features

Create build/quit habits · measurable goals (e.g. 8 glasses) · daily or
per-weekday schedule · one-tap check-off · current/longest streaks · month
heatmap · weekly stats · mood journal · daily reminders · light/dark theme ·
local persistence.

---

## Getting an installable IPA

You don't need a Mac. There are two routes.

### Route A — GitHub Actions (no Mac) → Signulous

1. Push this repo to GitHub (done on your branch).
2. Open the repo's **Actions** tab → the **"Build unsigned IPA"** workflow.
   It runs automatically on every push under `ios/`, or click
   **Run workflow** to trigger it.
3. When it finishes, download the **`Streaklet-unsigned-ipa`** artifact and
   unzip it to get `Streaklet-unsigned.ipa`.
4. In **Signulous**, upload `Streaklet-unsigned.ipa`, sign it with your
   certificate, and install it over the air.

> The bundle id is `com.streaklet.app` (set in `project.yml`). Change it there
> if Signulous needs a bundle id tied to your account, then re-run the build.

### Route B — on your own Mac

```bash
brew install xcodegen
cd ios
xcodegen generate
open Streaklet.xcodeproj
```

Then either archive in Xcode (**Product ▸ Archive**) and export, or build an
unsigned IPA from the command line:

```bash
xcodebuild -project Streaklet.xcodeproj -scheme Streaklet \
  -configuration Release -destination 'generic/platform=iOS' \
  -archivePath build/Streaklet.xcarchive archive \
  CODE_SIGNING_ALLOWED=NO
cd build
mkdir Payload && cp -R Streaklet.xcarchive/Products/Applications/Streaklet.app Payload/
zip -qry Streaklet-unsigned.ipa Payload
```

Upload `Streaklet-unsigned.ipa` to Signulous.

## Requirements

- iOS 16.0+
- Xcode 15.x (CI uses Xcode 15.4 on macOS 14)
