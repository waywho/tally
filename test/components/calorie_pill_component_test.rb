require "test_helper"

class CaloriePillComponentTest < ViewComponent::TestCase
  test "renders eaten and target calories" do
    render_inline(CaloriePillComponent.new(
      eaten: 470, target: 2000,
      protein: "28g / 150g", carbs: "52g / 250g", fat: "12g / 67g", fiber: "8g / 30g"
    ))

    assert_text "470"
    assert_text "/ 2,000 cal"
    assert_text "1,530 remaining"
  end

  test "renders macro summary with fiber" do
    render_inline(CaloriePillComponent.new(
      eaten: 470, target: 2000,
      protein: "28g / 150g", carbs: "52g / 250g", fat: "12g / 67g", fiber: "8g / 30g"
    ))

    assert_text "P: 28g / 150g"
    assert_text "C: 52g / 250g"
    assert_text "F: 12g / 67g"
    assert_text "Fiber: 8g / 30g"
  end

  test "renders progress bar at correct width" do
    render_inline(CaloriePillComponent.new(
      eaten: 500, target: 2000,
      protein: "0g / 0g", carbs: "0g / 0g", fat: "0g / 0g", fiber: "0g / 0g"
    ))

    assert_selector "[style*='width: 25%']"
  end

  test "shows over-target state" do
    render_inline(CaloriePillComponent.new(
      eaten: 2150, target: 2000,
      protein: "0g / 0g", carbs: "0g / 0g", fat: "0g / 0g", fiber: "0g / 0g"
    ))

    assert_text "150 over"
    assert_selector ".bg-danger"
  end
end
