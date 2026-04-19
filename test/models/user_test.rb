require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "factory is valid" do
    user = build(:user)
    assert user.valid?, user.errors.full_messages.join(", ")
  end

  test "belongs to account" do
    user = create(:user)
    assert_instance_of Account, user.account
  end

  test "account has one user" do
    user = create(:user)
    assert_equal user, user.account.user
  end

  test "destroying account destroys user" do
    user = create(:user)
    account = user.account
    account.destroy
    assert_not User.exists?(user.id)
  end

  # daily_calorie_target validations
  test "invalid without daily_calorie_target" do
    user = build(:user, daily_calorie_target: nil)
    assert_not user.valid?
    assert_includes user.errors[:daily_calorie_target], "can't be blank"
  end

  test "daily_calorie_target must be at least 1" do
    user = build(:user, daily_calorie_target: 0)
    assert_not user.valid?
    assert user.errors[:daily_calorie_target].any?
  end

  test "daily_calorie_target must be at most 10000" do
    user = build(:user, daily_calorie_target: 10_001)
    assert_not user.valid?
    assert user.errors[:daily_calorie_target].any?
  end

  # macro target validations
  %i[protein_target carbs_target fat_target fiber_target].each do |attr|
    test "invalid without #{attr}" do
      user = build(:user, attr => nil)
      assert_not user.valid?
      assert_includes user.errors[attr], "can't be blank"
    end

    test "#{attr} must be at least 0" do
      user = build(:user, attr => -1)
      assert_not user.valid?
      assert user.errors[attr].any?
    end

    test "#{attr} must be at most 1000" do
      user = build(:user, attr => 1001)
      assert_not user.valid?
      assert user.errors[attr].any?
    end
  end

  # timezone validation
  test "invalid with unknown timezone" do
    user = build(:user, timezone: "Mars/Olympus")
    assert_not user.valid?
    assert user.errors[:timezone].any?
  end

  test "valid with known timezone" do
    user = build(:user, timezone: "Eastern Time (US & Canada)")
    assert user.valid?
  end

  # language validation
  test "invalid with unsupported language" do
    user = build(:user, language: "klingon")
    assert_not user.valid?
    assert user.errors[:language].any?
  end

  test "valid with supported language" do
    user = build(:user, language: "en")
    assert user.valid?
  end

  # country validation
  test "valid without country" do
    user = build(:user, country: nil)
    assert user.valid?
  end

  test "valid with known country code" do
    user = build(:user, country: "GB")
    assert user.valid?
  end

  test "invalid with unknown country code" do
    user = build(:user, country: "ZZ")
    assert_not user.valid?
    assert user.errors[:country].any?
  end

  test "invalid with lowercase country code" do
    user = build(:user, country: "gb")
    assert_not user.valid?
    assert user.errors[:country].any?
  end

  # display_name validation
  test "valid with blank display name" do
    user = build(:user, display_name: "")
    assert user.valid?
  end

  test "invalid with display name over 100 characters" do
    user = build(:user, display_name: "a" * 101)
    assert_not user.valid?
    assert user.errors[:display_name].any?
  end

  # unit_preference enum
  test "default unit preference is metric" do
    user = User.new
    assert user.metric?
  end

  test "can set unit preference to imperial" do
    user = build(:user, unit_preference: :imperial)
    assert user.imperial?
  end
end
