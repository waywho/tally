require "test_helper"

class OnboardingRedirectTest < ActionDispatch::IntegrationTest
  test "authenticated user without onboarded_at is redirected to onboarding" do
    account = create(:account)
    create(:user, :not_onboarded, account: account)
    login(account)

    get edit_settings_path
    assert_redirected_to step1_onboarding_path
  end

  test "authenticated user with onboarded_at is not redirected" do
    account = create(:account)
    create(:user, account: account)
    login(account)

    get edit_settings_path
    assert_response :success
  end

  test "unauthenticated user is not redirected to onboarding" do
    get root_path
    assert_redirected_to "/login"
  end

  test "full wizard flow completes without redirect loop" do
    account = create(:account)
    create(:user, :not_onboarded, account: account)
    login(account)

    # Should be redirected to onboarding from settings
    get edit_settings_path
    assert_redirected_to step1_onboarding_path

    # Complete step 1
    patch update_step1_onboarding_path, params: { user: { display_name: "Test" } }
    assert_redirected_to step2_onboarding_path

    # Complete step 2
    patch update_step2_onboarding_path, params: { user: { daily_calorie_target: 2000 } }
    assert_redirected_to step3_onboarding_path

    # Complete step 3
    patch finish_onboarding_path, params: {
      user: { protein_target: 50, carbs_target: 250, fat_target: 65, fiber_target: 30 }
    }
    assert_redirected_to root_path

    # Now should be able to access settings without redirect
    follow_redirect! # root -> settings (via PagesController)
    follow_redirect! # -> edit_settings_path
    assert_response :success
  end

  private

  def login(account)
    post "/login", params: { email: account.email, password: "password" }
  end
end
