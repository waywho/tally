# Quick Re-log Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show a "Quick add" section on the search page with meal context, displaying the user's most frequently and recently logged foods for one-tap re-logging.

**Architecture:** A `QuickAddFoods` service queries FoodLogEntry history grouped by food, ranked by frequency + recency, with meal-scoped results first and global fallback. The FoodsController loads quick add foods when meal context is present and query is empty. A partial renders the foods using the same row layout as search results.

**Tech Stack:** Rails 8.1, PostgreSQL, Haml, Tailwind CSS, Minitest, FactoryBot

---

## File Structure

| Action | File | Responsibility |
|--------|------|----------------|
| Create | `app/services/quick_add_foods.rb` | Ranked food suggestions from log history |
| Create | `test/services/quick_add_foods_test.rb` | Service unit tests |
| Create | `app/views/foods/_quick_add.html.haml` | Quick add section partial |
| Modify | `app/controllers/foods_controller.rb` | Load quick add foods |
| Modify | `app/views/foods/index.html.haml` | Render quick add section |
| Modify | `test/controllers/foods_controller_test.rb` | Integration tests |

---

### Task 1: QuickAddFoods service with TDD

**Files:**
- Create: `test/services/quick_add_foods_test.rb`
- Create: `app/services/quick_add_foods.rb`

- [ ] **Step 1: Write the failing tests**

Create `test/services/quick_add_foods_test.rb`:

```ruby
require "test_helper"

class QuickAddFoodsTest < ActiveSupport::TestCase
  setup do
    @user = create(:user)
    @chicken = create(:food, name: "Chicken breast", calories: 120)
    @rice = create(:food, name: "Brown rice", calories: 130)
    @oats = create(:food, name: "Oatmeal", calories: 70)
    @pasta = create(:food, name: "Pasta", calories: 160)
  end

  test "returns foods ordered by frequency then recency" do
    # Chicken logged 3 times, rice logged 1 time
    3.times { |i| create(:food_log_entry, user: @user, food: @chicken, meal: :lunch, logged_on: i.days.ago.to_date) }
    create(:food_log_entry, user: @user, food: @rice, meal: :lunch, logged_on: Date.current)

    results = QuickAddFoods.call(user: @user, meal: "lunch")

    assert_equal @chicken, results.first
    assert_equal @rice, results.second
  end

  test "scopes to current meal first then fills with global" do
    # Chicken logged for lunch, oats logged for breakfast
    create(:food_log_entry, user: @user, food: @chicken, meal: :lunch, logged_on: Date.current)
    create(:food_log_entry, user: @user, food: @oats, meal: :breakfast, logged_on: Date.current)

    results = QuickAddFoods.call(user: @user, meal: "lunch", limit: 10)

    assert_includes results, @chicken
    assert_includes results, @oats
    # Chicken should be first (meal-scoped)
    assert_equal @chicken, results.first
  end

  test "deduplicates between meal-scoped and global results" do
    # Chicken logged for both lunch and breakfast
    create(:food_log_entry, user: @user, food: @chicken, meal: :lunch, logged_on: Date.current)
    create(:food_log_entry, user: @user, food: @chicken, meal: :breakfast, logged_on: Date.current)

    results = QuickAddFoods.call(user: @user, meal: "lunch")

    chicken_count = results.count { |f| f.id == @chicken.id }
    assert_equal 1, chicken_count
  end

  test "caps at limit" do
    12.times do |i|
      food = create(:food, name: "Food #{i}", calories: 100)
      create(:food_log_entry, user: @user, food: food, meal: :lunch, logged_on: Date.current)
    end

    results = QuickAddFoods.call(user: @user, meal: "lunch", limit: 10)

    assert_equal 10, results.size
  end

  test "returns empty array for user with no history" do
    results = QuickAddFoods.call(user: @user, meal: "lunch")

    assert_empty results
  end

  test "excludes foods the user has never logged" do
    create(:food_log_entry, user: @user, food: @chicken, meal: :lunch, logged_on: Date.current)

    results = QuickAddFoods.call(user: @user, meal: "lunch")

    assert_includes results, @chicken
    assert_not_includes results, @rice
    assert_not_includes results, @oats
  end

  test "does not include other users log history" do
    other_user = create(:user)
    create(:food_log_entry, user: other_user, food: @pasta, meal: :lunch, logged_on: Date.current)
    create(:food_log_entry, user: @user, food: @chicken, meal: :lunch, logged_on: Date.current)

    results = QuickAddFoods.call(user: @user, meal: "lunch")

    assert_includes results, @chicken
    assert_not_includes results, @pasta
  end

  test "meal-scoped results come before global results" do
    create(:food_log_entry, user: @user, food: @oats, meal: :breakfast, logged_on: Date.current)
    create(:food_log_entry, user: @user, food: @chicken, meal: :lunch, logged_on: Date.current)

    results = QuickAddFoods.call(user: @user, meal: "lunch", limit: 10)

    lunch_index = results.index(@chicken)
    breakfast_index = results.index(@oats)
    assert lunch_index < breakfast_index, "Meal-scoped food should come before global"
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bin/rails test test/services/quick_add_foods_test.rb`
Expected: FAIL — `QuickAddFoods` not defined.

- [ ] **Step 3: Write the implementation**

Create `app/services/quick_add_foods.rb`:

