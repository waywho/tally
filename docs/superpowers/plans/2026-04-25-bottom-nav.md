# Bottom Navigation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a floating, mobile-first bottom navigation bar to every page with five slots (Today, Search, +, Recipes, Profile). The center "+" infers the meal from the current time and routes to the meal-scoped foods index.

**Architecture:** A `MealInferrer` service maps wall-clock time to a meal symbol. A `BottomNavComponent` (ViewComponent) renders the bar, computes active states from the current request path, and uses `MealInferrer` for the `+` button. The component is rendered once in `application.html.haml`. Pages get `pb-24` so the floating nav does not cover content.

**Tech Stack:** Rails 7, Haml, Tailwind v4, ViewComponent, Minitest.

See the design doc: `docs/superpowers/specs/2026-04-25-bottom-nav-design.md`.

---

## File Structure

| Action  | File                                                                      | Responsibility                          |
| ------- | ------------------------------------------------------------------------- | --------------------------------------- |
| Create  | `app/services/meal_inferrer.rb`                                           | Time-of-day → meal symbol               |
| Create  | `test/services/meal_inferrer_test.rb`                                     | Service tests                           |
| Create  | `app/components/bottom_nav_component/bottom_nav_component.rb`             | Component class                         |
| Create  | `app/components/bottom_nav_component/bottom_nav_component.html.haml`      | Component template                      |
| Create  | `test/components/bottom_nav_component_test.rb`                            | Component tests                         |
| Modify  | `app/views/layouts/application.html.haml`                                 | Render component, add bottom padding    |
| Modify  | `app/views/days/show.html.haml`                                           | Remove gear icon (replaced by Profile)  |

---

### Task 1: MealInferrer service with TDD

- [ ] **Step 1: Write failing tests** — `test/services/meal_inferrer_test.rb`

```ruby
require "test_helper"

class MealInferrerTest < ActiveSupport::TestCase
  test "early morning maps to breakfast" do
    assert_equal :breakfast, MealInferrer.call(Time.zone.local(2026, 4, 25, 7, 0))
  end

  test "boundary 04:00 is breakfast" do
    assert_equal :breakfast, MealInferrer.call(Time.zone.local(2026, 4, 25, 4, 0))
  end

  test "boundary 10:30 flips to lunch" do
    assert_equal :lunch, MealInferrer.call(Time.zone.local(2026, 4, 25, 10, 30))
  end

  test "afternoon maps to snack" do
    assert_equal :snack, MealInferrer.call(Time.zone.local(2026, 4, 25, 15, 0))
  end

  test "evening maps to dinner" do
    assert_equal :dinner, MealInferrer.call(Time.zone.local(2026, 4, 25, 19, 0))
  end

  test "late night maps to snack" do
    assert_equal :snack, MealInferrer.call(Time.zone.local(2026, 4, 25, 23, 0))
  end

  test "after midnight maps to snack" do
    assert_equal :snack, MealInferrer.call(Time.zone.local(2026, 4, 25, 1, 30))
  end

  test "defaults to Time.current when no arg" do
    travel_to Time.zone.local(2026, 4, 25, 12, 0) do
      assert_equal :lunch, MealInferrer.call
    end
  end
end
```

- [ ] **Step 2: Verify tests fail** — `bin/rails test test/services/meal_inferrer_test.rb`

- [ ] **Step 3: Implement** — `app/services/meal_inferrer.rb`

```ruby
class MealInferrer
  def self.call(time = Time.current)
    minutes = time.hour * 60 + time.min

    case minutes
    when (4 * 60)...(10 * 60 + 30)  then :breakfast
    when (10 * 60 + 30)...(14 * 60 + 30) then :lunch
    when (14 * 60 + 30)...(17 * 60 + 30) then :snack
    when (17 * 60 + 30)...(21 * 60 + 30) then :dinner
    else :snack
    end
  end
end
```

- [ ] **Step 4: Tests pass** — `bin/rails test test/services/meal_inferrer_test.rb`

