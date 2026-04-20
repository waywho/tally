# Meal Templates Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Allow users to save meal bucket entries as reusable templates and one-tap log them into any meal.

**Architecture:** MealTemplate has many MealTemplateItems (food + weight). Created from existing meal entries on the Today view. Logged by creating FoodLogEntries for all items in one action. Templates shown on the search page when meal context is present.

**Tech Stack:** Rails 8.1, PostgreSQL, Haml, Tailwind CSS, Minitest, FactoryBot

---

## File Structure

| Action | File | Responsibility |
|--------|------|----------------|
| Create | `db/migrate/TIMESTAMP_create_meal_templates.rb` | meal_templates table migration |
| Create | `db/migrate/TIMESTAMP_create_meal_template_items.rb` | meal_template_items table migration |
| Create | `app/models/meal_template.rb` | MealTemplate model with associations, validations |
| Create | `app/models/meal_template_item.rb` | MealTemplateItem model with associations, validations |
| Modify | `app/models/user.rb` | Add `has_many :meal_templates` |
| Modify | `config/routes.rb` | Add `resources :meal_templates` with `log` member route |
| Create | `app/controllers/meal_templates_controller.rb` | CRUD + log controller |
| Create | `app/views/meal_templates/index.html.haml` | Template list page |
| Create | `app/views/meal_templates/new.html.haml` | New template page with preview |
| Modify | `app/views/days/show.html.haml` | Add "Save as template" link to meal buckets |
| Modify | `app/views/foods/index.html.haml` | Add templates section above search results |
| Create | `app/views/meal_templates/_templates_section.html.haml` | Templates partial for search page |
| Modify | `app/controllers/foods_controller.rb` | Load templates when meal context present |
| Modify | `config/locales/en.yml` | Flash messages for meal templates |
| Create | `test/factories/meal_templates.rb` | MealTemplate factory |
| Create | `test/factories/meal_template_items.rb` | MealTemplateItem factory |
| Create | `test/models/meal_template_test.rb` | MealTemplate model tests |
| Create | `test/models/meal_template_item_test.rb` | MealTemplateItem model tests |
| Create | `test/controllers/meal_templates_controller_test.rb` | Controller integration tests |

---

### Task 1: MealTemplate + MealTemplateItem models, migrations, factories

**Files:**
- Create: `db/migrate/TIMESTAMP_create_meal_templates.rb`
- Create: `db/migrate/TIMESTAMP_create_meal_template_items.rb`
- Create: `app/models/meal_template.rb`
- Create: `app/models/meal_template_item.rb`
- Modify: `app/models/user.rb`
- Create: `test/factories/meal_templates.rb`
- Create: `test/factories/meal_template_items.rb`
- Create: `test/models/meal_template_test.rb`
- Create: `test/models/meal_template_item_test.rb`

- [ ] **Step 1: Generate the meal_templates migration**

Run:
```bash
bin/rails generate migration CreateMealTemplates user:references name:string
```

Then edit the generated migration to match this exact content:

```ruby
class CreateMealTemplates < ActiveRecord::Migration[8.1]
  def change
    create_table :meal_templates do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.string :name, null: false, limit: 255

      t.timestamps
    end
  end
end
```

- [ ] **Step 2: Generate the meal_template_items migration**

Run:
```bash
bin/rails generate migration CreateMealTemplateItems meal_template:references food:references weight:decimal
```

Then edit the generated migration to match this exact content:

```ruby
class CreateMealTemplateItems < ActiveRecord::Migration[8.1]
  def change
    create_table :meal_template_items do |t|
      t.references :meal_template, null: false, foreign_key: { on_delete: :cascade }
      t.references :food, null: false, foreign_key: true
      t.decimal :weight, precision: 8, scale: 2, null: false

      t.timestamps
    end
  end
end
```

- [ ] **Step 3: Run migrations**

```bash
bin/rails db:migrate
```

- [ ] **Step 4: Write model tests for MealTemplate**

Create `test/models/meal_template_test.rb`:

