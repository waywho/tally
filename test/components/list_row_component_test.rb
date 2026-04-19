require "test_helper"

class ListRowComponentTest < ViewComponent::TestCase
  test "renders label and value" do
    render_inline(ListRowComponent.new(label: "Oatmeal with banana", value: "320 cal"))

    assert_text "Oatmeal with banana"
    assert_selector ".text-primary.font-semibold", text: "320 cal"
  end

  test "renders with flex layout" do
    render_inline(ListRowComponent.new(label: "Greek yogurt", value: "150 cal"))

    assert_selector "div.flex.justify-between.items-center"
  end
end
