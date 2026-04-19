require "test_helper"

class UsersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @account = create(:account)
    @user = create(:user, account: @account)
  end

  test "edit redirects when not authenticated" do
    get edit_settings_path
    assert_response :redirect
  end

  test "edit renders settings form when authenticated" do
    login(@account)
    get edit_settings_path
    assert_response :success
    assert_select "h2", "Profile"
    assert_select "h2", "Nutrition Targets"
    assert_select "h2", "Preferences"
    assert_select "h2", "Account"
    assert_select "input[name='user[display_name]']"
    assert_select "input[name='user[daily_calorie_target]']"
    assert_select "select[name='user[timezone]']"
  end

  test "update with valid params saves and redirects" do
    login(@account)
    patch settings_path, params: {
      user: {
        display_name: "New Name",
        daily_calorie_target: 1800,
        protein_target: 60,
        carbs_target: 200,
        fat_target: 70,
        fiber_target: 25,
        timezone: "London",
        unit_preference: "imperial",
        country: "GB",
        language: "en"
      }
    }
    assert_redirected_to edit_settings_path
    assert_equal "Settings saved.", flash[:notice]

    @user.reload
    assert_equal "New Name", @user.display_name
    assert_equal 1800, @user.daily_calorie_target
    assert_equal 60, @user.protein_target
    assert_equal 200, @user.carbs_target
    assert_equal 70, @user.fat_target
    assert_equal 25, @user.fiber_target
    assert_equal "London", @user.timezone
    assert @user.imperial?
    assert_equal "GB", @user.country
  end

  test "update with invalid params re-renders form" do
    login(@account)
    patch settings_path, params: {
      user: { daily_calorie_target: -1 }
    }
    assert_response :unprocessable_entity
    assert_select "p.field-error"
  end

  private

  def login(account)
    post "/login", params: { email: account.email, password: "password" }
  end
end
