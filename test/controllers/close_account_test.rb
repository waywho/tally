require "test_helper"

# Apple requires an in-app account deletion path, so this flow is a release
# blocker rather than a nice-to-have.
class CloseAccountTest < ActionDispatch::IntegrationTest
  setup do
    @account = create(:account)
    @user = create(:user, account: @account)
    login(@account)
  end

  test "settings links to account deletion" do
    get edit_settings_path
    assert_response :success
    assert_select "a[href='/close-account']", text: /Delete account/
  end

  test "GET /close-account renders the confirmation form" do
    get "/close-account"
    assert_response :success
    assert_select "form[action='/close-account']"
  end

  test "closing the account deletes the account and everything it owns" do
    entry = create(:food_log_entry, user: @user)
    recipe = create(:recipe, user: @user)

    post "/close-account", params: { password: "password" }

    assert_nil Account.find_by(id: @account.id)
    assert_nil User.find_by(id: @user.id)
    assert_nil FoodLogEntry.find_by(id: entry.id)
    assert_nil Recipe.find_by(id: recipe.id)
  end

  test "wrong password leaves the account intact" do
    post "/close-account", params: { password: "not-the-password" }

    assert Account.exists?(@account.id)
    assert User.exists?(@user.id)
  end

  private

  def login(account)
    post "/login", params: { email: account.email, password: "password" }
  end
end
