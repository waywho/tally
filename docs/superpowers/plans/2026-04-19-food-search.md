# Food Search Endpoint + UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a food search feature with local-first database search and automatic fallback to USDA/OFF APIs, rendered as a Turbo Frame with debounced Stimulus input.

**Architecture:** A `FoodSearch` service orchestrates multi-source queries (local PostgreSQL tsvector/trigram → OFF API → USDA API). `FoodsController#index` delegates to the service and renders results in a Turbo Frame. A Stimulus `search` controller handles 300ms debounce with 3-character minimum.

**Tech Stack:** Rails 8.1, PostgreSQL (tsvector, pg_trgm), Turbo Frames, Stimulus, Haml, Tailwind CSS

---

## File Structure

| Action | File | Responsibility |
|--------|------|----------------|
| Create | `app/services/food_search.rb` | Multi-source search orchestration |
| Create | `test/services/food_search_test.rb` | FoodSearch unit tests |
| Create | `app/controllers/foods_controller.rb` | Search endpoint (index action) |
| Create | `test/controllers/foods_controller_test.rb` | Controller integration tests |
| Create | `app/views/foods/index.html.haml` | Search page with input + Turbo Frame |
| Create | `app/views/foods/_results.html.haml` | Search results partial |
| Create | `app/javascript/controllers/search_controller.js` | Debounce + Turbo Frame submission |
| Modify | `config/routes.rb` | Add `resources :foods, only: [:index]` |
| Modify | `app/models/food.rb` | Add `search` scope |

---

### Task 1: Add search scope to Food model

**Files:**
- Modify: `app/models/food.rb`
- Create: `test/models/food_search_scope_test.rb`

- [ ] **Step 1: Write the failing tests**

Create `test/models/food_search_scope_test.rb`:

```ruby
require "test_helper"

class FoodSearchScopeTest < ActiveSupport::TestCase
  setup do
    @chicken = create(:food, name: "Chicken breast, raw", brand: nil, source: :usda, external_id: "usda-chicken")
    @chicken_stir = create(:food, name: "Chicken stir fry", brand: "Homemade", source: :user, external_id: nil, creator: create(:user))
    @pasta = create(:food, name: "Pasta, dry", brand: "Barilla", source: :off, external_id: "off-pasta")
  end

  test "search finds foods by name using full-text search" do
    results = Food.search("chicken")

    assert_includes results, @chicken
    assert_includes results, @chicken_stir
    assert_not_includes results, @pasta
  end

  test "search finds foods by brand" do
    results = Food.search("barilla")

    assert_includes results, @pasta
    assert_not_includes results, @chicken
  end

  test "search returns empty when no matches" do
    results = Food.search("nonexistent food xyz")

    assert_empty results
  end

  test "search respects limit" do
    results = Food.search("chicken", limit: 1)

    assert_equal 1, results.size
  end

  test "search returns empty for blank query" do
    assert_empty Food.search("")
    assert_empty Food.search(nil)
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bin/rails test test/models/food_search_scope_test.rb`
Expected: FAIL — `Food.search` not defined.

- [ ] **Step 3: Write the implementation**

Edit `app/models/food.rb` — add the `search` class method before the `private` keyword:

```ruby
class Food < ApplicationRecord
  # All nutritional values are stored per 100 grams.

  belongs_to :creator, class_name: "User", optional: true

  enum :source, { off: 0, usda: 1, user: 2 }

  validates :name, presence: true, length: { maximum: 255 }
  validates :calories, :protein, :carbs, :fat,
    presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :fiber, numericality: { greater_than_or_equal_to: 0 }
  validates :source, presence: true
  validates :external_id, uniqueness: { scope: :source }, allow_nil: true
  validate :creator_required_for_user_source

  def self.search(query, limit: 20)
    return none if query.blank?

    where("searchable @@ plainto_tsquery('english', ?)", query)
      .or(where("name ILIKE ?", "%#{sanitize_sql_like(query)}%"))
      .order(Arel.sql("ts_rank(searchable, plainto_tsquery('english', #{connection.quote(query)})) DESC"))
      .limit(limit)
  end

  private

  def creator_required_for_user_source
    if user? && creator_id.nil?
      errors.add(:creator_id, "is required for user-created foods")
    end
  end
end
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bin/rails test test/models/food_search_scope_test.rb`
Expected: 5 tests, 0 failures.

