# M4c-1: Barcode Scanner — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Scan product barcodes with the iPhone camera and look up nutritional info via local DB + Open Food Facts API. Show results inline as search results.

**Architecture:** Hotwire Native Bridge Component pattern — Stimulus controller on the web sends a `"scan"` message to the native bridge, iOS opens the camera (AVFoundation), detects the barcode, replies with the code, web navigates to a lookup endpoint that persists the food and redirects to search results.

**Tech Stack:** Swift (AVFoundation, UIKit), Hotwire Native Bridge, Rails, Stimulus, Minitest.

**Spec:** `docs/superpowers/specs/2026-05-01-m4c-barcode-scanner-design.md`

---

## File Structure

**Rails — Created:**
- `app/javascript/controllers/barcode_scanner_controller.js` — Stimulus bridge controller
- `test/controllers/foods_barcode_lookup_test.rb` — barcode lookup tests

**Rails — Modified:**
- `config/importmap.rb` — pin `@hotwired/hotwire-native-bridge`
- `app/controllers/foods_controller.rb` — add `barcode_lookup` and update `new` actions
- `app/services/off/client.rb` — set `barcode` column in `persist`
- `app/views/foods/index.html.haml` — barcode button in search bar + "not found" notice
- `app/views/foods/_form.html.haml` — barcode button next to barcode field
- `config/routes.rb` — add `barcode_lookup` route

**iOS — Created:**
- `ios/Tally/Tally/Bridge/BarcodeScannerComponent.swift` — bridge component
- `ios/Tally/Tally/Bridge/BarcodeScannerViewController.swift` — camera UI

**iOS — Modified:**
- `ios/Tally/Tally/App/AppDelegate.swift` — register bridge component

---

## Task 1: Fix Off::Client#persist to set the barcode column

**Files:**
- Modify: `app/services/off/client.rb`
- Modify: `test/services/off/client_test.rb`

- [ ] **Step 1: Write the failing test**

Read `test/services/off/client_test.rb` first to understand the existing test patterns.
Add a test that verifies `persist` sets the `barcode` column:

```ruby
test "persist sets barcode column on the Food record" do
  result = Off::FoodResult.new(
    barcode: "5060337500234",
    name: "Test Product",
    brand: "Test Brand",
    calories: 100, protein: 5, carbs: 20, fat: 3, fiber: 2,
    serving_size: 30, serving_label: "1 bar"
  )
  food = Off::Client.new.persist(result)
  assert_equal "5060337500234", food.barcode
end
```

- [ ] **Step 2: Run the test, confirm it fails**

```bash
bin/rails test test/services/off/client_test.rb -n "test_persist_sets_barcode"
```

Expected: failure — `barcode` is nil.

- [ ] **Step 3: Add barcode to the persist method**

In `app/services/off/client.rb`, in the `persist` method (around line 29), add
`barcode: food_result.barcode` to the `update!` call:

```ruby
def persist(food_result)
  food = Food.find_or_initialize_by(source: :off, external_id: food_result.barcode)
  food.update!(
    name: food_result.name,
    brand: food_result.brand,
    barcode: food_result.barcode,
    calories: food_result.calories,
    protein: food_result.protein,
    carbs: food_result.carbs,
    fat: food_result.fat,
    fiber: food_result.fiber,
    serving_size: food_result.serving_size,
    serving_label: food_result.serving_label,
    verified_at: Time.current
  )
  food
end
```

- [ ] **Step 4: Run the test, confirm it passes**

```bash
bin/rails test test/services/off/client_test.rb
```

Expected: all tests pass.

- [ ] **Step 5: Commit**

```bash
git add app/services/off/client.rb test/services/off/client_test.rb
git commit -m "Set barcode column in Off::Client#persist"
```

---

## Task 2: Add barcode_lookup action and route

**Files:**
- Modify: `config/routes.rb`
- Modify: `app/controllers/foods_controller.rb`
- Create: `test/controllers/foods_barcode_lookup_test.rb`

- [ ] **Step 1: Write the failing tests**

