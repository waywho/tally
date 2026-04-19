# Tailwind Theme + Base Components Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Establish the visual foundation for Tally — custom Tailwind theme tokens, 5 ViewComponents, and a Lookbook preview page.

**Architecture:** Tailwind v4 `@theme` block defines color tokens in `application.css`. Five ViewComponents (`ButtonComponent`, `CardComponent`, `ListRowComponent`, `BucketHeaderComponent`, `CaloriePillComponent`) use those tokens via Tailwind utility classes. Lookbook provides a live preview gallery in development.

**Tech Stack:** Rails 8.1.3, Tailwind CSS v4 (via tailwindcss-rails 4.4.0), ViewComponent 4.7.0, Lookbook, Minitest

---

## File Structure

| File | Responsibility |
|---|---|
| `app/assets/tailwind/application.css` | Modify: add `@theme` block with color tokens |
| `app/views/layouts/application.html.erb` | Modify: page bg, flash messages, page title |
| `app/components/button_component.rb` | Create: button/link rendering logic |
| `app/components/button_component.html.erb` | Create: button template |
| `app/components/card_component.rb` | Create: card container logic |
| `app/components/card_component.html.erb` | Create: card template |
| `app/components/list_row_component.rb` | Create: food row logic |
| `app/components/list_row_component.html.erb` | Create: food row template |
| `app/components/bucket_header_component.rb` | Create: meal header logic |
| `app/components/bucket_header_component.html.erb` | Create: meal header template |
| `app/components/calorie_pill_component.rb` | Create: daily progress logic |
| `app/components/calorie_pill_component.html.erb` | Create: daily progress template |
| `test/components/button_component_test.rb` | Create: button tests |
| `test/components/card_component_test.rb` | Create: card tests |
| `test/components/list_row_component_test.rb` | Create: list row tests |
| `test/components/bucket_header_component_test.rb` | Create: bucket header tests |
| `test/components/calorie_pill_component_test.rb` | Create: calorie pill tests |
| `test/components/previews/button_component_preview.rb` | Create: Lookbook preview |
| `test/components/previews/card_component_preview.rb` | Create: Lookbook preview |
| `test/components/previews/list_row_component_preview.rb` | Create: Lookbook preview |
| `test/components/previews/bucket_header_component_preview.rb` | Create: Lookbook preview |
| `test/components/previews/calorie_pill_component_preview.rb` | Create: Lookbook preview |
| `Gemfile` | Modify: add `lookbook` gem |
| `config/routes.rb` | Modify: mount Lookbook engine |

---

### Task 1: Tailwind Theme Tokens

**Files:**
- Modify: `app/assets/tailwind/application.css`
- Modify: `app/views/layouts/application.html.erb`

- [ ] **Step 1: Add `@theme` block with color tokens**

Replace the contents of `app/assets/tailwind/application.css` with:

```css
@import "tailwindcss";

@theme {
  --color-primary: #16A34A;
  --color-primary-light: #4ADE80;
  --color-primary-muted: #BBF7D0;
  --color-primary-tint: #F0FDF4;

  --color-text: #1C1917;
  --color-text-secondary: #78716C;

  --color-bg: #FFFFFF;
  --color-bg-page: #F5F5F4;

  --color-border: #E7E5E4;

  --color-danger: #EF4444;
}
```

This makes classes like `bg-primary`, `text-text-secondary`, `border-border`, etc. available throughout the app.

- [ ] **Step 2: Update the application layout**

Replace `app/views/layouts/application.html.erb` with:

