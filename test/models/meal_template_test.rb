require "test_helper"

class MealTemplateTest < ActiveSupport::TestCase
  test "factory is valid" do
    template = build(:meal_template)
    assert template.valid?, template.errors.full_messages.join(", ")
  end

  # Validations
  test "invalid without name" do
    template = build(:meal_template, name: nil)
    assert_not template.valid?
    assert_includes template.errors[:name], "can't be blank"
  end

  test "invalid with name over 255 characters" do
    template = build(:meal_template, name: "a" * 256)
    assert_not template.valid?
    assert template.errors[:name].any?
  end

  test "invalid without user" do
    template = build(:meal_template, user: nil)
    assert_not template.valid?
    assert_includes template.errors[:user], "must exist"
  end

  # Associations
  test "belongs to user" do
    template = create(:meal_template)
    assert_instance_of User, template.user
  end

  test "has many meal_template_items with dependent destroy" do
    template = create(:meal_template)
    create(:meal_template_item, meal_template: template)
    create(:meal_template_item, meal_template: template)

    assert_equal 2, template.meal_template_items.count

    assert_difference "MealTemplateItem.count", -2 do
      template.destroy!
    end
  end
end