Create `test/controllers/foods_barcode_lookup_test.rb`:

```ruby
require "test_helper"

class FoodsBarcodeLoopkupTest < ActionDispatch::IntegrationTest
  setup do
    @account = create(:account)
    @user = create(:user, account: @account)
    login(@account)
  end

  test "redirects to search when barcode found locally" do
    food = create(:food, barcode: "1234567890123", name: "Test Local Food")

    get barcode_lookup_foods_path(code: "1234567890123", meal: "lunch", date: "2026-05-01")

    assert_redirected_to foods_path(q: "Test Local Food", meal: "lunch", date: "2026-05-01")
  end

  test "redirects with not_found when barcode not in DB and OFF unavailable" do
    get barcode_lookup_foods_path(code: "0000000000000", meal: "lunch", date: "2026-05-01")

    assert_redirected_to foods_path(barcode_not_found: 1, barcode: "0000000000000", meal: "lunch", date: "2026-05-01")
  end

  test "requires authentication" do
    delete "/logout"
    get barcode_lookup_foods_path(code: "1234567890123")
    assert_response :redirect
  end

  private

  def login(account)
    post "/login", params: { email: account.email, password: "password" }
  end
end
```

- [ ] **Step 2: Run the tests, confirm they fail**

```bash
bin/rails test test/controllers/foods_barcode_lookup_test.rb
```

Expected: errors — route and action don't exist.

- [ ] **Step 3: Add the route**

In `config/routes.rb`, change the `resources :foods` line:

```ruby
resources :foods, only: [:index, :new, :create, :edit, :update, :destroy] do
  collection do
    get :barcode_lookup
  end
end
```

- [ ] **Step 4: Add the barcode_lookup action**

In `app/controllers/foods_controller.rb`, add after the `index` action:

```ruby
def barcode_lookup
  code = params[:code].to_s.strip
  food = Food.find_by(barcode: code)

  unless food
    begin
      result = Off::Client.new.fetch(code)
      food = Off::Client.new.persist(result)
    rescue Off::ProductNotFoundError
      # Not found in OFF either
    rescue Off::ApiError
      # API unavailable — treat as not found
    end
  end

  if food
    redirect_to foods_path(q: food.name, meal: params[:meal], date: params[:date])
  else
    redirect_to foods_path(barcode_not_found: 1, barcode: code, meal: params[:meal], date: params[:date])
  end
end
```

- [ ] **Step 5: Run the tests, confirm they pass**

```bash
bin/rails test test/controllers/foods_barcode_lookup_test.rb
```

Expected: 3 runs, 0 failures.

- [ ] **Step 6: Commit**

```bash
git add config/routes.rb app/controllers/foods_controller.rb test/controllers/foods_barcode_lookup_test.rb
git commit -m "Add barcode_lookup action with local DB + OFF API fallback"
```

---

## Task 3: Add "not found" notice and barcode pre-fill

**Files:**
- Modify: `app/views/foods/index.html.haml`
- Modify: `app/controllers/foods_controller.rb` (new action)

- [ ] **Step 1: Add the "not found" notice to the index view**

In `app/views/foods/index.html.haml`, after the search form (after line 46,
the clear button) and before the meal templates section, add:

```haml

  - if params[:barcode_not_found].present?
    .bg-amber-50.border.border-amber-200.rounded-lg.px-4.py-3.mb-3.text-sm
      %p.text-amber-800
        Barcode #{params[:barcode]} not found.
        = link_to "Create a custom food", new_food_path(barcode: params[:barcode]), class: "text-primary font-semibold"
        with this barcode.
```

- [ ] **Step 2: Update the new action to pre-fill barcode**

In `app/controllers/foods_controller.rb`, update the `new` action:

```ruby
def new
  @food = Food.new(name: params[:name], barcode: params[:barcode])
end
```

- [ ] **Step 3: Verify manually**

Visit `http://localhost:3000/foods?barcode_not_found=1&barcode=1234567890123&meal=lunch&date=2026-05-01`
in the browser. The amber notice should appear. Click "Create a custom food" —
the barcode field should be pre-filled.

