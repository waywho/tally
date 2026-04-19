require "test_helper"

class OnboardingControllerTest < ActionDispatch::IntegrationTest
  setup do
    @account = create(:account)
    @user = create(:user, :not_onboarded, account: @account)
  end

  # Authentication
  test "show redirects when not authenticated" do
    get onboarding_step_path(:step1)
    assert_response :redirect
  end

  # Rendering steps
  test "show step1 renders when not onboarded" do
    login(@account)
    get onboarding_step_path(:step1)
    assert_response :success
    assert_select "h2", "Welcome to Tally!"
  end

  test "show step2 renders when not onboarded" do
    login(@account)
    get onboarding_step_path(:step2)
    assert_response :success
    assert_select "h2", "Daily Calorie Target"
  end

  test "show step3 renders when not onboarded" do
    login(@account)
    get onboarding_step_path(:step3)
    assert_response :success
    assert_select "h2", "Macro Targets"
  end

  # Redirect if already onboarded
  test "show redirects to root when already onboarded" do
    @user.update!(onboarded_at: Time.current)
    login(@account)
    get onboarding_step_path(:step1)
    assert_redirected_to root_path
  end

  # update step1
  test "update step1 saves display name and redirects to step2" do
    login(@account)
    patch update_onboarding_step_path(:step1), params: { user: { display_name: "New Name" } }
    assert_redirected_to onboarding_step_path(:step2)
    assert_equal "New Name", @user.reload.display_name
  end

  # update step2
  test "update step2 saves calorie target and redirects to step3" do
    login(@account)
    patch update_onboarding_step_path(:step2), params: { user: { daily_calorie_target: 1800 } }
    assert_redirected_to onboarding_step_path(:step3)
    assert_equal 1800, @user.reload.daily_calorie_target
  end

  # update step3 (finish)
  test "update step3 saves macros and onboarded_at and redirects to root" do
    login(@account)
    patch update_onboarding_step_path(:step3), params: {
      user: {
        protein_target: 60,
        carbs_target: 200,
        fat_target: 70,
        fiber_target: 25
      }
    }
    assert_redirected_to root_path
    assert_equal "You're all set! Start tracking your nutrition.", flash[:notice]

    @user.reload
    assert_equal 60, @user.protein_target
    assert_equal 200, @user.carbs_target
    assert_equal 70, @user.fat_target
    assert_equal 25, @user.fiber_target
    assert_not_nil @user.onboarded_at
  end

  # skip
  test "skip sets onboarded_at without changing other fields and redirects" do
    login(@account)
    original_calories = @user.daily_calorie_target
    post skip_onboarding_path
    assert_redirected_to root_path

    @user.reload
    assert_not_nil @user.onboarded_at
    assert_equal original_calories, @user.daily_calorie_target
  end

  private

  def login(account)
    post "/login", params: { email: account.email, password: "password" }
  end
end