- [ ] **Step 5: Commit**

```bash
git add app/services/meal_inferrer.rb test/services/meal_inferrer_test.rb
git commit -m "Add MealInferrer for time-of-day meal detection"
```

---

### Task 2: BottomNavComponent

- [ ] **Step 1: Scaffold via generator** (project convention — never create component files manually)

```bash
bin/rails generate view_component:component BottomNav --sidecar
```

- [ ] **Step 2: Write component class** — `app/components/bottom_nav_component/bottom_nav_component.rb`

```ruby
class BottomNavComponent < ViewComponent::Base
  def initialize(current_path:, viewed_date: nil)
    @current_path = current_path
    @viewed_date = viewed_date
  end

  def add_path
    helpers.foods_path(meal: MealInferrer.call, date: (@viewed_date || Date.current).iso8601)
  end

  def today_active?
    @current_path.start_with?("/today") || @current_path.match?(%r{\A/days/})
  end

  def search_active?
    @current_path == "/foods" || @current_path.start_with?("/foods?")
  end

  def recipes_active?
    @current_path.start_with?("/recipes")
  end

  def profile_active?
    @current_path.start_with?("/settings")
  end
end
```

- [ ] **Step 3: Write template** — `app/components/bottom_nav_component/bottom_nav_component.html.haml`

```haml
%nav.fixed.bottom-0.left-0.right-0.z-40.pointer-events-none{ "aria-label": "Primary" }
  .max-w-lg.mx-auto.px-4.pb-[env(safe-area-inset-bottom)]
    .pointer-events-auto.relative.flex.items-end.justify-around.gap-1.bg-bg-page/90.backdrop-blur-md.border.border-border.rounded-full.shadow-lg.px-3.py-2.mb-3
      = link_to today_path, class: "flex flex-col items-center justify-center w-14 py-1 text-xs #{today_active? ? 'text-primary' : 'text-text-secondary'}", "aria-current": (today_active? ? "page" : nil) do
        != '<svg class="w-6 h-6" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="2" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" d="M2.25 12 12 3l9.75 9M4.5 10.5V21h15V10.5"/></svg>'
        %span Today
      = link_to foods_path, class: "flex flex-col items-center justify-center w-14 py-1 text-xs #{search_active? ? 'text-primary' : 'text-text-secondary'}", "aria-current": (search_active? ? "page" : nil) do
        != '<svg class="w-6 h-6" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="2" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" d="m21 21-4.3-4.3M10.5 18a7.5 7.5 0 1 0 0-15 7.5 7.5 0 0 0 0 15Z"/></svg>'
        %span Search
      = link_to add_path, class: "-translate-y-3 flex items-center justify-center w-14 h-14 rounded-full bg-primary text-white shadow-lg hover:opacity-90 transition", "aria-label": "Add food" do
        != '<svg class="w-7 h-7" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="2.5" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" d="M12 4.5v15m7.5-7.5h-15"/></svg>'
      = link_to recipes_path, class: "flex flex-col items-center justify-center w-14 py-1 text-xs #{recipes_active? ? 'text-primary' : 'text-text-secondary'}", "aria-current": (recipes_active? ? "page" : nil) do
        != '<svg class="w-6 h-6" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="2" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" d="M4 19.5A2.5 2.5 0 0 1 6.5 17H20M6.5 2h13.5v17H6.5A2.5 2.5 0 0 1 4 16.5v-12A2.5 2.5 0 0 1 6.5 2Z"/></svg>'
        %span Recipes
      = link_to edit_settings_path, class: "flex flex-col items-center justify-center w-14 py-1 text-xs #{profile_active? ? 'text-primary' : 'text-text-secondary'}", "aria-current": (profile_active? ? "page" : nil) do
        != '<svg class="w-6 h-6" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="2" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" d="M15.75 7.5a3.75 3.75 0 1 1-7.5 0 3.75 3.75 0 0 1 7.5 0ZM4.5 20.25a7.5 7.5 0 0 1 15 0"/></svg>'
        %span Profile
```

