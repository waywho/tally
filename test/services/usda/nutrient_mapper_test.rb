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