```ruby
require "test_helper"

class MealTemplateTest < ActiveSupport::TestCase
  test "factory is valid" do
    template = build(:meal_template)
    assert template.valid?, template.errors.full_messages.join(", ")
  end

  # Validations
  test "invalid without name" do
    template = build(:meal_template, name: nil)
    assert_not template.valid?
    assert_includes template.errors[:name], "can't be blank"
  end

  test "invalid with name over 255 characters" do
    template = build(:meal_template, name: "a" * 256)
    assert_not template.valid?
    assert template.errors[:name].any?
  end

  test "invalid without user" do
    template = build(:meal_template, user: nil)
    assert_not template.valid?
    assert_includes template.errors[:user], "must exist"
  end

  # Associations
  test "belongs to user" do
    template = create(:meal_template)
    assert_instance_of User, template.user
  end

  test "has many meal_template_items with dependent destroy" do
    template = create(:meal_template)
    create(:meal_template_item, meal_template: template)
    create(:meal_template_item, meal_template: template)

    assert_equal 2, template.meal_template_items.count

    assert_difference "MealTemplateItem.count", -2 do
      template.destroy!
    end
  end
end
```

- [ ] **Step 5: Write model tests for MealTemplateItem**

Create `test/models/meal_template_item_test.rb`:

```ruby
require "test_helper"

class MealTemplateItemTest < ActiveSupport::TestCase
  test "factory is valid" do
    item = build(:meal_template_item)
    assert item.valid?, item.errors.full_messages.join(", ")
  end

  test "invalid without food" do
    item = build(:meal_template_item, food: nil)
    assert_not item.valid?
    assert_includes item.errors[:food], "must exist"
  end

  test "invalid without weight" do
    item = build(:meal_template_item, weight: nil)
    assert_not item.valid?
    assert_includes item.errors[:weight], "can't be blank"
  end

  test "invalid with weight zero" do
    item = build(:meal_template_item, weight: 0)
    assert_not item.valid?
    assert item.errors[:weight].any?
  end

  test "invalid with negative weight" do
    item = build(:meal_template_item, weight: -5)
    assert_not item.valid?
    assert item.errors[:weight].any?
  end

  test "belongs to meal_template" do
    item = create(:meal_template_item)
    assert_instance_of MealTemplate, item.meal_template
  end

  test "belongs to food" do
    item = create(:meal_template_item)
    assert_instance_of Food, item.food
  end
end
```

