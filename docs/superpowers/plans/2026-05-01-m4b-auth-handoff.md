# M4b: Auth Handoff — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Persist login sessions across app restarts via iOS Keychain, add a native login screen, and detect logout from the web Settings page.

**Architecture:** Session cookies captured after login, serialized to Keychain. On launch, cookies restored into WKWebView before loading pages. Native login screen POSTs to Rodauth's existing `/login` endpoint. Rodauth returns JSON for native clients via an `after_login` hook. Logout detected by monitoring webview navigation to `/login`.

**Tech Stack:** Swift (UIKit), iOS Keychain, Rodauth, Rails, Minitest.

**Spec:** `docs/superpowers/specs/2026-05-01-m4b-auth-handoff-design.md`

---

## File Structure

**iOS — Created:**
- `ios/Tally/Tally/Auth/SessionStore.swift` — Keychain cookie persistence (save/load/clear)
- `ios/Tally/Tally/Auth/LoginViewController.swift` — native login screen

**iOS — Modified:**
- `ios/Tally/Tally/App/SceneDelegate.swift` — session check on launch, login/logout transitions
- `ios/Tally/Tally/Navigation/TallyNavigator.swift` — logout detection via URL monitoring

**Rails — Modified:**
- `app/misc/rodauth_main.rb` — JSON response for native login
- `test/integration/native_login_test.rb` — test for the Rodauth hook

---

## Task 1: Add Rodauth JSON login response for native clients

**Files:**
- Modify: `app/misc/rodauth_main.rb`
- Create: `test/integration/native_login_test.rb`

- [ ] **Step 1: Write the failing test**

Create `test/integration/native_login_test.rb`:

```ruby
require "test_helper"

class NativeLoginTest < ActionDispatch::IntegrationTest
  setup do
    @account = create(:account)
    @user = create(:user, account: @account)
  end

  test "native login with valid credentials returns JSON" do
    post "/login",
      params: { email: @account.email, password: "password" },
      headers: { "HTTP_USER_AGENT" => "Tally/1.0 Turbo Native iOS" }

    assert_equal "application/json", response.media_type
    json = JSON.parse(response.body)
    assert json["success"]
  end

  test "native login with invalid credentials returns HTML" do
    post "/login",
      params: { email: @account.email, password: "wrong" },
      headers: { "HTTP_USER_AGENT" => "Tally/1.0 Turbo Native iOS" }

    assert_equal "text/html", response.media_type
  end

  test "web login with valid credentials does not return JSON" do
    post "/login",
      params: { email: @account.email, password: "password" }

    # Web login redirects (302), not JSON
    assert_response :redirect
  end
end
```

- [ ] **Step 2: Run the test, confirm it fails**

```bash
bin/rails test test/integration/native_login_test.rb
```

Expected: first test fails — native login returns a redirect (302) instead of JSON.

- [ ] **Step 3: Add the JSON response hook to Rodauth**

Edit `app/misc/rodauth_main.rb`. Find the existing `after_login` block (line 120):

```ruby
    after_login { remember_login }
```

Replace it with:

```ruby
    after_login do
      remember_login

      if request.env["HTTP_USER_AGENT"].to_s.include?("Turbo Native")
        response.status = 200
        response["Content-Type"] = "application/json"
        response.write({ success: true }.to_json)
        request.halt
      end
    end
```

- [ ] **Step 4: Run the test, confirm it passes**

```bash
bin/rails test test/integration/native_login_test.rb
```

Expected: 3 runs, 0 failures.

- [ ] **Step 5: Run the full test suite**

```bash
bin/rails test
```

Expected: no new failures.

- [ ] **Step 6: Commit**

```bash
git add app/misc/rodauth_main.rb test/integration/native_login_test.rb
git commit -m "Return JSON on native login via Rodauth after_login hook"
```

---

## Task 2: Create SessionStore for Keychain persistence

**Files:**
- Create: `ios/Tally/Tally/Auth/SessionStore.swift`

- [ ] **Step 1: Create the SessionStore**

Create `ios/Tally/Tally/Auth/SessionStore.swift`:

