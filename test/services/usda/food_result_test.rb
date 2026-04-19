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
