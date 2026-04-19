# USDA FDC API Client Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a service class wrapping the USDA FoodData Central API for on-demand food search and lookup, with cache-on-interaction persistence to the foods table.

**Architecture:** `Usda::Client` service calls the USDA FDC REST API via `rest-client`, normalizes responses into `Usda::FoodResult` structs, and persists to the `Food` model only when a user selects a food. `Usda::NutrientMapper` handles nutrient ID → column mapping. Custom error hierarchy for API failures.

**Tech Stack:** Rails 8, rest-client, webmock (test), Minitest, factory_bot

---

## File Structure

| File | Responsibility |
|---|---|
| `Gemfile` | Add rest-client + webmock |
| `app/services/usda/error.rb` | Custom error classes |
| `app/services/usda/food_result.rb` | Plain struct for normalized results |
| `app/services/usda/nutrient_mapper.rb` | Extract nutrients from API response |
| `app/services/usda/client.rb` | API client (search, fetch, persist) |
| `test/fixtures/files/usda/search_response.json` | Sample search API fixture |
| `test/fixtures/files/usda/food_response.json` | Sample single food API fixture |
| `test/services/usda/food_result_test.rb` | Struct tests |
| `test/services/usda/nutrient_mapper_test.rb` | Nutrient extraction tests |
| `test/services/usda/client_test.rb` | Client integration tests with webmock |

---

### Task 1: Add gems (rest-client + webmock)

**Files:**
- Modify: `Gemfile`

- [ ] **Step 1: Add rest-client to the main gems**

In `Gemfile`, add after the `gem "countries"` line:

```ruby
# HTTP client for external API calls [https://github.com/rest-client/rest-client]
gem "rest-client"
```

- [ ] **Step 2: Add webmock to the test group**

In `Gemfile`, add to the `group :test` block after `gem "selenium-webdriver"`:

```ruby
  # Stub HTTP requests in tests [https://github.com/bblimke/webmock]
  gem "webmock"
```

- [ ] **Step 3: Install gems**

Run: `bundle install`
Expected: `rest-client` and `webmock` installed successfully.

- [ ] **Step 4: Configure webmock in test_helper**

In `test/test_helper.rb`, add after the `require "rails/test_help"` line:

```ruby
require "webmock/minitest"
```

- [ ] **Step 5: Run existing tests to verify nothing breaks**

Run: `bin/rails test`
Expected: All 108 tests pass. Note: webmock disables real HTTP connections in tests by default — existing tests should not be making external requests, so this should be fine.

- [ ] **Step 6: Commit**

```bash
git add Gemfile Gemfile.lock test/test_helper.rb
git commit -m "feat: add rest-client and webmock gems"
```

---

### Task 2: Error classes and FoodResult struct

**Files:**
- Create: `app/services/usda/error.rb`
- Create: `app/services/usda/food_result.rb`
- Create: `test/services/usda/food_result_test.rb`

- [ ] **Step 1: Create the error class hierarchy**

Create `app/services/usda/error.rb`:

```ruby
module Usda
  class Error < StandardError; end

  class ConfigError < Error; end

  class ApiError < Error
    attr_reader :status_code

    def initialize(message, status_code: nil)
      @status_code = status_code
      super(message)
    end
  end

  class RateLimitError < ApiError
    def initialize(message = "USDA API rate limit exceeded (1,000 requests/hour)")
      super(message, status_code: 429)
    end
  end
end
```

- [ ] **Step 2: Create the FoodResult struct**

Create `app/services/usda/food_result.rb`:

```ruby
module Usda
  FoodResult = Struct.new(
    :fdc_id, :name, :brand,
    :calories, :protein, :carbs, :fat, :fiber,
    :serving_size, :serving_label,
    keyword_init: true
  )
end
```

- [ ] **Step 3: Write FoodResult tests**

Create `test/services/usda/food_result_test.rb`:

