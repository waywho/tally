require "test_helper"

class FoodTest < ActiveSupport::TestCase
  # Factory
  test "factory is valid" do
    food = build(:food)
    assert food.valid?, food.errors.full_messages.join(", ")
  end

  test "usda trait is valid" do
    food = build(:food, :usda)
    assert food.valid?, food.errors.full_messages.join(", ")
  end

  test "user_created trait is valid" do
    food = build(:food, :user_created)
    assert food.valid?, food.errors.full_messages.join(", ")
  end

  # Name validations
  test "invalid without name" do
    food = build(:food, name: nil)
    assert_not food.valid?
    assert_includes food.errors[:name], "can't be blank"
  end

  test "invalid with name over 255 characters" do
    food = build(:food, name: "a" * 256)
    assert_not food.valid?
    assert food.errors[:name].any?
  end

  # Nutritional validations
  %i[calories protein carbs fat].each do |attr|
    test "invalid without #{attr}" do
      food = build(:food, attr => nil)
      assert_not food.valid?
      assert_includes food.errors[attr], "can't be blank"
    end

    test "invalid with negative #{attr}" do
      food = build(:food, attr => -1)
      assert_not food.valid?
      assert food.errors[attr].any?
    end

    test "valid with zero #{attr}" do
      food = build(:food, attr => 0)
      assert food.valid?
    end
  end

  test "invalid with negative fiber" do
    food = build(:food, fiber: -1)
    assert_not food.valid?
    assert food.errors[:fiber].any?
  end

  test "valid with zero fiber" do
    food = build(:food, fiber: 0)
    assert food.valid?
  end

  # Source enum
  test "source enum values" do
    assert Food.sources.key?("off")
    assert Food.sources.key?("usda")
    assert Food.sources.key?("user")
  end

  test "off? returns true for off source" do
    food = build(:food, source: :off)
    assert food.off?
  end

  test "usda? returns true for usda source" do
    food = build(:food, :usda)
    assert food.usda?
  end

  test "user? returns true for user source" do
    food = build(:food, :user_created)
    assert food.user?
  end

  # External ID uniqueness
  test "external_id must be unique within same source" do
    create(:food, source: :off, external_id: "dup-123")
    duplicate = build(:food, source: :off, external_id: "dup-123")
    assert_not duplicate.valid?
    assert duplicate.errors[:external_id].any?
  end

  test "external_id can be same across different sources" do
    create(:food, source: :off, external_id: "shared-123")
    food = build(:food, source: :usda, external_id: "shared-123")
    assert food.valid?
  end

  test "multiple foods can have nil external_id" do
    create(:food, :user_created, external_id: nil)
    food = build(:food, :user_created, external_id: nil)
    assert food.valid?
  end

  # Creator validation
  test "creator_id required for user source" do
    food = build(:food, source: :user, creator_id: nil, external_id: nil)
    assert_not food.valid?
    assert_includes food.errors[:creator_id], "is required for user-created foods"
  end

  test "creator_id not required for off source" do
    food = build(:food, source: :off, creator_id: nil)
    assert food.valid?
  end

  test "creator_id not required for usda source" do
    food = build(:food, :usda, creator_id: nil)
    assert food.valid?
  end

  # Associations
  test "belongs to creator" do
    food = create(:food, :user_created)
    assert_instance_of User, food.creator
  end

  test "user has many created foods" do
    user = create(:user)
    create(:food, :user_created, creator: user)
    create(:food, :user_created, creator: user)
    assert_equal 2, user.created_foods.count
  end

  test "destroying user destroys created foods" do
    user = create(:user)
    create(:food, :user_created, creator: user)
    assert_difference "Food.count", -1 do
      user.destroy
    end
  end

  # Searchable tsvector
  test "searchable column is populated from name and brand" do
    food = create(:food, name: "Chicken Breast", brand: "Tesco")
    food.reload
    assert_not_nil food.searchable
  end
end
