# Tally

A food and macro diary. Rails 8 server at [tally.quest](https://tally.quest), with a
Hotwire Native iOS app in `ios/` that wraps the same views.

- Ruby 3.4.7, Rails 8.1.3, PostgreSQL
- Propshaft, importmap, Tailwind v4, ViewComponent, HAML
- Rodauth for authentication, Solid Queue for jobs
- Deployed to Fly.io (app `tally-quest`) — **pushing to `main` deploys automatically**

## Getting started

```bash
bin/setup            # installs gems, prepares the database, starts the server
bin/dev              # server + Tailwind watcher (Procfile.dev)
```

`bin/setup --skip-server` prepares everything without booting.

## Tests and linting

```bash
bin/rails test                  # unit and integration tests
bin/rails test:system           # system tests
bin/rubocop                     # style
bin/brakeman                    # static security analysis of the Rails code
bin/bundler-audit check         # known CVEs in the gem lockfile
bin/importmap audit             # known CVEs in the pinned JavaScript
bin/ci                          # the full suite GitHub Actions runs (config/ci.rb)
```

`bin/ci` covers everything above plus a seed replant, but not the system tests —
run those yourself before anything that touches a form or a Stimulus controller.

`bin/bundler-audit` reads a local copy of the advisory database that goes stale
quietly — run `bin/bundler-audit update` first, or it will pass on gems that
have since been flagged.

## iOS

The Xcode project is `ios/Tally/Tally.xcodeproj`. Signing lives in
`ios/Tally/Signing.xcconfig`, which is gitignored — copy
`Signing.xcconfig.example` and fill in your Apple Developer team ID before the
first build.

Debug builds point at `http://localhost:3000`, Release builds at
`https://tally.quest` (`ios/Tally/Tally/Config/Endpoints.swift`).

### `bin/archive-ios`

Archives the app for submission into `build/Tally-<n>.xcarchive`.

```bash
bin/archive-ios
```

The build number comes from the commit count (`git rev-list --count HEAD`), so
it always increases and is reproducible from a checkout — App Store Connect
rejects a build number it has already seen. The script refuses to run on a dirty
working tree, so the number always matches a real commit. The user-visible
version (`MARKETING_VERSION`, currently 1.0) is bumped by hand in Xcode.

### `bin/upload-ios`

Exports an existing archive and uploads it to App Store Connect.

```bash
bin/upload-ios          # uses the current commit count
bin/upload-ios 286      # a specific archive
```

Credentials come from the Apple ID signed into Xcode (Settings → Accounts), so
no API key is stored in the repo. The build shows up under TestFlight after
Apple finishes processing it, usually within 15 minutes.

### `bin/screenshots-ios`

Captures App Store screenshots from the simulator at the two sizes Apple
requires — 6.9" iPhone (1320×2868) and 13" iPad (2064×2752).

```bash
bin/rails demo:seed        # populate the demo account first
bin/dev                    # Debug builds read localhost, so the server must be up
bin/screenshots-ios        # both sizes
bin/screenshots-ios iphone # one size
```

Output goes to `tmp/screenshots` (override with `OUT_ROOT`).

Log in to the app by hand once per simulator before running it — the script only
navigates and captures, it never types. Taps go through System Events because
`simctl` has no input API; tab coordinates are fractions of the device screen
and differ per device, because iPadOS renders the tab bar as a pill at the *top*
while iPhone keeps it at the bottom.

### `bin/rails demo:seed`

Fills the demo account (`demo@tally.quest`, override with `DEMO_EMAIL`) with a
plausible day of entries, some saved foods, recipes and a meal template — enough
for screenshots and for App Review to have something to look at. Development
only, and the account has to exist already: sign up through the UI, then run it.

## Deployment

Merging to `main` triggers the GitHub Actions deploy to Fly.io once CI passes.
Do not run `flyctl deploy` by hand.

`bin/fly-setup` creates the Fly app and Postgres cluster and attaches them. It
is idempotent, and only needed when standing up a new environment — it prints the
remaining secrets for you to set by hand rather than setting them itself.