```erb
<!DOCTYPE html>
<html>
  <head>
    <title><%= @page_title || "Tally" %></title>
    <meta name="viewport" content="width=device-width,initial-scale=1">
    <meta name="apple-mobile-web-app-capable" content="yes">
    <meta name="application-name" content="Tally">
    <meta name="mobile-web-app-capable" content="yes">
    <%= csrf_meta_tags %>
    <%= csp_meta_tag %>

    <%= yield :head %>

    <link rel="icon" href="/icon.png" type="image/png">
    <link rel="icon" href="/icon.svg" type="image/svg+xml">
    <link rel="apple-touch-icon" href="/icon.png">

    <%= stylesheet_link_tag :app, "data-turbo-track": "reload" %>
    <%= javascript_importmap_tags %>
  </head>

  <body class="bg-bg-page text-text font-sans antialiased">
    <main class="max-w-lg mx-auto px-4 py-6">
      <% if notice %>
        <div class="mb-4 p-3 bg-primary-tint text-primary text-sm rounded-md"><%= notice %></div>
      <% end %>
      <% if alert %>
        <div class="mb-4 p-3 bg-red-50 text-danger text-sm rounded-md"><%= alert %></div>
      <% end %>

      <%= yield %>
    </main>
  </body>
</html>
```

- [ ] **Step 3: Verify Tailwind compiles with new tokens**

Run: `bin/rails tailwindcss:build`
Expected: exits 0, no errors. `app/assets/builds/tailwind.css` contains the custom color values.

- [ ] **Step 4: Commit**

```bash
git add app/assets/tailwind/application.css app/views/layouts/application.html.erb
git commit -m "feat: add Tailwind v4 theme tokens and update layout"
```

---

### Task 2: Lookbook Setup

**Files:**
- Modify: `Gemfile`
- Modify: `config/routes.rb`

- [ ] **Step 1: Add lookbook gem**

Add to the `:development` group in `Gemfile`:

```ruby
  # Component previews [https://lookbook.build/]
  gem "lookbook"
```

- [ ] **Step 2: Bundle install**

Run: `bundle install`
Expected: Lookbook and its dependencies install successfully.

- [ ] **Step 3: Mount Lookbook in routes**

Add inside the `Rails.application.routes.draw` block in `config/routes.rb`, before the health check:

```ruby
  mount Lookbook::Engine, at: "/lookbook" if Rails.env.development?
```

- [ ] **Step 4: Verify Lookbook boots**

Run: `bin/rails server` and visit `http://localhost:3000/lookbook`
Expected: Lookbook UI loads (empty, no previews yet). Stop the server.

- [ ] **Step 5: Commit**

```bash
git add Gemfile Gemfile.lock config/routes.rb
git commit -m "feat: add Lookbook for component previews"
```

---

### Task 3: ButtonComponent

**Files:**
- Create: `app/components/button_component.rb`
- Create: `app/components/button_component.html.erb`
- Create: `test/components/button_component_test.rb`
- Create: `test/components/previews/button_component_preview.rb`

- [ ] **Step 1: Write the failing test**

Create `test/components/button_component_test.rb`:

```ruby
require "test_helper"

class ButtonComponentTest < ViewComponent::TestCase
  test "renders primary button with label" do
    render_inline(ButtonComponent.new(label: "Log Breakfast"))

    assert_selector "button.bg-primary", text: "Log Breakfast"
  end

  test "renders secondary button" do
    render_inline(ButtonComponent.new(label: "Cancel", scheme: :secondary))

    assert_selector "button.border-primary", text: "Cancel"
    assert_no_selector "button.bg-primary"
  end

  test "renders small size" do
    render_inline(ButtonComponent.new(label: "Add", size: :sm))

    assert_selector "button.px-3.py-1\\.5.text-sm"
  end

  test "renders as link when tag is :a" do
    render_inline(ButtonComponent.new(label: "Go", tag: :a, href: "/foods"))

    assert_selector "a[href='/foods']", text: "Go"
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/components/button_component_test.rb`
Expected: FAIL — `NameError: uninitialized constant ButtonComponent`

- [ ] **Step 3: Write the component**

Create `app/components/button_component.rb`:

```ruby
class ButtonComponent < ViewComponent::Base
  SCHEMES = {
    primary: "bg-primary text-white hover:bg-primary-light",
    secondary: "bg-white text-primary border border-primary hover:bg-primary-tint"
  }.freeze

  SIZES = {
    sm: "px-3 py-1.5 text-sm",
    md: "px-4 py-2.5 text-base"
  }.freeze

  def initialize(label:, scheme: :primary, size: :md, tag: :button, **system_arguments)
    @label = label
    @scheme = scheme
    @size = size
    @tag = tag
    @system_arguments = system_arguments
  end

  def call
    content_tag(
      @tag,
      @label,
      class: class_names,
      **@system_arguments
    )
  end

  private

  def class_names
    [
      "inline-flex items-center justify-center font-semibold rounded-md transition-colors cursor-pointer",
      SCHEMES.fetch(@scheme),
      SIZES.fetch(@size)
    ].join(" ")
  end
end
```

