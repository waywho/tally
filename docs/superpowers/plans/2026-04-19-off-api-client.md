# Open Food Facts API Client Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a thin wrapper service around the `openfoodfacts` Ruby gem that provides search-by-name and fetch-by-barcode capabilities, with persist-on-interaction caching into the `foods` table.

**Architecture:** `Off::Client` wraps the `openfoodfacts` gem, mapping results through `Off::NutrientMapper` into `Off::FoodResult` structs. The client mirrors the `Usda::Client` pattern with `search`, `fetch`, and `persist` methods. Tests stub the gem directly rather than using webmock.

**Tech Stack:** Rails 8.1, `openfoodfacts` gem, Minitest, FactoryBot

---

## File Structure

| Action | File | Responsibility |
|--------|------|----------------|
| Create | `app/services/off/error.rb` | Error hierarchy |
| Create | `app/services/off/food_result.rb` | Result struct |
| Create | `app/services/off/nutrient_mapper.rb` | OFF nutriments → our fields |
| Create | `app/services/off/client.rb` | Search, fetch, persist |
| Create | `test/services/off/nutrient_mapper_test.rb` | NutrientMapper unit tests |
| Create | `test/services/off/client_test.rb` | Client integration tests |
| Modify | `Gemfile` | Add `openfoodfacts` gem |

---

### Task 1: Add the openfoodfacts gem

**Files:**
- Modify: `Gemfile`

- [ ] **Step 1: Add the gem to the Gemfile**

Add after the `rest-client` line in `Gemfile`:

```ruby
# Open Food Facts API client [https://github.com/openfoodfacts/openfoodfacts-ruby]
gem "openfoodfacts"
```

- [ ] **Step 2: Bundle install**

Run: `bundle install`
Expected: Gem installs successfully.

- [ ] **Step 3: Verify the gem loads**

Run: `bin/rails runner "puts Openfoodfacts::Product.respond_to?(:search)"`
Expected: `true`

- [ ] **Step 4: Commit**

```bash
git add Gemfile Gemfile.lock
git commit -m "feat: add openfoodfacts gem for OFF API integration"
```

---

### Task 2: Create Off::Error hierarchy and Off::FoodResult struct

**Files:**
- Create: `app/services/off/error.rb`
- Create: `app/services/off/food_result.rb`

- [ ] **Step 1: Create the error hierarchy**

Create `app/services/off/error.rb`:

```ruby
module Off
  class Error < StandardError; end

  class ApiError < Error; end

  class ProductNotFoundError < Error
    def initialize(barcode)
      super("Product not found: #{barcode}")
    end
  end
end
```

- [ ] **Step 2: Create the FoodResult struct**

Create `app/services/off/food_result.rb`:

```ruby
module Off
  FoodResult = Struct.new(
    :barcode, :name, :brand,
    :calories, :protein, :carbs, :fat, :fiber,
    :serving_size, :serving_label,
    keyword_init: true
  )
end
```

- [ ] **Step 3: Verify autoloading**

Run: `bin/rails runner "puts Off::Error; puts Off::ApiError; puts Off::ProductNotFoundError; puts Off::FoodResult.members"`
Expected: Prints class names and struct members without error.

- [ ] **Step 4: Commit**

```bash
git add app/services/off/
git commit -m "feat: add Off::Error hierarchy and FoodResult struct"
```

---

### Task 3: Create Off::NutrientMapper with TDD

**Files:**
- Create: `test/services/off/nutrient_mapper_test.rb`
- Create: `app/services/off/nutrient_mapper.rb`

- [ ] **Step 1: Write the failing tests**

Create `test/services/off/nutrient_mapper_test.rb`:

