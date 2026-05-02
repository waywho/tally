# M4c-2: Polish (Pull-to-Refresh + Error Handling) — Design

**Date:** 2026-05-02
**Status:** Approved
**Scope:** Ticket 28

## Goal

Enable pull-to-refresh on all pages and show a branded error screen when
the server is unreachable or returns an error. Both features use Hotwire
Native's built-in mechanisms — minimal custom code.

## Non-goals

- Custom loading indicators or skeleton screens
- Offline caching or queuing
- Different error messages per error type

## Pull-to-Refresh

Hotwire Native's `VisitableView` includes pull-to-refresh by default. It
works on all pages automatically. We disable it on modal presentations
(new/edit forms) via a path configuration rule to prevent conflicts with
the swipe-to-dismiss gesture and accidental form data loss.

Path configuration addition:

```json
{
  "patterns": ["/new$", "/edit$"],
  "properties": {
    "presentation": "modal",
    "pull_to_refresh_enabled": false
  }
}
```

This merges with the existing modal rule (same patterns, same properties
block — just add the new key).

## Error Screen

Configure `Hotwire.config.makeCustomErrorView` in `AppDelegate` to return
a custom `ErrorView`. The view displays:

- Tally logo/title (green, centered)
- "Something went wrong" message
- "Try Again" button (green, full width) that calls the retry handler

The same view is shown for all error types (network offline, DNS failure,
server 5xx, timeout). No error code or technical details shown to the user.

## File Structure

**iOS — Created:**
- `ios/Tally/Tally/Views/ErrorView.swift` — custom error UIView

**iOS — Modified:**
- `ios/Tally/Tally/App/AppDelegate.swift` — set `makeCustomErrorView`

**Rails — Modified:**
- `config/path-configuration.json` — add `pull_to_refresh_enabled: false` to modal rule
- `ios/Tally/Tally/Config/path-configuration.json` — keep bundled copy in sync

## Testing

Manual only:
1. Pull down on the Today view — page refreshes.
2. Pull down on a modal form — nothing happens (disabled).
3. Stop the Rails server, pull to refresh — error screen appears with
   "Try Again" button.
4. Restart the server, tap "Try Again" — page loads.

## Acceptance Criteria

1. Pull-to-refresh works on all non-modal pages.
2. Pull-to-refresh is disabled on modal pages (new/edit forms).
3. Error screen shows "Something went wrong" with a branded "Try Again" button.
4. Tapping "Try Again" retries the failed request.

## Open Questions

None.
