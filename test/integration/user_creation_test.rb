require "test_helper"

class UserCreationTest < ActionDispatch::IntegrationTest
  test "creating an account automatically creates a user with defaults" do
    post "/create-account", params: {
      email: "auto-create@example.com",
      password: "password123",
      "password-confirm": "password123"
    }
    assert_response :redirect

    account = Account.find_by(email: "auto-create@example.com")
    assert account, "Account should be created"

    user = account.user
    assert user, "User should be auto-created"
    assert_equal 2000, user.daily_calorie_target
    assert_equal 50, user.protein_target
    assert_equal 250, user.carbs_target
    assert_equal 65, user.fat_target
    assert_equal 30, user.fiber_target
    assert_equal "UTC", user.timezone
    assert user.metric?
    assert_equal "en", user.language
    assert_nil user.country
    assert_match(/\A\w+ \w+\z/, user.display_name)
  end
end
