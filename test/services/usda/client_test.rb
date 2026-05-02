require "test_helper"

class Usda::ClientTest < ActiveSupport::TestCase
  setup do
    @client = Usda::Client.new(api_key: "test-key")
    @search_fixture = File.read(Rails.root.join("test/fixtures/files/usda/search_response.json"))
    @food_fixture = File.read(Rails.root.join("test/fixtures/files/usda/food_response.json"))
  end

  # Configuration
  test "raises ConfigError when API key is missing" do
    assert_raises(Usda::ConfigError) { Usda::Client.new(api_key: nil) }
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
      .with(body: hash_including("dataType" => [ "Foundation", "SR Legacy" ]))
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
