# Food Model Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create the `Food` model and schema with full-text search support, serving as the single table for all food data (Open Food Facts, USDA, user-created).

**Architecture:** Single `foods` table with nutritional values stored per 100g. Postgres `tsvector` generated column + `pg_trgm` extension for full-text and fuzzy search. Three sources tracked via integer enum. Optional `creator_id` FK to users for user-created foods.

**Tech Stack:** Rails 8, PostgreSQL (pg_trgm, tsvector), Minitest, factory_bot

---

## File Structure

| File | Responsibility |
|---|---|
| `db/migrate/TIMESTAMP_create_foods.rb` | Migration: foods table, pg_trgm extension, indexes |
| `app/models/food.rb` | Food model with validations, enum, association |
| `app/models/user.rb` | Add `has_many :created_foods` association |
| `test/factories/foods.rb` | Food factory with traits |
| `test/models/food_test.rb` | Model tests |

---

### Task 1: Migration and pg_trgm extension

**Files:**
- Create: `db/migrate/TIMESTAMP_create_foods.rb`

- [ ] **Step 1: Generate the model**

Run: `bin/rails generate model Food name:string brand:string barcode:string serving_size:decimal serving_label:string calories:decimal protein:decimal carbs:decimal fat:decimal fiber:decimal source:integer external_id:string verified_at:datetime`

This creates the migration, model, and test stub.

- [ ] **Step 2: Replace the migration with the full version**

Replace the generated migration content with:

```ruby
class CreateFoods < ActiveRecord::Migration[8.1]
  def change
    enable_extension "pg_trgm"

    create_table :foods do |t|
      t.string :name, null: false, limit: 255
      t.string :brand
      t.string :barcode
      t.decimal :serving_size, precision: 8, scale: 2
      t.string :serving_label
      t.decimal :calories, precision: 8, scale: 2, null: false
      t.decimal :protein, precision: 8, scale: 2, null: false
      t.decimal :carbs, precision: 8, scale: 2, null: false
      t.decimal :fat, precision: 8, scale: 2, null: false
      t.decimal :fiber, precision: 8, scale: 2, null: false, default: 0
      t.integer :source, null: false
      t.string :external_id
      t.references :creator, null: true, foreign_key: { to_table: :users, on_delete: :cascade }
      t.datetime :verified_at

      t.timestamps
    end

    add_index :foods, :barcode
    add_index :foods, [:source, :external_id], unique: true, where: "external_id IS NOT NULL"
    add_index :foods, :creator_id
    add_index :foods, :name, using: :gin, opclass: :gin_trgm_ops, name: "index_foods_on_name_trigram"

    reversible do |dir|
      dir.up do
        execute <<~SQL
          ALTER TABLE foods ADD COLUMN searchable tsvector
            GENERATED ALWAYS AS (
              to_tsvector('english', coalesce(name, '') || ' ' || coalesce(brand, ''))
            ) STORED;
        SQL
        execute <<~SQL
          CREATE INDEX index_foods_on_searchable ON foods USING gin(searchable);
        SQL
      end
    end
  end
end
```

- [ ] **Step 3: Run the migration**

Run: `bin/rails db:migrate`
Expected: Migration runs successfully, creates foods table with all columns, indexes, and generated tsvector column.

- [ ] **Step 4: Verify the table exists**

Run: `bin/rails runner "puts Food.column_names.sort.join(', ')"`
Expected: Output includes `barcode, brand, calories, carbs, created_at, creator_id, external_id, fat, fiber, id, name, protein, searchable, serving_label, serving_size, source, updated_at, verified_at`

- [ ] **Step 5: Commit**

```bash
git add db/migrate/ db/schema.rb app/models/food.rb test/models/food_test.rb
git commit -m "feat: create foods table with tsvector search and pg_trgm"
```

---

### Task 2: Food model with validations and associations

**Files:**
- Modify: `app/models/food.rb`
- Modify: `app/models/user.rb`
- Create: `test/factories/foods.rb`

- [ ] **Step 1: Write the Food model**

Replace the generated `app/models/food.rb` with:

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

  private

  def creator_required_for_user_source
    if user? && creator_id.nil?
      errors.add(:creator_id, "is required for user-created foods")
    end
  end
end
```

- [ ] **Step 2: Add the association to User model**

In `app/models/user.rb`, add after the `belongs_to :account` line:

```ruby
  has_many :created_foods, class_name: "Food", foreign_key: :creator_id, dependent: :destroy
```

- [ ] **Step 3: Create the Food factory**

Create `test/factories/foods.rb`:

```ruby
FactoryBot.define do
  factory :food do
    sequence(:name) { |n| "Food Item #{n}" }
    brand { "Generic Brand" }
    calories { 250.0 }
    protein { 10.0 }
    carbs { 30.0 }
    fat { 12.0 }
    fiber { 3.0 }
    source { :off }
    sequence(:external_id) { |n| "off-#{n}" }
    serving_size { 100.0 }
    serving_label { "1 serving" }

    trait :usda do
      source { :usda }
      sequence(:external_id) { |n| "usda-#{n}" }
      brand { nil }
    end

    trait :user_created do
      source { :user }
      external_id { nil }
      creator factory: :user
    end
  end