```ruby
require "test_helper"

class Off::NutrientMapperTest < ActiveSupport::TestCase
  test "extracts all 5 nutrients from nutriments hash" do
    nutriments = {
      "energy-kcal_100g" => 165.0,
      "proteins_100g" => 31.0,
      "carbohydrates_100g" => 0.0,
      "fat_100g" => 3.6,
      "fiber_100g" => 2.4
    }

    result = Off::NutrientMapper.extract(nutriments)

    assert_equal 165.0, result[:calories]
    assert_equal 31.0, result[:protein]
    assert_equal 0.0, result[:carbs]
    assert_equal 3.6, result[:fat]
    assert_equal 2.4, result[:fiber]
  end

  test "returns 0.0 for missing nutrients" do
    nutriments = {
      "energy-kcal_100g" => 100.0
    }

    result = Off::NutrientMapper.extract(nutriments)

    assert_equal 100.0, result[:calories]
    assert_equal 0.0, result[:protein]
    assert_equal 0.0, result[:carbs]
    assert_equal 0.0, result[:fat]
    assert_equal 0.0, result[:fiber]
  end

  test "handles nil values as 0.0" do
    nutriments = {
      "energy-kcal_100g" => nil,
      "proteins_100g" => nil
    }

    result = Off::NutrientMapper.extract(nutriments)

    assert_equal 0.0, result[:calories]
    assert_equal 0.0, result[:protein]
  end

  test "handles empty hash" do
    result = Off::NutrientMapper.extract({})

    assert_equal 0.0, result[:calories]
    assert_equal 0.0, result[:protein]
    assert_equal 0.0, result[:carbs]
    assert_equal 0.0, result[:fat]
    assert_equal 0.0, result[:fiber]
  end

  test "handles nil input" do
    result = Off::NutrientMapper.extract(nil)

    assert_equal 0.0, result[:calories]
    assert_equal 0.0, result[:protein]
    assert_equal 0.0, result[:carbs]
    assert_equal 0.0, result[:fat]
    assert_equal 0.0, result[:fiber]
  end

  test "ignores unrecognized nutrient keys" do
    nutriments = {
      "energy-kcal_100g" => 100.0,
      "sugars_100g" => 5.0,
      "salt_100g" => 1.2
    }

    result = Off::NutrientMapper.extract(nutriments)

    assert_equal 100.0, result[:calories]
    assert_equal 5, result.keys.size
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bin/rails test test/services/off/nutrient_mapper_test.rb`
Expected: FAIL — `Off::NutrientMapper` not defined.

- [ ] **Step 3: Write the implementation**

Create `app/services/off/nutrient_mapper.rb`:

```ruby
module Off
  class NutrientMapper
    FIELD_MAP = {
      "energy-kcal_100g" => :calories,
      "proteins_100g" => :protein,
      "carbohydrates_100g" => :carbs,
      "fat_100g" => :fat,
      "fiber_100g" => :fiber
    }.freeze

    DEFAULTS = FIELD_MAP.values.index_with { 0.0 }.freeze

    def self.extract(nutriments)
      return DEFAULTS.dup if nutriments.nil?

      nutrients = DEFAULTS.dup

      FIELD_MAP.each do |off_key, our_key|
        value = nutriments[off_key]
        nutrients[our_key] = value.to_f if value
      end

      nutrients
    end
  end
end
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bin/rails test test/services/off/nutrient_mapper_test.rb`
Expected: 6 tests, 0 failures.

- [ ] **Step 5: Commit**

```bash
git add app/services/off/nutrient_mapper.rb test/services/off/nutrient_mapper_test.rb
git commit -m "feat: add Off::NutrientMapper with TDD"
```

---

### Task 4: Create Off::Client with TDD

**Files:**
- Create: `test/services/off/client_test.rb`
- Create: `app/services/off/client.rb`

The OFF gem returns product objects with methods like `.code`, `.product_name`, `.brands`, `.nutriments`. The `.nutriments` method returns an object that responds to `.to_hash`. We stub the gem's class methods to return mock product objects.

- [ ] **Step 1: Write the failing tests**

Create `test/services/off/client_test.rb`:

