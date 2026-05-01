# M4c-1: Barcode Scanner — Design

**Date:** 2026-05-01
**Status:** Approved
**Scope:** Tickets 14 + 27 (barcode lookup + native scanner bridge)

## Goal

Scan product barcodes with the iPhone camera and look up nutritional
information. The scanned barcode is looked up in the local database first,
then via the Open Food Facts API if not found locally. Results appear inline
as search results. A "not found" state offers to create a custom food with
the barcode pre-filled.

## Non-goals

- Batch scanning (scan multiple items in one session)
- Barcode history / scan log
- Web-side camera scanning (native only)
- Scanning from the Today view (only from search bars and food form)

## Architecture

**Hotwire Native Bridge Component** pattern:
- Web side: a Stimulus controller (`barcode_scanner_controller`) sends
  messages to the native bridge.
- iOS side: a `BridgeComponent` subclass (`BarcodeScannerComponent`) receives
  scan requests, opens the camera, and replies with the barcode.
- Rails side: a new `barcode_lookup` action on `FoodsController` handles the
  lookup flow.

## Entry Points

The barcode scan button appears in three places:

1. **Add Food search bar** (with meal context at `/foods?meal=X&date=Y`) —
   barcode icon next to the search input. Scan → lookup → result appears as
   a search result ready to add to the meal.

2. **My Foods search bar** (no meal context at `/foods`) — same barcode icon.
   Scan → lookup → result appears for browsing.

3. **Custom food form barcode field** (`/foods/new`, `/foods/:id/edit`) —
   barcode icon next to the barcode text input. Scan → fills the barcode
   string into the field.

All three use the same native bridge component. The Stimulus controller's
`mode` value determines what happens with the scanned barcode:
- `"search"` mode (entry points 1 & 2): navigates to the barcode lookup
  endpoint
- `"input"` mode (entry point 3): fills the barcode into a target text field

The barcode button is only rendered when `native_app?` is true, since the
web has no camera access.

## Barcode Lookup Flow

```
GET /foods/barcode_lookup?code={barcode}&meal={meal}&date={date}
```

1. Check local DB: `Food.find_by(barcode: code)`
2. If not found locally, call `Off::Client.new.fetch(code)` which hits
   `https://world.openfoodfacts.org/api/v2/product/{code}.json`
3. If OFF returns a result, persist via `Off::Client.new.persist(result)`.
   The `persist` method already sets barcode via `external_id`.
4. If found (locally or via OFF), redirect to
   `/foods?q={food.name}&meal={meal}&date={date}` — the food appears as a
   normal search result.
5. If not found anywhere, redirect to
   `/foods?barcode_not_found=1&barcode={code}&meal={meal}&date={date}`.

Note: `Off::Client#fetch(barcode)` and `Off::Client#persist(result)` already
exist. The `persist` method uses `find_or_initialize_by(source: :off,
external_id: food_result.barcode)` but does not set the `barcode` column on
the `Food` record. We need to add `barcode: food_result.barcode` to the
`persist` method so local barcode lookups work on subsequent scans.

## "Not Found" UI

When `params[:barcode_not_found]` is present on `/foods`, show a notice above
the search results:

```
Barcode {code} not found.
[Create a custom food] with this barcode.
```

The "Create a custom food" link goes to `/foods/new?barcode={code}`, which
pre-fills the barcode field on the form.

The custom food form already accepts a `barcode` param via `food_params` — we
just need to pre-fill it from `params[:barcode]` in the `new` action.

## iOS Bridge Component

### BarcodeScannerComponent (Swift)

A Hotwire Native `BridgeComponent` subclass registered as `"barcode-scanner"`.

**Messages received from web:**
- `"scan"` — open the camera scanner

**Messages sent to web:**
- Reply to `"scan"` with `{ "barcode": "5060337500234" }` on success
- Reply to `"scan"` with `{ "barcode": "" }` on cancel