- [ ] **Step 5: Commit**

```bash
git add app/models/food.rb test/models/food_search_scope_test.rb
git commit -m "feat: add Food.search scope with tsvector + ILIKE"
```

---

### Task 2: Create FoodSearch service with TDD

**Files:**
- Create: `test/services/food_search_test.rb`
- Create: `app/services/food_search.rb`

This is the core orchestration service. It needs to stub both `Off::Client` and `Usda::Client`. Since the project uses `define_singleton_method` for stubbing (see `test/services/off/client_test.rb`), we'll use a similar approach but with dependency injection to keep tests clean.

- [ ] **Step 1: Write the failing tests**

Create `test/services/food_search_test.rb`:

```ruby
require "test_helper"

class FoodSearchTest < ActiveSupport::TestCase
  setup do
    @user = create(:user)
  end

  # Local results
  test "returns local results when 5+ exist" do
    5.times { |i| create(:food, name: "Chicken item #{i}") }

    results = FoodSearch.call("chicken")

    assert_equal 5, results.size
    assert results.all? { |r| r.is_a?(Food) }
  end

  test "returns empty array for blank query" do
    assert_empty FoodSearch.call("")
    assert_empty FoodSearch.call(nil)
  end

  test "caps results at limit" do
    25.times { |i| create(:food, name: "Chicken variety #{i}") }

    results = FoodSearch.call("chicken", limit: 20)

    assert_equal 20, results.size
  end

  # External API fallback
  test "queries external APIs when fewer than 5 local results" do
    create(:food, name: "Chicken local", source: :off, external_id: "off-local-1")

    off_client = Minitest::Mock.new
    usda_client = Minitest::Mock.new

    off_result = Off::FoodResult.new(
      barcode: "123456789", name: "Chicken OFF", brand: "Brand",
      calories: 120.0, protein: 22.0, carbs: 0.0, fat: 2.0, fiber: 0.0,
      serving_size: 100.0, serving_label: "100g"
    )
    usda_result = Usda::FoodResult.new(
      fdc_id: "999", name: "Chicken USDA", brand: nil,
      calories: 165.0, protein: 31.0, carbs: 0.0, fat: 3.6, fiber: 0.0,
      serving_size: 100.0, serving_label: "100g"
    )

    off_client.expect :search, [off_result], [String], page: 1, per_page: 20
    off_client.expect :persist, create(:food, name: "Chicken OFF", source: :off, external_id: "123456789"), [Off::FoodResult]
    usda_client.expect :search, [usda_result], [String], page: 1, per_page: 20

    results = FoodSearch.call("chicken", off_client: off_client, usda_client: usda_client)

    assert results.size > 1
    off_client.verify
    usda_client.verify
  end

  test "persists OFF results immediately on search" do
    off_client = Minitest::Mock.new
    usda_client = Minitest::Mock.new

    off_result = Off::FoodResult.new(
      barcode: "555555", name: "OFF Food", brand: "Brand",
      calories: 100.0, protein: 10.0, carbs: 20.0, fat: 5.0, fiber: 2.0,
      serving_size: 100.0, serving_label: "100g"
    )

    persisted_food = create(:food, name: "OFF Food", source: :off, external_id: "555555")

    off_client.expect :search, [off_result], [String], page: 1, per_page: 20
    off_client.expect :persist, persisted_food, [Off::FoodResult]
    usda_client.expect :search, [], [String], page: 1, per_page: 20

    results = FoodSearch.call("food", off_client: off_client, usda_client: usda_client)

    off_client.verify
    assert results.any? { |r| r.is_a?(Food) && r.off? }
  end

  test "does not persist USDA results on search" do
    usda_client = Minitest::Mock.new
    off_client = Minitest::Mock.new

    usda_result = Usda::FoodResult.new(
      fdc_id: "777", name: "USDA Food", brand: nil,
      calories: 200.0, protein: 20.0, carbs: 10.0, fat: 8.0, fiber: 1.0,
      serving_size: 100.0, serving_label: "100g"
    )

    off_client.expect :search, [], [String], page: 1, per_page: 20
    usda_client.expect :search, [usda_result], [String], page: 1, per_page: 20

    initial_count = Food.count
    results = FoodSearch.call("food", off_client: off_client, usda_client: usda_client)

    assert_equal initial_count, Food.count
    assert results.any? { |r| r.is_a?(Usda::FoodResult) }
  end

  test "deduplicates OFF results already in local DB" do
    existing = create(:food, name: "Existing OFF", source: :off, external_id: "dupe-123")

    off_client = Minitest::Mock.new
    usda_client = Minitest::Mock.new

    off_result = Off::FoodResult.new(
      barcode: "dupe-123", name: "Existing OFF", brand: nil,
      calories: 100.0, protein: 10.0, carbs: 20.0, fat: 5.0, fiber: 0.0,
      serving_size: 100.0, serving_label: "100g"
    )

    off_client.expect :search, [off_result], [String], page: 1, per_page: 20
    off_client.expect :persist, existing, [Off::FoodResult]
    usda_client.expect :search, [], [String], page: 1, per_page: 20

    results = FoodSearch.call("existing", off_client: off_client, usda_client: usda_client)

    food_ids = results.select { |r| r.is_a?(Food) }.map(&:id)
    assert_equal food_ids.uniq, food_ids
  end

  test "deduplicates USDA results already in local DB" do
    create(:food, name: "Chicken USDA", source: :usda, external_id: "usda-111")

    off_client = Minitest::Mock.new
    usda_client = Minitest::Mock.new

    usda_result = Usda::FoodResult.new(
      fdc_id: "usda-111", name: "Chicken USDA", brand: nil,
      calories: 120.0, protein: 22.0, carbs: 0.0, fat: 2.0, fiber: 0.0,
      serving_size: 100.0, serving_label: "100g"
    )

    off_client.expect :search, [], [String], page: 1, per_page: 20
    usda_client.expect :search, [usda_result], [String], page: 1, per_page: 20

    results = FoodSearch.call("chicken", off_client: off_client, usda_client: usda_client)

    usda_results = results.select { |r| r.is_a?(Usda::FoodResult) }
    assert_empty usda_results
  end

  # Error handling
  test "handles OFF API errors gracefully" do
    off_client = Minitest::Mock.new
    usda_client = Minitest::Mock.new

    usda_result = Usda::FoodResult.new(
      fdc_id: "888", name: "USDA Fallback", brand: nil,
      calories: 100.0, protein: 10.0, carbs: 20.0, fat: 5.0, fiber: 0.0,
      serving_size: 100.0, serving_label: "100g"
    )

    off_client.expect :search, nil do raise Off::ApiError, "OFF is down" end
    usda_client.expect :search, [usda_result], [String], page: 1, per_page: 20

    results = FoodSearch.call("food", off_client: off_client, usda_client: usda_client)

    assert results.any? { |r| r.is_a?(Usda::FoodResult) && r.name == "USDA Fallback" }
  end

  test "handles USDA API errors gracefully" do
    off_client = Minitest::Mock.new
    usda_client = Minitest::Mock.new

    off_result = Off::FoodResult.new(
      barcode: "graceful-1", name: "OFF Fallback", brand: nil,
      calories: 100.0, protein: 10.0, carbs: 20.0, fat: 5.0, fiber: 0.0,
      serving_size: 100.0, serving_label: "100g"
    )
    persisted = create(:food, name: "OFF Fallback", source: :off, external_id: "graceful-1")

    off_client.expect :search, [off_result], [String], page: 1, per_page: 20
    off_client.expect :persist, persisted, [Off::FoodResult]
    usda_client.expect :search, nil do raise Usda::ApiError, "USDA is down" end

    results = FoodSearch.call("food", off_client: off_client, usda_client: usda_client)

    assert results.any? { |r| r.is_a?(Food) && r.name == "OFF Fallback" }
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bin/rails test test/services/food_search_test.rb`
Expected: FAIL — `FoodSearch` not defined.

