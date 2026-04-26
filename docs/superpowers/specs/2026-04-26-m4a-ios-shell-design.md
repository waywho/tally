# M4a: iOS Hotwire Native Shell — Design

**Date:** 2026-04-26
**Status:** Approved
**Scope:** Tickets 23–25 (Xcode project, tab bar, path configuration)

## Goal

Ship a native iOS shell for Tally using Hotwire Native. The shell provides a
native tab bar with four tabs, a floating add button, and path-configuration-driven
navigation (push vs. modal). The Rails views render inside webviews — no native
UI beyond the tab bar, add button, and navigation chrome.

This is the first of three M4 sub-projects:
- **M4a** (this spec): Shell + Tab Bar + Path Config (tickets 23–25)
- **M4b:** Auth Handoff / JWT (ticket 26)
- **M4c:** Barcode Scanner + Polish + TestFlight (tickets 27–29)

## Non-goals

- Authentication / JWT (M4b)
- Barcode scanner bridge (M4c)
- Pull-to-refresh, native error screens (M4c)
- TestFlight / CI pipeline (M4c)
- iPad support
- Android

## Architecture

**Pattern:** UIKit + UITabBarController. Each tab owns a Hotwire `Navigator`
with its own navigation stack and webview session. This is the standard Hotwire
Native pattern used in the official demo app and 37signals' production apps.

**Why UIKit over SwiftUI:** Hotwire Native iOS is a UIKit library. Wrapping it
in SwiftUI via `UIViewControllerRepresentable` adds a bridging layer with more
debugging surface. Since this is a first Swift project, sticking with UIKit
aligns with the most community examples and documentation.

**Dependencies:** `hotwire-native-ios` via Swift Package Manager (SPM).

## Project structure

```
ios/
  Tally/
    Tally.xcodeproj/
    Tally/
      App/
        AppDelegate.swift            -- UIKit entry point
        SceneDelegate.swift          -- window setup, creates TabBarController
      Navigation/
        TabBarController.swift       -- UITabBarController + 4 tabs + floating "+"
        TallyNavigator.swift         -- thin wrapper configuring a Hotwire Navigator
      Config/
        Endpoints.swift              -- base URL (localhost for DEBUG, prod for RELEASE)
        path-configuration.json      -- bundled routing rules
      Helpers/
        MealInferrer.swift           -- time-of-day → meal name
      Assets.xcassets/               -- app icon, accent color
      Info.plist                     -- ATS exception for localhost
    TallyTests/
```

**Xcode project settings:**
- Deployment target: iOS 16.0
- Device: iPhone only
- Interface: Storyboard (but we delete Main.storyboard and set up the window in SceneDelegate)
- Language: Swift
- Bundle ID: `com.placeholder.tally` (update when developer account is set up)
- Team: None (personal team / simulator only for now)

## Tab bar

Four tabs, each with its own Hotwire Navigator:

| Tab | SF Symbol | URL | Purpose |
|-----|-----------|-----|---------|
| Today | `house` / `house.fill` | `/today` | Day view with meal buckets |
| Search | `magnifyingglass` | `/foods` | Food search |
| Recipes | `book` / `book.fill` | `/recipes` | Recipe list |
| Settings | `gearshape` / `gearshape.fill` | `/settings/edit` | Profile & preferences |

Each tab uses the filled variant of its icon when active.

**Tab behavior:**
- Tapping an already-selected tab pops to root (standard iOS convention).
- Each tab's Navigator maintains its own back stack independently.
- Switching tabs preserves each tab's state (scroll position, navigation depth).

## Floating add button