- [ ] **Step 4: Commit**

```bash
git add app/views/foods/index.html.haml app/controllers/foods_controller.rb
git commit -m "Add barcode not-found notice and pre-fill barcode on new food form"
```

---

## Task 4: Add the Hotwire Native Bridge JS package and Stimulus controller

**Files:**
- Modify: `config/importmap.rb`
- Create: `app/javascript/controllers/barcode_scanner_controller.js`

- [ ] **Step 1: Pin the bridge package**

```bash
bin/importmap pin @hotwired/hotwire-native-bridge
```

If the pin command fails (package not in jspm), manually add to `config/importmap.rb`:

```ruby
pin "@hotwired/hotwire-native-bridge", to: "https://cdn.jsdelivr.net/npm/@hotwired/hotwire-native-bridge@1.0.0/dist/bridge.js"
```

- [ ] **Step 2: Create the Stimulus controller**

Create `app/javascript/controllers/barcode_scanner_controller.js`:

```js
import { BridgeComponent } from "@hotwired/hotwire-native-bridge"

// Sends a "scan" message to the native barcode scanner bridge component.
// Modes:
//   "search" — navigates to the barcode lookup endpoint with the scanned code
//   "input"  — fills the scanned code into a target text field
export default class extends BridgeComponent {
  static component = "barcode-scanner"
  static values = {
    mode: { type: String, default: "search" },
    inputSelector: String,
    meal: String,
    date: String
  }

  scan() {
    this.send("scan", {}, (data) => {
      const barcode = data?.barcode
      if (!barcode) return

      if (this.modeValue === "input") {
        const input = document.querySelector(this.inputSelectorValue)
        if (input) {
          input.value = barcode
          input.dispatchEvent(new Event("input", { bubbles: true }))
        }
      } else {
        const params = new URLSearchParams({ code: barcode })
        if (this.mealValue) params.set("meal", this.mealValue)
        if (this.dateValue) params.set("date", this.dateValue)
        window.location.href = `/foods/barcode_lookup?${params}`
      }
    })
  }
}
```

- [ ] **Step 3: Verify the project builds**

```bash
bin/rails tailwindcss:build
```

Visit any page in the browser to confirm no JS errors.

- [ ] **Step 4: Commit**

```bash
git add config/importmap.rb app/javascript/controllers/barcode_scanner_controller.js
git commit -m "Add barcode scanner Stimulus bridge controller"
```

---

## Task 5: Add barcode scan buttons to the views

**Files:**
- Modify: `app/views/foods/index.html.haml`
- Modify: `app/views/foods/_form.html.haml`

- [ ] **Step 1: Add barcode button to the search bar on foods/index**

In `app/views/foods/index.html.haml`, find the search input's `.relative`
wrapper (around line 42). The current markup has a search icon on the left and
a clear button on the right. We need to add a barcode icon between them, but
only for native. We also need to wrap the `.relative` div with the barcode
scanner Stimulus controller.

Replace the search form block (lines 37–46) with:

```haml
    = form_with url: foods_path, method: :get, data: { controller: "search", search_target: "form", turbo_frame: "food_search_results" } do
      - if @meal.present?
        %input{ type: "hidden", name: "meal", value: @meal }
      - if @date.present?
        %input{ type: "hidden", name: "date", value: @date }
      .relative{ data: native_app? ? { controller: "barcode-scanner", barcode_scanner_mode_value: "search", barcode_scanner_meal_value: @meal, barcode_scanner_date_value: @date } : {} }
        %input.input.w-full.pl-10.peer{ type: "text", name: "q", value: @query, placeholder: "Search foods...", autocomplete: "off", class: native_app? ? "pr-20" : "pr-10", data: { search_target: "input", action: "input->search#debounce" } }
        %div.absolute.left-3{ class: "top-1/2 -translate-y-1/2 text-text-secondary" }
          != '<svg class="w-4 h-4" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="2" stroke="currentColor"><circle cx="11" cy="11" r="8"/><path d="M21 21l-4.35-4.35" stroke-linecap="round"/></svg>'
        - if native_app?
          %button.absolute.right-10.text-text-secondary{ type: "button", "aria-label": "Scan barcode", class: "top-1/2 -translate-y-1/2 hover:text-text", data: { action: "click->barcode-scanner#scan" } }
            != '<svg class="w-5 h-5" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" d="M3.75 4.875c0-.621.504-1.125 1.125-1.125h4.5c.621 0 1.125.504 1.125 1.125v4.5c0 .621-.504 1.125-1.125 1.125h-4.5A1.125 1.125 0 013.75 9.375v-4.5zM3.75 14.625c0-.621.504-1.125 1.125-1.125h4.5c.621 0 1.125.504 1.125 1.125v4.5c0 .621-.504 1.125-1.125 1.125h-4.5a1.125 1.125 0 01-1.125-1.125v-4.5zM14.25 4.875c0-.621.504-1.125 1.125-1.125h4.5c.621 0 1.125.504 1.125 1.125v4.5c0 .621-.504 1.125-1.125 1.125h-4.5a1.125 1.125 0 01-1.125-1.125v-4.5z"/><path stroke-linecap="round" stroke-linejoin="round" d="M14.25 14.625v6.75h6.75v-6.75h-6.75z"/></svg>'
        %button.absolute.right-3.text-xl.leading-none.text-text-secondary{ type: "button", "aria-label": "Clear search", class: "top-1/2 -translate-y-1/2 peer-placeholder-shown:hidden hover:text-text", data: { action: "click->search#clear" } } &times;
```

- [ ] **Step 2: Add barcode button to the food form**

In `app/views/foods/_form.html.haml`, replace the barcode field section
(lines 54–58) with:

```haml
    .relative{ data: native_app? ? { controller: "barcode-scanner", barcode_scanner_mode_value: "input", barcode_scanner_input_selector_value: "#food_barcode" } : {} }
      = f.label :barcode, class: "label" do
        Barcode
        %span.text-text-secondary.font-normal &nbsp;(optional)
      .relative
        = f.text_field :barcode, class: "input#{native_app? ? ' pr-12' : ''}", id: "food_barcode"
        - if native_app?
          %button.absolute.right-3.text-text-secondary{ type: "button", "aria-label": "Scan barcode", class: "top-1/2 -translate-y-1/2 hover:text-text", data: { action: "click->barcode-scanner#scan" } }
            != '<svg class="w-5 h-5" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" d="M3.75 4.875c0-.621.504-1.125 1.125-1.125h4.5c.621 0 1.125.504 1.125 1.125v4.5c0 .621-.504 1.125-1.125 1.125h-4.5A1.125 1.125 0 013.75 9.375v-4.5zM3.75 14.625c0-.621.504-1.125 1.125-1.125h4.5c.621 0 1.125.504 1.125 1.125v4.5c0 .621-.504 1.125-1.125 1.125h-4.5a1.125 1.125 0 01-1.125-1.125v-4.5zM14.25 4.875c0-.621.504-1.125 1.125-1.125h4.5c.621 0 1.125.504 1.125 1.125v4.5c0 .621-.504 1.125-1.125 1.125h-4.5a1.125 1.125 0 01-1.125-1.125v-4.5z"/><path stroke-linecap="round" stroke-linejoin="round" d="M14.25 14.625v6.75h6.75v-6.75h-6.75z"/></svg>'
```

- [ ] **Step 3: Verify on web (non-native)**

Visit `http://localhost:3000/foods?meal=lunch&date=2026-05-01` in the browser.
The barcode button should NOT appear (web has no `native_app?`).

- [ ] **Step 4: Commit**

```bash
git add app/views/foods/index.html.haml app/views/foods/_form.html.haml
git commit -m "Add barcode scan buttons to search bar and food form (native only)"
```

---

## Task 6: Create the iOS BarcodeScannerViewController