- [ ] **Step 3: Write the implementation**

Create `app/services/food_search.rb`:

```ruby
class FoodSearch
  LOCAL_THRESHOLD = 5

  def self.call(query, limit: 20, off_client: nil, usda_client: nil)
    new(query, limit: limit, off_client: off_client, usda_client: usda_client).call
  end

  def initialize(query, limit: 20, off_client: nil, usda_client: nil)
    @query = query
    @limit = limit
    @off_client = off_client || Off::Client.new
    @usda_client = usda_client || Usda::Client.new
  end

  def call
    return [] if @query.blank?

    local_results = Food.search(@query, limit: @limit)

    if local_results.size >= LOCAL_THRESHOLD
      return local_results.first(@limit)
    end

    external_results = fetch_external_results(local_results)
    merged = merge_results(local_results, external_results)
    merged.first(@limit)
  end

  private

  def fetch_external_results(local_results)
    results = []

    # OFF: persist immediately (aggressive caching)
    begin
      off_results = @off_client.search(@query, page: 1, per_page: 20)
      off_results.each do |off_result|
        food = @off_client.persist(off_result)
        results << food
      end
    rescue Off::Error => e
      Rails.logger.warn("OFF search failed: #{e.message}")
    end

    # USDA: return transient structs (persist on interaction)
    begin
      usda_results = @usda_client.search(@query, page: 1, per_page: 20)
      results.concat(usda_results)
    rescue Usda::Error => e
      Rails.logger.warn("USDA search failed: #{e.message}")
    end

    results
  end

  def merge_results(local_results, external_results)
    local_ids = local_results.map { |f| [f.source, f.external_id] }.to_set

    deduped_external = external_results.reject do |result|
      case result
      when Food
        local_ids.include?([result.source, result.external_id])
      when Usda::FoodResult
        local_ids.include?(["usda", result.fdc_id])
      else
        false
      end
    end

    local_results + deduped_external
  end
end
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bin/rails test test/services/food_search_test.rb`
Expected: 9 tests, 0 failures.