No `.html.erb` template needed — this component uses `call` directly.

- [ ] **Step 4: Run test to verify it passes**

Run: `bin/rails test test/components/button_component_test.rb`
Expected: 4 tests, 0 failures

- [ ] **Step 5: Add Lookbook preview**

Create `test/components/previews/button_component_preview.rb`:

```ruby
class ButtonComponentPreview < Lookbook::Preview
  # @label Primary (md)
  def primary
    render ButtonComponent.new(label: "Log Breakfast", scheme: :primary)
  end

  # @label Primary (sm)
  def primary_small
    render ButtonComponent.new(label: "+ Add", scheme: :primary, size: :sm)
  end

  # @label Secondary (md)
  def secondary
    render ButtonComponent.new(label: "Cancel", scheme: :secondary)
  end

  # @label Secondary (sm)
  def secondary_small
    render ButtonComponent.new(label: "Edit", scheme: :secondary, size: :sm)
  end

  # @label As link
  def as_link
    render ButtonComponent.new(label: "View Food", tag: :a, href: "#")
  end
end
```

- [ ] **Step 6: Commit**

```bash
git add app/components/button_component.rb test/components/button_component_test.rb test/components/previews/button_component_preview.rb
git commit -m "feat: add ButtonComponent with primary/secondary schemes"
```

---

### Task 4: CardComponent

**Files:**
- Create: `app/components/card_component.rb`
- Create: `app/components/card_component.html.erb`
- Create: `test/components/card_component_test.rb`
- Create: `test/components/previews/card_component_preview.rb`

- [ ] **Step 1: Write the failing test**

Create `test/components/card_component_test.rb`:

```ruby
require "test_helper"

class CardComponentTest < ViewComponent::TestCase
  test "renders card with content block" do
    render_inline(CardComponent.new) { "Hello" }

    assert_selector "div.bg-bg.border.border-border.rounded-md.overflow-hidden", text: "Hello"
  end

  test "passes through additional classes" do
    render_inline(CardComponent.new(class: "mt-4")) { "Content" }

    assert_selector "div.mt-4.bg-bg"
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/components/card_component_test.rb`
Expected: FAIL — `NameError: uninitialized constant CardComponent`

- [ ] **Step 3: Write the component**

Create `app/components/card_component.rb`:

```ruby
class CardComponent < ViewComponent::Base
  def initialize(**system_arguments)
    @system_arguments = system_arguments
  end
end
```

Create `app/components/card_component.html.erb`:

```erb
<%= content_tag :div, content, class: ["bg-bg border border-border rounded-md overflow-hidden", @system_arguments[:class]], **@system_arguments.except(:class) %>
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bin/rails test test/components/card_component_test.rb`
Expected: 2 tests, 0 failures

- [ ] **Step 5: Add Lookbook preview**

Create `test/components/previews/card_component_preview.rb`:

```ruby
class CardComponentPreview < Lookbook::Preview
  # @label Default card
  def default
    render CardComponent.new do
      tag.div(class: "p-4") do
        tag.h3("Breakfast", class: "font-semibold text-text") +
        tag.p("3 items logged", class: "text-sm text-text-secondary mt-1")
      end
    end
  end
end
```

- [ ] **Step 6: Commit**

```bash
git add app/components/card_component.rb app/components/card_component.html.erb test/components/card_component_test.rb test/components/previews/card_component_preview.rb
git commit -m "feat: add CardComponent"
```

---

### Task 5: ListRowComponent

**Files:**
- Create: `app/components/list_row_component.rb`
- Create: `app/components/list_row_component.html.erb`
- Create: `test/components/list_row_component_test.rb`
- Create: `test/components/previews/list_row_component_preview.rb`