```ruby
require "test_helper"

class Usda::FoodResultTest < ActiveSupport::TestCase
  test "creates struct with keyword arguments" do
    result = Usda::FoodResult.new(
      fdc_id: "12345",
      name: "Chicken Breast",
      brand: nil,
      calories: 165.0,
      protein: 31.0,
      carbs: 0.0,
      fat: 3.6,
      fiber: 0.0,
      serving_size: 100.0,
      serving_label: "100 g"
    )

    assert_equal "12345", result.fdc_id
    assert_equal "Chicken Breast", result.name
    assert_nil result.brand
    assert_equal 165.0, result.calories
    assert_equal 31.0, result.protein
    assert_equal 0.0, result.carbs
    assert_equal 3.6, result.fat
    assert_equal 0.0, result.fiber
    assert_equal 100.0, result.serving_size
    assert_equal "100 g", result.serving_label
  end

  test "has all expected attributes" do
    expected = %i[fdc_id name brand calories protein carbs fat fiber serving_size serving_label]
    assert_equal expected, Usda::FoodResult.members
  end
end
```

- [ ] **Step 4: Run the tests**

Run: `bin/rails test test/services/usda/food_result_test.rb`
Expected: 2 tests pass.

- [ ] **Step 5: Commit**

```bash
git add app/services/usda/ test/services/usda/food_result_test.rb
git commit -m "feat: add Usda error classes and FoodResult struct"
```

---

### Task 3: NutrientMapper

**Files:**
- Create: `app/services/usda/nutrient_mapper.rb`
- Create: `test/services/usda/nutrient_mapper_test.rb`

- [ ] **Step 1: Write the NutrientMapper tests**

Create `test/services/usda/nutrient_mapper_test.rb`:

```ruby
require "test_helper"

class Usda::NutrientMapperTest < ActiveSupport::TestCase
  test "extracts all 5 nutrients from foodNutrients array" do
    food_nutrients = [
      { "nutrientId" => 1008, "value" => 165.0 },
      { "nutrientId" => 1003, "value" => 31.0 },
      { "nutrientId" => 1005, "value" => 0.0 },
      { "nutrientId" => 1004, "value" => 3.6 },
      { "nutrientId" => 1079, "value" => 0.0 }
    ]

    result = Usda::NutrientMapper.extract(food_nutrients)

    assert_equal 165.0, result[:calories]
    assert_equal 31.0, result[:protein]
    assert_equal 0.0, result[:carbs]
    assert_equal 3.6, result[:fat]
    assert_equal 0.0, result[:fiber]
  end

  test "returns 0.0 for missing nutrients" do
    food_nutrients = [
      { "nutrientId" => 1008, "value" => 100.0 }
    ]

    result = Usda::NutrientMapper.extract(food_nutrients)

    assert_equal 100.0, result[:calories]
    assert_equal 0.0, result[:protein]
    assert_equal 0.0, result[:carbs]
    assert_equal 0.0, result[:fat]
    assert_equal 0.0, result[:fiber]
  end

  test "ignores unrecognized nutrient IDs" do
    food_nutrients = [
      { "nutrientId" => 1008, "value" => 100.0 },
      { "nutrientId" => 9999, "value" => 50.0 }
    ]

    result = Usda::NutrientMapper.extract(food_nutrients)

    assert_equal 100.0, result[:calories]
    assert_not result.key?(:unknown_nutrient)
  end

  test "handles empty foodNutrients array" do
    result = Usda::NutrientMapper.extract([])

    assert_equal 0.0, result[:calories]
    assert_equal 0.0, result[:protein]
    assert_equal 0.0, result[:carbs]
    assert_equal 0.0, result[:fat]
    assert_equal 0.0, result[:fiber]
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bin/rails test test/services/usda/nutrient_mapper_test.rb`
Expected: FAIL — `uninitialized constant Usda::NutrientMapper`

- [ ] **Step 3: Implement NutrientMapper**

Create `app/services/usda/nutrient_mapper.rb`:

```ruby
module Usda
  class NutrientMapper
    NUTRIENT_IDS = {
      1008 => :calories,
      1003 => :protein,
      1005 => :carbs,
      1004 => :fat,
      1079 => :fiber
    }.freeze

    DEFAULTS = NUTRIENT_IDS.values.index_with { 0.0 }.freeze

    def self.extract(food_nutrients)
      nutrients = DEFAULTS.dup

      food_nutrients.each do |nutrient|
        key = NUTRIENT_IDS[nutrient["nutrientId"]]
        nutrients[key] = nutrient["value"].to_f if key
      end

      nutrients
    end
  end
end
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bin/rails test test/services/usda/nutrient_mapper_test.rb`
Expected: 4 tests pass.

- [ ] **Step 5: Commit**

```bash
git add app/services/usda/nutrient_mapper.rb test/services/usda/nutrient_mapper_test.rb
git commit -m "feat: add Usda::NutrientMapper for nutrient ID extraction"
```

---

### Task 4: API fixture files

**Files:**
- Create: `test/fixtures/files/usda/search_response.json`
- Create: `test/fixtures/files/usda/food_response.json`

- [ ] **Step 1: Create the search response fixture**

Create `test/fixtures/files/usda/search_response.json`:

```json
{
  "totalHits": 2,
  "currentPage": 1,
  "totalPages": 1,
  "foods": [
    {
      "fdcId": 171077,
      "description": "Chicken, broilers or fryers, breast, skinless, boneless, meat only, raw",
      "dataType": "SR Legacy",
      "brandName": null,
      "foodNutrients": [
        { "nutrientId": 1008, "nutrientName": "Energy", "value": 120.0, "unitName": "KCAL" },
        { "nutrientId": 1003, "nutrientName": "Protein", "value": 22.5, "unitName": "G" },
        { "nutrientId": 1005, "nutrientName": "Carbohydrate, by difference", "value": 0.0, "unitName": "G" },
        { "nutrientId": 1004, "nutrientName": "Total lipid (fat)", "value": 2.62, "unitName": "G" },
        { "nutrientId": 1079, "nutrientName": "Fiber, total dietary", "value": 0.0, "unitName": "G" }
      ]
    },
    {
      "fdcId": 331960,
      "description": "Chicken, breast, raw",
      "dataType": "Foundation",
      "brandName": null,
      "foodNutrients": [
        { "nutrientId": 1008, "nutrientName": "Energy", "value": 100.0, "unitName": "KCAL" },
        { "nutrientId": 1003, "nutrientName": "Protein", "value": 22.0, "unitName": "G" },
        { "nutrientId": 1005, "nutrientName": "Carbohydrate, by difference", "value": 0.0, "unitName": "G" },
        { "nutrientId": 1004, "nutrientName": "Total lipid (fat)", "value": 1.0, "unitName": "G" },
        { "nutrientId": 1079, "nutrientName": "Fiber, total dietary", "value": 0.0, "unitName": "G" }
      ]
    }
  ]
}
```

- [ ] **Step 2: Create the single food response fixture**

Create `test/fixtures/files/usda/food_response.json`:

```json
{
  "fdcId": 171077,
  "description": "Chicken, broilers or fryers, breast, skinless, boneless, meat only, raw",
  "dataType": "SR Legacy",
  "brandName": null,
  "servingSize": 112.0,
  "servingSizeUnit": "g",
  "foodPortions": [
    {
      "gramWeight": 112.0,
      "portionDescription": "1 unit (yield from 1 lb ready-to-cook chicken)"
    }
  ],
  "foodNutrients": [
    { "nutrient": { "id": 1008, "name": "Energy", "unitName": "kcal" }, "amount": 120.0 },
    { "nutrient": { "id": 1003, "name": "Protein", "unitName": "g" }, "amount": 22.5 },
    { "nutrient": { "id": 1005, "name": "Carbohydrate, by difference", "unitName": "g" }, "amount": 0.0 },
    { "nutrient": { "id": 1004, "name": "Total lipid (fat)", "unitName": "g" }, "amount": 2.62 },
    { "nutrient": { "id": 1079, "name": "Fiber, total dietary", "unitName": "g" }, "amount": 0.0 }
  ]
}
```

