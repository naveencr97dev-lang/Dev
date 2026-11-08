# Recon map — Habit Tracker (clean-room clone target)

> Clean-room. We rebuild **features and flows**, with our own name, design, copy
> and assets. We do not copy the target's code, logo, icons, screenshots, copy
> or content.

## Target

- **App:** "Habit Tracker: Daily Planner & Goal Tracker"
- **Seller:** Inner Grow Limited (InnerGrow)
- **Store:** https://apps.apple.com/cz/app/habit-tracker/id1438388363
- **Platforms (original):** iOS 15+, iPadOS, macOS (M1+), visionOS, watchOS 9+
- **Category:** Productivity · Free with IAP · ~4.8★ (~2k ratings)

## Step 1 — Scope

- **Platform we build:** Web app first (responsive, mobile-first PWA). It is the
  fastest path to a working clone in a cloud session, installable on a phone,
  and the same backend later feeds native apps if wanted.
- **Slice (core loop):** *Create a habit → see today's habits → check them off →
  keep a streak → see progress stats.* This is what the app is for; everything
  else is around it.
- **Who it's for:** The user's own product to ship/sell.

## Step 2 — Sources

| source | URL | what it gave |
| --- | --- | --- |
| App Store listing | https://apps.apple.com/cz/app/habit-tracker/id1438388363 | feature list, IAP tiers, positioning, ratings |
| What's New / changelog | same listing | recent features: custom repeat intervals, health-linked habits, super reminder, shortcuts |
| Developer privacy policy | intuitive.studio/habify/privacy | data handled on-device (Health), analytics |
| Public reviews | App Store review section | pain points (see /replica-entrepreneur later): >5 habit paywall, watch bugs, stats, after-midnight logging |

No account used; no private APIs, bundles or network traffic read. Listing read once at human speed.

## Step 3 — Screen inventory

| ID | screen | route / how reached | purpose | key components | states seen |
| --- | --- | --- | --- | --- | --- |
| S01 | Onboarding / welcome | first launch | intro + sign-in choice | carousel, primary button | first-run only |
| S02 | Today (home) | `/` | today's habits, check off | date strip, habit row list, progress ring, FAB | empty, filled, all-done, loading |
| S03 | Habit create/edit | `/habit/new`, `/habit/:id/edit` | define a habit | form, icon/color picker, repeat picker, goal unit, reminder editor | new, editing, validation error |
| S04 | Habit detail | `/habit/:id` | one habit's history + stats | calendar heatmap, streak counter, note list | filled, empty history |
| S05 | Stats / reports | `/stats` | weekly/monthly/yearly progress | charts, completion %, streak leaderboard self | empty, filled, period switch |
| S06 | Mood / diary | `/journal` | log mood + note per day | mood scale, text note, day list | empty, filled |
| S07 | Focus timer | `/focus` | timed focus session w/ sounds | timer ring, sound picker, start/stop | idle, running, done |
| S08 | Groups / friends | `/groups` | shared habits with friends | group list, invite, member progress | empty, filled, invite pending |
| S09 | Settings | `/settings` | account, theme, lock, reminders | list rows, toggles, theme switch | default |
| S10 | Paywall / premium | modal from gated actions | upsell premium | plan cards, feature list, CTA | monthly / yearly / lifetime |
| S11 | Auth (sign in / up) | `/auth` | create account / log in | email+password, OAuth button | sign in, sign up, error |

## Step 4 — User flows

```
F01 Create a habit (core)
    S02 Today -> FAB -> S03 create -> pick name/icon/color/repeat/goal/reminder -> save -> S02
    happy-path clicks: ~5
    edge: no name, invalid goal, no repeat selected, duplicate name

F02 Check off today's habits (core loop)
    S02 Today -> tap habit row -> mark done (or +1 toward goal) -> progress ring updates -> streak++
    edge: undo a check, partial goal progress, habit already done, day rollover at midnight

F03 Keep / view a streak
    S02 -> S04 habit detail -> heatmap + current/longest streak
    edge: missed day breaks streak, grace/skip day

F04 See progress
    S02 -> S05 stats -> switch week/month/year -> completion % + charts
    edge: no data yet (empty), single day of data

F05 Log mood & diary
    S02 -> S06 journal -> pick mood -> write note -> save
    edge: multiple entries per day, edit past day

F06 Focus session
    S07 -> pick duration + sound -> start -> complete -> (optionally log toward a habit)

F07 Group habit with friends
    S08 -> create group -> invite by link -> members check in -> see member progress
    edge: invite not accepted, member leaves

F08 Hit a paywall
    any gated action (e.g. >N habits, advanced stats) -> S10 paywall -> choose plan -> (mock) purchase
    edge: dismiss, restore purchase

F09 Sign up / sign in
    S01/S11 -> email+password or OAuth -> S02
    edge: wrong password, email taken, offline
```

**Number to beat:** create-a-habit happy path ≈ 5 taps; daily check-off = 1 tap.

## Step 5 — Components

