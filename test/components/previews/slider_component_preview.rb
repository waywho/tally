# frozen_string_literal: true

class SliderComponentPreview < ViewComponent::Preview
  def default
    render(SliderComponent.new)
  end
end
