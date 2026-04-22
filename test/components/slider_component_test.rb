# frozen_string_literal: true

require "test_helper"

class SliderComponentTest < ViewComponent::TestCase
  def test_renders_range_input_with_defaults
    render_inline(SliderComponent.new)

    input = page.find("input")
    assert_equal "range", input["type"]
    assert_equal "0", input["value"]
    assert_equal "0", input["min"]
    assert_equal "500", input["max"]
    assert_equal "5", input["step"]
  end

  def test_passes_through_overrides_and_data_attributes
    render_inline(
      SliderComponent.new(
        value: 42,
        min: 10,
        max: 200,
        step: 1,
        aria_label: "Volume",
        data: { controller: "vol", action: "input->vol#change" }
      )
    )

    input = page.find("input")
    assert_equal "42", input["value"]
    assert_equal "10", input["min"]
    assert_equal "200", input["max"]
    assert_equal "1", input["step"]
    assert_equal "Volume", input["aria-label"]
    assert_equal "vol", input["data-controller"]
    assert_equal "input->vol#change", input["data-action"]
  end
end