| component | variants | states | used on |
| --- | --- | --- | --- |
| Habit row | default, goal-progress, group | unchecked, checked, partial, overdue | S02, S08 |
| Progress ring | day, habit | 0–100%, complete | S02, S04, S07 |
| Date strip | week | past, today, future, has-data dot | S02 |
| Calendar heatmap | month | empty, graded by completion | S04, S05 |
| Icon + color picker | grid | selected | S03 |
| Repeat picker | daily/weekly/interval/custom | — | S03 |
| Reminder editor | time-based, (location later) | one or many | S03 |
| Mood scale | 5-point | selected | S06 |
| Chart | bar, line | empty, filled | S05 |
| Plan card | monthly/yearly/lifetime | selected, current | S10 |
| FAB | add | — | S02 |
| Toast | success/error | — | global |
| Bottom nav | 5 tabs | active per tab | all primary |

## Step 6 — Inferred data model

```
User       id, email, password_hash, display_name, created_at, premium_until, theme, locale
           evidence: auth flow, settings, paywall · confidence: high

Habit      id, user_id, name, icon, color, type (build|quit), repeat_rule (json),
           goal_target (int|null), goal_unit (e.g. minutes, glasses|null),
           reminders (json array), group_id (null), archived, created_at
           evidence: S03 fields, feature list (goal units, quit habits, intervals) · confidence: high

Checkin    id, habit_id, user_id, date (date), value (int, default 1),
           status (done|skipped), created_at
           evidence: F02 check-off, goal progress, "skip day" · confidence: high

Streak     derived from Checkin (current, longest) — computed, not stored (or cached)
           evidence: streak counters · confidence: medium

MoodEntry  id, user_id, date, mood (1..5), note (text), created_at
           evidence: mood tracking + habit diary · confidence: medium

FocusSession id, user_id, duration_sec, sound, completed, habit_id (null), created_at
           evidence: focus timer feature · confidence: medium

Group      id, owner_id, name, invite_code, created_at
GroupMember group_id, user_id, role, joined_at
           evidence: group habits / friendly competition · confidence: medium

Subscription id, user_id, plan (monthly|yearly|lifetime), status, provider_ref, renews_at
           evidence: IAP tiers on listing · confidence: high
```

## Step 7 — Feature matrix

Written to `replica/features.csv`. Priority = must / should / could.

## Step 8 — What we will NOT clone (skip, with reason)

| item | reason |
| --- | --- |
| Apple Health / HealthKit sync (water, steps, sleep, HRV) | platform API, needs native iOS + entitlements; web has no equivalent. Offer manual logging instead. |
| HRV stress monitor | needs Apple Watch sensors + HealthKit. Out. |
| Apple Watch app, Lock-Screen/Home-Screen widgets, Siri, Shortcuts | native iOS surfaces, not web. Revisit if we go native. |
| The app's 15M-user network & social graph | we can't clone users; we rebuild the *mechanism* (groups/invites), not their community. |
| Their icons, illustrations, wallpapers, recorded sounds, copy, brand name | owned content. We ship our own original assets. |
| Real App Store IAP billing | we build the paywall + plans; real billing = Stripe later (`/replica-backend`). |
| Built-in ADHD plan content | if their plan text is their content, we write our own templates. |

## Step 9 — Size

- **Screens:** 11 · **Flows:** 9 · **Entities:** ~9
- **Hard parts:** (1) streak logic with day-rollover/skip rules, (2) stats/charts across periods, (3) group habits (shared state + invites), plus later auth+payments.
- **Core loop alone (S02 + S03 + S04 + streaks + local persistence):** size **S** — a focused build.
- **Full web clone (all must + most should, real auth + DB + paywall):** size **M**.

## Addendum — findings from the user's own screenshots (2026-11-08)

Confirmed against the live app (user's device, their account). Functional
patterns only; no visual assets copied.

- **Reports tab** has three periods — **Weekly / Monthly / Yearly** — and is
  **premium-gated** ("Demo report, buy premium to unlock. Unlock Now").
  - Weekly: habit-rows × weekday-columns grid; per-habit **PERFECT** badge at
    100%; goal habits show e.g. `1/1`; extra rows for **BestDay** and **Mood**.
  - Monthly: one calendar card per habit, with completion % and active-day count.
  - Yearly: one year-long heatmap per habit, with % and total days.
  - Footer metrics: **Met %**, **BestDay** (count of perfect days),
    **TotalDone**, **BestStreak**.
- **Home filters:** Status (**All / Unmet / Met**) and Time
  (**Now / Anytime / Morning / Afternoon / Evening**) → habits carry a
  **time-of-day** attribute.
- **New Habit** is a **template library** with category tabs
  (**Popular / Health / Sports / Lifestyle / Time / Quit**), a favourite (heart)
  and quick-add (+) per row, and a **Custom Habit** button. Quit habits are a
  category of their own ("Smoke Less", "Eat Less Sugar", "Less Social App"…).
- **Bottom nav (5):** Home · Notes · Groups · Reports · Settings.

### Folded into the clone this round
Time-of-day field + Today filters; habit template picker by category + custom;
Reports reworked into Weekly/Monthly/Yearly with the four summary metrics and a
weekly grid. (Reports-as-premium and Groups remain later-stage.)

## Next step

`/replica-architect` — pick the stack, turn this data model into a real schema,
and order the build thin-slice-first.
