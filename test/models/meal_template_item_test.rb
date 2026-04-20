require "test_helper"

class MealTemplateItemTest < ActiveSupport::TestCase
  test "factory is valid" do
    item = build(:meal_template_item)
    assert item.valid?, item.errors.full_messages.join(", ")
  end

  test "invalid without food" do
    item = build(:meal_template_item, food: nil)
    assert_not item.valid?
    assert_includes item.errors[:food], "must exist"
  end

  test "invalid without weight" do
    item = build(:meal_template_item, weight: nil)
    assert_not item.valid?
    assert_includes item.errors[:weight], "can't be blank"
  end

  test "invalid with weight zero" do
    item = build(:meal_template_item, weight: 0)
    assert_not item.valid?
    assert item.errors[:weight].any?
  end

  test "invalid with negative weight" do
    item = build(:meal_template_item, weight: -5)
    assert_not item.valid?
    assert item.errors[:weight].any?
  end

  test "belongs to meal_template" do
    item = create(:meal_template_item)
    assert_instance_of MealTemplate, item.meal_template
  end

  test "belongs to food" do
    item = create(:meal_template_item)
    assert_instance_of Food, item.food
  end
end