**Files:**
- Create: `ios/Tally/Tally/Bridge/BarcodeScannerViewController.swift`

- [ ] **Step 1: Create the camera view controller**

Create `ios/Tally/Tally/Bridge/BarcodeScannerViewController.swift`:

```swift
import AVFoundation
import UIKit

protocol BarcodeScannerDelegate: AnyObject {
    func barcodeScannerDidScan(_ barcode: String)
    func barcodeScannerDidCancel()
}

final class BarcodeScannerViewController: UIViewController {

    weak var scannerDelegate: BarcodeScannerDelegate?

    private let captureSession = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        if AVCaptureDevice.default(for: .video) != nil {
            setupCamera()
        } else {
            // Simulator fallback — show manual entry
            showManualEntry()
        }

        setupOverlay()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if !captureSession.isRunning {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.captureSession.startRunning()
            }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if captureSession.isRunning {
            captureSession.stopRunning()
        }
    }

    // MARK: - Camera Setup

    private func setupCamera() {
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device) else {
            showManualEntry()
            return
        }

        captureSession.addInput(input)

        let output = AVCaptureMetadataOutput()
        captureSession.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        output.metadataObjectTypes = [.ean8, .ean13, .upce]

        let preview = AVCaptureVideoPreviewLayer(session: captureSession)
        preview.videoGravity = .resizeAspectFill
        preview.frame = view.bounds
        view.layer.addSublayer(preview)
        previewLayer = preview
    }

    // MARK: - Overlay

    private func setupOverlay() {
        // Cancel button
        let cancelButton = UIButton(type: .system)
        cancelButton.setTitle("Cancel", for: .normal)
        cancelButton.setTitleColor(.white, for: .normal)
        cancelButton.titleLabel?.font = .systemFont(ofSize: 17)
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        view.addSubview(cancelButton)

        // Scan area guide
        let guideView = UIView()
        guideView.layer.borderColor = UIColor.white.cgColor
        guideView.layer.borderWidth = 2
        guideView.layer.cornerRadius = 12
        guideView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(guideView)

        // Instructions label
        let label = UILabel()
        label.text = "Point camera at a barcode"
        label.textColor = .white
        label.font = .systemFont(ofSize: 15)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)

        // Torch button
        let torchButton = UIButton(type: .system)
        let torchConfig = UIImage.SymbolConfiguration(pointSize: 20)
        torchButton.setImage(UIImage(systemName: "flashlight.off.fill", withConfiguration: torchConfig), for: .normal)
        torchButton.tintColor = .white
        torchButton.translatesAutoresizingMaskIntoConstraints = false
        torchButton.addTarget(self, action: #selector(torchTapped(_:)), for: .touchUpInside)
        view.addSubview(torchButton)

        NSLayoutConstraint.activate([
            cancelButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            cancelButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),

            torchButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            torchButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            guideView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            guideView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -40),
            guideView.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.75),
            guideView.heightAnchor.constraint(equalToConstant: 150),

            label.topAnchor.constraint(equalTo: guideView.bottomAnchor, constant: 24),
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
        ])
    }

    // MARK: - Actions

    @objc private func cancelTapped() {
        scannerDelegate?.barcodeScannerDidCancel()
        dismiss(animated: true)
    }

    @objc private func torchTapped(_ sender: UIButton) {
        guard let device = AVCaptureDevice.default(for: .video), device.hasTorch else { return }
        try? device.lockForConfiguration()
        device.torchMode = device.torchMode == .on ? .off : .on
        device.unlockForConfiguration()

        let iconName = device.torchMode == .on ? "flashlight.on.fill" : "flashlight.off.fill"
        let config = UIImage.SymbolConfiguration(pointSize: 20)
        sender.setImage(UIImage(systemName: iconName, withConfiguration: config), for: .normal)
    }

    // MARK: - Simulator Fallback

    private func showManualEntry() {
        let alert = UIAlertController(title: "Enter Barcode", message: "Camera unavailable (simulator)", preferredStyle: .alert)
        alert.addTextField { field in
            field.placeholder = "Barcode number"
            field.keyboardType = .numberPad
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { [weak self] _ in
            self?.scannerDelegate?.barcodeScannerDidCancel()
            self?.dismiss(animated: true)
        })
        alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
            if let barcode = alert.textFields?.first?.text, !barcode.isEmpty {
                self?.scannerDelegate?.barcodeScannerDidScan(barcode)
            } else {
                self?.scannerDelegate?.barcodeScannerDidCancel()
            }
            self?.dismiss(animated: true)
        })
        // Present the alert after the view appears
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.present(alert, animated: true)
        }
    }
}

// MARK: - AVCaptureMetadataOutputObjectsDelegate

extension BarcodeScannerViewController: AVCaptureMetadataOutputObjectsDelegate {
    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let barcode = object.stringValue else { return }

        // Stop scanning after first detection
        captureSession.stopRunning()

        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        scannerDelegate?.barcodeScannerDidScan(barcode)
        dismiss(animated: true)
    }
}
```