```swift
import Foundation
import Security

/// Persists session cookies in the iOS Keychain so login survives app restarts.
enum SessionStore {

    private static let service = "com.placeholder.tally"
    private static let account = "session.cookies"

    /// Save an array of HTTPCookie to the Keychain.
    static func save(cookies: [HTTPCookie]) {
        let properties = cookies.compactMap { $0.properties }
        guard let data = try? NSKeyedArchiver.archivedData(
            withRootObject: properties,
            requiringSecureCoding: false
        ) else { return }

        // Delete any existing entry first
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]
        SecItemAdd(addQuery as CFDictionary, nil)
    }

    /// Load previously saved cookies from the Keychain.
    static func loadCookies() -> [HTTPCookie]? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }

        guard let properties = try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data)
                as? [[HTTPCookiePropertyKey: Any]] else { return nil }

        let cookies = properties.compactMap { HTTPCookie(properties: $0) }
        return cookies.isEmpty ? nil : cookies
    }

    /// Delete saved cookies from the Keychain.
    static func clear() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
```

- [ ] **Step 2: Verify the project builds**

Cmd+B in Xcode. Expected: Build Succeeded.

- [ ] **Step 3: Commit**

```bash
git add ios/Tally/Tally/Auth/SessionStore.swift
git commit -m "Add SessionStore for Keychain cookie persistence"
```

---

## Task 3: Create LoginViewController

**Files:**
- Create: `ios/Tally/Tally/Auth/LoginViewController.swift`

- [ ] **Step 1: Create the LoginViewController**

Create `ios/Tally/Tally/Auth/LoginViewController.swift`:

```swift
import UIKit
import WebKit

/// Native login screen. POSTs credentials to Rodauth's /login endpoint.
/// On success, captures session cookies, stores in Keychain, and calls onLogin.
final class LoginViewController: UIViewController {

    private let onLogin: () -> Void

    private let logoLabel = UILabel()
    private let emailField = UITextField()
    private let passwordField = UITextField()
    private let loginButton = UIButton(type: .system)
    private let errorLabel = UILabel()
    private let createAccountButton = UIButton(type: .system)
    private let forgotPasswordButton = UIButton(type: .system)
    private let stackView = UIStackView()

    init(onLogin: @escaping () -> Void) {
        self.onLogin = onLogin
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 247/255, green: 247/255, blue: 245/255, alpha: 1) // bg-bg-page
        setupUI()
    }

    // MARK: - UI Setup

    private func setupUI() {
        // Logo
        logoLabel.text = "Tally"
        logoLabel.font = .systemFont(ofSize: 32, weight: .bold)
        logoLabel.textColor = UIColor(red: 34/255, green: 197/255, blue: 94/255, alpha: 1) // primary green
        logoLabel.textAlignment = .center

        // Email field
        emailField.placeholder = "Email"
        emailField.borderStyle = .roundedRect
        emailField.keyboardType = .emailAddress
        emailField.autocapitalizationType = .none
        emailField.autocorrectionType = .no
        emailField.returnKeyType = .next
        emailField.delegate = self

        // Password field
        passwordField.placeholder = "Password"
        passwordField.borderStyle = .roundedRect
        passwordField.isSecureTextEntry = true
        passwordField.returnKeyType = .go
        passwordField.delegate = self

        // Login button
        loginButton.setTitle("Login", for: .normal)
        loginButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        loginButton.setTitleColor(.white, for: .normal)
        loginButton.backgroundColor = UIColor(red: 34/255, green: 197/255, blue: 94/255, alpha: 1)
        loginButton.layer.cornerRadius = 10
        loginButton.heightAnchor.constraint(equalToConstant: 50).isActive = true
        loginButton.addTarget(self, action: #selector(loginTapped), for: .touchUpInside)

        // Error label
        errorLabel.text = "Invalid email or password"
        errorLabel.textColor = .systemRed
        errorLabel.font = .systemFont(ofSize: 14)
        errorLabel.textAlignment = .center
        errorLabel.isHidden = true

        // Create account link
        createAccountButton.setTitle("Don't have an account? Create one", for: .normal)
        createAccountButton.titleLabel?.font = .systemFont(ofSize: 14)
        createAccountButton.addTarget(self, action: #selector(createAccountTapped), for: .touchUpInside)

        // Forgot password link
        forgotPasswordButton.setTitle("Forgot password?", for: .normal)
        forgotPasswordButton.titleLabel?.font = .systemFont(ofSize: 14)
        forgotPasswordButton.addTarget(self, action: #selector(forgotPasswordTapped), for: .touchUpInside)

        // Stack view
        stackView.axis = .vertical
        stackView.spacing = 16
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(logoLabel)
        stackView.addArrangedSubview(UIView()) // spacer
        stackView.addArrangedSubview(emailField)
        stackView.addArrangedSubview(passwordField)
        stackView.addArrangedSubview(errorLabel)
        stackView.addArrangedSubview(loginButton)
        stackView.addArrangedSubview(createAccountButton)
        stackView.addArrangedSubview(forgotPasswordButton)

        // Custom spacing
        stackView.setCustomSpacing(32, after: logoLabel)
        stackView.setCustomSpacing(8, after: errorLabel)
        stackView.setCustomSpacing(8, after: createAccountButton)

        view.addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),
            stackView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -40),
        ])
    }

    // MARK: - Actions

    @objc private func loginTapped() {
        guard let email = emailField.text, !email.isEmpty,
              let password = passwordField.text, !password.isEmpty else {
            showError()
            return
        }

        errorLabel.isHidden = true
        loginButton.isEnabled = false
        loginButton.alpha = 0.6

        performLogin(email: email, password: password)
    }

    @objc private func createAccountTapped() {
        let url = Endpoints.baseURL.appendingPathComponent("/create-account")
        presentWebPage(url: url)
    }

    @objc private func forgotPasswordTapped() {
        let url = Endpoints.baseURL.appendingPathComponent("/reset-password-request")
        presentWebPage(url: url)
    }

    // MARK: - Login

    private func performLogin(email: String, password: String) {
        let url = Endpoints.baseURL.appendingPathComponent("/login")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("Tally/1.0 Turbo Native iOS", forHTTPHeaderField: "User-Agent")

        let body = "email=\(urlEncode(email))&password=\(urlEncode(password))"
        request.httpBody = body.data(using: .utf8)

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.handleLoginResponse(data: data, response: response, error: error)
            }
        }.resume()
    }

    private func handleLoginResponse(data: Data?, response: URLResponse?, error: Error?) {
        loginButton.isEnabled = true
        loginButton.alpha = 1.0

        guard let httpResponse = response as? HTTPURLResponse,
              let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type"),
              contentType.contains("application/json") else {
            showError()
            return
        }

        // Extract cookies from the shared cookie storage
        let url = Endpoints.baseURL
        if let cookies = HTTPCookieStorage.shared.cookies(for: url), !cookies.isEmpty {
            SessionStore.save(cookies: cookies)
            injectCookiesIntoWebView(cookies: cookies) { [weak self] in
                self?.onLogin()
            }
        } else {
            showError()
        }
    }

    private func injectCookiesIntoWebView(cookies: [HTTPCookie], completion: @escaping () -> Void) {
        let store = WKWebsiteDataStore.default().httpCookieStore
        let group = DispatchGroup()
        for cookie in cookies {
            group.enter()
            store.setCookie(cookie) { group.leave() }
        }
        group.notify(queue: .main) { completion() }
    }

    private func showError() {
        errorLabel.isHidden = false
        loginButton.isEnabled = true
        loginButton.alpha = 1.0
    }

    private func urlEncode(_ string: String) -> String {
        string.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? string
    }

    // MARK: - Web Fallback

    private func presentWebPage(url: URL) {
        let webVC = WebFallbackViewController(url: url)
        let nav = UINavigationController(rootViewController: webVC)
        present(nav, animated: true)
    }
}

// MARK: - UITextFieldDelegate

extension LoginViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField == emailField {
            passwordField.becomeFirstResponder()
        } else if textField == passwordField {
            loginTapped()
        }
        return true
    }
}

// MARK: - WebFallbackViewController

/// Minimal webview for "Create account" and "Forgot password" flows.
final class WebFallbackViewController: UIViewController {
    private let url: URL

    init(url: URL) {
        self.url = url
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done, target: self, action: #selector(dismissSelf)
        )

        let webView = WKWebView(frame: view.bounds)
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(webView)
        webView.load(URLRequest(url: url))
    }

    @objc private func dismissSelf() {
        dismiss(animated: true)
    }
}
```