- [ ] **Step 1: Write the failing test**

Create `test/components/list_row_component_test.rb`:

```ruby
require "test_helper"

class ListRowComponentTest < ViewComponent::TestCase
  test "renders label and value" do
    render_inline(ListRowComponent.new(label: "Oatmeal with banana", value: "320 cal"))

    assert_text "Oatmeal with banana"
    assert_selector ".text-primary.font-semibold", text: "320 cal"
  end

  test "renders with flex layout" do
    render_inline(ListRowComponent.new(label: "Greek yogurt", value: "150 cal"))

    assert_selector "div.flex.justify-between.items-center"
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/components/list_row_component_test.rb`
Expected: FAIL — `NameError: uninitialized constant ListRowComponent`

- [ ] **Step 3: Write the component**

Create `app/components/list_row_component.rb`:

```ruby
class ListRowComponent < ViewComponent::Base
  def initialize(label:, value:, **system_arguments)
    @label = label
    @value = value
    @system_arguments = system_arguments
  end
end
```

Create `app/components/list_row_component.html.erb`:

```erb
<div class="flex justify-between items-center px-4 py-3 border-b border-border last:border-b-0" <%= tag.attributes(**@system_arguments) %>>
  <span class="text-text"><%= @label %></span>
  <span class="text-primary font-semibold text-sm"><%= @value %></span>
</div>
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bin/rails test test/components/list_row_component_test.rb`
Expected: 2 tests, 0 failures

- [ ] **Step 5: Add Lookbook preview**

Create `test/components/previews/list_row_component_preview.rb`:

```ruby
class ListRowComponentPreview < Lookbook::Preview
  # @label Food items in a card
  def default
    render_with_template(template: "list_row_component_preview/default")
  end
end
```

Create `test/components/previews/list_row_component_preview/default.html.erb`:

```erb
<%= render CardComponent.new do %>
  <%= render ListRowComponent.new(label: "Oatmeal with banana", value: "320 cal") %>
  <%= render ListRowComponent.new(label: "Greek yogurt", value: "150 cal") %>
  <%= render ListRowComponent.new(label: "Black coffee", value: "5 cal") %>
<% end %>
```

- [ ] **Step 6: Commit**

```bash
git add app/components/list_row_component.rb app/components/list_row_component.html.erb test/components/list_row_component_test.rb test/components/previews/list_row_component_preview.rb test/components/previews/list_row_component_preview/
git commit -m "feat: add ListRowComponent"
```

---

### Task 6: BucketHeaderComponent

**Files:**
- Create: `app/components/bucket_header_component.rb`
- Create: `app/components/bucket_header_component.html.erb`
- Create: `test/components/bucket_header_component_test.rb`
- Create: `test/components/previews/bucket_header_component_preview.rb`

- [ ] **Step 1: Write the failing test**

Create `test/components/bucket_header_component_test.rb`:

```ruby
require "test_helper"

class BucketHeaderComponentTest < ViewComponent::TestCase
  test "renders meal name" do
    render_inline(BucketHeaderComponent.new(meal: "Breakfast", subtotal: 470, add_path: "/days/2026-04-19/meals/breakfast/entries/new"))

    assert_selector ".font-semibold.text-primary", text: "Breakfast"
  end

  test "renders subtotal" do
    render_inline(BucketHeaderComponent.new(meal: "Lunch", subtotal: 620, add_path: "#"))

    assert_text "620 cal"
  end

  test "renders add link" do
    render_inline(BucketHeaderComponent.new(meal: "Dinner", subtotal: 0, add_path: "/add"))

    assert_selector "a[href='/add']", text: "+ Add"
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/components/bucket_header_component_test.rb`
Expected: FAIL — `NameError: uninitialized constant BucketHeaderComponent`

- [ ] **Step 3: Write the component**

Create `app/components/bucket_header_component.rb`:

```ruby
class BucketHeaderComponent < ViewComponent::Base
  def initialize(meal:, subtotal:, add_path:)
    @meal = meal
    @subtotal = subtotal
    @add_path = add_path
  end
end
```

Create `app/components/bucket_header_component.html.erb`:

```erb
<div class="bg-primary-tint px-4 py-3 flex justify-between items-center">
  <div class="flex items-center gap-3">
    <span class="font-semibold text-primary text-sm"><%= @meal %></span>
    <span class="text-text-secondary text-xs"><%= @subtotal %> cal</span>
  </div>
  <a href="<%= @add_path %>" class="text-primary text-sm font-medium hover:text-primary-light">+ Add</a>
</div>
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bin/rails test test/components/bucket_header_component_test.rb`
Expected: 3 tests, 0 failures

- [ ] **Step 5: Add Lookbook preview**

Create `test/components/previews/bucket_header_component_preview.rb`:

```ruby
class BucketHeaderComponentPreview < Lookbook::Preview
  # @label Breakfast with entries
  def with_entries
    render_with_template(template: "bucket_header_component_preview/with_entries")
  end

  # @label Empty bucket
  def empty
    render BucketHeaderComponent.new(meal: "Snacks", subtotal: 0, add_path: "#")
  end
end
```

Create `test/components/previews/bucket_header_component_preview/with_entries.html.erb`:

```erb
<%= render CardComponent.new do %>
  <%= render BucketHeaderComponent.new(meal: "Breakfast", subtotal: 470, add_path: "#") %>
  <%= render ListRowComponent.new(label: "Oatmeal with banana", value: "320 cal") %>
  <%= render ListRowComponent.new(label: "Greek yogurt", value: "150 cal") %>
<% end %>
```

- [ ] **Step 6: Commit**

```bash
git add app/components/bucket_header_component.rb app/components/bucket_header_component.html.erb test/components/bucket_header_component_test.rb test/components/previews/bucket_header_component_preview.rb test/components/previews/bucket_header_component_preview/
git commit -m "feat: add BucketHeaderComponent"
```

---

### Task 7: CaloriePillComponent

**Files:**
- Create: `app/components/calorie_pill_component.rb`
- Create: `app/components/calorie_pill_component.html.erb`
- Create: `test/components/calorie_pill_component_test.rb`
- Create: `test/components/previews/calorie_pill_component_preview.rb`

- [ ] **Step 1: Write the failing test**

Create `test/components/calorie_pill_component_test.rb`:

```ruby
require "test_helper"

class CaloriePillComponentTest < ViewComponent::TestCase
  test "renders eaten and target calories" do
    render_inline(CaloriePillComponent.new(
      eaten: 470, target: 2000,
      protein: "28g / 150g", carbs: "52g / 250g", fat: "12g / 67g", fiber: "8g / 30g"
    ))

    assert_text "470"
    assert_text "/ 2,000 cal"
    assert_text "1,530 remaining"
  end

  test "renders macro summary with fiber" do
    render_inline(CaloriePillComponent.new(
      eaten: 470, target: 2000,
      protein: "28g / 150g", carbs: "52g / 250g", fat: "12g / 67g", fiber: "8g / 30g"
    ))

    assert_text "P: 28g / 150g"
    assert_text "C: 52g / 250g"
    assert_text "F: 12g / 67g"
    assert_text "Fiber: 8g / 30g"
  end

  test "renders progress bar at correct width" do
    render_inline(CaloriePillComponent.new(
      eaten: 500, target: 2000,
      protein: "0g / 0g", carbs: "0g / 0g", fat: "0g / 0g", fiber: "0g / 0g"
    ))

    assert_selector "[style*='width: 25%']"
  end

  test "shows over-target state" do
    render_inline(CaloriePillComponent.new(
      eaten: 2150, target: 2000,
      protein: "0g / 0g", carbs: "0g / 0g", fat: "0g / 0g", fiber: "0g / 0g"
    ))

    assert_text "150 over"
    assert_selector ".bg-danger"
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/components/calorie_pill_component_test.rb`
Expected: FAIL — `NameError: uninitialized constant CaloriePillComponent`

- [ ] **Step 3: Write the component**

Create `app/components/calorie_pill_component.rb`:

```ruby
class CaloriePillComponent < ViewComponent::Base
  def initialize(eaten:, target:, protein:, carbs:, fat:, fiber:)
    @eaten = eaten
    @target = target
    @protein = protein
    @carbs = carbs
    @fat = fat
    @fiber = fiber
  end

  def remaining
    @target - @eaten
  end

  def over_target?
    @eaten > @target
  end

  def progress_percent
    return 100 if over_target?
    return 0 if @target.zero?
    ((@eaten.to_f / @target) * 100).round
  end

  def formatted_target
    ActiveSupport::NumberHelper.number_to_delimited(@target)
  end

  def formatted_remaining
    ActiveSupport::NumberHelper.number_to_delimited(remaining.abs)
  end
end
```

Create `app/components/calorie_pill_component.html.erb`:

```erb
<%= render CardComponent.new(class: "p-4") do %>
  <div class="flex justify-between items-baseline mb-3">
    <div>
      <span class="text-3xl font-bold text-text"><%= @eaten %></span>
      <span class="text-sm text-text-secondary">/ <%= formatted_target %> cal</span>
    </div>
    <% if over_target? %>
      <span class="text-sm font-semibold text-danger"><%= formatted_remaining %> over</span>
    <% else %>
      <span class="text-sm font-semibold text-primary"><%= formatted_remaining %> remaining</span>
    <% end %>
  </div>

  <div class="h-2 bg-primary-tint rounded overflow-hidden">
    <div class="h-full rounded <%= over_target? ? 'bg-danger' : 'bg-primary' %>" style="width: <%= progress_percent %>%"></div>
  </div>

  <div class="flex gap-4 mt-3">
    <span class="text-xs text-text-secondary">P: <%= @protein %></span>
    <span class="text-xs text-text-secondary">C: <%= @carbs %></span>
    <span class="text-xs text-text-secondary">F: <%= @fat %></span>
    <span class="text-xs text-text-secondary">Fiber: <%= @fiber %></span>
  </div>
<% end %>
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bin/rails test test/components/calorie_pill_component_test.rb`
Expected: 4 tests, 0 failures

- [ ] **Step 5: Add Lookbook preview**

Create `test/components/previews/calorie_pill_component_preview.rb`:

```ruby
class CaloriePillComponentPreview < Lookbook::Preview
  # @label Normal (470 / 2,000)
  def normal
    render CaloriePillComponent.new(
      eaten: 470, target: 2000,
      protein: "28g / 150g", carbs: "52g / 250g", fat: "12g / 67g", fiber: "8g / 30g"
    )
  end

  # @label Over target (2,150 / 2,000)
  def over_target
    render CaloriePillComponent.new(
      eaten: 2150, target: 2000,
      protein: "165g / 150g", carbs: "280g / 250g", fat: "72g / 67g", fiber: "35g / 30g"
    )
  end

  # @label Empty day
  def empty_day
    render CaloriePillComponent.new(
      eaten: 0, target: 2000,
      protein: "0g / 150g", carbs: "0g / 250g", fat: "0g / 67g", fiber: "0g / 30g"
    )
  end
end
```

- [ ] **Step 6: Commit**

```bash
git add app/components/calorie_pill_component.rb app/components/calorie_pill_component.html.erb test/components/calorie_pill_component_test.rb test/components/previews/calorie_pill_component_preview.rb
git commit -m "feat: add CaloriePillComponent with over-target state"
```

---

### Task 8: Full Test Suite + Final Verification

- [ ] **Step 1: Run all component tests**

Run: `bin/rails test test/components/`
Expected: 15 tests, 0 failures

- [ ] **Step 2: Run full test suite**

Run: `bin/rails test`
Expected: All tests pass (no regressions)

- [ ] **Step 3: Run rubocop**

Run: `bin/rubocop app/components/ test/components/`
Expected: No offenses

- [ ] **Step 4: Verify Lookbook shows all 5 components**

Run: `bin/rails server` and visit `http://localhost:3000/lookbook`
Expected: All 5 components visible in the sidebar with their preview scenarios rendering correctly. Stop the server.

- [ ] **Step 5: Final commit (if any lint fixes were needed)**

```bash
git add -A
git commit -m "chore: lint fixes for components"
```