A green circular `UIButton` (44×44pt) centered horizontally, positioned above
the tab bar. Uses the SF Symbol `plus` in white on a green (#22c55e) background.

**Tap behavior:**
1. Determine the current meal using `MealInferrer` (see below).
2. Format today's date as `YYYY-MM-DD`.
3. Navigate the **Search tab's** Navigator to `/foods?meal={meal}&date={date}`.
4. Switch the tab bar's selected index to the Search tab (index 1).

## MealInferrer (Swift)

Mirrors the Ruby `MealInferrer` logic. Uses minute-of-day (hour × 60 + min)
in the user's local timezone:

| Time range | Meal |
|------------|------|
| 4:00–10:29 | breakfast |
| 10:30–14:29 | lunch |
| 14:30–17:29 | snacks |
| 17:30–21:29 | dinner |
| 21:30–3:59 | snacks (default) |

Returns a lowercase string (e.g., `"breakfast"`). The ranges and default
match `app/services/meal_inferrer.rb` exactly.

## Path configuration

Bundled as a local JSON file in the app, and also fetched from the server at
`/api/v1/path-configuration.json`. The app loads the bundled version on launch,
then fetches the server version in the background. Server version takes
precedence when available, allowing routing rule updates without an app release.

### Routing rules

```json
{
  "settings": {
    "tabs": [
      { "title": "Today", "url": "/today", "icon": "house" },
      { "title": "Search", "url": "/foods", "icon": "magnifyingglass" },
      { "title": "Recipes", "url": "/recipes", "icon": "book" },
      { "title": "Settings", "url": "/settings/edit", "icon": "gearshape" }
    ]
  },
  "rules": [
    {
      "patterns": ["/new$", "/edit$"],
      "properties": {
        "presentation": "modal"
      }
    },
    {
      "patterns": [".*"],
      "properties": {
        "presentation": "default"
      }
    }
  ]
}
```

**Rule logic:**
- URLs ending in `/new` or `/edit` → present as a native modal (slide-up sheet)
- Everything else → default push navigation

Note: `/meal_picker` is NOT listed as a path config rule. It loads via Turbo
Frame inside the webview's existing `ModalComponent` — the Hotwire Native layer
never sees it as a navigation event because it's a frame-scoped fetch, not a
full-page visit.

Rules are evaluated top-to-bottom; first match wins. The catch-all `.*` at the
bottom ensures everything gets a default presentation.

### Rails endpoint

A simple controller serves the path configuration:

```ruby
# app/controllers/api/v1/path_configurations_controller.rb
class Api::V1::PathConfigurationsController < ApplicationController
  skip_before_action :require_authentication

  def show
    render json: Rails.root.join("config/path-configuration.json").read,
           content_type: "application/json"
  end
end
```

Route: `GET /api/v1/path-configuration.json`

The JSON lives in `config/path-configuration.json` in the Rails app (single
source of truth). The iOS app also bundles a copy for offline/instant startup.

## Web-side changes

### Hide the bottom nav for native

Detect the Hotwire Native user-agent in `ApplicationController`:

```ruby
helper_method :native_app?

def native_app?
  request.user_agent.to_s.include?("Turbo Native")
end
```

Update `application.html.haml`:

```haml
%body.bg-bg-page.text-text.font-sans.antialiased{ data: { controller: "modal" },
  class: native_app? ? "native-app" : nil }
  %main.max-w-lg.mx-auto.px-4.pt-6.relative{ class: native_app? ? "pb-4" : "pb-24" }
    = render FlashComponent.new(notice:, alert:)
    = yield
  - unless native_app?
    = render BottomNavComponent.new(current_path: request.path, viewed_date: @date)
  = render ModalComponent.new
```

Changes:
- `BottomNavComponent` is not rendered when inside the native shell.
- `<main>` padding-bottom reduced from `pb-24` to `pb-4` (native tab bar handles
  the safe area).
- A `native-app` body class is added for any CSS adjustments needed.

### Route for path configuration

```ruby
# config/routes.rb
namespace :api do
  namespace :v1 do
    resource :path_configuration, only: :show
  end
end
```

## Development setup

**Base URL:**

```swift
enum Endpoints {
    #if DEBUG
    static let baseURL = URL(string: "http://localhost:3000")!
    #else
    static let baseURL = URL(string: "https://tally.example.com")!
    #endif
}
```

Production URL is a placeholder until hosting is configured.

**App Transport Security:** `Info.plist` includes an ATS exception allowing
`localhost` HTTP connections in development:

```xml
<key>NSAppTransportSecurity</key>
<dict>
  <key>NSAllowsLocalNetworking</key>
  <true/>
</dict>
```

`NSAllowsLocalNetworking` permits HTTP to localhost and link-local addresses
without opening up all domains. This is the recommended approach for Hotwire
Native development.

**Running locally:**
1. Start Rails: `bin/dev`
2. Open Xcode: `open ios/Tally/Tally.xcodeproj`
3. Select an iPhone simulator (e.g., iPhone 16)
4. Build and run (Cmd+R)

## Testing

### Rails-side tests

- `Api::V1::PathConfigurationsControllerTest`: GET returns 200 with valid JSON.
- `ApplicationController` test: `native_app?` returns true/false based on
  user-agent.
- Integration test: bottom nav is not rendered when `Turbo Native` user-agent
  is sent.

### iOS-side

- `MealInferrerTests`: verify hour-to-meal mapping for all boundary cases.
- Manual Xcode testing: build and run in simulator, verify tabs load correct
  URLs, verify "+" button navigates correctly, verify modal presentation for
  new/edit routes.

No automated UI tests for MVP — manual verification in the simulator.

## Acceptance criteria

1. App launches in the simulator showing the Today tab with `/today` loaded.
2. All four tabs load their respective URLs in independent webviews.
3. The web bottom nav is NOT visible inside the native shell.
4. Tapping "+" opens the Search tab at `/foods?meal={inferred}&date={today}`.
5. Navigating to a `/new` or `/edit` URL presents as a modal sheet.
6. Back navigation works within each tab.
7. Tapping an already-selected tab pops to root.
8. The path configuration endpoint returns valid JSON at `/api/v1/path-configuration.json`.

## Open questions

- **Production URL:** placeholder until hosting (M0 ticket #4) is resolved.
- **App icon:** no custom icon for now; use Xcode's default placeholder. Design
  the icon as part of M5 polish.