**IMPORTANT NOTE:** The search endpoint and single food endpoint return nutrients in DIFFERENT formats:
- Search: `{ "nutrientId": 1008, "value": 120.0 }`
- Single food: `{ "nutrient": { "id": 1008 }, "amount": 120.0 }`

The `NutrientMapper` and `Client` must handle both formats. The `NutrientMapper.extract` already handles the search format. For the single food format, the `Client.fetch` method must normalize the nutrient array before passing to `NutrientMapper`.

- [ ] **Step 3: Commit**

```bash
git add test/fixtures/files/usda/
git commit -m "test: add USDA API response fixture files"
```

---

### Task 5: Usda::Client

**Files:**
- Create: `app/services/usda/client.rb`
- Create: `test/services/usda/client_test.rb`

- [ ] **Step 1: Write the Client tests**

Create `test/services/usda/client_test.rb`:

```ruby
require "test_helper"

class Usda::ClientTest < ActiveSupport::TestCase
  setup do
    @client = Usda::Client.new(api_key: "test-key")
    @search_fixture = File.read(Rails.root.join("test/fixtures/files/usda/search_response.json"))
    @food_fixture = File.read(Rails.root.join("test/fixtures/files/usda/food_response.json"))
  end

  # Configuration
  test "raises ConfigError when API key is missing" do
    ENV.stub(:fetch, ->(_key) { raise KeyError }) do
      assert_raises(Usda::ConfigError) { Usda::Client.new }
    end
  end

  # Search
  test "search sends correct POST request" do
    stub_request(:post, "https://api.nal.usda.gov/fdc/v1/foods/search?api_key=test-key")
      .with(body: hash_including("query" => "chicken breast"))
      .to_return(status: 200, body: @search_fixture, headers: { "Content-Type" => "application/json" })

    @client.search("chicken breast")

    assert_requested(:post, "https://api.nal.usda.gov/fdc/v1/foods/search?api_key=test-key")
  end

  test "search returns array of FoodResult structs" do
    stub_request(:post, "https://api.nal.usda.gov/fdc/v1/foods/search?api_key=test-key")
      .to_return(status: 200, body: @search_fixture, headers: { "Content-Type" => "application/json" })

    results = @client.search("chicken breast")

    assert_equal 2, results.size
    assert_instance_of Usda::FoodResult, results.first
    assert_equal "171077", results.first.fdc_id
    assert_equal "Chicken, broilers or fryers, breast, skinless, boneless, meat only, raw", results.first.name
    assert_equal 120.0, results.first.calories
    assert_equal 22.5, results.first.protein
  end

  test "search handles empty results" do
    empty_response = { totalHits: 0, currentPage: 1, totalPages: 0, foods: [] }.to_json
    stub_request(:post, "https://api.nal.usda.gov/fdc/v1/foods/search?api_key=test-key")
      .to_return(status: 200, body: empty_response, headers: { "Content-Type" => "application/json" })

    results = @client.search("nonexistent food xyz")

    assert_equal [], results
  end

  test "search filters to Foundation and SR Legacy" do
    stub_request(:post, "https://api.nal.usda.gov/fdc/v1/foods/search?api_key=test-key")
      .with(body: hash_including("dataType" => ["Foundation", "SR Legacy"]))
      .to_return(status: 200, body: @search_fixture, headers: { "Content-Type" => "application/json" })

    @client.search("chicken")

    assert_requested(:post, "https://api.nal.usda.gov/fdc/v1/foods/search?api_key=test-key")
  end

  # Fetch
  test "fetch sends correct GET request" do
    stub_request(:get, "https://api.nal.usda.gov/fdc/v1/food/171077?api_key=test-key")
      .to_return(status: 200, body: @food_fixture, headers: { "Content-Type" => "application/json" })

    @client.fetch("171077")

    assert_requested(:get, "https://api.nal.usda.gov/fdc/v1/food/171077?api_key=test-key")
  end

  test "fetch returns a FoodResult struct" do
    stub_request(:get, "https://api.nal.usda.gov/fdc/v1/food/171077?api_key=test-key")
      .to_return(status: 200, body: @food_fixture, headers: { "Content-Type" => "application/json" })

    result = @client.fetch("171077")

    assert_instance_of Usda::FoodResult, result
    assert_equal "171077", result.fdc_id
    assert_equal 120.0, result.calories
    assert_equal 22.5, result.protein
    assert_equal 112.0, result.serving_size
  end

  # Persist
  test "persist creates a new Food record from FoodResult" do
    food_result = Usda::FoodResult.new(
      fdc_id: "171077",
      name: "Chicken Breast",
      brand: nil,
      calories: 120.0,
      protein: 22.5,
      carbs: 0.0,
      fat: 2.62,
      fiber: 0.0,
      serving_size: 112.0,
      serving_label: "1 unit"
    )

    assert_difference "Food.count", 1 do
      food = @client.persist(food_result)
      assert_instance_of Food, food
      assert food.persisted?
      assert food.usda?
      assert_equal "171077", food.external_id
      assert_equal "Chicken Breast", food.name
      assert_equal 120.0, food.calories
    end
  end

  test "persist finds existing Food instead of duplicating" do
    food_result = Usda::FoodResult.new(
      fdc_id: "171077", name: "Chicken Breast", brand: nil,
      calories: 120.0, protein: 22.5, carbs: 0.0, fat: 2.62, fiber: 0.0,
      serving_size: 112.0, serving_label: "1 unit"
    )

    @client.persist(food_result)

    assert_no_difference "Food.count" do
      food = @client.persist(food_result)
      assert_equal "171077", food.external_id
    end
  end

  test "persist updates existing Food nutritional data" do
    food_result = Usda::FoodResult.new(
      fdc_id: "171077", name: "Chicken Breast", brand: nil,
      calories: 120.0, protein: 22.5, carbs: 0.0, fat: 2.62, fiber: 0.0,
      serving_size: 112.0, serving_label: "1 unit"
    )
    @client.persist(food_result)

    updated_result = Usda::FoodResult.new(
      fdc_id: "171077", name: "Chicken Breast (updated)", brand: nil,
      calories: 130.0, protein: 25.0, carbs: 0.0, fat: 3.0, fiber: 0.0,
      serving_size: 112.0, serving_label: "1 unit"
    )
    food = @client.persist(updated_result)

    assert_equal "Chicken Breast (updated)", food.name
    assert_equal 130.0, food.calories
    assert_equal 25.0, food.protein
  end

  # Error handling
  test "raises ApiError on 500 response" do
    stub_request(:post, "https://api.nal.usda.gov/fdc/v1/foods/search?api_key=test-key")
      .to_return(status: 500, body: "Internal Server Error")

    assert_raises(Usda::ApiError) { @client.search("chicken") }
  end

  test "raises RateLimitError on 429 response" do
    stub_request(:post, "https://api.nal.usda.gov/fdc/v1/foods/search?api_key=test-key")
      .to_return(status: 429, body: "Rate limit exceeded")

    assert_raises(Usda::RateLimitError) { @client.search("chicken") }
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bin/rails test test/services/usda/client_test.rb`
Expected: FAIL — `uninitialized constant Usda::Client`