- [ ] **Step 2: Verify the project builds**

Cmd+B in Xcode. Expected: Build Succeeded.

- [ ] **Step 3: Commit**

```bash
git add ios/Tally/Tally/Auth/LoginViewController.swift
git commit -m "Add native LoginViewController with web fallback links"
```

---

## Task 4: Update SceneDelegate for session-aware launch

**Files:**
- Modify: `ios/Tally/Tally/App/SceneDelegate.swift`

- [ ] **Step 1: Replace SceneDelegate**

Replace the contents of `ios/Tally/Tally/SceneDelegate.swift` with:

```swift
import UIKit
import WebKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = (scene as? UIWindowScene) else { return }

        window = UIWindow(windowScene: windowScene)

        // Observe logout from web Settings page
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleLogout),
            name: .tallyDidLogout,
            object: nil
        )

        if let cookies = SessionStore.loadCookies() {
            injectCookiesAndShowApp(cookies: cookies)
        } else {
            showLogin()
        }
    }

    // MARK: - Transitions

    private func showLogin() {
        let loginVC = LoginViewController { [weak self] in
            self?.transitionToApp()
        }
        window?.rootViewController = loginVC
        window?.makeKeyAndVisible()
    }

    private func transitionToApp() {
        let tabBar = TabBarController()
        window?.rootViewController = tabBar
    }

    @objc private func handleLogout() {
        SessionStore.clear()
        // Clear all website data so stale cookies don't linger in webviews
        WKWebsiteDataStore.default().removeData(
            ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(),
            modifiedSince: .distantPast
        ) { [weak self] in
            self?.showLogin()
        }
    }

    // MARK: - Cookie Injection

    private func injectCookiesAndShowApp(cookies: [HTTPCookie]) {
        let store = WKWebsiteDataStore.default().httpCookieStore
        let group = DispatchGroup()
        for cookie in cookies {
            group.enter()
            store.setCookie(cookie) { group.leave() }
        }
        group.notify(queue: .main) { [weak self] in
            self?.transitionToApp()
            self?.window?.makeKeyAndVisible()
        }
    }
}

// MARK: - Notification Name

extension Notification.Name {
    static let tallyDidLogout = Notification.Name("tallyDidLogout")
}
```

- [ ] **Step 2: Verify the project builds**

Cmd+B in Xcode. Expected: Build Succeeded.

- [ ] **Step 3: Commit**

```bash
git add ios/Tally/Tally/SceneDelegate.swift
git commit -m "Add session-aware launch and logout handling to SceneDelegate"
```

---

## Task 5: Add logout detection to TallyNavigator

**Files:**
- Modify: `ios/Tally/Tally/Navigation/TallyNavigator.swift`

- [ ] **Step 1: Update TallyNavigator with logout detection**

Replace the contents of `ios/Tally/Tally/Navigation/TallyNavigator.swift` with:

```swift
import HotwireNative
import UIKit

/// Wraps a Hotwire Navigator for a single tab. Each tab in the app gets its
/// own TallyNavigator so navigation stacks are independent.
final class TallyNavigator: NavigatorDelegate {
    let navigator: Navigator
    let rootURL: URL

    init(name: String, rootURL: URL) {
        self.rootURL = rootURL
        self.navigator = Navigator(configuration: .init(
            name: name,
            startLocation: rootURL
        ))
        navigator.delegate = self
        // Hide the native nav bar — web views have their own headers
        navigationController.setNavigationBarHidden(true, animated: false)
    }

    /// The UINavigationController managed by this navigator, suitable for
    /// embedding in a UITabBarController.
    var navigationController: UINavigationController {
        navigator.rootViewController
    }

    /// Loads the root URL into the navigator. Call once after setup.
    func start() {
        navigator.start()
    }

    /// Navigate to a specific URL within this tab's navigator.
    func visit(_ url: URL) {
        navigator.route(url)
    }

    /// Pop to the root view controller (used when the tab is re-tapped).
    func popToRoot() {
        navigationController.popToRootViewController(animated: true)
    }

    // MARK: - NavigatorDelegate (logout detection)

    func handle(proposal: VisitProposal) -> ProposalResult {
        // If the server redirected to /login, the session has expired or user logged out
        if proposal.url.path == "/login" && SessionStore.loadCookies() != nil {
            NotificationCenter.default.post(name: .tallyDidLogout, object: nil)
            return .reject
        }
        return .acceptCustom(proposal)
    }
}
```

