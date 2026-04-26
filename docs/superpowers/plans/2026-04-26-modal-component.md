# Modal Component Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a reusable centered-card `ModalComponent` mounted in the layout, then port the meal switcher on `/foods` to it via a new `MealPickersController`.

**Architecture:** Single `ModalComponent` rendered once in `application.html.haml`. It owns the backdrop, card, close button, and a `<turbo-frame id="modal">` body slot. A Stimulus `modal_controller` toggles visibility on demand. Callers open it with `data-turbo-frame="modal"` (Turbo loads the response) plus `data-action="click->modal#open"` (Stimulus shows the chrome). Closing is via close button, backdrop click, or ESC; on close the frame's children are cleared so the next open fetches fresh.

**Tech Stack:** Rails 7, Hotwire (Turbo + Stimulus), ViewComponent (sidecar), HAML, Tailwind v4, Minitest, Playwright (acceptance).

**Spec:** `docs/superpowers/specs/2026-04-26-modal-component-design.md`

---

## File Structure

**Created:**
- `app/components/modal_component.rb` — empty `ViewComponent::Base` subclass
- `app/components/modal_component/modal_component.html.haml` — backdrop + card + frame
- `app/components/modal_component/modal_component.en.yml` — close button label
- `app/javascript/controllers/modal_controller.js` — open/close
- `app/controllers/meal_pickers_controller.rb` — `#show`
- `app/views/meal_pickers/show.html.haml` — frame-wrapped picker partial
- `test/components/modal_component_test.rb`
- `test/controllers/meal_pickers_controller_test.rb`

**Modified:**
- `config/routes.rb` — add `resource :meal_picker, only: :show`
- `app/views/layouts/application.html.haml` — render `ModalComponent.new`
- `app/views/foods/index.html.haml` — replace `<details>` block with modal trigger link
- `app/javascript/controllers/index.js` — register `modal_controller` (only if not auto-loaded; check first)

---

## Task 1: Generate the ModalComponent scaffold

**Files:**
- Create: `app/components/modal_component.rb`
- Create: `app/components/modal_component/modal_component.html.haml`
- Create: `app/components/modal_component/modal_component.en.yml`
- Create: `test/components/modal_component_test.rb`

- [ ] **Step 1: Run the generator (project convention requires this)**

```bash
bin/rails generate view_component:component Modal --sidecar --locale
```

