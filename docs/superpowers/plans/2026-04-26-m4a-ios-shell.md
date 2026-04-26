# M4a: iOS Hotwire Native Shell — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a native iOS shell with a UIKit tab bar (4 tabs + floating add button), path-configuration-driven navigation, and Rails-side changes to hide the web bottom nav for native clients.

**Architecture:** UIKit `UITabBarController` with one Hotwire `Navigator` per tab. Path configuration (bundled + server-fetched) controls push vs. modal presentation. Rails detects `Turbo Native` user-agent to conditionally render the web bottom nav.

**Tech Stack:** Swift (UIKit), Hotwire Native iOS (SPM), Rails 7, Minitest.

**Spec:** `docs/superpowers/specs/2026-04-26-m4a-ios-shell-design.md`

---

## File Structure

**iOS — Created:**
- `ios/Tally/Tally.xcodeproj/` — Xcode project (generated via Xcode CLI or manually)
- `ios/Tally/Tally/App/AppDelegate.swift` — UIKit app entry point
- `ios/Tally/Tally/App/SceneDelegate.swift` — window + root view controller setup
- `ios/Tally/Tally/Navigation/TabBarController.swift` — 4 tabs + floating "+" button
- `ios/Tally/Tally/Navigation/TallyNavigator.swift` — configures a Hotwire Navigator per tab
- `ios/Tally/Tally/Config/Endpoints.swift` — base URL (DEBUG vs RELEASE)
- `ios/Tally/Tally/Config/path-configuration.json` — bundled routing rules
- `ios/Tally/Tally/Helpers/MealInferrer.swift` — time-of-day → meal name
- `ios/Tally/Tally/Info.plist` — ATS exception for localhost
- `ios/Tally/Tally/Assets.xcassets/` — app icon placeholder, accent color
- `ios/Tally/TallyTests/MealInferrerTests.swift` — unit tests for meal inference

**Rails — Created:**
- `app/controllers/api/v1/path_configurations_controller.rb` — serves path config JSON
- `config/path-configuration.json` — canonical path configuration (single source of truth)
- `test/controllers/api/v1/path_configurations_controller_test.rb` — controller test

**Rails — Modified:**
- `config/routes.rb` — add `/api/v1/path_configuration` route
- `app/controllers/application_controller.rb` — add `native_app?` helper
- `app/views/layouts/application.html.haml` — conditionally hide bottom nav, adjust padding
- `test/controllers/application_controller_test.rb` — test `native_app?` detection

---

## Task 1: Add the path configuration JSON and Rails endpoint

**Files:**
- Create: `config/path-configuration.json`
- Create: `app/controllers/api/v1/path_configurations_controller.rb`
- Create: `test/controllers/api/v1/path_configurations_controller_test.rb`
- Modify: `config/routes.rb`

- [ ] **Step 1: Write the failing test**

Create `test/controllers/api/v1/path_configurations_controller_test.rb`:

```ruby
require "test_helper"

class Api::V1::PathConfigurationsControllerTest < ActionDispatch::IntegrationTest
  test "returns path configuration JSON without authentication" do
    get "/api/v1/path_configuration.json"
    assert_response :success
    json = JSON.parse(response.body)
    assert json.key?("settings")
    assert json.key?("rules")
    assert_equal "application/json", response.media_type
  end
end
```

- [ ] **Step 2: Run the test, confirm it fails**

```bash
bin/rails test test/controllers/api/v1/path_configurations_controller_test.rb
```

Expected: error — route and controller don't exist yet.

- [ ] **Step 3: Add the route**

In `config/routes.rb`, after the `mount Lookbook::Engine` line and before the health check, add:

```ruby
  namespace :api do
    namespace :v1 do
      resource :path_configuration, only: :show
    end
  end
```

- [ ] **Step 4: Create the path configuration JSON**

Create `config/path-configuration.json`:

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

- [ ] **Step 5: Create the controller**

Create `app/controllers/api/v1/path_configurations_controller.rb`:

```ruby
class Api::V1::PathConfigurationsController < ApplicationController
  skip_before_action :require_authentication
  skip_before_action :ensure_onboarded

  def show
    render json: Rails.root.join("config/path-configuration.json").read,
           content_type: "application/json"
  end
end
```

