require "test_helper"
require "ostruct"

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

    stub_product(:search, [mock_product_1, mock_product_2]) do
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
    stub_product(:search, []) do
      results = @client.search("nonexistent food xyz")
      assert_equal [], results
    end
  end

  test "search handles nil results from gem" do
    stub_product(:search, nil) do
      results = @client.search("anything")
      assert_equal [], results
    end
  end

  test "search wraps gem exceptions in ApiError" do
    stub_product_raise(:search, StandardError, "connection failed") do
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

    stub_product(:get, mock_product) do
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
    stub_product(:get, nil) do
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

    stub_product(:get, mock_product) do
      assert_raises(Off::ProductNotFoundError) { @client.fetch("0000000000000") }
    end
  end

  test "fetch wraps gem exceptions in ApiError" do
    stub_product_raise(:get, StandardError, "network error") do
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
    nutriments_obj = ::OpenStruct.new(to_hash: nutriments)
    ::OpenStruct.new(
      code: code,
      product_name: product_name,
      brands: brands,
      nutriments: nutriments_obj,
      serving_quantity: serving_quantity,
      serving_size: serving_size
    )
  end

  def stub_product(method_name, return_value)
    Openfoodfacts::Product.define_singleton_method(method_name) { |*| return_value }
    yield
  ensure
    Openfoodfacts::Product.singleton_class.remove_method(method_name)
  end

  def stub_product_raise(method_name, error_class, message)
    Openfoodfacts::Product.define_singleton_method(method_name) { |*| raise error_class, message }
    yield
  ensure
    Openfoodfacts::Product.singleton_class.remove_method(method_name)
  end
end