- [ ] **Step 2: Verify the project builds**

Cmd+B in Xcode. Expected: Build Succeeded.

- [ ] **Step 3: Commit**

```bash
git add ios/Tally/Tally/Bridge/BarcodeScannerViewController.swift
git commit -m "Add BarcodeScannerViewController with AVFoundation camera + simulator fallback"
```

---

## Task 7: Create the iOS BarcodeScannerComponent and register it

**Files:**
- Create: `ios/Tally/Tally/Bridge/BarcodeScannerComponent.swift`
- Modify: `ios/Tally/Tally/App/AppDelegate.swift`

- [ ] **Step 1: Create the bridge component**

Create `ios/Tally/Tally/Bridge/BarcodeScannerComponent.swift`:

```swift
import HotwireNative
import UIKit
import AVFoundation

final class BarcodeScannerComponent: BridgeComponent {
    override class var name: String { "barcode-scanner" }

    override func onReceive(message: Message) {
        guard message.event == "scan" else { return }
        presentScanner(replyTo: message.event)
    }

    private var viewController: UIViewController? {
        delegate?.destination as? UIViewController
    }

    private func presentScanner(replyTo event: String) {
        guard let viewController else { return }

        // Check camera permission
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            showScanner(from: viewController, event: event)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        self?.showScanner(from: viewController, event: event)
                    } else {
                        self?.showPermissionDenied(from: viewController)
                    }
                }
            }
        default:
            showPermissionDenied(from: viewController)
        }
    }

    private func showScanner(from presenter: UIViewController, event: String) {
        let scanner = BarcodeScannerViewController()
        scanner.scannerDelegate = self
        scanner.modalPresentationStyle = .fullScreen
        presenter.present(scanner, animated: true)
    }

    private func showPermissionDenied(from presenter: UIViewController) {
        let alert = UIAlertController(
            title: "Camera Access Required",
            message: "Please allow camera access in Settings to scan barcodes.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { [weak self] _ in
            self?.reply(to: "scan", with: BarcodeReply(barcode: ""))
        })
        alert.addAction(UIAlertAction(title: "Settings", style: .default) { _ in
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        })
        presenter.present(alert, animated: true)
    }
}

// MARK: - BarcodeScannerDelegate

extension BarcodeScannerComponent: BarcodeScannerDelegate {
    func barcodeScannerDidScan(_ barcode: String) {
        reply(to: "scan", with: BarcodeReply(barcode: barcode))
    }

    func barcodeScannerDidCancel() {
        reply(to: "scan", with: BarcodeReply(barcode: ""))
    }
}

// MARK: - Reply Data

private extension BarcodeScannerComponent {
    struct BarcodeReply: Encodable {
        let barcode: String
    }
}
```

- [ ] **Step 2: Register the component in AppDelegate**

In `ios/Tally/Tally/AppDelegate.swift`, add after the `Hotwire.loadPathConfiguration`
call:

```swift
        // Register bridge components
        Hotwire.registerBridgeComponents([
            BarcodeScannerComponent.self
        ])
```

