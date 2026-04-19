require "test_helper"

class BucketHeaderComponentTest < ViewComponent::TestCase
  test "renders meal name" do
    render_inline(BucketHeaderComponent.new(meal: "Breakfast", subtotal: 470, add_path: "/days/2026-04-19/meals/breakfast/entries/new"))

    assert_selector ".font-semibold.text-primary", text: "Breakfast"
  end

  test "renders subtotal" do
    render_inline(BucketHeaderComponent.new(meal: "Lunch", subtotal: 620, add_path: "#"))

    assert_text "620 cal"
  end

  test "renders add link" do
    render_inline(BucketHeaderComponent.new(meal: "Dinner", subtotal: 0, add_path: "/add"))

    assert_selector "a[href='/add']", text: "+ Add"
  end
end
