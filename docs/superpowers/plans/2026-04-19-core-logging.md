# Core Food Logging Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the core food logging loop — FoodLogEntry model, Today view with meal buckets, add-food flow with bottom sheet, and edit/delete entries.

**Architecture:** FoodLogEntry stores food + grams + meal + date per user. DaysController renders the Today view grouped by meal buckets. The add-food flow reuses the search page with meal context, adding a bottom sheet for quantity input with swipeable meal/daily tally. Stimulus controllers handle live preview and the swipeable card.

**Tech Stack:** Rails 8.1, PostgreSQL, Turbo Frames, Stimulus, Haml, Tailwind CSS

---

## File Structure

| Action | File | Responsibility |
|--------|------|----------------|
| Create | `db/migrate/XXXXXX_create_food_log_entries.rb` | Migration for food_log_entries table |
| Create | `app/models/food_log_entry.rb` | Model with validations, enum, computed methods |
| Create | `test/models/food_log_entry_test.rb` | Model unit tests |
| Create | `test/factories/food_log_entries.rb` | Factory for food_log_entry |
| Modify | `app/models/user.rb` | Add `has_many :food_log_entries` |
| Create | `app/controllers/days_controller.rb` | Today view controller |
| Create | `app/views/days/show.html.haml` | Today view with meal buckets |
| Create | `test/controllers/days_controller_test.rb` | Controller integration tests |
| Create | `app/controllers/food_log_entries_controller.rb` | CRUD for entries |
| Create | `app/views/food_log_entries/edit.html.haml` | Edit entry form |
| Create | `test/controllers/food_log_entries_controller_test.rb` | Controller integration tests |
| Modify | `app/controllers/pages_controller.rb` | Redirect to today_path |
| Modify | `config/routes.rb` | Add days + entries routes |
| Modify | `app/controllers/foods_controller.rb` | Add meal context params |
| Modify | `app/views/foods/index.html.haml` | Meal context header |
| Modify | `app/views/foods/_results.html.haml` | Clickable rows with bottom sheet |
| Create | `app/views/foods/_bottom_sheet.html.haml` | Bottom sheet partial |
| Create | `app/javascript/controllers/sheet_controller.js` | Bottom sheet open/close |
| Create | `app/javascript/controllers/quantity_preview_controller.js` | Live calorie/macro preview |
| Create | `app/javascript/controllers/swipe_controller.js` | Horizontal scroll snap for tally |
| Modify | `config/locales/en.yml` | Flash messages for entries |

---

### Task 1: FoodLogEntry model + migration + factory

**Files:**
- Create: `db/migrate/XXXXXX_create_food_log_entries.rb`
- Create: `app/models/food_log_entry.rb`
- Modify: `app/models/user.rb`
- Create: `test/factories/food_log_entries.rb`
- Create: `test/models/food_log_entry_test.rb`

- [ ] **Step 1: Write the failing tests**

Create `test/models/food_log_entry_test.rb`:

```ruby
require "test_helper"

class FoodLogEntryTest < ActiveSupport::TestCase
  setup do
    @user = create(:user)
    @food = create(:food, calories: 250, protein: 10, carbs: 30, fat: 12, fiber: 3)
  end

  # Factory
  test "factory is valid" do
    entry = build(:food_log_entry)
    assert entry.valid?, entry.errors.full_messages.join(", ")
  end

  # Associations
  test "belongs to user" do
    entry = create(:food_log_entry, user: @user)
    assert_equal @user, entry.user
  end

  test "belongs to food" do
    entry = create(:food_log_entry, food: @food)
    assert_equal @food, entry.food
  end

  test "user has many food log entries" do
    create(:food_log_entry, user: @user)
    create(:food_log_entry, user: @user)
    assert_equal 2, @user.food_log_entries.count
  end

  test "destroying user destroys food log entries" do
    create(:food_log_entry, user: @user)
    assert_difference "FoodLogEntry.count", -1 do
      @user.destroy
    end
  end

  # Validations
  test "invalid without user" do
    entry = build(:food_log_entry, user: nil)
    assert_not entry.valid?
    assert entry.errors[:user].any?
  end

  test "invalid without food" do
    entry = build(:food_log_entry, food: nil)
    assert_not entry.valid?
    assert entry.errors[:food].any?
  end

  test "invalid without logged_on" do
    entry = build(:food_log_entry, logged_on: nil)
    assert_not entry.valid?
    assert_includes entry.errors[:logged_on], "can't be blank"
  end

  test "invalid without meal" do
    entry = build(:food_log_entry, meal: nil)
    assert_not entry.valid?
    assert_includes entry.errors[:meal], "can't be blank"
  end

  test "invalid without quantity_g" do
    entry = build(:food_log_entry, quantity_g: nil)
    assert_not entry.valid?
    assert entry.errors[:quantity_g].any?
  end

  test "invalid with quantity_g of zero" do
    entry = build(:food_log_entry, quantity_g: 0)
    assert_not entry.valid?
    assert entry.errors[:quantity_g].any?
  end

  test "invalid with negative quantity_g" do
    entry = build(:food_log_entry, quantity_g: -10)
    assert_not entry.valid?
    assert entry.errors[:quantity_g].any?
  end

  test "valid with positive quantity_g" do
    entry = build(:food_log_entry, quantity_g: 150)
    assert entry.valid?
  end

  # Meal enum
  test "meal enum values" do
    assert FoodLogEntry.meals.key?("breakfast")
    assert FoodLogEntry.meals.key?("lunch")
    assert FoodLogEntry.meals.key?("dinner")
    assert FoodLogEntry.meals.key?("snacks")
  end

  test "breakfast? returns true for breakfast meal" do
    entry = build(:food_log_entry, meal: :breakfast)
    assert entry.breakfast?
  end

  test "lunch? returns true for lunch meal" do
    entry = build(:food_log_entry, meal: :lunch)
    assert entry.lunch?
  end

  test "dinner? returns true for dinner meal" do
    entry = build(:food_log_entry, meal: :dinner)
    assert entry.dinner?
  end

  test "snacks? returns true for snacks meal" do
    entry = build(:food_log_entry, meal: :snacks)
    assert entry.snacks?
  end

  # Computed methods
  test "calories computed from food per 100g and quantity" do
    entry = build(:food_log_entry, food: @food, quantity_g: 200)
    assert_equal 500.0, entry.calories
  end

  test "protein computed from food per 100g and quantity" do
    entry = build(:food_log_entry, food: @food, quantity_g: 200)
    assert_equal 20.0, entry.protein
  end

  test "carbs computed from food per 100g and quantity" do
    entry = build(:food_log_entry, food: @food, quantity_g: 200)
    assert_equal 60.0, entry.carbs
  end

  test "fat computed from food per 100g and quantity" do
    entry = build(:food_log_entry, food: @food, quantity_g: 200)
    assert_equal 24.0, entry.fat
  end

  test "fiber computed from food per 100g and quantity" do
    entry = build(:food_log_entry, food: @food, quantity_g: 200)
    assert_equal 6.0, entry.fiber
  end

  test "computed values work with decimal quantities" do
    entry = build(:food_log_entry, food: @food, quantity_g: 150)
    assert_equal 375.0, entry.calories
    assert_equal 15.0, entry.protein
    assert_equal 45.0, entry.carbs
    assert_equal 18.0, entry.fat
    assert_equal 4.5, entry.fiber
  end
end
```

