# frozen_string_literal: true

class BottomNavComponentPreview < ViewComponent::Preview
  def default
    render(BottomNavComponent.new)
  end
end