```ruby
class QuickAddFoods
  def self.call(user:, meal:, limit: 10)
    new(user: user, meal: meal, limit: limit).call
  end

  def initialize(user:, meal:, limit: 10)
    @user = user
    @meal = meal
    @limit = limit
  end

  def call
    meal_food_ids = ranked_food_ids(scope: @user.food_log_entries.where(meal: @meal), limit: @limit)

    if meal_food_ids.size < @limit
      remaining = @limit - meal_food_ids.size
      global_food_ids = ranked_food_ids(
        scope: @user.food_log_entries.where.not(food_id: meal_food_ids),
        limit: remaining
      )
      food_ids = meal_food_ids + global_food_ids
    else
      food_ids = meal_food_ids
    end

    return [] if food_ids.empty?

    foods_by_id = Food.where(id: food_ids).index_by(&:id)
    food_ids.filter_map { |id| foods_by_id[id] }
  end

  private

  def ranked_food_ids(scope:, limit:)
    scope
      .group(:food_id)
      .order(Arel.sql("COUNT(*) DESC, MAX(logged_on) DESC"))
      .limit(limit)
      .pluck(:food_id)
  end
end
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bin/rails test test/services/quick_add_foods_test.rb`
Expected: 8 tests, 0 failures.

- [ ] **Step 5: Run full test suite**

Run: `bin/rails test`
Expected: All tests pass.

- [ ] **Step 6: Commit**

```bash
git add app/services/quick_add_foods.rb test/services/quick_add_foods_test.rb
git commit -m "feat: add QuickAddFoods service with meal-scoped frequency ranking"
```

---

### Task 2: Quick add partial and controller integration

**Files:**
- Create: `app/views/foods/_quick_add.html.haml`
- Modify: `app/controllers/foods_controller.rb`
- Modify: `app/views/foods/index.html.haml`

- [ ] **Step 1: Create the quick add partial**

Create `app/views/foods/_quick_add.html.haml`:

```haml
- if quick_add_foods.present?
  .mb-4
    %h3.text-sm.font-semibold.text-text-secondary.mb-2 Quick add
    = render CardComponent.new do
      - quick_add_foods.each do |food|
        - calories = food.calories.to_f
        - protein = food.protein.to_f
        - carbs = food.carbs.to_f
        - fat = food.fat.to_f
        - fiber = food.fiber.to_f
        %div.border-b.border-border.py-3.px-4.cursor-pointer{ class: "hover:bg-primary-tint transition-colors", data: { food_result: true, quick_add: true, action: "click->sheet#open", sheet_name_param: food.name, sheet_calories_param: calories, sheet_protein_param: protein, sheet_carbs_param: carbs, sheet_fat_param: fat, sheet_fiber_param: fiber, sheet_food_id_param: food.id } }
          .flex.justify-between.items-center
            .min-w-0.flex-1.mr-3
              %p.font-medium.text-text.truncate= food.name
            .text-right.whitespace-nowrap
              %p.text-sm.font-semibold.text-text= "#{calories.round} kcal"
              %p.text-xs.text-text-secondary per 100g
```

- [ ] **Step 2: Update FoodsController#index**

In `app/controllers/foods_controller.rb`, add the quick add loading to the `index` action. Add after the `@meal_templates` assignment:

```ruby
    @quick_add_foods = if @meal.present? && @query.length < 3
      QuickAddFoods.call(user: current_user, meal: @meal)
    else
      []
    end
```

- [ ] **Step 3: Update the search page view**

In `app/views/foods/index.html.haml`, add the quick add section after the templates section and before the search form. Add this line after the templates_section render:

```haml
  = render "quick_add", quick_add_foods: @quick_add_foods
```

- [ ] **Step 4: Run full test suite**

Run: `bin/rails test`
Expected: All tests pass.

- [ ] **Step 5: Commit**

```bash
git add app/views/foods/_quick_add.html.haml app/controllers/foods_controller.rb app/views/foods/index.html.haml
git commit -m "feat: add Quick add section to search page with meal context"
```

---

### Task 3: Controller integration tests

**Files:**
- Modify: `test/controllers/foods_controller_test.rb`

- [ ] **Step 1: Write the tests**

Add to `test/controllers/foods_controller_test.rb`:

```ruby
  # Quick add
  test "index with meal context and empty query shows quick add section" do
    food = create(:food, name: "Chicken breast")
    create(:food_log_entry, user: @user, food: food, meal: :breakfast, logged_on: Date.current)

    login(@account)
    get foods_path(meal: "breakfast", date: Date.current.iso8601)

    assert_response :success
    assert_select "[data-quick-add]", minimum: 1
  end

  test "index with meal context and query hides quick add section" do
    food = create(:food, name: "Chicken breast")
    create(:food_log_entry, user: @user, food: food, meal: :breakfast, logged_on: Date.current)

    login(@account)
    get foods_path(meal: "breakfast", date: Date.current.iso8601, q: "chicken")

    assert_response :success
    assert_select "[data-quick-add]", count: 0
  end

  test "index without meal context does not show quick add section" do
    food = create(:food, name: "Chicken breast")
    create(:food_log_entry, user: @user, food: food, meal: :breakfast, logged_on: Date.current)

    login(@account)
    get foods_path

    assert_response :success
    assert_select "[data-quick-add]", count: 0
  end
```

- [ ] **Step 2: Run tests to verify they pass**

Run: `bin/rails test test/controllers/foods_controller_test.rb`
Expected: All pass.

- [ ] **Step 3: Run full test suite**

Run: `bin/rails test`
Expected: All tests pass.

- [ ] **Step 4: Commit**

```bash
git add test/controllers/foods_controller_test.rb
git commit -m "test: add integration tests for Quick add section on search page"
```