- [ ] **Step 2: Run the tests — they should fail (model and table don't exist)**

```bash
bin/rails test test/models/food_log_entry_test.rb
```

- [ ] **Step 3: Generate the migration**

```bash
bin/rails generate migration CreateFoodLogEntries user:references food:references logged_on:date meal:integer quantity_g:decimal
```

Then edit the generated migration to match this exact content:

```ruby
class CreateFoodLogEntries < ActiveRecord::Migration[8.1]
  def change
    create_table :food_log_entries do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.references :food, null: false, foreign_key: true
      t.date :logged_on, null: false
      t.integer :meal, null: false
      t.decimal :quantity_g, precision: 8, scale: 2, null: false

      t.timestamps
    end

    add_index :food_log_entries, [:user_id, :logged_on]
    add_index :food_log_entries, [:user_id, :food_id]
  end
end
```

Run the migration:

```bash
bin/rails db:migrate
```

- [ ] **Step 4: Create the factory**

Create `test/factories/food_log_entries.rb`:

```ruby
FactoryBot.define do
  factory :food_log_entry do
    user
    food
    logged_on { Date.current }
    meal { :breakfast }
    quantity_g { 100.0 }
  end
end
```

- [ ] **Step 5: Create the model**

Create `app/models/food_log_entry.rb`:

```ruby
class FoodLogEntry < ApplicationRecord
  belongs_to :user
  belongs_to :food

  enum :meal, { breakfast: 0, lunch: 1, dinner: 2, snacks: 3 }

  validates :logged_on, presence: true
  validates :meal, presence: true
  validates :quantity_g, presence: true, numericality: { greater_than: 0 }

  def calories
    food.calories * quantity_g / 100
  end

  def protein
    food.protein * quantity_g / 100
  end

  def carbs
    food.carbs * quantity_g / 100
  end

  def fat
    food.fat * quantity_g / 100
  end

  def fiber
    food.fiber * quantity_g / 100
  end
end
```

- [ ] **Step 6: Add association to User model**

In `app/models/user.rb`, add after the existing `has_many :created_foods` line:

```ruby
has_many :food_log_entries, dependent: :destroy
```

- [ ] **Step 7: Run the tests — they should all pass**

```bash
bin/rails test test/models/food_log_entry_test.rb
```

- [ ] **Step 8: Commit**

```bash
git add -A && git commit -m "Add FoodLogEntry model with migration, factory, and tests"
```

---

### Task 2: Routes + DaysController + Today view

**Files:**
- Modify: `config/routes.rb`
- Create: `app/controllers/days_controller.rb`
- Create: `app/views/days/show.html.haml`
- Modify: `app/controllers/pages_controller.rb`
- Create: `test/controllers/days_controller_test.rb`

- [ ] **Step 1: Write the failing tests**

Create `test/controllers/days_controller_test.rb`:

```ruby
require "test_helper"

class DaysControllerTest < ActionDispatch::IntegrationTest
  setup do
    @account = create(:account)
    @user = create(:user, account: @account, daily_calorie_target: 2000, protein_target: 50, carbs_target: 250, fat_target: 65, fiber_target: 30)
    @food = create(:food, calories: 250, protein: 10, carbs: 30, fat: 12, fiber: 3)
  end

  test "GET /today redirects to login when not authenticated" do
    get today_path
    assert_response :redirect
  end

  test "GET /today renders today's date for authenticated user" do
    login(@account)
    get today_path
    assert_response :success
    assert_select "[data-date]", Date.current.iso8601
  end

  test "GET /days/:date renders specific date" do
    login(@account)
    get day_path(date: "2026-04-19")
    assert_response :success
    assert_select "[data-date]", "2026-04-19"
  end

  test "shows entries grouped by meal" do
    breakfast_entry = create(:food_log_entry, user: @user, food: @food, logged_on: Date.current, meal: :breakfast, quantity_g: 200)
    lunch_entry = create(:food_log_entry, user: @user, food: @food, logged_on: Date.current, meal: :lunch, quantity_g: 150)

    login(@account)
    get today_path

    assert_response :success
    assert_select "[data-meal='breakfast']" do
      assert_select "[data-entry-id='#{breakfast_entry.id}']"
    end
    assert_select "[data-meal='lunch']" do
      assert_select "[data-entry-id='#{lunch_entry.id}']"
    end
  end

  test "shows calorie summary card with consumed and target" do
    create(:food_log_entry, user: @user, food: @food, logged_on: Date.current, meal: :breakfast, quantity_g: 200)

    login(@account)
    get today_path

    assert_response :success
    assert_select "[data-calorie-summary]"
  end

  test "shows empty state for meals with no entries" do
    login(@account)
    get today_path

    assert_response :success
    assert_select "[data-meal='breakfast']"
    assert_select "[data-empty-meal]", minimum: 1
  end

  test "does not show other user's entries" do
    other_user = create(:user)
    create(:food_log_entry, user: other_user, food: @food, logged_on: Date.current, meal: :breakfast, quantity_g: 100)

    login(@account)
    get today_path

    assert_response :success
    assert_select "[data-entry-id]", count: 0
  end

  test "home page redirects to today for logged in user" do
    login(@account)
    get root_path
    assert_redirected_to today_path
  end

  private

  def login(account)
    post "/login", params: { email: account.email, password: "password" }
  end
end
```

- [ ] **Step 2: Run the tests — they should fail (route and controller don't exist)**

```bash
bin/rails test test/controllers/days_controller_test.rb
```

- [ ] **Step 3: Add routes**

In `config/routes.rb`, add after the `root "pages#home"` line:

```ruby
get "today", to: "days#show", as: :today
resources :days, only: [:show], param: :date do
  resources :food_log_entries, only: [:create, :edit, :update, :destroy], path: "entries"
end
```

- [ ] **Step 4: Create DaysController**

Create `app/controllers/days_controller.rb`:

```ruby
class DaysController < ApplicationController
  before_action :require_authentication

  def show
    @date = params[:date]&.to_date || Date.current

    entries = current_user.food_log_entries
      .where(logged_on: @date)
      .includes(:food)
      .order(:created_at)

    @entries_by_meal = FoodLogEntry.meals.keys.index_with { |_meal| [] }
    entries.each { |entry| @entries_by_meal[entry.meal] << entry }

    @meal_totals = @entries_by_meal.transform_values do |meal_entries|
      {
        calories: meal_entries.sum(&:calories),
        protein: meal_entries.sum(&:protein),
        carbs: meal_entries.sum(&:carbs),
        fat: meal_entries.sum(&:fat),
        fiber: meal_entries.sum(&:fiber)
      }
    end

    @daily_totals = {
      calories: @meal_totals.values.sum { |t| t[:calories] },
      protein: @meal_totals.values.sum { |t| t[:protein] },
      carbs: @meal_totals.values.sum { |t| t[:carbs] },
      fat: @meal_totals.values.sum { |t| t[:fat] },
      fiber: @meal_totals.values.sum { |t| t[:fiber] },
      target_calories: current_user.daily_calorie_target,
      target_protein: current_user.protein_target,
      target_carbs: current_user.carbs_target,
      target_fat: current_user.fat_target,
      target_fiber: current_user.fiber_target
    }
  end
end
```

- [ ] **Step 5: Create the Today view**

Create `app/views/days/show.html.haml`:

```haml
%div{ data: { date: @date.iso8601 } }
  %h1.text-lg.font-semibold.text-text.mb-4= @date.strftime("%A, %b %-d")

  -# Calorie summary card
  %div{ data: { calorie_summary: true } }
    = render CaloriePillComponent.new(
        eaten: @daily_totals[:calories].round,
        target: @daily_totals[:target_calories],
        protein: "#{@daily_totals[:protein].round}g / #{@daily_totals[:target_protein]}g",
        carbs: "#{@daily_totals[:carbs].round}g / #{@daily_totals[:target_carbs]}g",
        fat: "#{@daily_totals[:fat].round}g / #{@daily_totals[:target_fat]}g",
        fiber: "#{@daily_totals[:fiber].round}g / #{@daily_totals[:target_fiber]}g")

  -# Meal buckets
  .mt-6.space-y-4
    - FoodLogEntry.meals.each_key do |meal|
      - entries = @entries_by_meal[meal]
      - subtotal = @meal_totals[meal][:calories].round
      - add_path = foods_path(meal: meal, date: @date.iso8601)

      %div{ data: { meal: meal } }
        = render CardComponent.new do
          = render BucketHeaderComponent.new(meal: meal.capitalize, subtotal: subtotal, add_path: add_path)

          - if entries.any?
            - entries.each do |entry|
              = link_to edit_day_food_log_entry_path(date: @date.iso8601, id: entry.id), class: "block" do
                .flex.justify-between.items-center.px-4.py-3.border-b.border-border.last:border-b-0{ data: { entry_id: entry.id } }
                  .min-w-0.flex-1
                    %p.font-medium.text-text.truncate= entry.food.name
                    %p.text-xs.text-text-secondary= "#{entry.quantity_g.to_i}g"
                  %span.text-sm.font-semibold.text-text.whitespace-nowrap= "#{entry.calories.round} kcal"
          - else
            .px-4.py-6.text-center.text-text-secondary.text-sm{ data: { empty_meal: true } }
              %p No foods logged yet
              = link_to "+ Add food", add_path, class: "text-primary font-medium"
```

- [ ] **Step 6: Update PagesController to redirect to today_path**

In `app/controllers/pages_controller.rb`, change `redirect_to edit_settings_path` to `redirect_to today_path`:

```ruby
class PagesController < ApplicationController
  skip_before_action :ensure_onboarded

  def home
    if rodauth.logged_in?
      redirect_to today_path
    else
      redirect_to rodauth.login_path
    end
  end
end
```

- [ ] **Step 7: Run the tests — they should all pass**

```bash
bin/rails test test/controllers/days_controller_test.rb
```

- [ ] **Step 8: Commit**

```bash
git add -A && git commit -m "Add DaysController with Today view, meal buckets, and calorie summary"
```

---

### Task 3: FoodLogEntriesController (create/edit/update/destroy)

**Files:**
- Create: `app/controllers/food_log_entries_controller.rb`
- Create: `app/views/food_log_entries/edit.html.haml`
- Modify: `config/locales/en.yml`
- Create: `test/controllers/food_log_entries_controller_test.rb`

- [ ] **Step 1: Write the failing tests**

Create `test/controllers/food_log_entries_controller_test.rb`:

```ruby
require "test_helper"

class FoodLogEntriesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @account = create(:account)
    @user = create(:user, account: @account)
    @food = create(:food, calories: 250, protein: 10, carbs: 30, fat: 12, fiber: 3)
    @date = "2026-04-19"
  end

  # Create
  test "POST creates entry with correct attributes" do
    login(@account)

    assert_difference "FoodLogEntry.count", 1 do
      post day_food_log_entries_path(date: @date), params: {
        food_log_entry: { food_id: @food.id, meal: "breakfast", quantity_g: 150 }
      }
    end

    entry = FoodLogEntry.last
    assert_equal @user.id, entry.user_id
    assert_equal @food.id, entry.food_id
    assert_equal Date.parse(@date), entry.logged_on
    assert_equal "breakfast", entry.meal
    assert_equal 150.0, entry.quantity_g.to_f
    assert_redirected_to day_path(date: @date)
  end

  test "POST with invalid params does not create entry" do
    login(@account)

    assert_no_difference "FoodLogEntry.count" do
      post day_food_log_entries_path(date: @date), params: {
        food_log_entry: { food_id: @food.id, meal: "breakfast", quantity_g: 0 }
      }
    end

    assert_response :unprocessable_entity
  end

  test "POST requires authentication" do
    post day_food_log_entries_path(date: @date), params: {
      food_log_entry: { food_id: @food.id, meal: "breakfast", quantity_g: 100 }
    }
    assert_response :redirect
  end

  # Edit
  test "GET edit renders form for own entry" do
    login(@account)
    entry = create(:food_log_entry, user: @user, food: @food, logged_on: Date.parse(@date), meal: :breakfast, quantity_g: 150)

    get edit_day_food_log_entry_path(date: @date, id: entry.id)

    assert_response :success
    assert_select "input[name='food_log_entry[quantity_g]']"
    assert_select "form[action='#{day_food_log_entry_path(date: @date, id: entry.id)}']"
  end

  test "GET edit returns 404 for other user's entry" do
    other_user = create(:user)
    entry = create(:food_log_entry, user: other_user, food: @food, logged_on: Date.parse(@date))

    login(@account)
    get edit_day_food_log_entry_path(date: @date, id: entry.id)

    assert_response :not_found
  end

  # Update
  test "PATCH updates quantity_g" do
    login(@account)
    entry = create(:food_log_entry, user: @user, food: @food, logged_on: Date.parse(@date), quantity_g: 100)

    patch day_food_log_entry_path(date: @date, id: entry.id), params: {
      food_log_entry: { quantity_g: 200 }
    }

    assert_redirected_to day_path(date: @date)
    assert_equal 200.0, entry.reload.quantity_g.to_f
  end

  test "PATCH with invalid quantity re-renders form" do
    login(@account)
    entry = create(:food_log_entry, user: @user, food: @food, logged_on: Date.parse(@date), quantity_g: 100)

    patch day_food_log_entry_path(date: @date, id: entry.id), params: {
      food_log_entry: { quantity_g: 0 }
    }

    assert_response :unprocessable_entity
    assert_equal 100.0, entry.reload.quantity_g.to_f
  end

  test "PATCH returns 404 for other user's entry" do
    other_user = create(:user)
    entry = create(:food_log_entry, user: other_user, food: @food, logged_on: Date.parse(@date))

    login(@account)
    patch day_food_log_entry_path(date: @date, id: entry.id), params: {
      food_log_entry: { quantity_g: 200 }
    }

    assert_response :not_found
  end

  # Destroy
  test "DELETE destroys entry and redirects" do
    login(@account)
    entry = create(:food_log_entry, user: @user, food: @food, logged_on: Date.parse(@date))

    assert_difference "FoodLogEntry.count", -1 do
      delete day_food_log_entry_path(date: @date, id: entry.id)
    end

    assert_redirected_to day_path(date: @date)
    follow_redirect!
    assert_equal "Entry deleted.", flash[:notice]
  end

  test "DELETE returns 404 for other user's entry" do
    other_user = create(:user)
    entry = create(:food_log_entry, user: other_user, food: @food, logged_on: Date.parse(@date))

    login(@account)

    assert_no_difference "FoodLogEntry.count" do
      delete day_food_log_entry_path(date: @date, id: entry.id)
    end

    assert_response :not_found
  end

  private

  def login(account)
    post "/login", params: { email: account.email, password: "password" }
  end
end
```

- [ ] **Step 2: Run the tests — they should fail (controller doesn't exist)**

```bash
bin/rails test test/controllers/food_log_entries_controller_test.rb
```

- [ ] **Step 3: Add flash messages to en.yml**

In `config/locales/en.yml`, add under the `flash:` key:

```yaml
    entry_created: "Entry added."
    entry_updated: "Entry updated."
    entry_deleted: "Entry deleted."
```

- [ ] **Step 4: Create FoodLogEntriesController**

Create `app/controllers/food_log_entries_controller.rb`:

```ruby
class FoodLogEntriesController < ApplicationController
  before_action :require_authentication
  before_action :set_date
  before_action :set_entry, only: [:edit, :update, :destroy]

  def create
    @entry = current_user.food_log_entries.build(entry_params)
    @entry.logged_on = @date

    if @entry.save
      redirect_to day_path(date: @date.iso8601), notice: t("flash.entry_created")
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @entry.update(entry_params)
      redirect_to day_path(date: @date.iso8601), notice: t("flash.entry_updated")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @entry.destroy!
    redirect_to day_path(date: @date.iso8601), notice: t("flash.entry_deleted")
  end

  private

  def set_date
    @date = params[:day_date].to_date
  end

  def set_entry
    @entry = current_user.food_log_entries.find(params[:id])
  end

  def entry_params
    params.require(:food_log_entry).permit(:food_id, :meal, :quantity_g)
  end
end
```

- [ ] **Step 5: Create the edit view**

Create `app/views/food_log_entries/edit.html.haml`:

```haml
%h1.text-xl.font-bold.mb-4 Edit Entry

= render CardComponent.new(class: "p-4") do
  %p.font-medium.text-text.mb-1= @entry.food.name
  %p.text-sm.text-text-secondary.mb-4= "#{@entry.food.calories.round} kcal per 100g"

  = form_with model: @entry, url: day_food_log_entry_path(date: @date.iso8601, id: @entry.id), method: :patch do |f|
    .mb-4
      = f.label :quantity_g, "Grams", class: "label"
      = f.number_field :quantity_g, step: 0.01, min: 0.01, class: "input w-full", autofocus: true
      - if @entry.errors[:quantity_g].any?
        %p.field-error= @entry.errors[:quantity_g].first

    .flex.justify-between.items-center.gap-3.mt-4.text-sm
      %p.text-text-secondary
        = "#{@entry.calories.round} kcal"
        %span.mx-1 &middot;
        = "P #{@entry.protein.round(1)}g"
        %span.mx-1 &middot;
        = "C #{@entry.carbs.round(1)}g"
        %span.mx-1 &middot;
        = "F #{@entry.fat.round(1)}g"

    .mt-6.space-y-3
      = render ButtonComponent.new(label: "Save", tag: :input, type: :submit)
      .text-center
        = link_to "Delete entry", day_food_log_entry_path(date: @date.iso8601, id: @entry.id), data: { turbo_method: :delete, turbo_confirm: "Delete this entry?" }, class: "text-danger text-sm font-medium"
```

- [ ] **Step 6: Run the tests — they should all pass**

```bash
bin/rails test test/controllers/food_log_entries_controller_test.rb
```

- [ ] **Step 7: Commit**

```bash
git add -A && git commit -m "Add FoodLogEntriesController with create, edit, update, destroy actions"
```

---

### Task 4: Search page meal context

**Files:**
- Modify: `app/controllers/foods_controller.rb`
- Modify: `app/views/foods/index.html.haml`
- Modify: `app/views/foods/_results.html.haml`
- Modify: `test/controllers/foods_controller_test.rb`

- [ ] **Step 1: Write the failing tests**

Add these tests to the existing `test/controllers/foods_controller_test.rb`:

```ruby
# Meal context
test "index shows meal context header when meal param present" do
  login(@account)
  get foods_path(meal: "breakfast", date: "2026-04-19")

  assert_response :success
  assert_select "[data-meal-context]", /Adding to Breakfast/
  assert_select "[data-meal-context]", /Apr 19/
end

test "index does not show meal context header without meal param" do
  login(@account)
  get foods_path

  assert_response :success
  assert_select "[data-meal-context]", count: 0
end

test "index passes meal context to results" do
  create(:food, name: "Chicken breast", source: :off, external_id: "ctx-1")

  login(@account)
  get foods_path(q: "chicken", meal: "lunch", date: "2026-04-19")

  assert_response :success
  assert_select "[data-food-result][data-meal-context-active]"
end
```

- [ ] **Step 2: Run the tests — they should fail**

```bash
bin/rails test test/controllers/foods_controller_test.rb
```

- [ ] **Step 3: Update FoodsController#index**

In `app/controllers/foods_controller.rb`, add to the `index` action after the existing `@query` and `@results` assignments:

```ruby
@meal = params[:meal]
@date = params[:date]
```

- [ ] **Step 4: Update index.html.haml**

Replace the content of `app/views/foods/index.html.haml` with:

```haml
%h1.text-xl.font-bold.mb-4 Search Foods

- if @meal.present? && @date.present?
  %div.text-sm.text-text-secondary.mb-3.font-medium{ data: { meal_context: true } }
    Adding to #{@meal.capitalize} &middot; #{Date.parse(@date).strftime("%b %-d")}

= form_with url: foods_path, method: :get, data: { controller: "search", search_target: "form", turbo_frame: "food_search_results" } do
  - if @meal.present?
    %input{ type: "hidden", name: "meal", value: @meal }
  - if @date.present?
    %input{ type: "hidden", name: "date", value: @date }
  .relative
    %input.input.w-full.pl-10{ type: "text", name: "q", value: @query, placeholder: "Search foods...", autocomplete: "off", data: { search_target: "input", action: "input->search#debounce" } }
    %div.absolute.left-3{ class: "top-1/2 -translate-y-1/2 text-text-secondary" }
      != '<svg class="w-4 h-4" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="2" stroke="currentColor"><circle cx="11" cy="11" r="8"/><path d="M21 21l-4.35-4.35" stroke-linecap="round"/></svg>'

= turbo_frame_tag "food_search_results", class: "block mt-4" do
  = render "results"
```

- [ ] **Step 5: Update _results.html.haml**

Update `app/views/foods/_results.html.haml` to add `data-meal-context-active` attribute to food result rows when meal context is present. Change the opening `%div` of each result row:

Replace:
```haml
  %div.border-b.border-border.py-3{ data: { food_result: true } }
```

With:
```haml
  - has_meal_context = @meal.present? && @date.present?
  %div.border-b.border-border.py-3{ data: { food_result: true }.merge(has_meal_context ? { meal_context_active: true } : {}) }
```

When meal context is present, wrap each result row in a clickable trigger. After the existing food result content (before the "Can't find it?" section at the bottom), no structural changes are needed yet — the click handling is added in Task 5 with the sheet Stimulus controller.

- [ ] **Step 6: Run the tests — they should all pass**

```bash
bin/rails test test/controllers/foods_controller_test.rb
```

- [ ] **Step 7: Commit**

```bash
git add -A && git commit -m "Add meal context to food search page with date and meal params"
```

---

### Task 5: Bottom sheet + Stimulus controllers

**Files:**
- Create: `app/javascript/controllers/sheet_controller.js`
- Create: `app/javascript/controllers/quantity_preview_controller.js`
- Create: `app/javascript/controllers/swipe_controller.js`
- Create: `app/views/foods/_bottom_sheet.html.haml`
- Modify: `app/views/foods/_results.html.haml`

- [ ] **Step 1: Create sheet_controller.js**

Create `app/javascript/controllers/sheet_controller.js`:

```javascript
import { Controller } from "@hotwired/stimulus"

// Manages a bottom sheet overlay.
// Usage:
//   <div data-controller="sheet">
//     <button data-action="click->sheet#open" data-sheet-name-param="Chicken" ...>
//     <div data-sheet-target="overlay" class="hidden">
//       <div data-sheet-target="panel">...</div>
//     </div>
//   </div>
export default class extends Controller {
  static targets = ["overlay", "panel", "foodName", "foodCalories", "foodProtein", "foodCarbs", "foodFat", "foodFiber", "foodIdField", "usdaFdcIdField", "usdaNameField", "usdaCaloriesField", "usdaProteinField", "usdaCarbsField", "usdaFatField", "usdaFiberField"]

  open(event) {
    event.preventDefault()

    const dataset = event.currentTarget.dataset

    // Populate food info in the sheet
    this.foodNameTarget.textContent = dataset.sheetNameParam
    this.foodCaloriesTarget.textContent = `${Math.round(parseFloat(dataset.sheetCaloriesParam))} kcal per 100g`

    // Store per-100g values for the preview controller
    this.panelTarget.dataset.caloriesPer100 = dataset.sheetCaloriesParam
    this.panelTarget.dataset.proteinPer100 = dataset.sheetProteinParam
    this.panelTarget.dataset.carbsPer100 = dataset.sheetCarbsParam
    this.panelTarget.dataset.fatPer100 = dataset.sheetFatParam
    this.panelTarget.dataset.fiberPer100 = dataset.sheetFiberParam

    // Set food_id or USDA fields
    if (dataset.sheetFoodIdParam) {
      this.foodIdFieldTarget.value = dataset.sheetFoodIdParam
      this.foodIdFieldTarget.disabled = false
      this.usdaFdcIdFieldTarget.disabled = true
    } else {
      this.foodIdFieldTarget.disabled = true
      this.usdaFdcIdFieldTarget.value = dataset.sheetUsdaFdcIdParam
      this.usdaFdcIdFieldTarget.disabled = false
      this.usdaNameFieldTarget.value = dataset.sheetNameParam
      this.usdaCaloriesFieldTarget.value = dataset.sheetCaloriesParam
      this.usdaProteinFieldTarget.value = dataset.sheetProteinParam
      this.usdaCarbsFieldTarget.value = dataset.sheetCarbsParam
      this.usdaFatFieldTarget.value = dataset.sheetFatParam
      this.usdaFiberFieldTarget.value = dataset.sheetFiberParam
    }

    this.overlayTarget.classList.remove("hidden")
    document.body.classList.add("overflow-hidden")
  }

  close(event) {
    if (event) event.preventDefault()
    this.overlayTarget.classList.add("hidden")
    document.body.classList.remove("overflow-hidden")
  }

  closeOnOverlay(event) {
    if (event.target === this.overlayTarget) {
      this.close(event)
    }
  }
}
```

- [ ] **Step 2: Create quantity_preview_controller.js**

Create `app/javascript/controllers/quantity_preview_controller.js`:

```javascript
import { Controller } from "@hotwired/stimulus"

// Live calorie/macro preview as user types grams.
// Reads per-100g values from the panel's data attributes.
// Usage:
//   <div data-controller="quantity-preview"
//        data-quantity-preview-calories-per100-value="250"
//        data-quantity-preview-protein-per100-value="10"
//        ...>
//     <input data-quantity-preview-target="input" data-action="input->quantity-preview#update">
//     <span data-quantity-preview-target="calories">0</span>
//     <span data-quantity-preview-target="protein">0</span>
//     ...
//   </div>
export default class extends Controller {
  static targets = ["input", "calories", "protein", "carbs", "fat", "fiber"]
  static values = {
    caloriesPer100: { type: Number, default: 0 },
    proteinPer100: { type: Number, default: 0 },
    carbsPer100: { type: Number, default: 0 },
    fatPer100: { type: Number, default: 0 },
    fiberPer100: { type: Number, default: 0 }
  }

  update() {
    const grams = parseFloat(this.inputTarget.value) || 0
    const factor = grams / 100

    this.caloriesTarget.textContent = Math.round(this.caloriesPer100Value * factor)
    this.proteinTarget.textContent = (this.proteinPer100Value * factor).toFixed(1)
    this.carbsTarget.textContent = (this.carbsPer100Value * factor).toFixed(1)
    this.fatTarget.textContent = (this.fatPer100Value * factor).toFixed(1)
    this.fiberTarget.textContent = (this.fiberPer100Value * factor).toFixed(1)
  }
}
```

- [ ] **Step 3: Create swipe_controller.js**

Create `app/javascript/controllers/swipe_controller.js`:

```javascript
import { Controller } from "@hotwired/stimulus"

// Horizontal scroll snap for tally card pages with dot indicators.
// Usage:
//   <div data-controller="swipe">
//     <div data-swipe-target="container" class="flex overflow-x-auto snap-x snap-mandatory">
//       <div class="snap-center min-w-full">Page 1</div>
//       <div class="snap-center min-w-full">Page 2</div>
//     </div>
//     <div class="flex justify-center gap-1.5 mt-2">
//       <span data-swipe-target="dot" class="w-1.5 h-1.5 rounded-full bg-primary"></span>
//       <span data-swipe-target="dot" class="w-1.5 h-1.5 rounded-full bg-border"></span>
//     </div>
//   </div>
export default class extends Controller {
  static targets = ["container", "dot"]

  connect() {
    this.containerTarget.addEventListener("scroll", this.updateDots.bind(this))
  }

  disconnect() {
    this.containerTarget.removeEventListener("scroll", this.updateDots.bind(this))
  }

  updateDots() {
    const container = this.containerTarget
    const scrollLeft = container.scrollLeft
    const pageWidth = container.offsetWidth
    const currentPage = Math.round(scrollLeft / pageWidth)

    this.dotTargets.forEach((dot, index) => {
      if (index === currentPage) {
        dot.classList.remove("bg-border")
        dot.classList.add("bg-primary")
      } else {
        dot.classList.remove("bg-primary")
        dot.classList.add("bg-border")
      }
    })
  }
}
```

- [ ] **Step 4: Create the bottom sheet partial**

Create `app/views/foods/_bottom_sheet.html.haml`:

```haml
-# Bottom sheet overlay — hidden by default, opened by sheet controller
%div.hidden.fixed.inset-0.z-50.bg-black.bg-opacity-50.flex.items-end.justify-center{ data: { sheet_target: "overlay", action: "click->sheet#closeOnOverlay" } }
  %div.bg-bg.rounded-t-xl.w-full.max-w-lg.max-h-[85vh].overflow-y-auto.p-5{ data: { sheet_target: "panel" } }
    -# Close button
    .flex.justify-between.items-center.mb-4
      %h2.text-lg.font-bold.text-text{ data: { sheet_target: "foodName" } }
      %button.text-text-secondary.text-xl{ data: { action: "click->sheet#close" } } &times;

    %p.text-sm.text-text-secondary.mb-4{ data: { sheet_target: "foodCalories" } }

    = form_with url: day_food_log_entries_path(date: @date), method: :post do |f|
      %input{ type: "hidden", name: "food_log_entry[meal]", value: @meal }
      %input{ type: "hidden", name: "food_log_entry[food_id]", data: { sheet_target: "foodIdField" } }
      -# USDA hidden fields (disabled by default, enabled when USDA food selected)
      %input{ type: "hidden", name: "usda_fdc_id", disabled: true, data: { sheet_target: "usdaFdcIdField" } }
      %input{ type: "hidden", name: "usda_name", disabled: true, data: { sheet_target: "usdaNameField" } }
      %input{ type: "hidden", name: "usda_calories", disabled: true, data: { sheet_target: "usdaCaloriesField" } }
      %input{ type: "hidden", name: "usda_protein", disabled: true, data: { sheet_target: "usdaProteinField" } }
      %input{ type: "hidden", name: "usda_carbs", disabled: true, data: { sheet_target: "usdaCarbsField" } }
      %input{ type: "hidden", name: "usda_fat", disabled: true, data: { sheet_target: "usdaFatField" } }
      %input{ type: "hidden", name: "usda_fiber", disabled: true, data: { sheet_target: "usdaFiberField" } }

      -# Gram input with live preview
      %div{ data: { controller: "quantity-preview" } }
        .mb-4
          = label_tag :quantity_g, "Grams", class: "label"
          %input.input.w-full.text-center.text-2xl.font-bold{ type: "number", name: "food_log_entry[quantity_g]", step: "0.01", min: "0.01", placeholder: "0", autofocus: true, data: { quantity_preview_target: "input", action: "input->quantity-preview#update" } }

        -# This food preview
        .bg-primary-tint.rounded-md.p-3.mb-4
          %p.text-xs.font-medium.text-text-secondary.mb-1 This food
          .flex.items-baseline.gap-1
            %span.text-lg.font-bold.text-text{ data: { quantity_preview_target: "calories" } } 0
            %span.text-sm.text-text-secondary kcal
          .flex.gap-3.mt-1.text-xs.text-text-secondary
            %span
              P
              %b.text-text{ data: { quantity_preview_target: "protein" } } 0
              g
            %span
              C
              %b.text-text{ data: { quantity_preview_target: "carbs" } } 0
              g
            %span
              F
              %b.text-text{ data: { quantity_preview_target: "fat" } } 0
              g
            %span
              Fiber
              %b.text-text{ data: { quantity_preview_target: "fiber" } } 0
              g

        -# Swipeable tally card
        %div{ data: { controller: "swipe" } }
          .flex.overflow-x-auto.snap-x.snap-mandatory.scrollbar-none.rounded-md.border.border-border{ data: { swipe_target: "container" }, style: "-webkit-overflow-scrolling: touch;" }
            -# Page 1: Meal tally
            .snap-center.min-w-full.p-3
              %p.text-xs.font-semibold.text-primary.mb-2= "#{@meal&.capitalize} total"
              %p.text-text-secondary.text-xs (projected values shown after adding)
            -# Page 2: Daily tally
            .snap-center.min-w-full.p-3
              %p.text-xs.font-semibold.text-primary.mb-2 Daily total
              %p.text-text-secondary.text-xs (projected values shown after adding)
          .flex.justify-center.gap-1.mt-2{ class: "py-0.5" }
            %span.w-1.h-1.rounded-full.bg-primary{ data: { swipe_target: "dot" } }
            %span.w-1.h-1.rounded-full.bg-border{ data: { swipe_target: "dot" } }

        .mt-4
          = render ButtonComponent.new(label: "Add to #{@meal&.capitalize}", tag: :input, type: :submit, class: "w-full")
```

- [ ] **Step 5: Update _results.html.haml to add click triggers**

Update `app/views/foods/_results.html.haml` to wrap each food result with sheet open action when meal context is present. Replace the entire file with:

```haml
- has_meal_context = @meal.present? && @date.present?

- if @query.present? && @query.length >= 3 && @results.empty?
  .text-center.py-8.text-text-secondary
    %p No foods found for "#{@query}"
    %p.text-sm.mt-1 Try a different search term

- @results.each do |result|
  - calories = result.calories.to_f
  - protein = result.protein.to_f
  - carbs = result.carbs.to_f
  - fat = result.fat.to_f
  - fiber = result.fiber.to_f
  - source = result.respond_to?(:source) ? result.source : "usda"
  - is_local = result.is_a?(Food)
  - food_id = is_local ? result.id : nil
  - usda_fdc_id = result.is_a?(Usda::FoodResult) ? result.fdc_id : nil

  %div.border-b.border-border.py-3{ data: { food_result: true }.merge(has_meal_context ? { meal_context_active: true, action: "click->sheet#open", sheet_name_param: result.name, sheet_calories_param: calories, sheet_protein_param: protein, sheet_carbs_param: carbs, sheet_fat_param: fat, sheet_fiber_param: fiber, sheet_food_id_param: food_id, sheet_usda_fdc_id_param: usda_fdc_id } : {}), class: has_meal_context ? "cursor-pointer hover:bg-primary-tint transition-colors" : nil }
    .flex.justify-between.items-start
      .min-w-0.flex-1.mr-3
        %p.font-medium.text-text.truncate= result.name
        %p.text-sm.text-text-secondary{ class: "mt-0.5" }
          - case source
          - when "usda"
            %span.inline-block.text-xs.font-medium.rounded{ class: "px-1.5 py-0.5", style: "background: #F0FDF4; color: #16A34A;" } USDA
          - when "off"
            %span.inline-block.text-xs.font-medium.rounded{ class: "px-1.5 py-0.5", style: "background: #FEF3C7; color: #D97706;" } OFF
          - when "user"
            %span.inline-block.text-xs.font-medium.rounded{ class: "px-1.5 py-0.5", style: "background: #EDE9FE; color: #7C3AED;" } You
          - if result.brand.present?
            = result.brand
      .text-right.whitespace-nowrap
        %p.font-semibold.text-text= "#{calories.round} kcal"
    .flex.flex-wrap.gap-2.text-xs.text-text-secondary{ class: "mt-1.5" }
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
    - if !has_meal_context && result.is_a?(Food) && result.user? && result.creator_id == current_user&.id
      .flex.gap-3.mt-1.text-xs
        = link_to "Edit", edit_food_path(result), class: "text-primary"
        = link_to "Delete", food_path(result), data: { turbo_method: :delete, turbo_confirm: "Delete #{result.name}?" }, class: "text-danger"

- if @query.present? && @query.length >= 3
  .text-center.py-4.border-t.border-border.mt-2
    %p.text-sm.text-text-secondary
      Can't find it?
      = link_to "Create your own", new_food_path(name: @query), class: "text-primary font-medium"
```

- [ ] **Step 6: Add bottom sheet to index.html.haml**

Add at the bottom of `app/views/foods/index.html.haml`, after the turbo_frame_tag block:

```haml

- if @meal.present? && @date.present?
  = render "bottom_sheet"
```

Also wrap the entire page content in the sheet controller scope. Add at the very top of `index.html.haml`:

```haml
%div{ data: { controller: @meal.present? ? "sheet" : nil } }
```

And close it at the bottom (indent all existing content one level).

The final `app/views/foods/index.html.haml` should be:

```haml
%div{ data: { controller: @meal.present? ? "sheet" : nil } }
  %h1.text-xl.font-bold.mb-4 Search Foods

  - if @meal.present? && @date.present?
    %div.text-sm.text-text-secondary.mb-3.font-medium{ data: { meal_context: true } }
      Adding to #{@meal.capitalize} &middot; #{Date.parse(@date).strftime("%b %-d")}

  = form_with url: foods_path, method: :get, data: { controller: "search", search_target: "form", turbo_frame: "food_search_results" } do
    - if @meal.present?
      %input{ type: "hidden", name: "meal", value: @meal }
    - if @date.present?
      %input{ type: "hidden", name: "date", value: @date }
    .relative
      %input.input.w-full.pl-10{ type: "text", name: "q", value: @query, placeholder: "Search foods...", autocomplete: "off", data: { search_target: "input", action: "input->search#debounce" } }
      %div.absolute.left-3{ class: "top-1/2 -translate-y-1/2 text-text-secondary" }
        != '<svg class="w-4 h-4" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="2" stroke="currentColor"><circle cx="11" cy="11" r="8"/><path d="M21 21l-4.35-4.35" stroke-linecap="round"/></svg>'

  = turbo_frame_tag "food_search_results", class: "block mt-4" do
    = render "results"

  - if @meal.present? && @date.present?
    = render "bottom_sheet"
```

- [ ] **Step 7: Run all existing tests to ensure nothing is broken**

```bash
bin/rails test
```

- [ ] **Step 8: Commit**

```bash
git add -A && git commit -m "Add bottom sheet with quantity preview and swipeable tally for food logging"
```

---

### Task 6: USDA transient food persistence on log

**Files:**
- Modify: `app/controllers/food_log_entries_controller.rb`
- Modify: `test/controllers/food_log_entries_controller_test.rb`

- [ ] **Step 1: Write the failing tests**

Add these tests to `test/controllers/food_log_entries_controller_test.rb`:

```ruby
# USDA transient food persistence
test "POST with usda_fdc_id persists food then creates entry" do
  login(@account)

  usda_client = Minitest::Mock.new
  food_result = Usda::FoodResult.new(
    fdc_id: "12345",
    name: "USDA Chicken",
    brand: nil,
    calories: 165,
    protein: 31,
    carbs: 0,
    fat: 3.6,
    fiber: 0,
    serving_size: nil,
    serving_label: nil
  )
  persisted_food = create(:food, :usda, name: "USDA Chicken", external_id: "12345", calories: 165, protein: 31, carbs: 0, fat: 3.6, fiber: 0)
  usda_client.expect(:persist, persisted_food, [Usda::FoodResult])

  Usda::Client.stub(:new, usda_client) do
    assert_difference "FoodLogEntry.count", 1 do
      post day_food_log_entries_path(date: @date), params: {
        food_log_entry: { meal: "breakfast", quantity_g: 200 },
        usda_fdc_id: "12345",
        usda_name: "USDA Chicken",
        usda_calories: "165",
        usda_protein: "31",
        usda_carbs: "0",
        usda_fat: "3.6",
        usda_fiber: "0"
      }
    end
  end

  entry = FoodLogEntry.last
  assert_equal persisted_food.id, entry.food_id
  assert_equal @user.id, entry.user_id
  assert_redirected_to day_path(date: @date)
end

test "POST with usda_fdc_id and existing persisted food reuses it" do
  login(@account)
  existing_food = create(:food, :usda, name: "USDA Chicken", external_id: "12345", calories: 165, protein: 31, carbs: 0, fat: 3.6, fiber: 0)

  usda_client = Minitest::Mock.new
  usda_client.expect(:persist, existing_food, [Usda::FoodResult])

  Usda::Client.stub(:new, usda_client) do
    assert_difference "FoodLogEntry.count", 1 do
      assert_no_difference "Food.count" do
        post day_food_log_entries_path(date: @date), params: {
          food_log_entry: { meal: "lunch", quantity_g: 100 },
          usda_fdc_id: "12345",
          usda_name: "USDA Chicken",
          usda_calories: "165",
          usda_protein: "31",
          usda_carbs: "0",
          usda_fat: "3.6",
          usda_fiber: "0"
        }
      end
    end
  end

  entry = FoodLogEntry.last
  assert_equal existing_food.id, entry.food_id
end
```

- [ ] **Step 2: Run the tests — the new ones should fail**

```bash
bin/rails test test/controllers/food_log_entries_controller_test.rb
```

- [ ] **Step 3: Update FoodLogEntriesController#create to handle USDA transient foods**

Replace the `create` action in `app/controllers/food_log_entries_controller.rb`:

```ruby
def create
  @entry = current_user.food_log_entries.build(entry_params)
  @entry.logged_on = @date

  if params[:usda_fdc_id].present?
    food_result = Usda::FoodResult.new(
      fdc_id: params[:usda_fdc_id],
      name: params[:usda_name],
      brand: nil,
      calories: params[:usda_calories].to_f,
      protein: params[:usda_protein].to_f,
      carbs: params[:usda_carbs].to_f,
      fat: params[:usda_fat].to_f,
      fiber: params[:usda_fiber].to_f,
      serving_size: nil,
      serving_label: nil
    )
    food = Usda::Client.new.persist(food_result)
    @entry.food = food
  end

  if @entry.save
    redirect_to day_path(date: @date.iso8601), notice: t("flash.entry_created")
  else
    render :new, status: :unprocessable_entity
  end
end
```

- [ ] **Step 4: Update entry_params to exclude food_id when USDA flow is used**

The existing `entry_params` method already permits `food_id`, which works for both flows. When `usda_fdc_id` is present, the form sends `food_log_entry[food_id]` as disabled (so it's blank), and the controller sets `@entry.food` explicitly. No change needed to `entry_params`.

- [ ] **Step 5: Run the tests — they should all pass**

```bash
bin/rails test test/controllers/food_log_entries_controller_test.rb
```

- [ ] **Step 6: Run the full test suite**

```bash
bin/rails test
```

- [ ] **Step 7: Commit**

```bash
git add -A && git commit -m "Handle USDA transient food persistence when creating food log entries"
```