end
```

- [ ] **Step 4: Verify the factory works**

Run: `bin/rails runner "require 'factory_bot'; FactoryBot.find_definitions; puts FactoryBot.build(:food).valid?"`
Expected: `true`

- [ ] **Step 5: Commit**

```bash
git add app/models/food.rb app/models/user.rb test/factories/foods.rb
git commit -m "feat: add Food model with validations, enum, and associations"
```

---

### Task 3: Model tests

**Files:**
- Create: `test/models/food_test.rb`

- [ ] **Step 1: Write the model tests**

Replace the generated `test/models/food_test.rb` with:

```ruby
require "test_helper"

class FoodTest < ActiveSupport::TestCase
  # Factory
  test "factory is valid" do
    food = build(:food)
    assert food.valid?, food.errors.full_messages.join(", ")
  end

  test "usda trait is valid" do
    food = build(:food, :usda)
    assert food.valid?, food.errors.full_messages.join(", ")
  end

  test "user_created trait is valid" do
    food = build(:food, :user_created)
    assert food.valid?, food.errors.full_messages.join(", ")
  end

  # Name validations
  test "invalid without name" do
    food = build(:food, name: nil)
    assert_not food.valid?
    assert_includes food.errors[:name], "can't be blank"
  end

  test "invalid with name over 255 characters" do
    food = build(:food, name: "a" * 256)
    assert_not food.valid?
    assert food.errors[:name].any?
  end

  # Nutritional validations
  %i[calories protein carbs fat].each do |attr|
    test "invalid without #{attr}" do
      food = build(:food, attr => nil)
      assert_not food.valid?
      assert_includes food.errors[attr], "can't be blank"
    end

    test "invalid with negative #{attr}" do
      food = build(:food, attr => -1)
      assert_not food.valid?
      assert food.errors[attr].any?
    end

    test "valid with zero #{attr}" do
      food = build(:food, attr => 0)
      assert food.valid?
    end
  end

  test "invalid with negative fiber" do
    food = build(:food, fiber: -1)
    assert_not food.valid?
    assert food.errors[:fiber].any?
  end

  test "valid with zero fiber" do
    food = build(:food, fiber: 0)
    assert food.valid?
  end

  # Source enum
  test "source enum values" do
    assert Food.sources.key?("off")
    assert Food.sources.key?("usda")
    assert Food.sources.key?("user")
  end

  test "off? returns true for off source" do
    food = build(:food, source: :off)
    assert food.off?
  end

  test "usda? returns true for usda source" do
    food = build(:food, :usda)
    assert food.usda?
  end

  test "user? returns true for user source" do
    food = build(:food, :user_created)
    assert food.user?
  end

  # External ID uniqueness
  test "external_id must be unique within same source" do
    create(:food, source: :off, external_id: "dup-123")
    duplicate = build(:food, source: :off, external_id: "dup-123")
    assert_not duplicate.valid?
    assert food_errors_on(duplicate, :external_id)
  end

  test "external_id can be same across different sources" do
    create(:food, source: :off, external_id: "shared-123")
    food = build(:food, source: :usda, external_id: "shared-123")
    assert food.valid?
  end

  test "multiple foods can have nil external_id" do
    create(:food, :user_created, external_id: nil)
    food = build(:food, :user_created, external_id: nil)
    assert food.valid?
  end

  # Creator validation
  test "creator_id required for user source" do
    food = build(:food, source: :user, creator_id: nil, external_id: nil)
    assert_not food.valid?
    assert_includes food.errors[:creator_id], "is required for user-created foods"
  end

  test "creator_id not required for off source" do
    food = build(:food, source: :off, creator_id: nil)
    assert food.valid?
  end

  test "creator_id not required for usda source" do
    food = build(:food, :usda, creator_id: nil)
    assert food.valid?
  end

  # Associations
  test "belongs to creator" do
    food = create(:food, :user_created)
    assert_instance_of User, food.creator
  end

  test "user has many created foods" do
    user = create(:user)
    create(:food, :user_created, creator: user)
    create(:food, :user_created, creator: user)
    assert_equal 2, user.created_foods.count
  end

  test "destroying user destroys created foods" do
    user = create(:user)
    create(:food, :user_created, creator: user)
    assert_difference "Food.count", -1 do
      user.destroy
    end
  end

  # Searchable tsvector
  test "searchable column is populated from name and brand" do
    food = create(:food, name: "Chicken Breast", brand: "Tesco")
    food.reload
    assert_not_nil food.searchable
  end

  private

  def food_errors_on(record, attribute)
    record.errors[attribute].any?
  end
end
```

- [ ] **Step 2: Run the tests**

Run: `bin/rails test test/models/food_test.rb`
Expected: All tests pass (0 failures, 0 errors)

- [ ] **Step 3: Run the full test suite**

Run: `bin/rails test`
Expected: All tests pass (0 failures, 0 errors)

- [ ] **Step 4: Commit**

```bash
git add test/models/food_test.rb
git commit -m "test: add Food model validation, association, and enum tests"
```

---

## Notes for implementers

- **Generated column caveat:** The `searchable` tsvector column is `GENERATED ALWAYS AS ... STORED`. You cannot write to it directly — Postgres computes it automatically. ActiveRecord may complain if you try to set it. If needed, add `self.ignored_columns += ["searchable"]` to the model, but try without first — Rails 8 handles generated columns fine in most cases.
- **pg_trgm extension:** The migration enables `pg_trgm`. If running tests with a fresh database, make sure `db:test:prepare` runs the migration (it should by default).
- **Decimal precision:** Using `precision: 8, scale: 2` gives up to 999,999.99 — more than enough for nutritional values per 100g.
- **Foreign key on_delete:** Creator FK uses `on_delete: :cascade` to match `dependent: :destroy` on the User association. User-created foods are personal and have no value without their creator.