- [ ] **Step 5: Run the full test suite**

Run: `bin/rails test`
Expected: All tests pass.

- [ ] **Step 6: Commit**

```bash
git add app/services/food_search.rb test/services/food_search_test.rb
git commit -m "feat: add FoodSearch service with local-first + API fallback"
```

---

### Task 3: Create FoodsController with TDD

**Files:**
- Create: `test/controllers/foods_controller_test.rb`
- Create: `app/controllers/foods_controller.rb`
- Modify: `config/routes.rb`

- [ ] **Step 1: Add the route**

Edit `config/routes.rb` — add after the settings resource:

```ruby
Rails.application.routes.draw do
  root "pages#home"

  resource :settings, only: [:edit, :update], controller: "users"
  resources :foods, only: [:index]

  post "onboarding/skip", to: "onboarding#skip", as: :skip_onboarding
  get "onboarding/:step", to: "onboarding#show", as: :onboarding_step
  patch "onboarding/:step", to: "onboarding#update", as: :update_onboarding_step

  mount Lookbook::Engine, at: "/lookbook" if Rails.env.development?

  get "up" => "rails/health#show", as: :rails_health_check
end
```

- [ ] **Step 2: Write the failing tests**

Create `test/controllers/foods_controller_test.rb`:

```ruby
require "test_helper"

class FoodsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @account = create(:account)
    @user = create(:user, account: @account)
  end

  test "index redirects when not authenticated" do
    get foods_path(q: "chicken")
    assert_response :redirect
  end

  test "index renders search page when authenticated" do
    login(@account)
    get foods_path
    assert_response :success
    assert_select "input[name='q']"
    assert_select "turbo-frame#food_search_results"
  end

  test "index returns results for valid query" do
    create(:food, name: "Chicken breast", source: :usda, external_id: "usda-1")
    create(:food, name: "Chicken thigh", source: :usda, external_id: "usda-2")
    create(:food, name: "Chicken wings", source: :off, external_id: "off-1")
    create(:food, name: "Chicken drumstick", source: :off, external_id: "off-2")
    create(:food, name: "Chicken tenders", source: :off, external_id: "off-3")

    login(@account)
    get foods_path(q: "chicken")

    assert_response :success
    assert_select "[data-food-result]", count: 5
  end

  test "index returns empty state for short query" do
    login(@account)
    get foods_path(q: "ch")

    assert_response :success
    assert_select "[data-food-result]", count: 0
  end

  test "index returns empty state for blank query" do
    login(@account)
    get foods_path(q: "")

    assert_response :success
    assert_select "[data-food-result]", count: 0
  end

  test "index responds to turbo frame request" do
    create(:food, name: "Chicken breast", source: :usda, external_id: "usda-frame")

    login(@account)
    get foods_path(q: "chicken"), headers: { "Turbo-Frame" => "food_search_results" }

    assert_response :success
  end

  private

  def login(account)
    post "/login", params: { email: account.email, password: "password" }
  end
end
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `bin/rails test test/controllers/foods_controller_test.rb`
Expected: FAIL — `FoodsController` not defined or routing error.

- [ ] **Step 4: Write the controller**

Create `app/controllers/foods_controller.rb`:

```ruby
class FoodsController < ApplicationController
  before_action :require_authentication

  def index
    @query = params[:q].to_s.strip
    @results = if @query.length >= 3
      FoodSearch.call(@query)
    else
      []
    end
  end