- [ ] **Step 6: Run tests (expect failures — models don't exist yet)**

```bash
bin/rails test test/models/meal_template_test.rb test/models/meal_template_item_test.rb
```

- [ ] **Step 7: Create MealTemplate model**

Create `app/models/meal_template.rb`:

```ruby
class MealTemplate < ApplicationRecord
  belongs_to :user
  has_many :meal_template_items, dependent: :destroy

  validates :name, presence: true, length: { maximum: 255 }
end
```

- [ ] **Step 8: Create MealTemplateItem model**

Create `app/models/meal_template_item.rb`:

```ruby
class MealTemplateItem < ApplicationRecord
  belongs_to :meal_template
  belongs_to :food

  validates :weight, presence: true, numericality: { greater_than: 0 }
end
```

- [ ] **Step 9: Add association to User model**

In `app/models/user.rb`, add after the `has_many :recipes` line:

```ruby
  has_many :meal_templates, dependent: :destroy
```

- [ ] **Step 10: Create MealTemplate factory**

Create `test/factories/meal_templates.rb`:

```ruby
FactoryBot.define do
  factory :meal_template do
    association :user
    sequence(:name) { |n| "Template #{n}" }
  end
end
```

- [ ] **Step 11: Create MealTemplateItem factory**

Create `test/factories/meal_template_items.rb`:

```ruby
FactoryBot.define do
  factory :meal_template_item do
    association :meal_template
    association :food
    weight { 150 }
  end
end
```

- [ ] **Step 12: Run tests (expect pass)**

```bash
bin/rails test test/models/meal_template_test.rb test/models/meal_template_item_test.rb
```

- [ ] **Step 13: Commit**

```bash
git add app/models/meal_template.rb app/models/meal_template_item.rb app/models/user.rb \
  db/migrate/*_create_meal_templates.rb db/migrate/*_create_meal_template_items.rb db/schema.rb \
  test/models/meal_template_test.rb test/models/meal_template_item_test.rb \
  test/factories/meal_templates.rb test/factories/meal_template_items.rb
git commit -m "Add MealTemplate and MealTemplateItem models, migrations, and factories"
```

---

### Task 2: MealTemplatesController (new, create, index, destroy)

**Files:**
- Modify: `config/routes.rb`
- Create: `app/controllers/meal_templates_controller.rb`
- Create: `app/views/meal_templates/index.html.haml`
- Create: `app/views/meal_templates/new.html.haml`
- Modify: `config/locales/en.yml`
- Create: `test/controllers/meal_templates_controller_test.rb`

- [ ] **Step 1: Write controller tests for index, new, create, destroy**

Create `test/controllers/meal_templates_controller_test.rb`:

```ruby
require "test_helper"

class MealTemplatesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @account = create(:account)
    @user = create(:user, account: @account)
  end

  # Authentication
  test "index redirects when not authenticated" do
    get meal_templates_path
    assert_response :redirect
  end

  # Index
  test "index lists current user templates" do
    template = create(:meal_template, user: @user, name: "My Breakfast")
    create(:meal_template_item, meal_template: template)

    other_user = create(:user)
    create(:meal_template, user: other_user, name: "Other Template")

    login(@account)
    get meal_templates_path

    assert_response :success
    assert_select "[data-template]", count: 1
    assert_select "[data-template]", text: /My Breakfast/
  end

  test "index shows empty state when no templates" do
    login(@account)
    get meal_templates_path

    assert_response :success
    assert_select "p", text: /haven't saved any meal templates/
  end

  # New
  test "new pre-fills from meal entries" do
    food = create(:food, name: "Oatmeal", calories: 150)
    create(:food_log_entry, user: @user, food: food, meal: :breakfast, logged_on: Date.parse("2026-04-21"), weight: 200)

    login(@account)
    get new_meal_template_path(date: "2026-04-21", meal: "breakfast")

    assert_response :success
    assert_select "input[name='meal_template[name]']"
    assert_select "[data-preview-item]", count: 1
    assert_select "[data-preview-item]", text: /Oatmeal/
  end

  test "new shows empty state when no entries for meal" do
    login(@account)
    get new_meal_template_path(date: "2026-04-21", meal: "breakfast")

    assert_response :success
    assert_select "[data-empty-preview]"
  end

  test "new redirects when not authenticated" do
    get new_meal_template_path(date: "2026-04-21", meal: "breakfast")
    assert_response :redirect
  end

  # Create
  test "create saves template with items from meal entries" do
    food_a = create(:food, name: "Eggs")
    food_b = create(:food, name: "Toast")
    create(:food_log_entry, user: @user, food: food_a, meal: :breakfast, logged_on: Date.parse("2026-04-21"), weight: 120)
    create(:food_log_entry, user: @user, food: food_b, meal: :breakfast, logged_on: Date.parse("2026-04-21"), weight: 60)

    login(@account)

    assert_difference "MealTemplate.count", 1 do
      assert_difference "MealTemplateItem.count", 2 do
        post meal_templates_path, params: {
          meal_template: { name: "Quick Breakfast" },
          date: "2026-04-21",
          meal: "breakfast"
        }
      end
    end

    template = MealTemplate.last
    assert_equal "Quick Breakfast", template.name
    assert_equal @user.id, template.user_id
    assert_equal 2, template.meal_template_items.count

    food_ids = template.meal_template_items.pluck(:food_id)
    assert_includes food_ids, food_a.id
    assert_includes food_ids, food_b.id

    assert_redirected_to meal_templates_path
    assert_equal "Template saved.", flash[:notice]
  end

  test "create with blank name re-renders form" do
    food = create(:food)
    create(:food_log_entry, user: @user, food: food, meal: :breakfast, logged_on: Date.parse("2026-04-21"), weight: 100)

    login(@account)

    assert_no_difference "MealTemplate.count" do
      post meal_templates_path, params: {
        meal_template: { name: "" },
        date: "2026-04-21",
        meal: "breakfast"
      }
    end

    assert_response :unprocessable_entity
  end

  # Destroy
  test "destroy removes template" do
    template = create(:meal_template, user: @user)
    create(:meal_template_item, meal_template: template)

    login(@account)

    assert_difference "MealTemplate.count", -1 do
      assert_difference "MealTemplateItem.count", -1 do
        delete meal_template_path(template)
      end
    end

    assert_redirected_to meal_templates_path
    assert_equal "Template deleted.", flash[:notice]
  end

  test "destroy returns 404 for non-owner" do
    other_user = create(:user)
    template = create(:meal_template, user: other_user)

    login(@account)
    delete meal_template_path(template)
    assert_response :not_found
  end

  private

  def login(account)
    post "/login", params: { email: account.email, password: "password" }
  end
end
```

- [ ] **Step 2: Run tests (expect failures — controller and routes don't exist yet)**

```bash
bin/rails test test/controllers/meal_templates_controller_test.rb
```

- [ ] **Step 3: Add routes**

In `config/routes.rb`, add after the `resources :recipes` line:

```ruby
  resources :meal_templates, only: [:index, :new, :create, :destroy] do
    member do
      post :log
    end
  end
```

- [ ] **Step 4: Create MealTemplatesController**

Create `app/controllers/meal_templates_controller.rb`:

```ruby
class MealTemplatesController < ApplicationController
  before_action :require_authentication
  before_action :set_meal_template, only: [:destroy]

  def index
    @meal_templates = current_user.meal_templates
      .includes(meal_template_items: :food)
      .order(updated_at: :desc)
  end

  def new
    @meal_template = MealTemplate.new
    @date = params[:date]
    @meal = params[:meal]

    if @date.present? && @meal.present?
      @entries = current_user.food_log_entries
        .includes(:food)
        .where(logged_on: @date.to_date, meal: @meal)
      @meal_template.name = "#{@meal.capitalize} — #{@date.to_date.strftime("%b %-d")}"
    else
      @entries = []
    end
  end

  def create
    @meal_template = current_user.meal_templates.build(meal_template_params)
    @date = params[:date]
    @meal = params[:meal]

    entries = current_user.food_log_entries
      .where(logged_on: @date.to_date, meal: @meal)

    entries.each do |entry|
      @meal_template.meal_template_items.build(
        food_id: entry.food_id,
        weight: entry.weight
      )
    end

    if @meal_template.save
      redirect_to meal_templates_path, notice: t("flash.template_saved")
    else
      @entries = current_user.food_log_entries
        .includes(:food)
        .where(logged_on: @date.to_date, meal: @meal)
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    @meal_template.destroy!
    redirect_to meal_templates_path, notice: t("flash.template_deleted")
  end

  private

  def set_meal_template
    @meal_template = current_user.meal_templates.find(params[:id])
  end

  def meal_template_params
    params.require(:meal_template).permit(:name)
  end
end
```

- [ ] **Step 5: Add flash messages to en.yml**

In `config/locales/en.yml`, add under the `flash:` key after `recipe_deleted`:

```yaml
    template_saved: "Template saved."
    template_deleted: "Template deleted."
    template_logged: "Template logged."
```

- [ ] **Step 6: Create index view**

Create `app/views/meal_templates/index.html.haml`:

```haml
- @page_title = "Meal Templates"

%h1.text-xl.font-bold.mb-4 Meal Templates

- if @meal_templates.any?
  = render CardComponent.new(class: "divide-y divide-gray-100") do
    - @meal_templates.each do |template|
      - total_calories = template.meal_template_items.sum { |item| item.food.calories * item.weight / 100 }.round
      - item_count = template.meal_template_items.size

      %div{ data: { template: true } }
        .flex.justify-between.items-center.px-4.py-3
          .min-w-0.flex-1
            %p.font-medium.text-text.truncate= template.name
            %p.text-xs.text-text-secondary
              = "#{total_calories} kcal"
              %span.mx-1 &middot;
              = pluralize(item_count, "item")
          = button_to "Delete", meal_template_path(template), method: :delete, class: "text-sm text-danger font-medium ml-3", data: { turbo_confirm: "Delete #{template.name}?" }
- else
  = render CardComponent.new(class: "p-6 text-center text-text-secondary") do
    %p You haven't saved any meal templates yet.
    %p.mt-2.text-sm Save a meal from the Today view to create your first template.
```

- [ ] **Step 7: Create new view**

Create `app/views/meal_templates/new.html.haml`:

```haml
- @page_title = "Save as Template"

%h1.text-xl.font-bold.mb-4 Save as Template

= form_with model: @meal_template, url: meal_templates_path, method: :post do |f|
  %input{ type: "hidden", name: "date", value: @date }
  %input{ type: "hidden", name: "meal", value: @meal }

  .mb-4
    = f.label :name, "Template name", class: "block text-sm font-medium text-text mb-1"
    = f.text_field :name, class: "input w-full", maxlength: 255, required: true

  - if @entries.any?
    .mb-6
      %h2.text-sm.font-semibold.text-text-secondary.mb-2 Foods to save
      = render CardComponent.new(class: "divide-y divide-gray-100") do
        - @entries.each do |entry|
          .flex.justify-between.items-center.px-4.py-3{ data: { preview_item: true } }
            .min-w-0.flex-1
              %p.font-medium.text-text.truncate= entry.food.name
              %p.text-xs.text-text-secondary= "#{entry.weight.to_i}g"
            %span.text-sm.font-semibold.text-text.whitespace-nowrap= "#{entry.calories.round} kcal"

    = f.submit "Save Template", class: "w-full bg-primary text-white font-semibold py-2.5 px-4 rounded-md hover:bg-primary-light transition-colors cursor-pointer"
  - else
    %div{ data: { empty_preview: true } }
      = render CardComponent.new(class: "p-6 text-center text-text-secondary") do
        %p No entries found for this meal.
        %p.mt-2.text-sm Log some foods first, then save as a template.

%p.text-center.text-sm.text-text-secondary.mt-4
  = link_to "Back to templates", meal_templates_path, class: "text-primary"
```

- [ ] **Step 8: Run tests (expect pass)**

```bash
bin/rails test test/controllers/meal_templates_controller_test.rb
```

- [ ] **Step 9: Commit**

```bash
git add app/controllers/meal_templates_controller.rb \
  app/views/meal_templates/index.html.haml app/views/meal_templates/new.html.haml \
  config/routes.rb config/locales/en.yml \
  test/controllers/meal_templates_controller_test.rb
git commit -m "Add MealTemplatesController with index, new, create, destroy actions"
```

---

### Task 3: Log action on MealTemplatesController

**Files:**
- Modify: `app/controllers/meal_templates_controller.rb`
- Modify: `test/controllers/meal_templates_controller_test.rb`

- [ ] **Step 1: Write tests for the log action**

Append to `test/controllers/meal_templates_controller_test.rb`, inside the class but before the `private` section:

```ruby
  # Log
  test "log creates food_log_entries for all template items" do
    food_a = create(:food, name: "Eggs")
    food_b = create(:food, name: "Toast")
    template = create(:meal_template, user: @user, name: "Quick Breakfast")
    create(:meal_template_item, meal_template: template, food: food_a, weight: 120)
    create(:meal_template_item, meal_template: template, food: food_b, weight: 60)

    login(@account)

    assert_difference "FoodLogEntry.count", 2 do
      post log_meal_template_path(template), params: {
        date: "2026-04-21",
        meal: "lunch"
      }
    end

    entries = FoodLogEntry.last(2)
    entries.each do |entry|
      assert_equal @user.id, entry.user_id
      assert_equal "lunch", entry.meal
      assert_equal Date.parse("2026-04-21"), entry.logged_on
    end

    food_ids = entries.map(&:food_id)
    assert_includes food_ids, food_a.id
    assert_includes food_ids, food_b.id

    weights = entries.sort_by(&:food_id).map(&:weight)
    expected_weights = [food_a, food_b].sort_by(&:id).map { |f| f == food_a ? 120.0 : 60.0 }
    expected_weights.each_with_index do |w, i|
      assert_in_delta w, weights[i], 0.01
    end

    assert_redirected_to day_path(date: "2026-04-21")
    assert_equal "Template logged.", flash[:notice]
  end

  test "log returns 404 for other user template" do
    other_user = create(:user)
    template = create(:meal_template, user: other_user)

    login(@account)
    post log_meal_template_path(template), params: {
      date: "2026-04-21",
      meal: "breakfast"
    }
    assert_response :not_found
  end
```

- [ ] **Step 2: Run tests (expect failure for log tests)**

```bash
bin/rails test test/controllers/meal_templates_controller_test.rb
```

- [ ] **Step 3: Implement the log action**

In `app/controllers/meal_templates_controller.rb`:

Update the `before_action` line to include `log`:

```ruby
  before_action :set_meal_template, only: [:destroy, :log]
```

Add the `log` action after `destroy`:

```ruby
  def log
    date = params[:date].to_date
    meal = params[:meal]

    @meal_template.meal_template_items.each do |item|
      current_user.food_log_entries.create!(
        food_id: item.food_id,
        weight: item.weight,
        meal: meal,
        logged_on: date
      )
    end

    redirect_to day_path(date: date.iso8601), notice: t("flash.template_logged")
  end
```

- [ ] **Step 4: Run tests (expect pass)**

```bash
bin/rails test test/controllers/meal_templates_controller_test.rb
```

- [ ] **Step 5: Commit**

```bash
git add app/controllers/meal_templates_controller.rb \
  test/controllers/meal_templates_controller_test.rb
git commit -m "Add log action to MealTemplatesController for one-tap template logging"
```

---

### Task 4: Today view modification — "Save as template" link

**Files:**
- Modify: `app/views/days/show.html.haml`

- [ ] **Step 1: Add "Save as template" link to meal buckets**

In `app/views/days/show.html.haml`, find the block inside each meal bucket where entries are rendered. After the last entry link (the `- entries.each do |entry|` block's closing), add a "Save as template" link that only appears when the bucket has entries.

Replace the existing `- if entries.any?` block inside the meal bucket with:

```haml
          - if entries.any?
            - entries.each do |entry|
              = link_to edit_day_food_log_entry_path(day_date: @date.iso8601, id: entry.id), class: "block" do
                .flex.justify-between.items-center.px-4.py-3.border-b.border-border{ data: { entry_id: entry.id } }
                  .min-w-0.flex-1
                    %p.font-medium.text-text.truncate= entry.food.name
                    %p.text-xs.text-text-secondary= "#{entry.weight.to_i}g"
                  %span.text-sm.font-semibold.text-text.whitespace-nowrap= "#{entry.calories.round} kcal"
            .px-4.py-2.text-center
              = link_to "Save as template", new_meal_template_path(date: @date.iso8601, meal: meal), class: "text-xs text-primary font-medium", data: { save_template: true }
```

The key change is adding the `.px-4.py-2.text-center` block with the link after the entries loop.

- [ ] **Step 2: Verify the view renders without error**

```bash
bin/rails test test/controllers/days_controller_test.rb
```

If no days controller test exists, manually verify by running:

```bash
bin/rails runner "puts 'View compiles OK'"
```

- [ ] **Step 3: Commit**

```bash
git add app/views/days/show.html.haml
git commit -m "Add 'Save as template' link to meal buckets on Today view"
```

---

### Task 5: Search page templates section

**Files:**
- Modify: `app/controllers/foods_controller.rb`
- Create: `app/views/meal_templates/_templates_section.html.haml`
- Modify: `app/views/foods/index.html.haml`
- Modify: `test/controllers/meal_templates_controller_test.rb`

- [ ] **Step 1: Write integration tests for templates on search page**

Append to `test/controllers/meal_templates_controller_test.rb`, inside the class but before the `private` section:

```ruby
  # Search page integration
  test "templates section appears on search page with meal context" do
    food = create(:food, name: "Eggs", calories: 150)
    template = create(:meal_template, user: @user, name: "Quick Breakfast")
    create(:meal_template_item, meal_template: template, food: food, weight: 100)

    login(@account)
    get foods_path(meal: "breakfast", date: "2026-04-21")

    assert_response :success
    assert_select "[data-templates-section]"
    assert_select "[data-templates-section]", text: /Quick Breakfast/
  end

  test "templates section hidden when no meal context" do
    template = create(:meal_template, user: @user, name: "Quick Breakfast")
    create(:meal_template_item, meal_template: template)

    login(@account)
    get foods_path

    assert_response :success
    assert_select "[data-templates-section]", count: 0
  end

  test "templates section hidden when user has no templates" do
    login(@account)
    get foods_path(meal: "breakfast", date: "2026-04-21")

    assert_response :success
    assert_select "[data-templates-section]", count: 0
  end
```

- [ ] **Step 2: Run tests (expect failure)**

```bash
bin/rails test test/controllers/meal_templates_controller_test.rb
```

- [ ] **Step 3: Modify FoodsController to load templates**

In `app/controllers/foods_controller.rb`, update the `index` action to load templates when meal context is present. Add after `@date = params[:date]`:

```ruby
    @meal_templates = if @meal.present? && @date.present?
      current_user.meal_templates
        .includes(meal_template_items: :food)
        .order(updated_at: :desc)
    else
      []
    end
```

The full `index` action becomes:

```ruby
  def index
    @query = params[:q].to_s.strip
    @results = if @query.length >= 3
      FoodSearch.call(@query, user: current_user)
    else
      []
    end
    @meal = params[:meal]
    @date = params[:date]
    @meal_templates = if @meal.present? && @date.present?
      current_user.meal_templates
        .includes(meal_template_items: :food)
        .order(updated_at: :desc)
    else
      []
    end
  end
```

- [ ] **Step 4: Create templates section partial**

Create `app/views/meal_templates/_templates_section.html.haml`:

```haml
- if meal_templates.any?
  %div{ data: { templates_section: true } }
    %h2.text-sm.font-semibold.text-text-secondary.mb-2 Templates
    = render CardComponent.new(class: "divide-y divide-gray-100 mb-4") do
      - meal_templates.each do |template|
        - total_calories = template.meal_template_items.sum { |item| item.food.calories * item.weight / 100 }.round
        - item_count = template.meal_template_items.size

        .flex.justify-between.items-center.px-4.py-3
          .min-w-0.flex-1
            %p.font-medium.text-text.truncate= template.name
            %p.text-xs.text-text-secondary
              = "#{total_calories} kcal"
              %span.mx-1 &middot;
              = pluralize(item_count, "item")
          = form_with url: log_meal_template_path(template), method: :post, class: "ml-3" do
            %input{ type: "hidden", name: "date", value: date }
            %input{ type: "hidden", name: "meal", value: meal }
            %button.text-sm.font-semibold.text-primary.cursor-pointer{ type: "submit" } Log

    .text-center.mb-4
      = link_to "Manage templates", meal_templates_path, class: "text-xs text-text-secondary hover:text-primary"
```

- [ ] **Step 5: Render templates section on search page**

In `app/views/foods/index.html.haml`, add the templates section after the meal context badge and before the search form. Insert after the `- if @meal.present? && @date.present?` context block (the `%div.text-sm.text-text-secondary.mb-3.font-medium` block) and before the `= form_with` line:

```haml
  = render "meal_templates/templates_section", meal_templates: @meal_templates, date: @date, meal: @meal
```

The relevant portion of the file becomes:

```haml
  - if @meal.present? && @date.present?
    %div.text-sm.text-text-secondary.mb-3.font-medium{ data: { meal_context: true } }
      Adding to #{@meal.capitalize} &middot; #{Date.parse(@date).strftime("%b %-d")}

  = render "meal_templates/templates_section", meal_templates: @meal_templates, date: @date, meal: @meal

  = form_with url: foods_path, method: :get, data: { controller: "search", search_target: "form", turbo_frame: "food_search_results" } do
```

- [ ] **Step 6: Run tests (expect pass)**

```bash
bin/rails test test/controllers/meal_templates_controller_test.rb
```

- [ ] **Step 7: Run full test suite to verify no regressions**

```bash
bin/rails test
```

- [ ] **Step 8: Commit**

```bash
git add app/controllers/foods_controller.rb \
  app/views/meal_templates/_templates_section.html.haml \
  app/views/foods/index.html.haml \
  test/controllers/meal_templates_controller_test.rb
git commit -m "Show meal templates on search page when meal context is present"
```