- [ ] **Step 3: Implement Usda::Client**

Create `app/services/usda/client.rb`:

```ruby
module Usda
  class Client
    BASE_URL = "https://api.nal.usda.gov/fdc/v1".freeze
    DATA_TYPES = ["Foundation", "SR Legacy"].freeze

    def initialize(api_key: nil)
      @api_key = api_key || ENV.fetch("USDA_API_KEY") { raise ConfigError, "USDA_API_KEY environment variable is not set" }
    end

    def search(query, page: 1, per_page: 20)
      body = {
        query: query,
        dataType: DATA_TYPES,
        pageSize: per_page,
        pageNumber: page
      }

      response = post("/foods/search", body)
      data = JSON.parse(response.body)

      (data["foods"] || []).map { |food| build_result_from_search(food) }
    rescue RestClient::TooManyRequests
      raise RateLimitError
    rescue RestClient::Exception => e
      raise ApiError.new("USDA API error: #{e.message}", status_code: e.http_code)
    end

    def fetch(fdc_id)
      response = get("/food/#{fdc_id}")
      data = JSON.parse(response.body)

      build_result_from_detail(data)
    rescue RestClient::TooManyRequests
      raise RateLimitError
    rescue RestClient::Exception => e
      raise ApiError.new("USDA API error: #{e.message}", status_code: e.http_code)
    end

    def persist(food_result)
      food = Food.find_or_initialize_by(source: :usda, external_id: food_result.fdc_id)
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

    def post(path, body)
      RestClient.post(
        "#{BASE_URL}#{path}?api_key=#{@api_key}",
        body.to_json,
        content_type: :json, accept: :json
      )
    end

    def get(path)
      RestClient.get(
        "#{BASE_URL}#{path}?api_key=#{@api_key}",
        accept: :json
      )
    end

    def build_result_from_search(food_data)
      nutrients = NutrientMapper.extract(food_data["foodNutrients"] || [])

      FoodResult.new(
        fdc_id: food_data["fdcId"].to_s,
        name: food_data["description"],
        brand: food_data["brandName"],
        serving_size: nil,
        serving_label: nil,
        **nutrients
      )
    end

    def build_result_from_detail(food_data)
      raw_nutrients = (food_data["foodNutrients"] || []).map do |fn|
        { "nutrientId" => fn.dig("nutrient", "id"), "value" => fn["amount"] }
      end
      nutrients = NutrientMapper.extract(raw_nutrients)

      portion = food_data.dig("foodPortions", 0)
      serving_size = food_data["servingSize"] || portion&.dig("gramWeight")
      serving_label = portion&.dig("portionDescription")

      FoodResult.new(
        fdc_id: food_data["fdcId"].to_s,
        name: food_data["description"],
        brand: food_data["brandName"],
        serving_size: serving_size,
        serving_label: serving_label,
        **nutrients
      )
    end
  end
end
```