Expected: creates `app/components/modal_component.rb`,
`app/components/modal_component/modal_component.html.erb` (we'll convert to HAML),
`app/components/modal_component/modal_component.en.yml`,
`test/components/modal_component_test.rb`.

- [ ] **Step 2: Convert the generated `.erb` template file to `.haml`**

```bash
rm app/components/modal_component/modal_component.html.erb
touch app/components/modal_component/modal_component.html.haml
```

- [ ] **Step 3: Verify the component class file is empty boilerplate**

Read `app/components/modal_component.rb`. It should look like:

```ruby
# frozen_string_literal: true

class ModalComponent < ViewComponent::Base
end
```

If the generator added an `initialize` taking attrs, replace the body with the empty version above (the component takes no constructor args).

- [ ] **Step 4: Commit the scaffold**

```bash
git add app/components/modal_component.rb app/components/modal_component/ test/components/modal_component_test.rb
git commit -m "Scaffold ModalComponent via generator"
```

---

## Task 2: Write failing tests for the component

**Files:**
- Modify: `test/components/modal_component_test.rb`

- [ ] **Step 1: Write the tests**

Replace the contents of `test/components/modal_component_test.rb` with:

```ruby
# frozen_string_literal: true

require "test_helper"

class ModalComponentTest < ViewComponent::TestCase
  test "renders a hidden root with the modal Stimulus controller" do
    render_inline(ModalComponent.new)
    assert_selector "[data-controller='modal'][data-modal-target='root'].hidden", visible: :all
  end

  test "renders an empty turbo-frame named modal as the body slot" do
    render_inline(ModalComponent.new)
    assert_selector "turbo-frame#modal[data-modal-target='frame']", visible: :all
  end

  test "renders a close button with an aria-label" do
    render_inline(ModalComponent.new)
    assert_selector "button[type='button'][aria-label][data-action*='modal#close']", visible: :all
  end

  test "backdrop closes the modal" do
    render_inline(ModalComponent.new)
    assert_selector "[data-action='click->modal#close'].bg-black\\/40", visible: :all
  end
end
```

- [ ] **Step 2: Run the tests, confirm they fail**

```bash
bin/rails test test/components/modal_component_test.rb
```

Expected: 4 failures/errors (template is empty, selectors don't match).

---

## Task 3: Implement the modal template

**Files:**
- Modify: `app/components/modal_component/modal_component.html.haml`
- Modify: `app/components/modal_component/modal_component.en.yml`

- [ ] **Step 1: Set the locale value**

Replace the contents of `app/components/modal_component/modal_component.en.yml` with:

```yaml
en:
  modal_component:
    close: "Close"
```

- [ ] **Step 2: Write the template**

Replace the contents of `app/components/modal_component/modal_component.html.haml` with:

```haml
%div.fixed.inset-0.z-50.hidden.items-center.justify-center.p-4{ data: { controller: "modal", modal_target: "root", action: "keydown.esc@window->modal#close" } }
  %div.absolute.inset-0{ class: "bg-black/40", data: { action: "click->modal#close" } }
  %div.relative.bg-bg.rounded-lg.shadow-xl.w-full.max-w-sm.overflow-auto{ class: "max-h-[85vh]" }
    %button.absolute.top-2.right-2.p-1.text-text-secondary.hover:text-text{ type: "button", "aria-label": t(".close"), data: { action: "click->modal#close" } }
      != '<svg class="w-5 h-5" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 256 256" fill="currentColor"><path d="M205.66,194.34a8,8,0,0,1-11.32,11.32L128,139.31,61.66,205.66a8,8,0,0,1-11.32-11.32L116.69,128,50.34,61.66A8,8,0,0,1,61.66,50.34L128,116.69l66.34-66.35a8,8,0,0,1,11.32,11.32L139.31,128Z"/></svg>'
    %div.p-4
      = turbo_frame_tag "modal", data: { modal_target: "frame" }
```

- [ ] **Step 3: Run the tests, confirm they pass**

```bash
bin/rails test test/components/modal_component_test.rb
```

Expected: 4 runs, 0 failures.

- [ ] **Step 4: Commit**

```bash
git add app/components/modal_component/ test/components/modal_component_test.rb
git commit -m "Implement ModalComponent template (centered card + turbo-frame)"
```

---

## Task 4: Add the Stimulus modal controller

**Files:**
- Create: `app/javascript/controllers/modal_controller.js`
- Possibly modify: `app/javascript/controllers/index.js`

- [ ] **Step 1: Check whether controllers are autoloaded**

Read `app/javascript/controllers/index.js`. If it uses
`eagerLoadControllersFrom("controllers", application)` from
`@hotwired/stimulus-loading`, no registration edit is needed. Otherwise note the
manual import pattern used by existing controllers (e.g. `search_controller`)
and replicate it for `modal_controller` after Step 2.

- [ ] **Step 2: Write the controller**

Create `app/javascript/controllers/modal_controller.js`:

```js
import { Controller } from "@hotwired/stimulus"

// Single layout-mounted modal. Triggers open with:
//   data-turbo-frame="modal" (Turbo fetches body into the frame)
//   data-action="click->modal#open" (we show the chrome)
// Close: backdrop click, close button, ESC key.
export default class extends Controller {
  static targets = ["root", "frame"]

  open() {
    this.rootTarget.classList.remove("hidden")
    this.rootTarget.classList.add("flex")
    document.body.classList.add("overflow-hidden")
  }

  close(event) {
    if (event) event.preventDefault()
    this.rootTarget.classList.add("hidden")
    this.rootTarget.classList.remove("flex")
    document.body.classList.remove("overflow-hidden")
    // Reset frame so the next open re-fetches.
    this.frameTarget.innerHTML = ""
  }
}
```

- [ ] **Step 3: Manually register if needed**

If Step 1 showed manual registration, add to `app/javascript/controllers/index.js`:

```js
import ModalController from "./modal_controller"
application.register("modal", ModalController)
```

Otherwise skip.

- [ ] **Step 4: Commit**

```bash
git add app/javascript/controllers/modal_controller.js app/javascript/controllers/index.js
git commit -m "Add modal Stimulus controller (open/close + scroll lock)"
```

---

## Task 5: Mount ModalComponent in the layout

**Files:**
- Modify: `app/views/layouts/application.html.haml`

- [ ] **Step 1: Add the render call**

Edit `app/views/layouts/application.html.haml`. After the `BottomNavComponent`
line, add:

```haml
    = render BottomNavComponent.new(current_path: request.path, viewed_date: @date)
    = render ModalComponent.new
```

(Indent so `ModalComponent.new` is at the same level as `BottomNavComponent`.)

- [ ] **Step 2: Rebuild Tailwind so new classes (e.g. `bg-black/40`, `max-h-[85vh]`) are picked up**

```bash
bin/rails tailwindcss:build
```

Expected: "Done in …ms".

- [ ] **Step 3: Sanity-check the page still renders**

Visit `http://localhost:3000/today` in the browser (Playwright or manual). The
page should look unchanged because the modal is hidden.

- [ ] **Step 4: Commit**

```bash
git add app/views/layouts/application.html.haml
git commit -m "Mount ModalComponent in application layout"
```

---

## Task 6: Add meal_picker route

**Files:**
- Modify: `config/routes.rb`

- [ ] **Step 1: Add the route**

In `config/routes.rb`, after the `resources :foods, …` line, add:

```ruby
  resource :meal_picker, only: :show
```

- [ ] **Step 2: Verify the route exists**

```bash
bin/rails routes -g meal_picker
```

Expected output includes:

```
meal_picker GET  /meal_picker(.:format)  meal_pickers#show
```

- [ ] **Step 3: Commit**

```bash
git add config/routes.rb
git commit -m "Add meal_picker route"
```

---

## Task 7: Write failing controller test for MealPickersController

**Files:**
- Create: `test/controllers/meal_pickers_controller_test.rb`

- [ ] **Step 1: Write the tests**

Create `test/controllers/meal_pickers_controller_test.rb`:

```ruby
require "test_helper"

class MealPickersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
  end

  test "renders a turbo-frame with all four meal links" do
    get meal_picker_path(meal: "lunch", date: "2026-04-26")
    assert_response :success
    assert_select "turbo-frame#modal" do
      FoodLogEntry.meals.each_key do |meal_key|
        assert_select "a[href*='meal=#{meal_key}']", text: /#{meal_key.capitalize}/i
        assert_select "a[href*='date=2026-04-26']"
      end
    end
  end

  test "highlights the currently selected meal" do
    get meal_picker_path(meal: "lunch", date: "2026-04-26")
    assert_response :success
    assert_select "a.text-primary.bg-primary-tint", text: /Lunch/i
  end

  test "preserves the search query when given" do
    get meal_picker_path(meal: "lunch", date: "2026-04-26", q: "apple")
    assert_response :success
    assert_select "a[href*='q=apple']"
  end
end
```

If the existing test suite uses a different auth helper (not `sign_in_as`),
match what `test/controllers/foods_controller_test.rb` does instead. Confirm by
reading that file before running.

- [ ] **Step 2: Run the tests, confirm they fail**

```bash
bin/rails test test/controllers/meal_pickers_controller_test.rb
```

Expected: errors — controller and view don't exist yet.

---

## Task 8: Implement MealPickersController and view

**Files:**
- Create: `app/controllers/meal_pickers_controller.rb`
- Create: `app/views/meal_pickers/show.html.haml`

- [ ] **Step 1: Write the controller**

Create `app/controllers/meal_pickers_controller.rb`:

```ruby
class MealPickersController < ApplicationController
  def show
    @current_meal = params[:meal]
    @date = params[:date]
    @query = params[:q]
  end
end
```

- [ ] **Step 2: Write the view**

Create `app/views/meal_pickers/show.html.haml`:

```haml
= turbo_frame_tag "modal" do
  %h2.text-lg.font-semibold.mb-3 Choose meal
  %ul.flex.flex-col.gap-1
    - FoodLogEntry.meals.each_key do |meal_key|
      - active = meal_key.to_s == @current_meal.to_s
      %li
        = link_to meal_key.to_s.capitalize, foods_path(meal: meal_key, date: @date, q: @query.presence), class: "block px-3 py-2 rounded-md #{active ? 'text-primary font-semibold bg-primary-tint' : 'text-text hover:bg-primary-tint'}"
```

- [ ] **Step 3: Rebuild Tailwind (the view introduces no new utility classes used elsewhere, but rerun to be safe)**

```bash
bin/rails tailwindcss:build
```

- [ ] **Step 4: Run the controller tests, confirm they pass**

```bash
bin/rails test test/controllers/meal_pickers_controller_test.rb
```

Expected: 3 runs, 0 failures.

- [ ] **Step 5: Commit**

```bash
git add app/controllers/meal_pickers_controller.rb app/views/meal_pickers/ test/controllers/meal_pickers_controller_test.rb
git commit -m "Add MealPickersController#show returning frame-wrapped picker"
```

---

## Task 9: Replace the `<details>` dropdown on /foods with the modal trigger

**Files:**
- Modify: `app/views/foods/index.html.haml` (lines 11–18)

- [ ] **Step 1: Read the current block**

Open `app/views/foods/index.html.haml` and locate lines 11–18 (the
`%details.relative.inline-block{ data: { meal_picker: true } }` block and its
`%summary` and `%ul` children).

- [ ] **Step 2: Replace it with a modal trigger link**

Replace those lines with:

```haml
          = link_to meal_picker_path(meal: @meal, date: @date, q: @query.presence), class: "text-primary font-semibold inline-flex items-center gap-1", data: { turbo_frame: "modal", action: "click->modal#open" } do
            = @meal.capitalize
            != '<svg class="w-3.5 h-3.5" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 256 256" fill="currentColor"><path d="M213.66,101.66l-80,80a8,8,0,0,1-11.32,0l-80-80A8,8,0,0,1,53.66,90.34L128,164.69l74.34-74.35a8,8,0,0,1,11.32,11.32Z"/></svg>'
```

Preserve the surrounding `text-base.text-text-secondary.font-medium.mb-1` line
and the `· #{date_label}` span exactly as they are.

- [ ] **Step 3: Run the full test suite to make sure nothing regressed**

```bash
bin/rails test
```

Expected: all tests that were passing before still pass. (One pre-existing
failure in `food_log_entries_controller_test.rb:42` is acceptable per current
baseline; verify only that no *new* failures appeared.)

- [ ] **Step 4: Commit**

```bash
git add app/views/foods/index.html.haml
git commit -m "Replace <details> meal picker with modal trigger"
```

---

## Task 10: Playwright acceptance

**Files:** none (manual verification per project convention)

- [ ] **Step 1: Restart dev server if not already running, build CSS once more**

```bash
bin/rails tailwindcss:build
```

(`bin/dev` should already be up; if not, start it.)

- [ ] **Step 2: Navigate and screenshot the closed state**

Use Playwright MCP:
- `mcp__playwright__browser_navigate` to `http://localhost:3000/foods?meal=lunch&date=2026-04-26`
- `mcp__playwright__browser_take_screenshot` (viewport)

Expected: page renders, "Adding to Lunch ⌄ · Today, Apr 26" visible. No modal.

- [ ] **Step 3: Click the trigger, screenshot the open state**

- `mcp__playwright__browser_snapshot` to find the trigger
- `mcp__playwright__browser_click` on the "Lunch" link
- `mcp__playwright__browser_take_screenshot`

Expected: backdrop dims the page, centered card shows "Choose meal" heading and
four meal links, Lunch highlighted (`text-primary` + `bg-primary-tint`).

- [ ] **Step 4: Press ESC, screenshot**

- `mcp__playwright__browser_press_key` "Escape"
- `mcp__playwright__browser_take_screenshot`

Expected: modal closed, page interactive again.

- [ ] **Step 5: Reopen, click backdrop**

- click trigger again
- click on the backdrop area (use coordinates outside the card, e.g. top-left
  corner)
- screenshot

Expected: modal closes.

- [ ] **Step 6: Reopen, click "Dinner"**

- click trigger
- click "Dinner" in the modal
- snapshot

Expected: full-page navigation to `/foods?meal=dinner&date=2026-04-26&...`,
page header now reads "Adding to Dinner", modal gone.

- [ ] **Step 7: Commit only if any fixes were needed during acceptance**

If acceptance revealed a bug and you fixed it, commit the fix:

```bash
git add <changed files>
git commit -m "Fix <issue> found in modal acceptance"
```

If no fixes were needed, no commit.

---

## Self-Review Notes

**Spec coverage check:**
- ModalComponent + sidecar template + locale → Tasks 1–3 ✓
- Stimulus controller (open/close/scroll lock/clear frame) → Task 4 ✓
- Layout mount → Task 5 ✓
- `resource :meal_picker, only: :show` → Task 6 ✓
- `MealPickersController#show` accepting meal/date/q → Tasks 7–8 ✓
- View wrapped in `turbo_frame_tag "modal"` with all four meals + active highlight → Tasks 7–8 ✓
- /foods trigger using modal → Task 9 ✓
- ModalComponentTest assertions (hidden root, frame#modal, close aria-label) → Task 2 ✓
- MealPickersControllerTest (4 meals, current highlighted, query preserved) → Task 7 ✓
- Playwright acceptance flow → Task 10 ✓

**Type/method consistency:** target names (`root`, `frame`), action names (`open`, `close`), frame id (`modal`), route helper (`meal_picker_path`), and instance vars (`@current_meal`, `@date`, `@query`) match across tasks.

**Placeholder scan:** none.
