# frozen_string_literal: true

# Styled range slider. Defaults cover the common 0–500 grams case used by
# the quantity-preview bottom sheet and edit form, but min/max/step/value
# can be overridden for any other use. Extra Stimulus wiring (targets,
# actions) can be passed through the `data:` kwarg.
class SliderComponent < ViewComponent::Base
  def initialize(value: 0, min: 0, max: 500, step: 5, aria_label: nil, data: {})
    @value = value
    @min = min
    @max = max
    @step = step
    @aria_label = aria_label
    @data = data
  end
end
