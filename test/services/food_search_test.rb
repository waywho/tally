require "test_helper"
require "minitest/mock"

# Ensure error subclasses are loaded (Zeitwerk expects them in separate files)
Off::Error
Usda::Error

class FoodSearchTest < ActiveSupport::TestCase
  setup do
    @user = create(:user)
  end

  test "returns local results when 5+ exist" do
    5.times { |i| create(:food, name: "Chicken item #{i}", source: :off, external_id: "local-#{i}") }

    results = FoodSearch.call("chicken")

    assert_equal 5, results.size
    assert results.all? { |r| r.is_a?(Food) }
  end

  test "returns empty array for blank query" do
    assert_empty FoodSearch.call("")
    assert_empty FoodSearch.call(nil)
  end

  test "caps results at limit" do
    25.times { |i| create(:food, name: "Chicken variety #{i}", source: :off, external_id: "cap-#{i}") }

    results = FoodSearch.call("chicken", limit: 20)

    assert_equal 20, results.size
  end

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

    persisted_off = create(:food, name: "Chicken OFF", source: :off, external_id: "123456789")

    off_client.expect(:search, [off_result]) { |q, **kw| q == "chicken" }
    off_client.expect(:persist, persisted_off) { |r| r.is_a?(Off::FoodResult) }
    usda_client.expect(:search, [usda_result]) { |q, **kw| q == "chicken" }

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

    off_client.expect(:search, [off_result]) { true }
    off_client.expect(:persist, persisted_food) { true }
    usda_client.expect(:search, []) { true }

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

    off_client.expect(:search, []) { true }
    usda_client.expect(:search, [usda_result]) { true }

    initial_count = Food.count
    results = FoodSearch.call("food", off_client: off_client, usda_client: usda_client)

    assert_equal initial_count, Food.count
    assert results.any? { |r| r.is_a?(Usda::FoodResult) }
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

    off_client.expect(:search, []) { true }
    usda_client.expect(:search, [usda_result]) { true }

    results = FoodSearch.call("chicken", off_client: off_client, usda_client: usda_client)

    usda_structs = results.select { |r| r.is_a?(Usda::FoodResult) }
    assert_empty usda_structs
  end

  test "handles OFF API errors gracefully" do
    off_client = Minitest::Mock.new
    usda_client = Minitest::Mock.new

    usda_result = Usda::FoodResult.new(
      fdc_id: "888", name: "USDA Fallback", brand: nil,
      calories: 100.0, protein: 10.0, carbs: 20.0, fat: 5.0, fiber: 0.0,
      serving_size: 100.0, serving_label: "100g"
    )

    off_client.expect(:search, nil) { raise Off::ApiError, "OFF is down" }
    usda_client.expect(:search, [usda_result]) { true }

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

    off_client.expect(:search, [off_result]) { true }
    off_client.expect(:persist, persisted) { true }
    usda_client.expect(:search, nil) { raise Usda::ApiError, "USDA is down" }

    results = FoodSearch.call("food", off_client: off_client, usda_client: usda_client)

    assert results.any? { |r| r.is_a?(Food) && r.name == "OFF Fallback" }
  end

  test "passes user to Food.search for visibility scoping" do
    user = create(:user)
    custom = create(:food, name: "Chicken custom", source: :user, external_id: nil, creator: user)
    5.times { |i| create(:food, name: "Chicken item #{i}", source: :off, external_id: "scope-#{i}") }

    results = FoodSearch.call("chicken", user: user)

    assert results.any? { |r| r.is_a?(Food) && r.user? && r.creator_id == user.id }
  end

  test "excludes other users custom foods from results" do
    other_user = create(:user)
    create(:food, name: "Chicken other", source: :user, external_id: nil, creator: other_user)
    5.times { |i| create(:food, name: "Chicken item #{i}", source: :off, external_id: "excl-#{i}") }

    user = create(:user)
    results = FoodSearch.call("chicken", user: user)

    assert_not results.any? { |r| r.is_a?(Food) && r.user? && r.creator_id == other_user.id }
  end
end
