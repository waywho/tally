require "test_helper"

class MealInferrerTest < ActiveSupport::TestCase
  test "early morning maps to breakfast" do
    assert_equal :breakfast, MealInferrer.call(Time.zone.local(2026, 4, 25, 7, 0))
  end

  test "boundary 04:00 is breakfast" do
    assert_equal :breakfast, MealInferrer.call(Time.zone.local(2026, 4, 25, 4, 0))
  end

  test "boundary 10:30 flips to lunch" do
    assert_equal :lunch, MealInferrer.call(Time.zone.local(2026, 4, 25, 10, 30))
  end

  test "afternoon maps to snack" do
    assert_equal :snacks, MealInferrer.call(Time.zone.local(2026, 4, 25, 15, 0))
  end

  test "evening maps to dinner" do
    assert_equal :dinner, MealInferrer.call(Time.zone.local(2026, 4, 25, 19, 0))
  end

  test "late night maps to snack" do
    assert_equal :snacks, MealInferrer.call(Time.zone.local(2026, 4, 25, 23, 0))
  end

  test "after midnight maps to snack" do
    assert_equal :snacks, MealInferrer.call(Time.zone.local(2026, 4, 25, 1, 30))
  end

  test "defaults to Time.current when no arg" do
    travel_to Time.zone.local(2026, 4, 25, 12, 0) do
      assert_equal :lunch, MealInferrer.call
    end
  end
end