Note: `require_authentication` is defined on individual controllers (not
`ApplicationController`), but `ensure_onboarded` IS on `ApplicationController`,
so we skip that here. This endpoint has no `before_action :require_authentication`
since it inherits from `ApplicationController` which doesn't set one globally —
but we add the skip for `ensure_onboarded` which does run globally.

- [ ] **Step 6: Run the test, confirm it passes**

```bash
bin/rails test test/controllers/api/v1/path_configurations_controller_test.rb
```

Expected: 1 run, 0 failures.

- [ ] **Step 7: Commit**

```bash
git add config/path-configuration.json app/controllers/api/ test/controllers/api/ config/routes.rb
git commit -m "Add path configuration endpoint at /api/v1/path_configuration"
```

---

## Task 2: Add native_app? helper and hide bottom nav for native

**Files:**
- Modify: `app/controllers/application_controller.rb`
- Modify: `app/views/layouts/application.html.haml`
- Create: `test/integration/native_app_detection_test.rb`

- [ ] **Step 1: Write the failing test**

Create `test/integration/native_app_detection_test.rb`:

```ruby
require "test_helper"

class NativeAppDetectionTest < ActionDispatch::IntegrationTest
  setup do
    @account = create(:account)
    @user = create(:user, account: @account)
    login(@account)
  end

  test "web request renders the bottom nav" do
    get today_path
    assert_response :success
    assert_select "nav[aria-label='Primary']"
  end

  test "Turbo Native request hides the bottom nav" do
    get today_path, headers: { "HTTP_USER_AGENT" => "Tally/1.0 Turbo Native iOS" }
    assert_response :success
    assert_select "nav[aria-label='Primary']", count: 0
  end

  test "Turbo Native request reduces main padding" do
    get today_path, headers: { "HTTP_USER_AGENT" => "Tally/1.0 Turbo Native iOS" }
    assert_response :success
    assert_select "main.pb-4"
    assert_select "main.pb-24", count: 0
  end

  private

  def login(account)
    post "/login", params: { email: account.email, password: "password" }
  end
end
```

- [ ] **Step 2: Run the test, confirm it fails**

```bash
bin/rails test test/integration/native_app_detection_test.rb
```

Expected: the "hides the bottom nav" and "reduces main padding" tests fail (bottom nav still renders, padding still pb-24).

- [ ] **Step 3: Add the native_app? helper to ApplicationController**

Edit `app/controllers/application_controller.rb`. Add after the `helper_method :current_account` line:

```ruby
  def native_app?
    request.user_agent.to_s.include?("Turbo Native")
  end
  helper_method :native_app?
```

- [ ] **Step 4: Update the layout to conditionally hide the bottom nav**

Edit `app/views/layouts/application.html.haml`. Replace lines 18–23:

```haml
  %body.bg-bg-page.text-text.font-sans.antialiased{ data: { controller: "modal" } }
    %main.max-w-lg.mx-auto.px-4.pt-6.pb-24.relative
      = render FlashComponent.new(notice:, alert:)
      = yield
    = render BottomNavComponent.new(current_path: request.path, viewed_date: @date)
    = render ModalComponent.new
```

With:

```haml
  %body.bg-bg-page.text-text.font-sans.antialiased{ data: { controller: "modal" }, class: native_app? ? "native-app" : nil }
    %main.max-w-lg.mx-auto.px-4.pt-6.relative{ class: native_app? ? "pb-4" : "pb-24" }
      = render FlashComponent.new(notice:, alert:)
      = yield
    - unless native_app?
      = render BottomNavComponent.new(current_path: request.path, viewed_date: @date)
    = render ModalComponent.new
```

- [ ] **Step 5: Run the test, confirm it passes**

```bash
bin/rails test test/integration/native_app_detection_test.rb
```

Expected: 3 runs, 0 failures.

- [ ] **Step 6: Run the full test suite to check for regressions**

```bash
bin/rails test
```

Expected: no new failures (the pre-existing `food_log_entries_controller_test.rb:42` failure is acceptable).

- [ ] **Step 7: Commit**

```bash
git add app/controllers/application_controller.rb app/views/layouts/application.html.haml test/integration/native_app_detection_test.rb
git commit -m "Hide web bottom nav when Turbo Native user-agent is detected"
```

---

## Task 3: Create the Xcode project

**Files:**
- Create: entire `ios/Tally/` directory structure

