class ButtonComponentPreview < Lookbook::Preview
  # @label Primary (md)
  def primary
    render ButtonComponent.new(label: "Log Breakfast", scheme: :primary)
  end

  # @label Primary (sm)
  def primary_small
    render ButtonComponent.new(label: "+ Add", scheme: :primary, size: :sm)
  end

  # @label Secondary (md)
  def secondary
    render ButtonComponent.new(label: "Cancel", scheme: :secondary)
  end

  # @label Secondary (sm)
  def secondary_small
    render ButtonComponent.new(label: "Edit", scheme: :secondary, size: :sm)
  end

  # @label As link
  def as_link
    render ButtonComponent.new(label: "View Food", tag: :a, href: "#")
  end
end
