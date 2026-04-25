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

  test "uses Atwater General Factors (2047) when 1008 is missing" do
    food_nutrients = [
      { "nutrientId" => 2047, "value" => 64.0 },
      { "nutrientId" => 1003, "value" => 0.15 }
    ]

    result = Usda::NutrientMapper.extract(food_nutrients)

    assert_equal 64.0, result[:calories]
  end

  test "uses Atwater Specific Factors (2048) when 1008 and 2047 are missing" do
    food_nutrients = [
      { "nutrientId" => 2048, "value" => 52.0 }
    ]

    result = Usda::NutrientMapper.extract(food_nutrients)

    assert_equal 52.0, result[:calories]
  end

  test "prefers 1008 over Atwater factors" do
    food_nutrients = [
      { "nutrientId" => 1008, "value" => 100.0 },
      { "nutrientId" => 2047, "value" => 95.0 },
      { "nutrientId" => 2048, "value" => 90.0 }
    ]

    result = Usda::NutrientMapper.extract(food_nutrients)

    assert_equal 100.0, result[:calories]
  end

  test "falls back to next energy ID when first is zero" do
    food_nutrients = [
      { "nutrientId" => 1008, "value" => 0.0 },
      { "nutrientId" => 2047, "value" => 64.0 }
    ]

    result = Usda::NutrientMapper.extract(food_nutrients)

    assert_equal 64.0, result[:calories]
  end
end
