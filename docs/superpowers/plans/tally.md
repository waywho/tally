# Tally — calorie tracking mobile app

## Context

A personal calorie-tracking app for the user, also to be released publicly. Wedge against MyFitnessPal: minimalist UX for people overwhelmed by MFP. Built on Ruby on Rails with a Hotwire Native iOS shell. Standalone — **deliberately not** part of the user's `Simply::*` platform, so it gets its own auth, layout, and notifications stack.

Lives at `/Users/weihsihu/Documents/src/tally/` (parallel to `simply`, not inside it).

## Decisions captured from interview

| Area | Decision |
|---|---|
| Name & path | `tally` at `/Users/weihsihu/Documents/src/tally/` |
| Platforms | iOS first (TestFlight → App Store). Android deferred to v1.1. |
| Backend | Rails 8 (latest), standalone — **no** `Simply::*` gems |
| Auth | Email/password via **Rodauth** (`rodauth-rails`). Sessions for web/Hotwire; JWT for the iOS shell (Rodauth's `jwt` feature). Leaves a clean upgrade path to passkeys / OAuth / 2FA later. |
| Frontend | Hotwire (Turbo + Stimulus) + Tailwind CSS. ViewComponent for shared UI. |
| Native shell | Hotwire Native iOS (Swift). Webview-first; native bridges only where required (barcode scan). |
| MVP features | Food log by search • barcode scan • custom foods • recipes • meal templates / quick re-log • macros + calories |
| Day view | Meal buckets (Breakfast / Lunch / Dinner / Snacks). Each food on its own line with its own calorie value. |
| Goal setup | Manual calorie + macro targets in MVP. Biometrics-based calculator (Mifflin-St Jeor) deferred to v1.1. |
| Food database | **Open Food Facts** primary (free, strong UK/EU + barcode coverage) + **USDA FoodData Central** fallback (US whole foods) + user-contributed custom foods. No paid APIs. |
| Native capabilities (MVP) | Barcode scanner (native bridge) only |
| Deferred to v1.1 | Offline logging, push notifications, HealthKit, Android shell, biometrics calculator, weight log, water tracking, streaks |

## Architecture

**Backend** — Rails 8 + Postgres + Solid Queue (built-in, no Redis needed) + Solid Cache. Hosted via Kamal 2 (Rails 8 default) on a small VPS.

**Frontend (web/PWA-capable)** — Turbo + Stimulus + Tailwind v4 + ViewComponent. Built mobile-first because the iOS shell renders the same views.

**iOS shell** — Hotwire Native iOS (Swift, Xcode project at `tally/ios/`). Native components:
- Tab bar (Today, Search, Recipes, Profile)
- Native `path-configuration.json` for routing rules
- Native barcode scanner screen (AVFoundation) → posts result back to webview via `BridgeComponent`

**Food data ingestion** — A Rails-side `Foods` table is the single search target. Two background jobs:
1. **Open Food Facts** — nightly sync of newly-added/updated products (their daily delta dump, ~hundreds of MB). Filter to common locales (EN, FR, DE, IT, ES, NL).
2. **USDA FDC** — one-time bulk import of the Foundation + SR Legacy datasets (whole foods, ~10k items).

Search is Postgres `pg_trgm` + a generated `tsvector` column. Elasticsearch is overkill here.

**Barcode lookup** — direct API call to `world.openfoodfacts.org/api/v2/product/{barcode}` (no key needed). Cache in Tally's `Foods` table on first hit.

## Ticket breakdown

Tickets are grouped by milestone. Each one is sized to be a coherent PR. `[L]` = long pole.

### M0 — Project foundation

1. **Bootstrap Rails 8 app at `~/Documents/src/tally/`** — `rails new tally --css=tailwind --database=postgresql`, commit, push to GitHub.
2. **Set up CI** — GitHub Actions: rubocop, brakeman, minitest, system tests.
3. **Add core gems** — `rodauth-rails`, `view_component`, `factory_bot_rails`, `capybara`. Testing via Minitest (Rails default) + factory_bot.
4. **Set up Kamal 2 deploy target** — single VPS, Postgres + app on same box for MVP. Deploy a "hello world" to prove the pipeline.
5. **Tailwind theme + design tokens** — colors, spacing, typography. Build a `Lookbook` page showing the base components (button, card, list-row, bucket-header, calorie-pill).

### M1 — Auth & user model

6. **Auth via Rodauth** — `bin/rails generate rodauth:install`. Enable features: `login`, `logout`, `create_account`, `verify_account` (email confirmation), `reset_password`, `change_password`, `close_account`. Tailwind-style the generated views. Set up ActionMailer for the auth emails.
7. **User profile model** — `User` has `daily_calorie_target`, `protein_g_target`, `carbs_g_target`, `fat_g_target`, `timezone`. Settings page to edit.
8. **Onboarding flow** — 3-step wizard on first sign-in: welcome → set calorie target → set macro targets (with a "skip and use defaults" option).

### M2 — Food database & search

9. **`Food` model + schema** — `name`, `brand`, `barcode`, `serving_size_g`, `serving_label`, `calories_per_serving`, `protein_g`, `carbs_g`, `fat_g`, `source` (enum: `off`, `usda`, `user`), `external_id`, `verified_at`. Index on `barcode`. tsvector column for search.
10. **`[L]` USDA FDC bulk importer** — Rake task that downloads the Foundation Foods + SR Legacy JSON dumps, normalizes to `Food`, dedupes by `(source, external_id)`. Idempotent. Run once at deploy time.
11. **`[L]` Open Food Facts daily sync** — Solid Queue recurring job. Streams the daily delta JSONL, filters to ~6 EU/EN locales, upserts. Track the last imported timestamp in a `SyncCheckpoint` table.
12. **Food search endpoint + Stimulus combobox** — debounced search, top 20 results, brand badge, calories-per-serving on the right.
13. **Custom foods (user-contributed)** — `Food` rows with `source: :user` and `created_by_user_id`. Form + visibility scoping (only the creator sees them in search, plus an opt-in "share to community" toggle that's a no-op until v2).
14. **Open Food Facts barcode lookup-on-miss** — when a scanned barcode isn't in the local `Foods` table, hit `world.openfoodfacts.org/api/v2/product/{barcode}`, persist, return.

### M3 — The logging loop (web first)

15. **Day model** — `FoodLogEntry` with `user_id`, `food_id`, `logged_on` (date), `meal` (enum: breakfast/lunch/dinner/snacks), `servings` (decimal). Computed calories/macros via delegation to `Food` × `servings`.
16. **Today view (meal buckets)** — `/today` shows date header with calories-consumed / target, then four bucket sections. Each entry on its own row showing food name + per-entry calories. Per-bucket subtotals. "+ Add" link in each bucket.
17. **Add-food flow** — bucket-aware route `/days/:date/meals/:meal/entries/new` → search combobox → serving size + servings → save. Turbo-stream the new row into the bucket without a full page reload.
18. **Edit / delete log entry** — swipe-or-tap row → edit servings or delete. Turbo stream to update bucket subtotal + day total.
19. **Date navigation** — prev/next day arrows on Today view; tap date to open a date picker. URL-driven so back/forward works.
20. **Recipes** — `Recipe` (user-owned, `name`, `servings_in_recipe`) `has_many :recipe_ingredients` (`food_id`, `quantity_g`). When logged, expands to per-serving macros. CRUD UI.
21. **Meal templates / "favorites"** — `MealTemplate` (a saved combination of foods + servings). One-tap "log this template into Lunch today". Auto-suggest converting frequently re-logged combos into a template.
22. **Quick re-log** — on the search screen, show "Recent" and "Frequent" tabs above search results, scoped to the current `meal` bucket.

### M4 — iOS Hotwire Native shell `[L]`

23. **Xcode project at `tally/ios/`** — Hotwire Native iOS template. App icon, splash, signing, bundle ID `com.weihsihu.tally`.
24. **Tab bar with native tabs** — Today, Search, Recipes, Profile. Each tab opens a `Hotwire.Navigator` rooted at the matching webview URL.
25. **`path-configuration.json`** — modal presentation rules for new/edit forms; native push for drilldowns.
26. **Auth handoff** — enable Rodauth's `jwt` feature on a `/api/auth/*` route prefix. iOS sign-in screen calls Rodauth's JSON login endpoint → receives a JWT → store in iOS Keychain → attach as `Authorization: Bearer` on every webview request via a `WKURLSchemeHandler` (or by setting the cookie equivalent on `WKWebsiteDataStore`). Rodauth handles the JWT lifecycle, refresh, and revocation on `close_account`.
27. **`[L]` Native barcode scanner bridge** — Swift `BridgeComponent` named `barcode-scanner`. Web side: a Stimulus controller that posts a `connect` message; iOS opens AVFoundation scanner; on detection, sends the barcode back. Web then navigates to the lookup result. Falls back gracefully on simulator (manual entry).
28. **Pull-to-refresh + Turbo errors** — wire native pull-to-refresh on Today; native error screen for offline / 5xx.
29. **TestFlight build pipeline** — Fastlane `match` for signing, `pilot` for upload. GitHub Action that builds on tag push.

### M5 — Polish & launch

30. **Empty states & first-run copy** — for empty Today, empty Recipes, empty search results.
31. **Accessibility pass** — Dynamic Type, VoiceOver labels on bucket headers and entry rows, color contrast ≥ AA.
32. **Privacy policy + terms + account deletion** — required for App Store. GDPR data export endpoint (JSON dump of user's foods + entries + recipes).
33. **App Store listing** — screenshots, description, category, keywords. Submit for review.
34. **Analytics (privacy-respecting)** — basic event log table for funnel analysis (`signed_up`, `onboarding_completed`, `first_food_logged`, `barcode_scanned`). No third-party SDK.
35. **Sentry / error reporting** — Rails side + iOS side.
36. **Recommended daily targets** — Pre-fill calorie and macro goals based on standard government dietary guidelines (by age/sex). Selectable during onboarding or from settings as a starting point.

## Long poles & risks

- **OFF data quality is uneven** — entries with missing macros, weird serving sizes, duplicate barcodes. Mitigations: skip rows with null calories on import; "report this entry" link in the UI; allow users to override locally.
- **OFF daily delta size** — hundreds of MB. First sync needs the full dump (~10 GB compressed). Plan for ~30 GB disk on the VPS.
- **iOS native bridge** — first time building a `BridgeComponent`. Allow a few extra days.
- **App Store review** — health/diet apps sometimes get extra scrutiny. Be conservative in marketing copy ("track calories" not "lose weight fast").
- **Auth for the iOS shell** — Hotwire Native cookie sharing across webviews is workable but easy to misconfigure. Worth a spike before ticket #26 to validate the Rodauth-JWT-in-Keychain → webview-Authorization-header path end to end.
- **Rodauth schema is its own world** — Rodauth uses dedicated tables (`accounts`, `account_password_hashes`, etc.) separate from your `User` model. Plan to add a thin `User` model that `belongs_to` an `Account` for app-level profile data (`daily_calorie_target`, etc., from ticket #7). The Rodauth-Rails generator scaffolds this — just be aware it's two models, not one.

## Verification

End-to-end happy path that should work after M3:
1. Sign up at `tally.test`, complete onboarding, set 2,000 cal target.
2. Open Today view (date = today, all buckets empty, total = 0/2,000).
3. "+ Add" under Breakfast → search "oats" → pick first result → 1 serving → save.
4. Row appears in Breakfast bucket; bucket total + day total update without full reload.
5. Add another entry under Lunch; verify per-bucket and per-day totals.
6. Edit Lunch entry servings to 2; verify totals recompute.
7. Delete Breakfast entry; verify totals recompute.
8. Create a recipe with 3 ingredients; log it under Dinner; verify it expands to one row.
9. Save a meal template from yesterday's lunch; one-tap log into today's lunch.

After M4, the same flow runs inside the iOS shell, plus:
10. From Search, tap the barcode icon → native scanner opens → scan a UK supermarket barcode → product appears in search results → log into Snacks.

## Out of scope (post-MVP, in priority order)

1. Android Hotwire Native shell (mirror of M4)
2. Offline logging — read-cache the day view + recents; queue new entries; server-authoritative on conflict
3. Biometrics-based calorie calculator (Mifflin-St Jeor)
4. Weight log + chart
5. Push notifications (meal reminders)
6. Water intake
7. Streaks / consistency stats
8. HealthKit two-way sync
9. Community-shared custom foods

## Open questions to resolve at execution time

- App Store bundle ID — `com.weihsihu.tally` is a placeholder; pick the real one before ticket #23.
- VPS provider for Kamal — Hetzner / DigitalOcean / Fly? Pick before M0 ticket #4.
- Analytics: is the homegrown event log fine, or do you want PostHog (self-hostable)?