**Camera view:** A `BarcodeScannerViewController` using `AVCaptureSession` +
`AVCaptureMetadataOutput`. Supported barcode types: `.ean8`, `.ean13`,
`.upce`. Full-screen camera preview with:
- A translucent overlay with a cutout rectangle (scan area guide)
- A cancel button (top-left)
- Torch/flash toggle (top-right, if available)

**Permissions:** Request camera access via `AVCaptureDevice.requestAccess`.
If denied, show an alert directing the user to Settings.

**Simulator fallback:** When `AVCaptureDevice.default` returns nil (no camera),
show a `UIAlertController` with a text field for manual barcode entry. This
allows development/testing in the simulator.

### Registration

The bridge component must be registered with Hotwire Native in `AppDelegate`:

```swift
Hotwire.registerBridgeComponents([BarcodeScannerComponent.self])
```

## Web-side Stimulus Controller

### barcode_scanner_controller.js

```
data-controller="barcode-scanner"
data-barcode-scanner-mode-value="search"    // or "input"
data-barcode-scanner-target-value="#food_barcode"  // for input mode
```

**Targets:** none (uses values for configuration)

**Values:**
- `mode`: `"search"` or `"input"`
- `target`: CSS selector for the input field (input mode only)
- `meal`: current meal (search mode, for redirect)
- `date`: current date (search mode, for redirect)

**Actions:**
- `scan`: sends `"scan"` message to bridge, handles reply

**Behavior on reply:**
- If `mode == "search"` and barcode is not empty: navigate to
  `/foods/barcode_lookup?code={barcode}&meal={meal}&date={date}`
- If `mode == "input"` and barcode is not empty: set the target input's value
- If barcode is empty (cancelled): do nothing

**Non-native fallback:** On web (no bridge), the scan button is not rendered
(`native_app?` check in the template). The controller itself is harmless if
loaded — the bridge message just goes nowhere.

## File Structure

**iOS — Created:**
- `ios/Tally/Tally/Bridge/BarcodeScannerComponent.swift` — bridge component
- `ios/Tally/Tally/Bridge/BarcodeScannerViewController.swift` — camera UI

**iOS — Modified:**
- `ios/Tally/Tally/App/AppDelegate.swift` — register bridge component

**Rails — Created:**
- `app/javascript/controllers/barcode_scanner_controller.js` — Stimulus controller

**Rails — Modified:**
- `app/controllers/foods_controller.rb` — add `barcode_lookup` action, update `new` action
- `app/services/off/client.rb` — set `barcode` column in `persist`
- `app/views/foods/index.html.haml` — add barcode icon button to search bar, add "not found" notice
- `app/views/foods/_form.html.haml` — add barcode icon button next to barcode field
- `config/routes.rb` — add `barcode_lookup` route
- `test/controllers/foods_controller_test.rb` — test barcode_lookup action
- `test/services/off/client_test.rb` — test barcode fetch + persist with barcode column

## Testing

### Rails-side

- `FoodsController#barcode_lookup`:
  - Barcode found locally → redirects to `/foods?q={name}&...`
  - Barcode not found locally, found via OFF → persists food, redirects
  - Barcode not found anywhere → redirects with `barcode_not_found=1`
- `Off::Client#persist` sets `barcode` column on Food record
- Integration test: "not found" notice renders when `barcode_not_found` param present
- `FoodsController#new` pre-fills barcode from params

### iOS-side

- Manual testing with simulator (manual entry fallback)
- Manual testing on physical device (real camera) if available

## Acceptance Criteria

1. On the Add Food page (native), a barcode icon appears in the search bar.
2. Tapping the icon opens the camera (or manual entry on simulator).
3. Scanning a barcode that exists in the local DB → food appears as a search result.
4. Scanning a barcode not in local DB but in OFF → food is fetched, persisted, appears as result.
5. Scanning a barcode not found anywhere → "not found" message with create link.
6. "Create a custom food" link pre-fills the barcode on the new food form.
7. On the custom food form (native), a barcode icon appears next to the barcode field.
8. Tapping it scans and fills the barcode into the field.
9. My Foods search bar also has the barcode icon, same behavior as Add Food.
10. On web (non-native), no barcode buttons appear.

## Open Questions

None.