end
```

- [ ] **Step 5: Create the index view**

Create `app/views/foods/index.html.haml`:

```haml
%h1.text-xl.font-bold.mb-4 Search Foods

= form_with url: foods_path, method: :get, data: { controller: "search", search_target: "form", turbo_frame: "food_search_results" } do
  .relative
    %input.input.w-full.pl-10{ type: "text", name: "q", value: @query, placeholder: "Search foods...", autocomplete: "off", data: { search_target: "input", action: "input->search#debounce" } }
    .absolute.left-3.top-1\/2.-translate-y-1\/2.text-text-secondary
      %svg.w-4.h-4{ xmlns: "http://www.w3.org/2000/svg", fill: "none", viewBox: "0 0 24 24", "stroke-width": "2", stroke: "currentColor" }
        %circle{ cx: "11", cy: "11", r: "8" }
        %path{ d: "M21 21l-4.35-4.35", "stroke-linecap": "round" }

= turbo_frame_tag "food_search_results", class: "block mt-4" do
  = render "results"
```

- [ ] **Step 6: Create the results partial**

Create `app/views/foods/_results.html.haml`:

```haml
- if @query.present? && @query.length >= 3 && @results.empty?
  .text-center.py-8.text-text-secondary
    %p No foods found for "#{@query}"
    %p.text-sm.mt-1 Try a different search term

- @results.each do |result|
  - name = result.is_a?(Food) ? result.name : result.name
  - brand = result.is_a?(Food) ? result.brand : result.brand
  - calories = result.is_a?(Food) ? result.calories.to_f : result.calories
  - protein = result.is_a?(Food) ? result.protein.to_f : result.protein
  - carbs = result.is_a?(Food) ? result.carbs.to_f : result.carbs
  - fat = result.is_a?(Food) ? result.fat.to_f : result.fat
  - fiber = result.is_a?(Food) ? result.fiber.to_f : result.fiber
  - source = result.is_a?(Food) ? result.source : "usda"

  %div.border-b.border-border.py-3{ data: { food_result: true } }
    .flex.justify-between.items-start
      .min-w-0.flex-1.mr-3
        %p.font-medium.text-text.truncate= name
        %p.text-sm.text-text-secondary.mt-0\.5
          - case source
          - when "usda"
            %span.inline-block.text-xs.font-medium.px-1\.5.py-0\.5.rounded{ style: "background: #F0FDF4; color: #16A34A;" } USDA
          - when "off"
            %span.inline-block.text-xs.font-medium.px-1\.5.py-0\.5.rounded{ style: "background: #FEF3C7; color: #D97706;" } OFF
          - when "user"
            %span.inline-block.text-xs.font-medium.px-1\.5.py-0\.5.rounded{ style: "background: #EDE9FE; color: #7C3AED;" } You
          - if brand.present?
            = brand
      .text-right.whitespace-nowrap
        %p.font-semibold.text-text= "#{calories.round} kcal"
    .flex.flex-wrap.gap-2.mt-1\.5.text-xs.text-text-secondary
      %span
        Protein
        %b.text-text= "#{protein.round(1)}g"
      %span.text-border &middot;
      %span
        Carbs
        %b.text-text= "#{carbs.round(1)}g"
      %span.text-border &middot;
      %span
        Fat
        %b.text-text= "#{fat.round(1)}g"
      %span.text-border &middot;
      %span
        Fiber
        %b.text-text= "#{fiber.round(1)}g"
      %span.ml-auto{ style: "font-size: 11px;" } per 100g