This task is done manually in Xcode since Claude Code cannot generate `.xcodeproj` files. The steps below walk through the process.

- [ ] **Step 1: Create the project in Xcode**

1. Open Xcode → File → New → Project
2. Choose: iOS → App
3. Settings:
   - Product Name: `Tally`
   - Team: None (or your personal team)
   - Organization Identifier: `com.placeholder`
   - Bundle Identifier: `com.placeholder.tally`
   - Interface: Storyboard
   - Language: Swift
   - Uncheck "Include Tests" (we'll add a test target manually for better control)
4. Save to: `{project_root}/ios/Tally/`

This creates `ios/Tally/Tally.xcodeproj` and `ios/Tally/Tally/` with boilerplate files.

- [ ] **Step 2: Set deployment target and device**

In Xcode → project settings (click "Tally" in the project navigator, select the "Tally" target):
- General → Minimum Deployments: iOS 16.0
- General → Supported Destinations: remove iPad, keep iPhone only

- [ ] **Step 3: Delete the storyboard**

1. Delete `Main.storyboard` from the project navigator (Move to Trash).
2. In the Tally target → Info tab, delete the "Main storyboard file base name" row.
3. In the Tally target → Info tab, expand "Application Scene Manifest" → "Scene Configuration" → "Application Session Role" → "Item 0", and delete the "Storyboard Name" row.

- [ ] **Step 4: Add the Hotwire Native iOS package**

1. File → Add Package Dependencies
2. Enter URL: `https://github.com/hotwired/hotwire-native-ios`
3. Dependency Rule: Up to Next Major Version, starting from `1.0.0`
4. Click "Add Package"
5. Select "HotwireNative" library → Add to "Tally" target

- [ ] **Step 5: Add a test target**

1. File → New → Target
2. Choose: iOS → Unit Testing Bundle
3. Product Name: `TallyTests`
4. Target to be Tested: `Tally`
5. Click Finish

- [ ] **Step 6: Verify the project builds**

Select an iPhone 16 simulator, press Cmd+R. The app should launch to a blank white screen (the default ViewController). This confirms the project is set up correctly and the Hotwire Native dependency resolved.

- [ ] **Step 7: Commit**

```bash
git add ios/
git commit -m "Scaffold Xcode project with Hotwire Native dependency"
```

---

## Task 4: Add Endpoints and Info.plist ATS exception

**Files:**
- Create: `ios/Tally/Tally/Config/Endpoints.swift`
- Modify: `ios/Tally/Tally/Info.plist`

- [ ] **Step 1: Create the Endpoints file**

In Xcode: File → New → File → Swift File. Save as `Endpoints.swift` in a new group `Config` under `Tally/Tally/`.

Replace the contents with:

```swift
import Foundation

enum Endpoints {
    #if DEBUG
    static let baseURL = URL(string: "http://localhost:3000")!
    #else
    static let baseURL = URL(string: "https://tally.example.com")!
    #endif

    static let pathConfigurationURL = baseURL.appendingPathComponent("/api/v1/path_configuration.json")
}
```

- [ ] **Step 2: Add ATS exception to Info.plist**

Open `Info.plist` (or use the Info tab in target settings). Add:

Key: `App Transport Security Settings` (NSAppTransportSecurity)
- Type: Dictionary
- Add child: `Allows Local Networking` (NSAllowsLocalNetworking) = `YES` (Boolean)

In raw XML this is:

```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsLocalNetworking</key>
    <true/>
</dict>
```

- [ ] **Step 3: Verify the project still builds**

Cmd+B in Xcode. Expected: Build Succeeded.

- [ ] **Step 4: Commit**

```bash
git add ios/
git commit -m "Add Endpoints config and ATS exception for localhost"
```

---

## Task 5: Add MealInferrer with tests

**Files:**
- Create: `ios/Tally/Tally/Helpers/MealInferrer.swift`
- Create: `ios/Tally/TallyTests/MealInferrerTests.swift`

- [ ] **Step 1: Write the failing tests first**

In Xcode: File → New → File → Unit Test Case Class (or Swift File). Save as `MealInferrerTests.swift` in `TallyTests/`.

Replace the contents with:

```swift
import XCTest
@testable import Tally

final class MealInferrerTests: XCTestCase {

    func testEarlyMorningIsBreakfast() {
        // 7:00 AM
        XCTAssertEqual(MealInferrer.meal(at: minuteOfDay(hour: 7, min: 0)), "breakfast")
    }

    func testBoundary0400IsBreakfast() {
        // 4:00 AM — start of breakfast range
        XCTAssertEqual(MealInferrer.meal(at: minuteOfDay(hour: 4, min: 0)), "breakfast")
    }

    func testBoundary1030FlipsToLunch() {
        // 10:30 AM — start of lunch range
        XCTAssertEqual(MealInferrer.meal(at: minuteOfDay(hour: 10, min: 30)), "lunch")
    }

    func testAfternoonIsSnacks() {
        // 3:00 PM
        XCTAssertEqual(MealInferrer.meal(at: minuteOfDay(hour: 15, min: 0)), "snacks")
    }

    func testEveningIsDinner() {
        // 7:00 PM
        XCTAssertEqual(MealInferrer.meal(at: minuteOfDay(hour: 19, min: 0)), "dinner")
    }

    func testLateNightIsSnacks() {
        // 11:00 PM — past dinner, defaults to snacks
        XCTAssertEqual(MealInferrer.meal(at: minuteOfDay(hour: 23, min: 0)), "snacks")
    }

    func testAfterMidnightIsSnacks() {
        // 1:30 AM — defaults to snacks
        XCTAssertEqual(MealInferrer.meal(at: minuteOfDay(hour: 1, min: 30)), "snacks")
    }

    func testCurrentReturnsAValidMeal() {
        let validMeals = ["breakfast", "lunch", "snacks", "dinner"]
        XCTAssertTrue(validMeals.contains(MealInferrer.current()))
    }

    // MARK: - Helpers

    private func minuteOfDay(hour: Int, min: Int) -> Int {
        hour * 60 + min
    }
}
```

- [ ] **Step 2: Run the tests, confirm they fail**

In Xcode: Product → Test (Cmd+U). Expected: compilation error — `MealInferrer` doesn't exist yet.

- [ ] **Step 3: Implement MealInferrer**

In Xcode: File → New → File → Swift File. Save as `MealInferrer.swift` in a new group `Helpers` under `Tally/Tally/`.

Replace the contents with:

```swift
import Foundation

enum MealInferrer {

    /// Returns the meal name for a given minute-of-day (hour * 60 + min).
    /// Ranges match `app/services/meal_inferrer.rb` exactly.
    static func meal(at minuteOfDay: Int) -> String {
        switch minuteOfDay {
        case (4 * 60)..<(10 * 60 + 30):
            return "breakfast"
        case (10 * 60 + 30)..<(14 * 60 + 30):
            return "lunch"
        case (14 * 60 + 30)..<(17 * 60 + 30):
            return "snacks"
        case (17 * 60 + 30)..<(21 * 60 + 30):
            return "dinner"
        default:
            return "snacks"
        }
    }

    /// Returns the meal name for the current time in the user's local timezone.
    static func current() -> String {
        let now = Calendar.current.dateComponents([.hour, .minute], from: Date())
        let minuteOfDay = (now.hour ?? 0) * 60 + (now.minute ?? 0)
        return meal(at: minuteOfDay)
    }
}
```

- [ ] **Step 4: Run the tests, confirm they pass**

In Xcode: Cmd+U. Expected: 8 tests, all pass.

- [ ] **Step 5: Commit**

```bash
git add ios/
git commit -m "Add MealInferrer with unit tests (mirrors Ruby implementation)"
```

---

## Task 6: Implement TallyNavigator

**Files:**
- Create: `ios/Tally/Tally/Navigation/TallyNavigator.swift`

- [ ] **Step 1: Create the TallyNavigator file**

In Xcode: File → New → File → Swift File. Save as `TallyNavigator.swift` in a new group `Navigation` under `Tally/Tally/`.

Replace the contents with:

```swift
import HotwireNative
import UIKit

/// Wraps a Hotwire Navigator for a single tab. Each tab in the app gets its
/// own TallyNavigator so navigation stacks are independent.
final class TallyNavigator {
    let navigator: Navigator
    let rootURL: URL

    init(rootURL: URL) {
        self.rootURL = rootURL
        self.navigator = Navigator()
    }

    /// The UINavigationController managed by this navigator, suitable for
    /// embedding in a UITabBarController.
    var navigationController: UINavigationController {
        navigator.rootViewController
    }

    /// Loads the root URL into the navigator. Call once after setup.
    func start() {
        navigator.route(rootURL)
    }

    /// Navigate to a specific URL within this tab's navigator.
    func visit(_ url: URL) {
        navigator.route(url)
    }

    /// Pop to the root view controller (used when the tab is re-tapped).
    func popToRoot() {
        navigationController.popToRootViewController(animated: true)
    }
}
```

- [ ] **Step 2: Verify the project builds**

Cmd+B in Xcode. Expected: Build Succeeded.

- [ ] **Step 3: Commit**

```bash
git add ios/
git commit -m "Add TallyNavigator wrapping Hotwire Navigator per tab"
```

---

## Task 7: Implement TabBarController with floating add button

**Files:**
- Create: `ios/Tally/Tally/Navigation/TabBarController.swift`

- [ ] **Step 1: Create the TabBarController**

In Xcode: File → New → File → Swift File. Save as `TabBarController.swift` in the `Navigation` group.

Replace the contents with:

```swift
import UIKit

final class TabBarController: UITabBarController {

    private var navigators: [TallyNavigator] = []
    private let addButton = UIButton(type: .system)

    // MARK: - Tab definitions

    private struct TabDefinition {
        let title: String
        let icon: String        // SF Symbol name
        let activeIcon: String  // SF Symbol name (filled)
        let path: String        // appended to Endpoints.baseURL
    }

    private let tabs: [TabDefinition] = [
        TabDefinition(title: "Today",    icon: "house",           activeIcon: "house.fill",     path: "/today"),
        TabDefinition(title: "Search",   icon: "magnifyingglass", activeIcon: "magnifyingglass", path: "/foods"),
        TabDefinition(title: "Recipes",  icon: "book",            activeIcon: "book.fill",      path: "/recipes"),
        TabDefinition(title: "Settings", icon: "gearshape",       activeIcon: "gearshape.fill", path: "/settings/edit"),
    ]

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        delegate = self
        setupTabs()
        setupAddButton()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        positionAddButton()
    }

    // MARK: - Tab setup

    private func setupTabs() {
        navigators = tabs.map { tab in
            let url = Endpoints.baseURL.appendingPathComponent(tab.path)
            let nav = TallyNavigator(rootURL: url)

            nav.navigationController.tabBarItem = UITabBarItem(
                title: tab.title,
                image: UIImage(systemName: tab.icon),
                selectedImage: UIImage(systemName: tab.activeIcon)
            )

            return nav
        }

        viewControllers = navigators.map(\.navigationController)

        // Start each navigator (loads the root URL)
        navigators.forEach { $0.start() }
    }

    // MARK: - Floating add button

    private func setupAddButton() {
        addButton.translatesAutoresizingMaskIntoConstraints = false

        let config = UIImage.SymbolConfiguration(pointSize: 20, weight: .semibold)
        addButton.setImage(UIImage(systemName: "plus", withConfiguration: config), for: .normal)
        addButton.tintColor = .white
        addButton.backgroundColor = UIColor(red: 34/255, green: 197/255, blue: 94/255, alpha: 1) // #22c55e
        addButton.layer.cornerRadius = 22
        addButton.clipsToBounds = true

        addButton.addTarget(self, action: #selector(addButtonTapped), for: .touchUpInside)

        view.addSubview(addButton)

        NSLayoutConstraint.activate([
            addButton.widthAnchor.constraint(equalToConstant: 44),
            addButton.heightAnchor.constraint(equalToConstant: 44),
            addButton.centerXAnchor.constraint(equalTo: tabBar.centerXAnchor),
        ])
    }

    private func positionAddButton() {
        // Position the button so its bottom edge sits 8pt above the tab bar top
        addButton.frame.origin.y = tabBar.frame.origin.y - 44 - 8
        addButton.center.x = tabBar.center.x
    }

    @objc private func addButtonTapped() {
        let meal = MealInferrer.current()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let today = dateFormatter.string(from: Date())

        let url = Endpoints.baseURL.appendingPathComponent("/foods")
            .appending(queryItems: [
                URLQueryItem(name: "meal", value: meal),
                URLQueryItem(name: "date", value: today),
            ])

        // Switch to the Search tab (index 1) and navigate
        selectedIndex = 1
        navigators[1].visit(url)
    }
}

// MARK: - UITabBarControllerDelegate

extension TabBarController: UITabBarControllerDelegate {
    func tabBarController(_ tabBarController: UITabBarController, shouldSelect viewController: UIViewController) -> Bool {
        // If the user taps the already-selected tab, pop to root
        if viewController == selectedViewController {
            let index = viewControllers?.firstIndex(of: viewController) ?? 0
            navigators[index].popToRoot()
        }
        return true
    }
}
```

- [ ] **Step 2: Verify the project builds**

Cmd+B in Xcode. Expected: Build Succeeded.

- [ ] **Step 3: Commit**

```bash
git add ios/
git commit -m "Add TabBarController with 4 tabs and floating add button"
```

---

## Task 8: Wire up AppDelegate and SceneDelegate

**Files:**
- Modify: `ios/Tally/Tally/App/AppDelegate.swift`
- Modify: `ios/Tally/Tally/App/SceneDelegate.swift`

- [ ] **Step 1: Replace AppDelegate.swift**

Open `ios/Tally/Tally/AppDelegate.swift` (Xcode may have generated it at this path). Replace the entire contents with:

```swift
import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        return true
    }

    // MARK: UISceneSession Lifecycle

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let config = UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
        config.delegateClass = SceneDelegate.self
        return config
    }
}
```

- [ ] **Step 2: Replace SceneDelegate.swift**

Open `ios/Tally/Tally/SceneDelegate.swift`. Replace the entire contents with:

```swift
import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = (scene as? UIWindowScene) else { return }

        window = UIWindow(windowScene: windowScene)
        window?.rootViewController = TabBarController()
        window?.makeKeyAndVisible()
    }
}
```

- [ ] **Step 3: Delete the generated ViewController.swift**

If Xcode generated a `ViewController.swift`, delete it (Move to Trash). It's no longer needed since `TabBarController` is the root.

- [ ] **Step 4: Build and run in the simulator**

Make sure `bin/dev` is running in your terminal. In Xcode, select an iPhone 16 simulator and press Cmd+R.

Expected: The app launches with a tab bar at the bottom showing Today, Search, Recipes, Settings. The Today tab loads `http://localhost:3000/today`. The green "+" button floats above the tab bar.

If you see a blank screen or error, check that:
- `bin/dev` is running and accessible at `http://localhost:3000`
- The ATS exception is set in Info.plist
- You deleted Main.storyboard and its references (Task 3, Step 3)

- [ ] **Step 5: Commit**

```bash
git add ios/
git commit -m "Wire AppDelegate and SceneDelegate to launch TabBarController"
```

---

## Task 9: Bundle the path configuration in the iOS app

**Files:**
- Modify: `ios/Tally/Tally/Navigation/TallyNavigator.swift`

- [ ] **Step 1: Copy the path configuration into the Xcode project**

1. In Xcode, right-click the `Config` group → Add Files to "Tally"
2. Navigate to `{project_root}/config/path-configuration.json`
3. Check "Copy items if needed"
4. Make sure "Add to targets: Tally" is checked
5. Click Add

This adds the JSON to the app bundle so it's available at launch before the server responds.

- [ ] **Step 2: Update TallyNavigator to configure path configuration**

Replace the contents of `TallyNavigator.swift` with:

```swift
import HotwireNative
import UIKit

/// Wraps a Hotwire Navigator for a single tab. Each tab in the app gets its
/// own TallyNavigator so navigation stacks are independent.
final class TallyNavigator {
    let navigator: Navigator
    let rootURL: URL

    init(rootURL: URL) {
        self.rootURL = rootURL
        self.navigator = Navigator()
        configurePathConfiguration()
    }

    /// The UINavigationController managed by this navigator, suitable for
    /// embedding in a UITabBarController.
    var navigationController: UINavigationController {
        navigator.rootViewController
    }

    /// Loads the root URL into the navigator. Call once after setup.
    func start() {
        navigator.route(rootURL)
    }

    /// Navigate to a specific URL within this tab's navigator.
    func visit(_ url: URL) {
        navigator.route(url)
    }

    /// Pop to the root view controller (used when the tab is re-tapped).
    func popToRoot() {
        navigationController.popToRootViewController(animated: true)
    }

    // MARK: - Path Configuration

    private func configurePathConfiguration() {
        // Load the bundled copy for instant startup
        if let bundledURL = Bundle.main.url(forResource: "path-configuration", withExtension: "json") {
            navigator.pathConfiguration.sources = [
                .file(bundledURL),
                .server(Endpoints.pathConfigurationURL)
            ]
        }
    }
}
```

- [ ] **Step 3: Build and run**

Cmd+R. Navigate to a `/new` or `/edit` route (e.g., tap "+ Add" in a meal bucket, or create a new recipe). Expected: the page presents as a modal sheet sliding up from the bottom, not as a pushed page.

- [ ] **Step 4: Commit**

```bash
git add ios/
git commit -m "Bundle path configuration and configure push vs modal routing"
```

---

## Task 10: Acceptance testing

**Files:** none (manual verification)

- [ ] **Step 1: Ensure Rails server is running**

```bash
bin/dev
```

- [ ] **Step 2: Launch the app in the simulator (Cmd+R)**

Verify:
1. App launches showing the Today tab with `/today` loaded.
2. The web bottom nav is NOT visible (no double navigation).
3. The native tab bar shows 4 tabs: Today, Search, Recipes, Settings.
4. The green "+" button floats above the tab bar.

- [ ] **Step 3: Test tab navigation**

1. Tap each tab — verify it loads the correct page:
   - Today → `/today` (day view with meal buckets)
   - Search → `/foods` (food search)
   - Recipes → `/recipes` (recipe list)
   - Settings → `/settings/edit` (user profile)
2. Navigate within a tab (e.g., tap a recipe → recipe detail).
3. Switch to another tab and back — verify the first tab's state is preserved (you're still on the recipe detail, not the list).
4. Tap the already-selected tab — verify it pops to root.