- [ ] **Step 3: Add camera usage description to Info.plist**

In `ios/Tally/Tally/Info.plist`, add:

```xml
<key>NSCameraUsageDescription</key>
<string>Tally uses the camera to scan food barcodes for quick nutritional lookup.</string>
```

- [ ] **Step 4: Verify the project builds**

Cmd+B in Xcode. Expected: Build Succeeded.

- [ ] **Step 5: Commit**

```bash
git add ios/Tally/Tally/Bridge/ ios/Tally/Tally/App/AppDelegate.swift ios/Tally/Tally/Info.plist
git commit -m "Add BarcodeScannerComponent bridge and register in AppDelegate"
```

---

## Task 8: Acceptance testing

**Files:** none (manual verification)

- [ ] **Step 1: Ensure Rails server is running**

```bash
bin/dev
```

- [ ] **Step 2: Test barcode lookup endpoint directly**

```bash
curl -s "http://localhost:3000/foods/barcode_lookup?code=3017620422003&meal=lunch&date=2026-05-01" -I
```

This is the barcode for Nutella. If the OFF API is reachable, it should
redirect to `/foods?q=Nutella...`. Check the `Location` header.

- [ ] **Step 3: Test in the iOS simulator**

Build and run (Cmd+R). Navigate to the Add Food page (tap "+"):

1. A barcode icon should appear in the search bar (next to the clear button).
2. Tap the barcode icon → manual entry alert appears (simulator has no camera).
3. Enter `3017620422003` (Nutella) → tap OK.
4. The page should redirect and show Nutella in the search results.

- [ ] **Step 4: Test "not found" flow**

1. Tap the barcode icon again.
2. Enter `0000000000000` (invalid barcode).
3. The page should show "Barcode 0000000000000 not found" with a "Create a
   custom food" link.
4. Tap the link — the new food form should have the barcode pre-filled.

- [ ] **Step 5: Test the food form barcode scan**

1. Navigate to My Foods tab → tap "+" to create a new food.
2. Scroll to the barcode field — a barcode icon should appear next to it.
3. Tap the icon → manual entry alert → enter a barcode → field should fill.

- [ ] **Step 6: Test on web (non-native)**

Visit `http://localhost:3000/foods?meal=lunch&date=2026-05-01` in the browser.
No barcode icon should appear.

- [ ] **Step 7: Commit only if fixes were needed**

If acceptance revealed a bug and you fixed it:

```bash
git add <changed files>
git commit -m "Fix <issue> found in barcode scanner acceptance"
```

---

## Self-Review Notes

**Spec coverage check:**
- Off::Client#persist sets barcode column → Task 1 ✓
- Barcode lookup endpoint (local DB + OFF fallback) → Task 2 ✓
- "Not found" notice with create link → Task 3 ✓
- Barcode pre-fill on new food form → Task 3 ✓
- Hotwire Native Bridge JS package + Stimulus controller → Task 4 ✓
- Barcode icon on Add Food search bar → Task 5 ✓
- Barcode icon on My Foods search bar → Task 5 ✓
- Barcode icon on food form barcode field → Task 5 ✓
- Buttons only render for native_app? → Task 5 ✓
- BarcodeScannerViewController (AVFoundation + simulator fallback) → Task 6 ✓
- BarcodeScannerComponent (bridge, permissions, reply) → Task 7 ✓
- Camera usage description in Info.plist → Task 7 ✓
- Registration in AppDelegate → Task 7 ✓
- Acceptance criteria walkthrough → Task 8 ✓

**Type/method consistency:** `BarcodeScannerDelegate` protocol (didScan/didCancel)
matches between Tasks 6 and 7. `BarcodeReply` struct with `barcode` field matches
the JS callback `data?.barcode`. Stimulus values (`mode`, `inputSelector`, `meal`,
`date`) match between Tasks 4 and 5. `barcode_lookup_foods_path` route name matches
between Tasks 2 and the Stimulus controller's URL construction.

**Placeholder scan:** none found.