- [ ] **Step 4: Component tests** — `test/components/bottom_nav_component_test.rb`

```ruby
require "test_helper"

class BottomNavComponentTest < ViewComponent::TestCase
  test "renders all five slots" do
    render_inline(BottomNavComponent.new(current_path: "/today"))
    assert_selector "a", text: "Today"
    assert_selector "a", text: "Search"
    assert_selector "a[aria-label='Add food']"
    assert_selector "a", text: "Recipes"
    assert_selector "a", text: "Profile"
  end

  test "marks Today active on /today" do
    render_inline(BottomNavComponent.new(current_path: "/today"))
    assert_selector "a[aria-current='page']", text: "Today"
  end

  test "marks Today active on /days/:date" do
    render_inline(BottomNavComponent.new(current_path: "/days/2026-04-25"))
    assert_selector "a[aria-current='page']", text: "Today"
  end

  test "marks Recipes active on /recipes" do
    render_inline(BottomNavComponent.new(current_path: "/recipes"))
    assert_selector "a[aria-current='page']", text: "Recipes"
  end

  test "marks Profile active on /settings/edit" do
    render_inline(BottomNavComponent.new(current_path: "/settings/edit"))
    assert_selector "a[aria-current='page']", text: "Profile"
  end

  test "add button uses inferred meal and viewed date" do
    travel_to Time.zone.local(2026, 4, 25, 12, 0) do
      render_inline(BottomNavComponent.new(current_path: "/today", viewed_date: Date.new(2026, 4, 20)))
      assert_selector "a[aria-label='Add food'][href*='meal=lunch'][href*='date=2026-04-20']"
    end
  end

  test "add button defaults to today when viewed_date is nil" do
    travel_to Time.zone.local(2026, 4, 25, 8, 0) do
      render_inline(BottomNavComponent.new(current_path: "/recipes"))
      assert_selector "a[aria-label='Add food'][href*='meal=breakfast'][href*='date=2026-04-25']"
    end
  end
end
```

- [ ] **Step 5: Tests pass** — `bin/rails test test/components/bottom_nav_component_test.rb`

- [ ] **Step 6: Commit**

```bash
git add app/components/bottom_nav_component test/components/bottom_nav_component_test.rb
git commit -m "Add BottomNavComponent with five-slot floating nav"
```

---

### Task 3: Render in layout & remove gear icon

- [ ] **Step 1: Update `app/views/layouts/application.html.haml`**

Change `%main.max-w-lg.mx-auto.px-4.py-6.relative` to `%main.max-w-lg.mx-auto.px-4.pt-6.pb-24.relative`. After `= yield` add:

```haml
    = render BottomNavComponent.new(current_path: request.path, viewed_date: @date)
```

- [ ] **Step 2: Remove gear icon from `app/views/days/show.html.haml`**

Remove lines 2–4 (the `.flex.justify-end.mb-2` div containing the settings link).

- [ ] **Step 3: Full test suite** — `bin/rails test`

- [ ] **Step 4: Commit**

```bash
git add app/views/layouts/application.html.haml app/views/days/show.html.haml
git commit -m "Render BottomNavComponent globally; remove redundant gear icon"
```

---

### Task 4: Playwright acceptance

- [ ] Sign in, visit `/today`. Confirm the floating nav appears, Today is highlighted, content is not covered.
- [ ] Tap Search → lands on `/foods`, Search highlighted.
- [ ] Tap `+` → lands on `/foods?meal=<expected>&date=<today>`, meal-scoped header shows.
- [ ] Tap Recipes → `/recipes`, Recipes highlighted.
- [ ] Tap Profile → `/settings/edit`, Profile highlighted.
- [ ] Navigate to a non-today day (`/days/2026-04-23`) and tap `+` — confirm the date param matches the viewed date.
- [ ] Confirm gear icon no longer appears on the day view.
