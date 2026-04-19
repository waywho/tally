require "test_helper"

class ButtonComponentTest < ViewComponent::TestCase
  test "renders primary button with label" do
    render_inline(ButtonComponent.new(label: "Log Breakfast"))

    assert_selector "button.bg-primary", text: "Log Breakfast"
  end

  test "renders secondary button" do
    render_inline(ButtonComponent.new(label: "Cancel", scheme: :secondary))

    assert_selector "button.border-primary", text: "Cancel"
    assert_no_selector "button.bg-primary"
  end

  test "renders small size" do
    render_inline(ButtonComponent.new(label: "Add", size: :sm))

    assert_selector "button.px-3.py-1\\.5.text-sm"
  end

  test "renders as link when tag is :a" do
    render_inline(ButtonComponent.new(label: "Go", tag: :a, href: "/foods"))

    assert_selector "a[href='/foods']", text: "Go"
  end
end
