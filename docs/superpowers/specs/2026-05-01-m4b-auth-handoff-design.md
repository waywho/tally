# M4b: Auth Handoff — Design

**Date:** 2026-05-01
**Status:** Approved
**Scope:** Ticket 26 (auth for iOS shell)

## Goal

Persist the user's login session across app restarts and provide a native login
screen for the iOS shell. Use cookie-based auth (not JWT) — capture session
cookies from Rodauth, store in the iOS Keychain, and restore them on launch.

This is the second of three M4 sub-projects:
- **M4a:** Shell + Tab Bar + Path Config — Done
- **M4b** (this spec): Auth Handoff
- **M4c:** Barcode Scanner + Polish + TestFlight (tickets 27–29)

## Non-goals

- JWT tokens or API token model — cookies are sufficient for webview-based auth.
- Native account creation, password reset, or email verification — these use the
  existing web pages via webview fallback.
- Biometric auth (Face ID / Touch ID) — deferred to post-MVP.
- Token refresh — Rodauth's `remember` feature handles session extension via
  the remember-me cookie.

## Architecture

**Approach:** Session cookie persistence via iOS Keychain. No backend auth
changes beyond a small Rodauth hook for JSON login responses.

**Why not JWT:** The app is webview-based. Cookies already work for all webview
requests. JWT would require a separate auth configuration in Rodauth, cookie
injection from tokens, and refresh logic — all complexity with no benefit for
the current architecture. If native API calls are needed later (e.g., barcode
scanner in M4c), the session cookie can be attached to `URLSession` requests.

## Auth Flow

### First launch (not logged in)

1. `SceneDelegate` checks Keychain for saved session cookies → none found.
2. Shows `LoginViewController` as the root view controller.
3. User enters email + password, taps Login.
4. iOS POSTs to `/login` with form-encoded body and `Turbo Native` user-agent.
5. Rodauth authenticates and returns JSON `{ "success": true }` with session
   cookies in the `Set-Cookie` headers.
6. iOS captures cookies from the `URLSession` response, stores in Keychain
   via `SessionStore`.
7. iOS injects cookies into `WKWebsiteDataStore.default().httpCookieStore`.
8. `SceneDelegate` swaps root to `TabBarController`.

### Subsequent launches (logged in)

1. `SceneDelegate` checks Keychain → finds saved cookies.
2. Injects cookies into `WKHTTPCookieStore` before any Navigator starts.
3. Shows `TabBarController` directly — no login screen.

### Logout

1. User taps logout in the web Settings page (Rodauth handles session destroy).
2. Rodauth redirects webview to `/login`.
3. `TallyNavigator` detects navigation to `/login` post-authentication.
4. Posts `Notification.Name("tallyDidLogout")`.
5. `SceneDelegate` observes the notification, calls `SessionStore.clear()`,
   swaps root to `LoginViewController`.

### Session expiry

Same as logout — if the server-side session expires and Rodauth redirects to
`/login`, the logout detection triggers and the user is shown the login screen.

## iOS Components

### LoginViewController

A UIKit view controller presented as root when no session is saved.

**UI elements:**
- Tally logo/title at top (green, matching the app brand)
- Email text field (`UITextField`, keyboard type: `.emailAddress`)
- Password text field (`UITextField`, `isSecureTextEntry: true`)
- Login button (green background, white text, full width)
- "Create account" link → opens `/create-account` in a modal webview
- "Forgot password?" link → opens `/reset-password-request` in a modal webview
- Error label (hidden by default, shown on failure: "Invalid email or password")

**Login action:**
- Constructs `URLRequest` to `Endpoints.baseURL/login`
- Method: POST, Content-Type: `application/x-www-form-urlencoded`
- Body: `email={email}&password={password}`
- User-Agent header includes `Turbo Native`
- On 200 response: extract cookies from `HTTPURLResponse`, save via
  `SessionStore`, inject into webview cookie store, transition to tab bar.
- On non-200: show error label.

**Web fallback links:**
- "Create account" and "Forgot password?" present a `SFSafariViewController`
  or a minimal webview that loads the Rodauth page. These are one-time flows
  that don't need native UI.