```ruby
require "test_helper"

class Off::ClientTest < ActiveSupport::TestCase
  setup do
    @client = Off::Client.new
  end

  # Search
  test "search returns array of FoodResult structs" do
    mock_product_1 = mock_off_product(
      code: "3017620422003",
      product_name: "Nutella",
      brands: "Ferrero",
      nutriments: { "energy-kcal_100g" => 539.0, "proteins_100g" => 6.3, "carbohydrates_100g" => 57.5, "fat_100g" => 30.9, "fiber_100g" => 0.0 },
      serving_quantity: 15.0,
      serving_size: "15 g"
    )
    mock_product_2 = mock_off_product(
      code: "8000500310427",
      product_name: "Nutella B-ready",
      brands: "Ferrero",
      nutriments: { "energy-kcal_100g" => 530.0, "proteins_100g" => 7.0, "carbohydrates_100g" => 58.0, "fat_100g" => 29.0, "fiber_100g" => 1.5 },
      serving_quantity: 22.0,
      serving_size: "1 bar (22 g)"
    )

    Openfoodfacts::Product.stub :search, [mock_product_1, mock_product_2] do
      results = @client.search("nutella")

      assert_equal 2, results.size
      assert_instance_of Off::FoodResult, results.first
      assert_equal "3017620422003", results.first.barcode
      assert_equal "Nutella", results.first.name
      assert_equal "Ferrero", results.first.brand
      assert_equal 539.0, results.first.calories
      assert_equal 6.3, results.first.protein
      assert_equal 57.5, results.first.carbs
      assert_equal 30.9, results.first.fat
      assert_equal 0.0, results.first.fiber
    end
  end

  test "search returns empty array when no results" do
    Openfoodfacts::Product.stub :search, [] do
      results = @client.search("nonexistent food xyz")

      assert_equal [], results
    end
  end

  test "search handles nil results from gem" do
    Openfoodfacts::Product.stub :search, nil do
      results = @client.search("anything")

      assert_equal [], results
    end
  end

  test "search wraps gem exceptions in ApiError" do
    Openfoodfacts::Product.stub :search, -> (*) { raise StandardError, "connection failed" } do
      assert_raises(Off::ApiError) { @client.search("nutella") }
    end
  end

  # Fetch
  test "fetch returns a FoodResult for a valid barcode" do
    mock_product = mock_off_product(
      code: "3017620422003",
      product_name: "Nutella",
      brands: "Ferrero",
      nutriments: { "energy-kcal_100g" => 539.0, "proteins_100g" => 6.3, "carbohydrates_100g" => 57.5, "fat_100g" => 30.9, "fiber_100g" => 0.0 },
      serving_quantity: 15.0,
      serving_size: "15 g"
    )

    Openfoodfacts::Product.stub :get, mock_product do
      result = @client.fetch("3017620422003")

      assert_instance_of Off::FoodResult, result
      assert_equal "3017620422003", result.barcode
      assert_equal "Nutella", result.name
      assert_equal 539.0, result.calories
      assert_equal 15.0, result.serving_size
      assert_equal "15 g", result.serving_label
    end
  end

  test "fetch raises ProductNotFoundError when product is nil" do
    Openfoodfacts::Product.stub :get, nil do
      error = assert_raises(Off::ProductNotFoundError) { @client.fetch("0000000000000") }
      assert_match "0000000000000", error.message
    end
  end

  test "fetch raises ProductNotFoundError when product has no name" do
    mock_product = mock_off_product(
      code: "0000000000000",
      product_name: nil,
      brands: nil,
      nutriments: {},
      serving_quantity: nil,
      serving_size: nil
    )

    Openfoodfacts::Product.stub :get, mock_product do
      assert_raises(Off::ProductNotFoundError) { @client.fetch("0000000000000") }
    end
  end

  test "fetch wraps gem exceptions in ApiError" do
    Openfoodfacts::Product.stub :get, -> (*) { raise StandardError, "network error" } do
      assert_raises(Off::ApiError) { @client.fetch("3017620422003") }
    end
  end

  # Persist
  test "persist creates a new Food record" do
    food_result = Off::FoodResult.new(
      barcode: "3017620422003",
      name: "Nutella",
      brand: "Ferrero",
      calories: 539.0, protein: 6.3, carbs: 57.5, fat: 30.9, fiber: 0.0,
      serving_size: 15.0, serving_label: "15 g"
    )

    assert_difference "Food.count", 1 do
      food = @client.persist(food_result)

      assert food.persisted?
      assert food.off?
      assert_equal "3017620422003", food.external_id
      assert_equal "Nutella", food.name
      assert_equal "Ferrero", food.brand
      assert_equal 539.0, food.calories.to_f
      assert_equal 6.3, food.protein.to_f
      assert_equal 57.5, food.carbs.to_f
      assert_equal 30.9, food.fat.to_f
      assert_equal 0.0, food.fiber.to_f
      assert_equal 15.0, food.serving_size.to_f
      assert_equal "15 g", food.serving_label
    end
  end

  test "persist finds existing Food instead of duplicating" do
    food_result = Off::FoodResult.new(
      barcode: "3017620422003", name: "Nutella", brand: "Ferrero",
      calories: 539.0, protein: 6.3, carbs: 57.5, fat: 30.9, fiber: 0.0,
      serving_size: 15.0, serving_label: "15 g"
    )

    @client.persist(food_result)

    assert_no_difference "Food.count" do
      food = @client.persist(food_result)
      assert_equal "3017620422003", food.external_id
    end
  end

  test "persist updates existing Food with new data" do
    food_result = Off::FoodResult.new(
      barcode: "3017620422003", name: "Nutella", brand: "Ferrero",
      calories: 539.0, protein: 6.3, carbs: 57.5, fat: 30.9, fiber: 0.0,
      serving_size: 15.0, serving_label: "15 g"
    )
    @client.persist(food_result)

    updated_result = Off::FoodResult.new(
      barcode: "3017620422003", name: "Nutella (updated)", brand: "Ferrero",
      calories: 540.0, protein: 6.5, carbs: 58.0, fat: 31.0, fiber: 0.5,
      serving_size: 15.0, serving_label: "15 g"
    )
    food = @client.persist(updated_result)

    assert_equal "Nutella (updated)", food.name
    assert_equal 540.0, food.calories.to_f
    assert_equal 6.5, food.protein.to_f
  end

  private

  def mock_off_product(code:, product_name:, brands:, nutriments:, serving_quantity:, serving_size:)
    nutriments_obj = OpenStruct.new(to_hash: nutriments)
    OpenStruct.new(
      code: code,
      product_name: product_name,
      brands: brands,
      nutriments: nutriments_obj,
      serving_quantity: serving_quantity,
      serving_size: serving_size
    )
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bin/rails test test/services/off/client_test.rb`
Expected: FAIL — `Off::Client` not defined.