- [ ] **Step 4: Run the client tests**

Run: `bin/rails test test/services/usda/client_test.rb`
Expected: All 11 tests pass.

- [ ] **Step 5: Run the full test suite**

Run: `bin/rails test`
Expected: All tests pass (0 failures, 0 errors).

- [ ] **Step 6: Commit**

```bash
git add app/services/usda/client.rb test/services/usda/client_test.rb
git commit -m "feat: add Usda::Client with search, fetch, and persist"
```

---

## Notes for implementers

- **Rails autoloading:** `app/services/` is autoloaded by Rails 8 by default. The `Usda` module is inferred from the directory structure (`app/services/usda/client.rb` → `Usda::Client`). No configuration needed.
- **Search vs Detail nutrient format:** The USDA API returns nutrients differently in search results vs single food detail. Search uses `{ "nutrientId": 1008, "value": 120.0 }`. Detail uses `{ "nutrient": { "id": 1008 }, "amount": 120.0 }`. The `Client` normalizes the detail format to match the search format before passing to `NutrientMapper`.
- **Webmock:** After adding `require "webmock/minitest"` to test_helper, all real HTTP connections are blocked in tests. If any existing test was secretly making HTTP calls, it will now fail — this is a feature, not a bug.
- **API key in tests:** The client tests pass `api_key: "test-key"` directly to the constructor to avoid needing the env var in CI. The `ConfigError` test verifies the env var lookup path.
- **`find_or_initialize_by` + `update!`:** This is the persist/dedup strategy. It finds by `(source: :usda, external_id: fdc_id)` or creates a new record, then updates all fields. This means re-persisting the same food updates its data (useful if USDA corrects values).