- [ ] **Step 4: Test the "+" button**

1. Tap the green "+" button.
2. Verify: switches to the Search tab, loads `/foods?meal={inferred}&date={today}`.
3. The page should show "Add Food" with the correct meal for the current time of day.

- [ ] **Step 5: Test modal presentation**

1. Navigate to a page with a "new" or "edit" action (e.g., create a new recipe from the Recipes tab).
2. Verify: the form slides up as a modal sheet, not a pushed page.
3. Dismiss the modal (swipe down or tap a cancel/back control if present).

- [ ] **Step 6: Test the path configuration endpoint**

Open a browser or curl:

```bash
curl -s http://localhost:3000/api/v1/path_configuration.json | python3 -m json.tool
```

Verify: returns valid JSON with `settings.tabs` and `rules`.

- [ ] **Step 7: Commit only if fixes were needed**

If acceptance revealed a bug and you fixed it:

```bash
git add <changed files>
git commit -m "Fix <issue> found in iOS shell acceptance"
```

If no fixes were needed, no commit.

---

## Self-Review Notes

**Spec coverage check:**
- Xcode project scaffold (iOS 16, iPhone, no storyboard, SPM) → Task 3 ✓
- Tab bar with 4 tabs + own Navigator each → Tasks 6–7 ✓
- Floating green "+" button with meal inference → Tasks 5, 7 ✓
- Path configuration (bundled + server-fetched, push vs modal) → Tasks 1, 9 ✓
- Rails endpoint at `/api/v1/path_configuration.json` → Task 1 ✓
- `native_app?` helper + hide bottom nav → Task 2 ✓
- ATS exception for localhost → Task 4 ✓
- Endpoints (DEBUG vs RELEASE) → Task 4 ✓
- MealInferrer with matching hour ranges → Task 5 ✓
- AppDelegate / SceneDelegate wiring → Task 8 ✓
- Acceptance criteria walkthrough → Task 10 ✓

**Type/method consistency:** `TallyNavigator` uses `start()`, `visit(_:)`, `popToRoot()` consistently across Tasks 6, 7, 9. `Endpoints.baseURL` and `Endpoints.pathConfigurationURL` match between Tasks 4 and 9. `MealInferrer.current()` and `MealInferrer.meal(at:)` match between Tasks 5 and 7. Tab indices (Search = index 1) consistent between Task 7's `addButtonTapped()` and tab definitions array.

**Placeholder scan:** none found. All code blocks are complete.
