# Bottom Navigation Design

**Date:** 2026-04-25
**Status:** Approved for implementation

## Problem

Tally currently has no global navigation chrome on the web. The only way to reach Settings is to know the URL. Recipes and the foods index are reachable only via in-context links from the day view. As a mobile-first web app, we need persistent navigation that puts the most-used destinations one tap away.

The plan (`docs/superpowers/plans/tally.md`) describes a **native** iOS tab bar in M4 (ticket #24, tabs: Today / Search / Recipes / Profile) but says nothing about web-side navigation. Web navigation is the baseline for mobile Safari, desktop, and the inside of the eventual iOS web view, so a web bottom nav is not throwaway work — it is the floor that the native tab bar will replace only when running inside the iOS shell.

## Solution

A floating, Apple-style sticky bottom navigation bar rendered once in the application layout. Five slots, with a visually elevated center action:

```
┌─────────────────────────────────────────────┐
│  Today    Search   [ + ]   Recipes  Profile │
└─────────────────────────────────────────────┘
```

| Slot     | Route                                                      | Notes                                                     |
| -------- | ---------------------------------------------------------- | --------------------------------------------------------- |
| Today    | `today_path`                                               | Active on `days#show`                                     |
| Search   | `foods_path`                                               | Active on `foods#index` when no meal param                |
| **+**    | `foods_path(meal: <inferred>, date: <viewed_or_current>)`  | Center FAB; meal inferred from local time                 |
| Recipes  | `recipes_path`                                             | Active on `recipes/*`                                     |
| Profile  | `edit_settings_path`                                       | Active on `users#edit` (renamed Profile in the UI)        |

### Meal inference

A `MealInferrer` POAH (plain old Ruby class) maps current time-of-day to a meal:

| Local time      | Meal       |
| --------------- | ---------- |
| 04:00 – 10:29   | breakfast  |
| 10:30 – 14:29   | lunch      |
| 14:30 – 17:29   | snack      |
| 17:30 – 21:29   | dinner     |
| 21:30 – 03:59   | snack      |

Time zone follows `Time.current` (Rails app TZ). User TZ override is out of scope for v1.

### Date for the + button

If the current page exposes a viewed date (the `days#show` page sets `@date`), the `+` button uses that date so late-night logging from "yesterday's" view goes to yesterday. Otherwise the button uses `Date.current`.

We expose this through a layout helper or an `@date`-aware `content_for(:bottom_nav_date)` so the component does not have to know about controller state directly.

### Visual design

- Pill-shaped container, fixed to the bottom of the viewport, centered.
- Backdrop blur (`backdrop-blur-md`) + semi-transparent background (`bg-bg-page/80`) so content scrolls underneath.
- Subtle border and shadow.
- Safe-area aware: bottom inset uses `env(safe-area-inset-bottom)` (Tailwind: `pb-[env(safe-area-inset-bottom)]` on a wrapping `div`).
- Center `+` button is larger (e.g. `w-14 h-14`), elevated (`-translate-y-3`), uses `bg-primary` with white icon, has its own shadow.
- Other tabs: 24×24 icon + label, `text-text-secondary` inactive, `text-primary` active.
- Active state: filled icon variant + `aria-current="page"`.

### Hiding inside Hotwire Native

When the iOS shell ships, it will set a `data-hotwire-native` attribute on `<body>` (or pass a header). The component reads that flag and renders nothing. For now this is a forward-compatibility stub — the attribute does not yet exist, so the nav always renders on web.

### Page padding

Pages need bottom padding so the floating nav does not cover content. Add `pb-24` to the `<main>` element in `application.html.haml` (the current padding is `py-6`, which we keep on top via `pt-6`).

## Out of scope (v1)

- Long-press / explicit meal selector on the `+` button. Users can change meal on the entry edit page.
- A separate "Add recipe" entry. New recipes are reached from the Recipes tab.
- Tab badges (e.g. "you're behind on calories today").
- User-configurable nav order or labels.
- Hiding the nav on scroll. Apps that do this often regret it; we keep it pinned.

## File structure

| Action  | File                                                                                | Responsibility                          |
| ------- | ----------------------------------------------------------------------------------- | --------------------------------------- |
| Create  | `app/services/meal_inferrer.rb`                                                     | Time-of-day → meal symbol               |
| Create  | `test/services/meal_inferrer_test.rb`                                               | Service tests                           |
| Create  | `app/components/bottom_nav_component/bottom_nav_component.rb`                       | Component class                         |
| Create  | `app/components/bottom_nav_component/bottom_nav_component.html.haml`                | Component template                      |
| Create  | `test/components/bottom_nav_component_test.rb`                                      | Component tests                         |
| Modify  | `app/views/layouts/application.html.haml`                                           | Render component, add bottom padding    |
| Modify  | `app/views/days/show.html.haml`                                                     | Remove gear icon (replaced by Profile)  |
