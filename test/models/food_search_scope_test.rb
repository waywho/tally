require "test_helper"

class FoodSearchScopeTest < ActiveSupport::TestCase
  setup do
    @chicken = create(:food, name: "Chicken breast, raw", brand: nil, source: :usda, external_id: "usda-chicken")
    @chicken_stir = create(:food, name: "Chicken stir fry", brand: "Homemade", source: :user, external_id: nil, creator: create(:user))
    @pasta = create(:food, name: "Pasta, dry", brand: "Barilla", source: :off, external_id: "off-pasta")
  end

  test "search finds foods by name using full-text search" do
    results = Food.search("chicken")
    assert_includes results, @chicken
    assert_not_includes results, @chicken_stir
    assert_not_includes results, @pasta
  end

  test "search with user includes that user's custom foods" do
    user = create(:user)
    custom = create(:food, name: "Chicken custom", source: :user, external_id: nil, creator: user)

    results = Food.search("chicken", user: user)

    assert_includes results, custom
    assert_includes results, @chicken
  end

  test "search with user excludes other users' custom foods" do
    other_user = create(:user)
    other_custom = create(:food, name: "Chicken other", source: :user, external_id: nil, creator: other_user)

    user = create(:user)
    results = Food.search("chicken", user: user)

    assert_not_includes results, other_custom
    assert_includes results, @chicken
  end

  test "search without user excludes all user-created foods" do
    results = Food.search("chicken")

    assert_includes results, @chicken
    assert_not_includes results, @chicken_stir
  end

  test "search finds foods by brand" do
    results = Food.search("barilla")
    assert_includes results, @pasta
    assert_not_includes results, @chicken
  end

  test "search returns empty when no matches" do
    results = Food.search("nonexistent food xyz")
    assert_empty results
  end

  test "search respects limit" do
    results = Food.search("chicken", limit: 1)
    assert_equal 1, results.size
  end

  test "search returns empty for blank query" do
    assert_empty Food.search("")
    assert_empty Food.search(nil)
  end
end