- [ ] **Step 3: Write the implementation**

Create `app/services/off/client.rb`:

```ruby
require_relative "error"

module Off
  class Client
    def search(query, page: 1, per_page: 20)
      results = Openfoodfacts::Product.search(query, locale: "world", page_size: per_page)

      (results || []).map { |product| build_result(product) }
    rescue Off::Error
      raise
    rescue StandardError => e
      raise ApiError, "Open Food Facts API error: #{e.message}"
    end

    def fetch(barcode)
      product = Openfoodfacts::Product.get(barcode, locale: "world")

      raise ProductNotFoundError, barcode if product.nil? || product.product_name.blank?

      build_result(product)
    rescue Off::Error
      raise
    rescue StandardError => e
      raise ApiError, "Open Food Facts API error: #{e.message}"
    end

    def persist(food_result)
      food = Food.find_or_initialize_by(source: :off, external_id: food_result.barcode)
      food.update!(
        name: food_result.name,
        brand: food_result.brand,
        calories: food_result.calories,
        protein: food_result.protein,
        carbs: food_result.carbs,
        fat: food_result.fat,
        fiber: food_result.fiber,
        serving_size: food_result.serving_size,
        serving_label: food_result.serving_label,
        verified_at: Time.current
      )
      food
    end

    private

    def build_result(product)
      nutrients = NutrientMapper.extract(product.nutriments&.to_hash)

      FoodResult.new(
        barcode: product.code,
        name: product.product_name,
        brand: product.brands,
        serving_size: product.serving_quantity&.to_f,
        serving_label: product.serving_size,
        **nutrients
      )
    end
  end
end
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bin/rails test test/services/off/client_test.rb`
Expected: 12 tests, 0 failures.

- [ ] **Step 5: Run the full test suite**

Run: `bin/rails test`
Expected: All tests pass (existing + new).

- [ ] **Step 6: Commit**

```bash
git add app/services/off/client.rb test/services/off/client_test.rb
git commit -m "feat: add Off::Client with search, fetch, and persist"
```
