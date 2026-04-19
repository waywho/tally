require "test_helper"

class CardComponentTest < ViewComponent::TestCase
  test "renders card with content block" do
    render_inline(CardComponent.new) { "Hello" }

    assert_selector "div.bg-bg.border.border-border.rounded-md.overflow-hidden", text: "Hello"
  end

  test "passes through additional classes" do
    render_inline(CardComponent.new(class: "mt-4")) { "Content" }

    assert_selector "div.mt-4.bg-bg"
  end
end
