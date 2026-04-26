# Modal Component — Design

**Date:** 2026-04-26
**Status:** Approved

## Goal

Add a reusable `ModalComponent` that any page in Tally can open to display
short, focused content (pickers, confirmations, small forms). The component is
mounted once in the layout and loads its body via a `<turbo-frame id="modal">`,
so callers don't repeat the modal chrome (backdrop, card, close button, ESC
handler).

The first consumer is the meal switcher on the Add Food page, which currently
uses a `<details>`-based dropdown.

## Non-goals

- Bottom-sheet variant. Centered card only for now. The existing one-off
  `sheet_controller` for the food-add flow stays as-is.
- Stacked modals.
- Custom open/close animations beyond instant show/hide.
- Generic helper methods (`modal_link_to`, etc.) — we'll see how the API feels
  after a couple of consumers before extracting helpers.

## Architecture

```
app/components/modal_component.rb
app/components/modal_component/
  modal_component.html.haml
  modal_component.en.yml
app/javascript/controllers/modal_controller.js
app/controllers/meal_pickers_controller.rb
app/views/meal_pickers/show.html.haml
config/routes.rb            # resource :meal_picker, only: :show
test/components/modal_component_test.rb
test/controllers/meal_pickers_controller_test.rb
```

Generated via `bin/rails generate view_component:component Modal --sidecar
--locale` per project convention, then edited.

## Component contract

`ModalComponent.new` takes no args. Rendered once in
`app/views/layouts/application.html.haml` after the bottom nav. The component
emits:

- A fixed full-screen root, hidden by default, with a Stimulus `modal`
  controller bound and an ESC keydown listener on `window`.
- A backdrop div (`bg-black/40`) that closes on click.
- A card (`bg-bg rounded-lg shadow-xl max-w-sm max-h-[85vh] overflow-auto`)
  containing:
  - A close button (top-right, Phosphor X icon, `aria-label` from locale).
  - `<turbo-frame id="modal">` slot for body content.

The card is centered on screen by `items-center justify-center` on the root.
On mobile (max-w-sm = 24rem ≈ 384px) the card stays comfortably inside the
viewport with `p-4` outer padding.

## Stimulus controller

`app/javascript/controllers/modal_controller.js`

```js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["root", "frame"]

  open() {
    this.rootTarget.classList.remove("hidden")
    this.rootTarget.classList.add("flex")
    document.body.classList.add("overflow-hidden")
    // Do NOT preventDefault — Turbo still navigates the link into the frame.
  }

  close(event) {
    if (event) event.preventDefault()
    this.rootTarget.classList.add("hidden")
    this.rootTarget.classList.remove("flex")
    document.body.classList.remove("overflow-hidden")
    // Clear so reopening fetches fresh content.
    this.frameTarget.innerHTML = ""
  }
}
```

Wiring (in component template):

- Root: `data-controller="modal" data-modal-target="root"
  data-action="keydown.esc@window->modal#close"`
- Backdrop: `data-action="click->modal#close"`
- Close button: `data-action="click->modal#close"`
- Frame: `data-modal-target="frame"`

## Caller contract

To open the modal from any page:

```haml
= link_to "Change meal", meal_picker_path(date: @date, meal: @meal),
    data: { turbo_frame: "modal", action: "click->modal#open" }
```

Two attributes on the trigger:

1. `data-turbo-frame="modal"` — Turbo intercepts the navigation and fetches the
   response into the layout's frame.
2. `data-action="click->modal#open"` — Stimulus shows the backdrop. Open is
   explicit per trigger (we considered a single `data-modal-open` attribute
   with a document-level listener; we chose explicit actions for locality).

The server response must wrap content in `<turbo-frame id="modal">…</turbo-frame>`.
There is no helper to enforce this; convention.

## First consumer: meal picker

### Route

```ruby
# config/routes.rb
resource :meal_picker, only: :show
```

`GET /meal_picker?date=…&meal=…&q=…`

### Controller

`MealPickersController#show` accepts:

- `meal` — currently selected meal key (highlighted in the list)
- `date` — preserved on each meal link
- `q` — preserved on each meal link

It assigns `@current_meal`, `@date`, `@query` and renders
`meal_pickers/show.html.haml`. The view is wrapped in
`<turbo-frame id="modal">` so it lands in the layout's frame.

### View (`meal_pickers/show.html.haml`)

```haml
= turbo_frame_tag "modal" do
  %h2.text-lg.font-semibold.mb-3 Choose meal
  %ul.flex.flex-col.gap-1
    - FoodLogEntry.meals.each_key do |meal_key|
      - active = meal_key == @current_meal
      %li
        = link_to meal_key.capitalize,
            foods_path(meal: meal_key, date: @date, q: @query.presence),
            class: "block px-3 py-2 rounded-md #{active ? 'text-primary font-semibold bg-primary-tint' : 'text-text hover:bg-primary-tint'}"
```

Clicking a meal link does a full-page navigation (no `data-turbo-frame`),
which dismisses the modal naturally because the whole page reloads.

### Foods index changes

Replace the `<details>` meal-picker block in
`app/views/foods/index.html.haml` (lines 11–18) with a single link:

```haml
= link_to meal_picker_path(date: @date, meal: @meal, q: @query.presence),
    class: "text-primary font-semibold inline-flex items-center gap-1",
    data: { turbo_frame: "modal", action: "click->modal#open" } do
  = @meal.capitalize
  != '<svg class="w-3.5 h-3.5" ...phosphor caret-down...>'
```

## Layout change

```haml
# app/views/layouts/application.html.haml
%body.bg-bg-page.text-text.font-sans.antialiased
  %main.max-w-lg.mx-auto.px-4.pt-6.pb-24.relative
    = render FlashComponent.new(notice:, alert:)
    = yield
  = render BottomNavComponent.new(current_path: request.path, viewed_date: @date)
  = render ModalComponent.new
```

## Tests

### `ModalComponentTest`

- Renders a root element with `hidden` class.
- Contains a `<turbo-frame id="modal">`.
- Renders a close button with `aria-label` from locale.

### `MealPickersControllerTest`

- `GET /meal_picker?meal=lunch&date=2026-04-26` returns 200.
- Response includes `<turbo-frame id="modal">`.
- Lists all four meals with links to `foods_path(meal: …, date: "2026-04-26")`.
- The link for the currently selected meal carries the active styling class
  (`text-primary` and `bg-primary-tint`).

No JS test for the Stimulus controller — exercised end-to-end via Playwright
during acceptance per project convention.

## Acceptance (Playwright)

1. Navigate to `/foods?meal=lunch&date=2026-04-26`.
2. Click the "Lunch ⌄" trigger — modal backdrop appears, card shows "Choose
   meal" heading and four meal links, current meal (Lunch) highlighted.
3. Press ESC — modal closes, body scroll restored.
4. Reopen, click the backdrop outside the card — closes.
5. Reopen, click "Dinner" — full-page navigation to `/foods?meal=dinner&...`,
   modal is gone, header now reads "Adding to Dinner".

## Open questions

None — design approved.