Note: The `NavigatorDelegate` protocol and its `handle(proposal:)` method is the
Hotwire Native way to intercept navigation decisions. If the API is different in
the installed version, check the Hotwire Native iOS documentation for the
correct delegate method name. The key behavior is: when a visit to `/login` is
proposed and we have saved cookies (meaning we were authenticated), post the
logout notification and reject the navigation.

- [ ] **Step 2: Verify the project builds**

Cmd+B in Xcode. Expected: Build Succeeded. If the `NavigatorDelegate` protocol
or `handle(proposal:)` method doesn't exist, check the Hotwire Native source
for the correct delegate API and adapt accordingly.

- [ ] **Step 3: Commit**

```bash
git add ios/Tally/Tally/Navigation/TallyNavigator.swift
git commit -m "Add logout detection via NavigatorDelegate in TallyNavigator"
```

---

## Task 6: Acceptance testing

**Files:** none (manual verification)

- [ ] **Step 1: Ensure Rails server is running**

```bash
bin/dev
```

- [ ] **Step 2: Reset the simulator (clean install)**

In Xcode: Device → Erase All Content and Settings (on the simulator). This
ensures no stale cookies or Keychain data.

- [ ] **Step 3: Build and run (Cmd+R)**

Verify:
1. App launches showing the native login screen (green "Tally" title, email
   field, password field, Login button).
2. Enter invalid credentials → "Invalid email or password" error shown.
3. Enter valid credentials → tab bar appears, Today view loads.

- [ ] **Step 4: Test session persistence**

1. With the app running and logged in, kill it: Cmd+Shift+H (home), then
   swipe up on the app in the app switcher.
2. Re-launch from Xcode (Cmd+R).
3. Verify: app goes directly to the tab bar (no login screen).

- [ ] **Step 5: Test logout**

1. Navigate to the Settings tab.
2. Scroll down and tap "Logout" (the Rodauth logout link in the web view).
3. Verify: app transitions to the native login screen.
4. Kill and relaunch the app.
5. Verify: login screen appears (Keychain was cleared on logout).

- [ ] **Step 6: Test web fallback links**

1. On the login screen, tap "Don't have an account? Create one".
2. Verify: a modal webview opens showing the Rodauth create-account page.
3. Dismiss (tap Done).
4. Tap "Forgot password?".
5. Verify: a modal webview opens showing the Rodauth reset-password page.
6. Dismiss.

- [ ] **Step 7: Commit only if fixes were needed**

If acceptance revealed a bug and you fixed it:

```bash
git add <changed files>
git commit -m "Fix <issue> found in auth handoff acceptance"
```

If no fixes were needed, no commit.

---

## Self-Review Notes

**Spec coverage check:**
- Native login screen with email/password → Task 3 ✓
- JSON response from Rodauth for native clients → Task 1 ✓
- Session cookie persistence via Keychain (save/load/clear) → Task 2 ✓
- SceneDelegate session check on launch → Task 4 ✓
- Cookie injection into WKWebView before loading → Tasks 3, 4 ✓
- Logout detection via URL monitoring → Task 5 ✓
- Notification-based logout → Tasks 4, 5 ✓
- Web fallback for create account / forgot password → Task 3 ✓
- Rails-side test for JSON login → Task 1 ✓
- Acceptance criteria walkthrough → Task 6 ✓

**Type/method consistency:** `SessionStore.save(cookies:)`, `SessionStore.loadCookies()`,
`SessionStore.clear()` match across Tasks 2, 3, 4, 5. `Notification.Name.tallyDidLogout`
defined in Task 4, used in Task 5. `LoginViewController(onLogin:)` signature matches
between Tasks 3 and 4. `Endpoints.baseURL` used consistently.

**Placeholder scan:** none found. All code blocks are complete.

**API uncertainty note:** Task 5 uses `NavigatorDelegate` and `handle(proposal:)` which
may not match the exact Hotwire Native iOS API. A note is included in the task to check
the installed version's delegate API and adapt. The behavior (intercept navigation to
`/login`) is clear regardless of the exact method name.
