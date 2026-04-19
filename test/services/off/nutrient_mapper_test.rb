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
    nutriments = { "energy-kcal_100g" => 100.0 }
    result = Off::NutrientMapper.extract(nutriments)

    assert_equal 100.0, result[:calories]
    assert_equal 0.0, result[:protein]
    assert_equal 0.0, result[:carbs]
    assert_equal 0.0, result[:fat]
    assert_equal 0.0, result[:fiber]
  end

  test "handles nil values as 0.0" do
    nutriments = { "energy-kcal_100g" => nil, "proteins_100g" => nil }
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
    nutriments = { "energy-kcal_100g" => 100.0, "sugars_100g" => 5.0, "salt_100g" => 1.2 }
    result = Off::NutrientMapper.extract(nutriments)

    assert_equal 100.0, result[:calories]
    assert_equal 5, result.keys.size
  end
end