```

- [ ] **Step 7: Run tests to verify they pass**

Run: `bin/rails test test/controllers/foods_controller_test.rb`
Expected: 6 tests, 0 failures.

- [ ] **Step 8: Run the full test suite**

Run: `bin/rails test`
Expected: All tests pass.

- [ ] **Step 9: Commit**

```bash
git add app/controllers/foods_controller.rb app/views/foods/ test/controllers/foods_controller_test.rb config/routes.rb
git commit -m "feat: add FoodsController with search page and Turbo Frame results"
```

---

### Task 4: Create Stimulus search controller

**Files:**
- Create: `app/javascript/controllers/search_controller.js`

- [ ] **Step 1: Create the Stimulus controller**

Create `app/javascript/controllers/search_controller.js`:

```javascript
import { Controller } from "@hotwired/stimulus"

// Debounced search that submits a form targeting a Turbo Frame.
// Usage:
//   <form data-controller="search" data-search-target="form" data-turbo-frame="food_search_results">
//     <input data-search-target="input" data-action="input->search#debounce">
//   </form>
export default class extends Controller {
  static targets = ["input", "form"]

  connect() {
    this.timeout = null
  }

  debounce() {
    clearTimeout(this.timeout)

    const query = this.inputTarget.value.trim()
    if (query.length < 3) return

    this.timeout = setTimeout(() => {
      this.formTarget.requestSubmit()
    }, 300)
  }

  disconnect() {
    clearTimeout(this.timeout)
  }
}
```

- [ ] **Step 2: Verify the controller loads**

Run: `bin/rails runner "puts 'Stimulus controllers directory exists: ' + Dir.exist?('app/javascript/controllers').to_s"`
Expected: `Stimulus controllers directory exists: true`

The controller will be auto-registered by `eagerLoadControllersFrom("controllers", application)` in `app/javascript/controllers/index.js`.

- [ ] **Step 3: Commit**

```bash
git add app/javascript/controllers/search_controller.js
git commit -m "feat: add Stimulus search controller with 300ms debounce"
```

---

### Task 5: Manual verification and polish

**Files:**
- No new files — verify existing implementation works end-to-end

- [ ] **Step 1: Run the full test suite**

Run: `bin/rails test`
Expected: All tests pass, 0 failures.

- [ ] **Step 2: Seed some test data for manual verification**

Run: `bin/rails runner "5.times { |i| Food.create!(name: 'Chicken item #{i}', calories: 120 + i, protein: 22, carbs: 0, fat: 2.6, fiber: 0, source: :usda, external_id: 'manual-#{i}') }"`
Expected: 5 foods created.

- [ ] **Step 3: Start the dev server and verify**

Run: `bin/dev`

Manual checks:
1. Navigate to `/foods` — should see the search page with input
2. Type "chi" — results should appear after 300ms debounce
3. Type "ch" (only 2 chars) — no search should fire
4. Verify result rows show: name, source badge, calories, macro line
5. Verify Turbo Frame updates without full page reload

- [ ] **Step 4: Clean up seed data**

Run: `bin/rails runner "Food.where(external_id: (0..4).map { |i| 'manual-#{i}' }).destroy_all"`

- [ ] **Step 5: Commit any polish fixes**

If any fixes were needed during manual verification, commit them:

```bash
git add -A
git commit -m "fix: polish food search UI after manual verification"
```

If no fixes needed, skip this step.