### SessionStore

An enum (no instances) with static methods for Keychain operations.

```swift
enum SessionStore {
    static func save(cookies: [HTTPCookie])
    static func loadCookies() -> [HTTPCookie]?
    static func clear()
}
```

**Keychain details:**
- Service: `"com.placeholder.tally"`
- Account/key: `"session.cookies"`
- Accessibility: `.afterFirstUnlock` (available after device is unlocked once
  after boot — good balance of security and availability)
- Serialization: `NSKeyedArchiver` to encode `[HTTPCookie]` as `Data`

**Cookie filtering:** Only persist cookies from the app's domain that are
relevant to auth — the session cookie and the remember-me cookie. Skip
analytics, CSRF, or other transient cookies.

### SceneDelegate changes

```
func scene(_:willConnectTo:options:) {
    if let cookies = SessionStore.loadCookies() {
        inject cookies into WKWebsiteDataStore
        rootViewController = TabBarController()
    } else {
        rootViewController = LoginViewController(onLogin: { [weak self] in
            self?.transitionToTabBar()
        })
    }
}
```

The `LoginViewController` takes an `onLogin` closure that the `SceneDelegate`
uses to swap the root. This avoids tight coupling.

**Logout observer:** `SceneDelegate` observes `tallyDidLogout` notification
and calls `transitionToLogin()` which clears cookies and swaps root.

### TallyNavigator changes

After each navigation completes, check if the destination URL path is `/login`.
If so, and cookies exist in the Keychain (meaning we were authenticated), post
the logout notification.

This is a lightweight check — just a URL path comparison on the navigation
delegate callback.

## Rails-side Changes

### Rodauth after_login hook

In `app/misc/rodauth_main.rb`, add an `after_login` hook that returns JSON
when the request comes from the native app:

```ruby
after_login do
  if request.env["HTTP_USER_AGENT"].to_s.include?("Turbo Native")
    response.status = 200
    response["Content-Type"] = "application/json"
    response.write({ success: true }.to_json)
    request.halt
  end
end
```

On login failure, Rodauth re-renders the login form (status 200 with HTML).
Both success and failure return status 200, so the native client distinguishes
them by checking the `Content-Type` response header: `application/json` means
success (our hook fired), `text/html` means failure (Rodauth re-rendered the
form). The native client does NOT parse the HTML — it just checks the header.

## File Structure

**iOS — Created:**
- `ios/Tally/Tally/Auth/LoginViewController.swift` — native login screen
- `ios/Tally/Tally/Auth/SessionStore.swift` — Keychain cookie persistence

**iOS — Modified:**
- `ios/Tally/Tally/App/SceneDelegate.swift` — session check on launch,
  login/logout transitions
- `ios/Tally/Tally/Navigation/TallyNavigator.swift` — logout detection

**Rails — Modified:**
- `app/misc/rodauth_main.rb` — after_login JSON response hook

## Testing

### Rails-side

- Test that POST `/login` with `Turbo Native` user-agent returns JSON
  `{ "success": true }` on valid credentials.
- Test that POST `/login` with `Turbo Native` user-agent returns non-JSON
  on invalid credentials.

### iOS-side

- `SessionStoreTests`: save cookies, load cookies, clear cookies. Verify
  Keychain round-trip.
- Manual testing in simulator:
  1. Fresh install → login screen appears.
  2. Enter credentials → login succeeds → tab bar appears.
  3. Kill app (Cmd+Shift+H twice, swipe up) → reopen → tab bar appears
     directly (no login).
  4. Tap logout in Settings → login screen appears.
  5. Reopen app → login screen (cookies were cleared).

## Acceptance Criteria

1. Fresh app launch shows native login screen.
2. Valid login transitions to the tab bar with all tabs working.
3. Invalid login shows error message, does not transition.
4. App kill + restart skips login (session persisted in Keychain).
5. "Create account" link opens web page.
6. "Forgot password?" link opens web page.
7. Logout from Settings web page returns to native login screen.
8. Session expiry on server side returns to native login screen.

## Open Questions

None.
